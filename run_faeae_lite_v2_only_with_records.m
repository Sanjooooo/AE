function summary = run_faeae_lite_v2_only_with_records(resultDir)
%RUN_FAEAE_LITE_V2_ONLY_WITH_RECORDS
% 只跑 FAEAE-lite-v2，并保存：
%   1) run_records/*.mat
%   2) uav_comparison_runs.csv
%   3) uav_comparison_summary_long.csv
%   4) uav_comparison_average_rank.csv
%   5) uav_comparison_summary_workspace.mat
%   6) uav_comparison_results.mat
%
% 用法：
%   run_faeae_lite_v2_only_with_records
%   run_faeae_lite_v2_only_with_records('F:\...\results_uav_lite_v2_fair_only_faeae_records')

    if nargin < 1 || isempty(resultDir)
        resultDir = fullfile(pwd, 'results_uav_lite_v2_fair_only_faeae_records');
    end

    if ~exist(resultDir, 'dir')
        mkdir(resultDir);
    end

    runDir = fullfile(resultDir, 'run_records');
    if ~exist(runDir, 'dir')
        mkdir(runDir);
    end

    addpath(genpath(pwd));

    % ------------------------------------------------------------
    % cfg
    % ------------------------------------------------------------
    cfg = getUAVComparisonConfig('formal');
    cfg.resultDir = resultDir;
    cfg.algorithms = {'FAEAE'};
    cfg.sceneIds = [1, 2, 4];

    % 与论文主实验一致：公平初始化
    cfg.useFairReferenceInit = true;
    cfg.fairReferenceInitRatio = 0.7;
    cfg.fairReferenceNoiseScale = 0.05;

    % 使用 lite v2
    cfg.useLiteFAEAE = true;

    % 尽量对齐你原 full-batch 中 FAEAE 的随机种子位置
    cfg.baseSeed = 20260328 + 100 * (6 - 1);

    algName = 'FAEAE';
    nScenes = numel(cfg.sceneIds);
    nRuns = cfg.nRuns;

    runRows = [];
    allResults = cell(nScenes, 1);

    fprintf('\n============================================================\n');
    fprintf('Run FAEAE-lite-v2 only (with run_records)\n');
    fprintf('Result folder : %s\n', resultDir);
    fprintf('Run folder    : %s\n', runDir);
    fprintf('Scenes        : %s\n', mat2str(cfg.sceneIds));
    fprintf('Runs          : %d\n', nRuns);
    fprintf('============================================================\n\n');

    for s = 1:nScenes
        sceneId = cfg.sceneIds(s);

        params = defaultParams();
        params.sceneId = sceneId;

        map = createMap(params);
        refCtrl = generateReferencePath(map, params);
        refX = encodeControlPoints(refCtrl);
        objFun = @(x) fitnessFAEAE(x, map, params);

        algCfg = getUAVAlgorithmConfig(algName, params, cfg);

        runs = struct([]);
        
        fprintf('--- Scene %d | %s ---\n', sceneId, algName);
        
        for r = 1:nRuns
            runSeed = cfg.baseSeed + 10000 * sceneId + 100 * 1 + r;
        
            result = optimizer_FAEAE_lite_v2_uav(objFun, params, map, refX, algCfg, runSeed);
        
            % 补兼容字段
            if ~isfield(result, 'bestFitness') && isfield(result, 'bestFit')
                result.bestFitness = result.bestFit;
            end
            if ~isfield(result, 'runtime') && isfield(result, 'runTime')
                result.runtime = result.runTime;
            end
            if ~isfield(result, 'runTime') && isfield(result, 'runtime')
                result.runTime = result.runtime;
            end
            if ~isfield(result, 'convergence') && isfield(result, 'bestHist')
                result.convergence = result.bestHist;
            end
            if ~isfield(result, 'bestHist') && isfield(result, 'convergence')
                result.bestHist = result.convergence;
            end
            if ~isfield(result, 'finalFeasible')
                if isfield(result, 'bestDetail') && isfield(result.bestDetail, 'isFeasible')
                    result.finalFeasible = result.bestDetail.isFeasible;
                else
                    result.finalFeasible = NaN;
                end
            end
            if ~isfield(result, 'finalViolation')
                if isfield(result, 'bestDetail') && isfield(result.bestDetail, 'V')
                    result.finalViolation = result.bestDetail.V;
                else
                    result.finalViolation = NaN;
                end
            end
        
            result.sceneId = sceneId;
            result.runId = r;
            result.seed = runSeed;
            result.algName = algName;
        
            % ===== 关键：先对齐字段，再追加 =====
            if isempty(runs)
                runs = result;
            else
                [runs, result] = localAlignStructArrayAndScalar(runs, result);
                runs(end+1) = result;
            end
        
            save(fullfile(runDir, sprintf('scene%d_FAEAE_run%03d.mat', sceneId, r)), 'result');
        
            row = table( ...
                sceneId, {algName}, r, runSeed, ...
                result.bestFitness, result.runtime, ...
                logical(result.finalFeasible), result.finalViolation, result.runtime, ...
                'VariableNames', {'Scene','Algorithm','Run','Seed','BestFitness','Runtime','Feasible','Violation','WallClock'} );
        
            if isempty(runRows)
                runRows = row;
            else
                runRows = [runRows; row]; %#ok<AGROW>
            end
        
            fprintf('  run %2d/%2d | best = %.6f | feas = %d | time = %.3fs\n', ...
                r, nRuns, result.bestFitness, logical(result.finalFeasible), result.runtime);
        end

        allResults{s,1} = runs;
    end

    % ------------------------------------------------------------
    % 导出 runs.csv
    % ------------------------------------------------------------
    writetable(runRows, fullfile(resultDir, 'uav_comparison_runs.csv'));

    % ------------------------------------------------------------
    % summary_long
    % ------------------------------------------------------------
    summaryLong = build_summary_long_from_runs(runRows, cfg.sceneIds, {algName});
    writetable(summaryLong, fullfile(resultDir, 'uav_comparison_summary_long.csv'));

    % ------------------------------------------------------------
    % average_rank
    % ------------------------------------------------------------
    avgRank = table({algName}', 1, 'VariableNames', {'Algorithm','AverageRank'});
    writetable(avgRank, fullfile(resultDir, 'uav_comparison_average_rank.csv'));

    % ------------------------------------------------------------
    % workspace
    % ------------------------------------------------------------
    summary = struct();
    summary.runTable = runRows;
    summary.longTable = summaryLong;
    summary.avgRankTable = avgRank;
    save(fullfile(resultDir, 'uav_comparison_summary_workspace.mat'), 'summary', 'cfg');

    % ------------------------------------------------------------
    % uav_comparison_results.mat
    % ------------------------------------------------------------
    save(fullfile(resultDir, 'uav_comparison_results.mat'), 'allResults', 'cfg', '-v7.3');

    fprintf('\nDone.\n');
    fprintf('Saved:\n');
    fprintf('  %s\n', fullfile(resultDir, 'uav_comparison_runs.csv'));
    fprintf('  %s\n', fullfile(resultDir, 'uav_comparison_summary_long.csv'));
    fprintf('  %s\n', fullfile(resultDir, 'uav_comparison_average_rank.csv'));
    fprintf('  %s\n', fullfile(resultDir, 'uav_comparison_summary_workspace.mat'));
    fprintf('  %s\n', fullfile(resultDir, 'uav_comparison_results.mat'));
    fprintf('  %s\n', runDir);
end

%% ========================================================================
function T = build_summary_long_from_runs(runRows, sceneIds, algorithms)

rows = table();

for s = 1:numel(sceneIds)
    sid = sceneIds(s);

    means = nan(1, numel(algorithms));
    stds  = nan(1, numel(algorithms));

    for a = 1:numel(algorithms)
        alg = algorithms{a};
        mask = runRows.Scene == sid & strcmpi(runRows.Algorithm, alg);
        vals = runRows.BestFitness(mask);
        means(a) = mean(vals, 'omitnan');
        stds(a) = std(vals, 'omitnan');
    end

    [~, order] = sort(means, 'ascend');
    rankVals = nan(1, numel(algorithms));
    rankVals(order) = 1:numel(algorithms);

    for a = 1:numel(algorithms)
        alg = algorithms{a};
        mask = runRows.Scene == sid & strcmpi(runRows.Algorithm, alg);

        row = table( ...
            sid, {alg}, ...
            means(a), stds(a), rankVals(a), ...
            mean(double(runRows.Feasible(mask)), 'omitnan'), ...
            mean(runRows.Runtime(mask), 'omitnan'), ...
            'VariableNames', {'Scene','Algorithm','Mean','Std','Rank','Feasibility','AvgRuntime'} );

        if isempty(rows)
            rows = row;
        else
            rows = [rows; row]; %#ok<AGROW>
        end
    end
end

T = rows;
end

function [A, b] = localAlignStructArrayAndScalar(A, b)
% 让 struct 数组 A 和单个 struct b 拥有完全一致的字段集合

aFields = fieldnames(A);
bFields = fieldnames(b);

allFields = unique([aFields; bFields]);

% 给 A 补字段
for i = 1:numel(allFields)
    fn = allFields{i};
    if ~isfield(A, fn)
        A = localAddMissingFieldToStructArray(A, fn, b);
    end
end

% 给 b 补字段
for i = 1:numel(allFields)
    fn = allFields{i};
    if ~isfield(b, fn)
        b.(fn) = localDefaultValueLike(A(1).(fn));
    end
end

% 统一字段顺序
A = orderfields(A, b);
b = orderfields(b, A(1));
end

function S = localAddMissingFieldToStructArray(S, fieldName, refStruct)
% 给 struct 数组 S 增加缺失字段 fieldName，默认值参考 refStruct 中对应字段类型

defaultVal = localDefaultValueLike(refStruct.(fieldName));

for k = 1:numel(S)
    S(k).(fieldName) = defaultVal;
end
end

function v = localDefaultValueLike(example)
% 根据示例值生成一个默认值

if isnumeric(example)
    if isscalar(example)
        v = NaN;
    else
        v = nan(size(example));
    end
elseif islogical(example)
    v = false;
elseif ischar(example)
    v = '';
elseif isstring(example)
    v = "";
elseif iscell(example)
    v = cell(size(example));
elseif isstruct(example)
    v = struct();
else
    v = [];
end
end