function summary = run_uav_ablation_lite_v2_batch(cfg)
%RUN_UAV_ABLATION_LITE_V2_BATCH
% UAV ablation batch for lite-v2 FAEAE.
%
% Ablation groups:
%   1) Base-AE
%   2) AE+Init
%   3) AE+Init+AOS
%   4) AE+Init+AOS+Repair
%   5) FAEAE
%
% Output files:
% - uav_comparison_runs.csv
% - uav_comparison_summary_long.csv
% - uav_comparison_average_rank.csv
% - uav_comparison_summary_workspace.mat
% - uav_comparison_results.mat
% - run_records/*.mat

if nargin < 1 || isempty(cfg)
    cfg = struct();
end

if ~isfield(cfg, 'sceneIds') || isempty(cfg.sceneIds)
    cfg.sceneIds = [1, 2, 4];
end
if ~isfield(cfg, 'algorithms') || isempty(cfg.algorithms)
    cfg.algorithms = {'Base-AE', 'AE+Init', 'AE+Init+AOS', 'AE+Init+AOS+Repair', 'FAEAE'};
end
if ~isfield(cfg, 'nRuns') || isempty(cfg.nRuns)
    cfg.nRuns = 30;
end
if ~isfield(cfg, 'baseSeed') || isempty(cfg.baseSeed)
    cfg.baseSeed = 20260329;
end
if ~isfield(cfg, 'resultDir') || isempty(cfg.resultDir)
    cfg.resultDir = fullfile(pwd, ['results_uav_ablation_lite_v2_' datestr(now, 'yyyymmdd_HHMMSS')]);
end

% 为了与主实验一致，给带 Init 的版本统一参考初始化参数
if ~isfield(cfg, 'referenceInitRatio')
    cfg.referenceInitRatio = 0.7;
end
if ~isfield(cfg, 'referenceNoiseScale')
    cfg.referenceNoiseScale = 0.05;
end

if ~exist(cfg.resultDir, 'dir')
    mkdir(cfg.resultDir);
end

runDir = fullfile(cfg.resultDir, 'run_records');
if ~exist(runDir, 'dir')
    mkdir(runDir);
end

nScenes = numel(cfg.sceneIds);
nAlgs   = numel(cfg.algorithms);
nRuns   = cfg.nRuns;

runRows = [];
allResults = cell(nScenes, nAlgs);

fprintf('\n============================================================\n');
fprintf('UAV Ablation Lite-V2 Batch Experiment\n');
fprintf('Result folder : %s\n', cfg.resultDir);
fprintf('Run folder    : %s\n', runDir);
fprintf('Scenes        : %s\n', mat2str(cfg.sceneIds));
fprintf('Algorithms    : %s\n', strjoin(cfg.algorithms, ', '));
fprintf('Runs          : %d\n', cfg.nRuns);
fprintf('============================================================\n\n');

for s = 1:nScenes
    sceneId = cfg.sceneIds(s);

    params = defaultParams();
    params.sceneId = sceneId;

    if isfield(cfg, 'paramsOverride') && isstruct(cfg.paramsOverride)
        params = localApplyOverrides(params, cfg.paramsOverride);
    end

    map = createMap(params);
    refCtrl = generateReferencePath(map, params);
    refX = encodeControlPoints(refCtrl);
    objFun = @(x) fitnessFAEAE(x, map, params);

    for a = 1:nAlgs
        algName = cfg.algorithms{a};
        algCfg = localGetAblationConfig(algName, params, cfg);

        fprintf('--- Scene %d | %s ---\n', sceneId, algName);

        runs = struct([]);
        okCount = 0;

        for r = 1:nRuns
            runSeed = cfg.baseSeed + 10000 * sceneId + 100 * a + r;
            tRun = tic;

            try
                result = localRunSingleAblation(objFun, params, map, refX, algCfg, runSeed);
                elapsed = toc(tRun);

                result = localNormalizeResultStruct(result, sceneId, algName, r, runSeed);

                save(fullfile(runDir, sprintf('scene%d_%s_run%03d.mat', sceneId, localSafeName(algName), r)), 'result');

                if isempty(runs)
                    runs = result;
                else
                    [runs, result] = localAlignStructArrayAndScalar(runs, result);
                    runs(end+1) = result;
                end
                okCount = okCount + 1;

                row = table( ...
                    sceneId, {algName}, r, runSeed, ...
                    result.bestFitness, result.runtime, ...
                    logical(result.finalFeasible), result.finalViolation, ...
                    elapsed, ...
                    'VariableNames', {'Scene','Algorithm','Run','Seed','BestFitness','Runtime','Feasible','Violation','WallClock'} );

                if isempty(runRows)
                    runRows = row;
                else
                    runRows = [runRows; row]; %#ok<AGROW>
                end

                fprintf('  run %2d/%2d | best = %.6f | feas = %d | time = %.3fs\n', ...
                    r, nRuns, result.bestFitness, logical(result.finalFeasible), result.runtime);

            catch ME
                warning('Scene %d | %s | run %d failed: %s', sceneId, algName, r, ME.message);
            end
        end

        allResults{s, a} = runs;
        fprintf('  -> Scene %d | %s saved %d/%d runs\n', sceneId, algName, okCount, nRuns);
    end
end

if isempty(runRows)
    error('No UAV ablation results were produced.');
end

writetable(runRows, fullfile(cfg.resultDir, 'uav_comparison_runs.csv'));

summaryLong = localBuildSummary(runRows, cfg.sceneIds, cfg.algorithms);
writetable(summaryLong, fullfile(cfg.resultDir, 'uav_comparison_summary_long.csv'));

avgRank = localAverageRank(summaryLong, cfg.algorithms);
writetable(avgRank, fullfile(cfg.resultDir, 'uav_comparison_average_rank.csv'));

summary = struct();
summary.runTable = runRows;
summary.longTable = summaryLong;
summary.avgRankTable = avgRank;
save(fullfile(cfg.resultDir, 'uav_comparison_summary_workspace.mat'), 'summary', 'cfg');

save(fullfile(cfg.resultDir, 'uav_comparison_results.mat'), 'allResults', 'cfg', '-v7.3');

fprintf('\nSaved:\n');
fprintf('  %s\n', fullfile(cfg.resultDir, 'uav_comparison_runs.csv'));
fprintf('  %s\n', fullfile(cfg.resultDir, 'uav_comparison_summary_long.csv'));
fprintf('  %s\n', fullfile(cfg.resultDir, 'uav_comparison_average_rank.csv'));
fprintf('  %s\n', fullfile(cfg.resultDir, 'uav_comparison_summary_workspace.mat'));
fprintf('  %s\n', fullfile(cfg.resultDir, 'uav_comparison_results.mat'));
fprintf('  %s\n', runDir);

summary.resultDir = cfg.resultDir;
summary.runDir = runDir;
end

% ========================================================================
function algCfg = localGetAblationConfig(algName, params, cfg)
% 全五组统一走 lite-v2 骨架
% 差别只在模块开关

algCfg = getUAVAlgorithmConfig('FAEAE', params, cfg);
algCfg.runner = 'FAEAE_LITE_V2';

% 统一给带 Init 的版本设置参考初始化参数
algCfg.referenceInitRatio = cfg.referenceInitRatio;
algCfg.referenceNoiseScale = cfg.referenceNoiseScale;

switch upper(strtrim(algName))
    case 'BASE-AE'
        algCfg.useReferenceInit = false;
        algCfg.useAOS = false;
        algCfg.useRepair = false;
        algCfg.useRegen = false;

    case 'AE+INIT'
        algCfg.useReferenceInit = true;
        algCfg.useAOS = false;
        algCfg.useRepair = false;
        algCfg.useRegen = false;

    case 'AE+INIT+AOS'
        algCfg.useReferenceInit = true;
        algCfg.useAOS = true;
        algCfg.useRepair = false;
        algCfg.useRegen = false;

    case 'AE+INIT+AOS+REPAIR'
        algCfg.useReferenceInit = true;
        algCfg.useAOS = true;
        algCfg.useRepair = true;
        algCfg.useRegen = false;

    case 'FAEAE'
        algCfg.useReferenceInit = true;
        algCfg.useAOS = true;
        algCfg.useRepair = true;
        algCfg.useRegen = true;

    otherwise
        error('Unknown ablation algorithm: %s', algName);
end
end

% ========================================================================
function result = localRunSingleAblation(objFun, params, map, refX, algCfg, runSeed)
% 全部统一走 lite-v2 执行器
result = optimizer_FAEAE_lite_v2_uav(objFun, params, map, refX, algCfg, runSeed);
end

% ========================================================================
function result = localNormalizeResultStruct(result, sceneId, algName, runId, runSeed)
if ~isfield(result, 'bestFitness') && isfield(result, 'bestFit')
    result.bestFitness = result.bestFit;
end
if ~isfield(result, 'bestFit') && isfield(result, 'bestFitness')
    result.bestFit = result.bestFitness;
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
    if isfield(result, 'bestDetail') && isstruct(result.bestDetail) && isfield(result.bestDetail, 'isFeasible')
        result.finalFeasible = result.bestDetail.isFeasible;
    elseif isfield(result, 'isFeasible')
        result.finalFeasible = result.isFeasible;
    else
        result.finalFeasible = false;
    end
end

if ~isfield(result, 'finalViolation')
    if isfield(result, 'bestDetail') && isstruct(result.bestDetail) && isfield(result.bestDetail, 'V')
        result.finalViolation = result.bestDetail.V;
    elseif isfield(result, 'violation')
        result.finalViolation = result.violation;
    else
        result.finalViolation = NaN;
    end
end

if ~isfield(result, 'sceneId')
    result.sceneId = sceneId;
end
if ~isfield(result, 'runId')
    result.runId = runId;
end
if ~isfield(result, 'seed')
    result.seed = runSeed;
end
if ~isfield(result, 'algName')
    result.algName = algName;
end
end

% ========================================================================
function safe = localSafeName(name)
safe = upper(name);
safe = strrep(safe, '+', '_');
safe = strrep(safe, '-', '_');
safe = strrep(safe, ' ', '_');
end

% ========================================================================
function [A, b] = localAlignStructArrayAndScalar(A, b)
aFields = fieldnames(A);
bFields = fieldnames(b);
allFields = unique([aFields; bFields]);

for i = 1:numel(allFields)
    fn = allFields{i};
    if ~isfield(A, fn)
        defaultVal = localDefaultValueLike(b.(fn));
        for k = 1:numel(A)
            A(k).(fn) = defaultVal;
        end
    end
end

for i = 1:numel(allFields)
    fn = allFields{i};
    if ~isfield(b, fn)
        b.(fn) = localDefaultValueLike(A(1).(fn));
    end
end

A = orderfields(A, b);
b = orderfields(b, A(1));
end

% ========================================================================
function v = localDefaultValueLike(example)
if isnumeric(example)
    if isempty(example)
        v = [];
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

% ========================================================================
function T = localBuildSummary(runRows, sceneIds, algorithms)
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
        stds(a)  = std(vals, 'omitnan');
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

% ========================================================================
function Tavg = localAverageRank(Tlong, algorithms)
avgRanks = nan(numel(algorithms), 1);
for a = 1:numel(algorithms)
    mask = strcmpi(Tlong.Algorithm, algorithms{a});
    avgRanks(a) = mean(Tlong.Rank(mask), 'omitnan');
end
Tavg = table(algorithms(:), avgRanks, 'VariableNames', {'Algorithm','AverageRank'});
Tavg = sortrows(Tavg, 'AverageRank', 'ascend');
end

% ========================================================================
function params = localApplyOverrides(params, overrides)
f = fieldnames(overrides);
for k = 1:numel(f)
    if isstruct(overrides.(f{k})) && isfield(params, f{k}) && isstruct(params.(f{k}))
        params.(f{k}) = localApplyOverrides(params.(f{k}), overrides.(f{k}));
    else
        params.(f{k}) = overrides.(f{k});
    end
end
end