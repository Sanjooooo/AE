addpath(genpath(pwd));

%% ===== 1) 路径设置 =====
oldDir = 'F:\MATLAB_Project\FAEAE_matlab\results_uav_comparison_formal_20260322_165216\fair_init';

% 改成你这次 v2 只跑 FAEAE 的结果目录
newDir = fullfile(pwd, 'results_uav_lite_v2_fair_only_faeae');

mergedDir = fullfile(pwd, 'results_uav_comparison_fair_merged_v2');
if ~exist(mergedDir, 'dir')
    mkdir(mergedDir);
end

runRecordDir = fullfile(oldDir, 'run_records');

algOrder = {'AE','PSO','GWO','HHO','WOA','FAEAE'};

%% ===== 2) 读取旧 summary_long 与新 summary_long =====
oldLong = readtable(fullfile(oldDir, 'uav_comparison_summary_long.csv'));
newLong = readtable(fullfile(newDir, 'uav_comparison_summary_long.csv'));

% 新 FAEAE 的 run-level 结果
newRuns = readtable(fullfile(newDir, 'uav_comparison_runs.csv'));
newRuns = newRuns(strcmpi(newRuns.Algorithm, 'FAEAE'), :);

% 标准化两张 long 表
oldLong = normalize_old_long_table(oldLong);
newLong = normalize_new_long_table(newLong, newRuns);

%% ===== 3) 从旧 run_records 重建 oldRuns（只保留非 FAEAE） =====
oldRuns = rebuild_runs_from_run_records(runRecordDir);

% 只保留旧的五个 baseline
oldRuns = oldRuns(~strcmpi(oldRuns.Algorithm, 'FAEAE'), :);

%% ===== 4) 读取新 FAEAE 的 runs =====
newRuns = readtable(fullfile(newDir, 'uav_comparison_runs.csv'));

% 保险起见，只保留新目录中的 FAEAE
newRuns = newRuns(strcmpi(newRuns.Algorithm, 'FAEAE'), :);

%% ===== 5) 合并 run-level 结果 =====
[oldRuns, newRuns] = align_runs_tables(oldRuns, newRuns);
mergedRuns = [oldRuns; newRuns];

% 统一算法顺序
mergedRuns.Algorithm = categorical(mergedRuns.Algorithm, algOrder, 'Ordinal', true);
mergedRuns = sortrows(mergedRuns, {'Scene','Algorithm','Run'});
mergedRuns.Algorithm = cellstr(string(mergedRuns.Algorithm));

writetable(mergedRuns, fullfile(mergedDir, 'uav_comparison_runs.csv'));

%% ===== 6) 合并 summary_long：旧 5 个 baseline + 新 FAEAE =====
mergedLong = [oldLong(~strcmpi(oldLong.Algorithm, 'FAEAE'), :); ...
              newLong(strcmpi(newLong.Algorithm, 'FAEAE'), :)];

mergedLong.Algorithm = categorical(mergedLong.Algorithm, algOrder, 'Ordinal', true);
mergedLong = sortrows(mergedLong, {'Scene','Algorithm'});
mergedLong.Algorithm = cellstr(string(mergedLong.Algorithm));

% 重新计算每个场景内的 Rank
sceneList = unique(mergedLong.Scene);
for s = sceneList'
    mask = mergedLong.Scene == s;
    idx = find(mask);
    means = mergedLong.Mean(mask);

    [~, ord] = sort(means, 'ascend');
    newRanks = zeros(numel(idx), 1);
    newRanks(ord) = 1:numel(idx);

    mergedLong.Rank(idx) = newRanks;
end

writetable(mergedLong, fullfile(mergedDir, 'uav_comparison_summary_long.csv'));
%% ===== 7) 重新计算 summary_wide =====
mergedWide = long_to_wide_summary(mergedLong, algOrder);
writetable(mergedWide, fullfile(mergedDir, 'uav_comparison_summary_wide.csv'));

%% ===== 8) 重新计算 Average Rank =====
avgRank = table(algOrder(:), zeros(numel(algOrder),1), ...
    'VariableNames', {'Algorithm','AverageRank'});

for i = 1:numel(algOrder)
    mask = strcmpi(mergedLong.Algorithm, algOrder{i});
    avgRank.AverageRank(i) = mean(mergedLong.Rank(mask), 'omitnan');
end
avgRank = sortrows(avgRank, 'AverageRank', 'ascend');

writetable(avgRank, fullfile(mergedDir, 'uav_comparison_average_rank.csv'));

%% ===== 9) 重算 FAEAE vs baselines 的 W/T/L =====
faeaeWTL = build_faeae_wtl(mergedRuns, algOrder);
writetable(faeaeWTL, fullfile(mergedDir, 'uav_comparison_faeae_wtl.csv'));

%% ===== 10) 保存 workspace =====
summary = struct();
summary.runTable = mergedRuns;
summary.longTable = mergedLong;
summary.wideTable = mergedWide;
summary.avgRankTable = avgRank;
summary.faeaeWTLTable = faeaeWTL;

save(fullfile(mergedDir, 'uav_comparison_summary_workspace.mat'), 'summary');

%% ===== 11) 导表 =====
% 这两个脚本如果依赖 runs.csv / summary_long.csv，应该可以直接接
make_tab_runtime_feasibility(mergedDir, 'paper_final_tables', 'main');
make_tab4_1_uav_main_results(mergedDir, 'paper_final_tables');

disp('合并完成。');
disp(['mergedDir = ' mergedDir]);
disp(avgRank);

%% =======================================================================
function T = rebuild_runs_from_run_records(runRecordDir)

files = dir(fullfile(runRecordDir, '**', '*.mat'));
if isempty(files)
    error('run_records 目录下没有找到 mat 文件。');
end

rows = table();

for k = 1:numel(files)
    fpath = fullfile(files(k).folder, files(k).name);
    S = load(fpath);

    % 尝试识别算法名 / 场景 / run id / seed / result
    alg = '';
    scene = NaN;
    runId = NaN;
    seed = NaN;
    bestFitness = NaN;
    runtime = NaN;
    feasible = NaN;
    violation = NaN;

    % ---------- 1) 从顶层字段尝试 ----------
    topFields = fieldnames(S);

    % 常见顶层 cfg / result / summary / algName / sceneId / runSeed
    if isfield(S, 'algName'), alg = string(S.algName); end
    if isfield(S, 'algorithm'), alg = string(S.algorithm); end
    if isfield(S, 'sceneId'), scene = double(S.sceneId); end
    if isfield(S, 'runId'), runId = double(S.runId); end
    if isfield(S, 'runSeed'), seed = double(S.runSeed); end
    if isfield(S, 'seed'), seed = double(S.seed); end

    % ---------- 2) 尝试寻找 result struct ----------
    result = [];
    candNames = {'result','res','runResult','out'};
    for i = 1:numel(candNames)
        if isfield(S, candNames{i}) && isstruct(S.(candNames{i}))
            result = S.(candNames{i});
            break;
        end
    end

    % 如果没找到 result，就在顶层字段里找一个 struct
    if isempty(result)
        for i = 1:numel(topFields)
            if isstruct(S.(topFields{i}))
                result = S.(topFields{i});
                break;
            end
        end
    end

    if ~isempty(result)
        if isfield(result, 'algName') && strlength(string(result.algName)) > 0
            alg = string(result.algName);
        end
        if isfield(result, 'sceneId'), scene = double(result.sceneId); end
        if isfield(result, 'runId'), runId = double(result.runId); end
        if isfield(result, 'seed'), seed = double(result.seed); end
        if isfield(result, 'runSeed'), seed = double(result.runSeed); end

        % best fitness
        if isfield(result, 'bestFitness')
            bestFitness = double(result.bestFitness);
        elseif isfield(result, 'bestFit')
            bestFitness = double(result.bestFit);
        end

        % runtime
        if isfield(result, 'runtime')
            runtime = double(result.runtime);
        elseif isfield(result, 'runTime')
            runtime = double(result.runTime);
        end

        % feasibility
        if isfield(result, 'finalFeasible')
            feasible = double(result.finalFeasible);
        elseif isfield(result, 'isFeasible')
            feasible = double(result.isFeasible);
        elseif isfield(result, 'bestDetail') && isstruct(result.bestDetail) && isfield(result.bestDetail, 'isFeasible')
            feasible = double(result.bestDetail.isFeasible);
        end

        % violation
        if isfield(result, 'finalViolation')
            violation = double(result.finalViolation);
        elseif isfield(result, 'violation')
            violation = double(result.violation);
        elseif isfield(result, 'bestDetail') && isstruct(result.bestDetail) && isfield(result.bestDetail, 'V')
            violation = double(result.bestDetail.V);
        end
    end

    % ---------- 3) 如果还有缺失，尝试从文件名解析 ----------
    fname = files(k).name;

    if strlength(alg) == 0
        algTokens = regexp(fname, '(AE|PSO|GWO|HHO|WOA|FAEAE)', 'match', 'once');
        if ~isempty(algTokens)
            alg = string(algTokens);
        end
    end

    if isnan(scene)
        tok = regexp(fname, 'Scene[_\- ]?(\d+)|scene[_\- ]?(\d+)', 'tokens', 'once');
        if ~isempty(tok)
            nums = tok(~cellfun(@isempty, tok));
            scene = str2double(nums{1});
        end
    end

    if isnan(runId)
        tok = regexp(fname, 'run[_\- ]?(\d+)|Run[_\- ]?(\d+)', 'tokens', 'once');
        if ~isempty(tok)
            nums = tok(~cellfun(@isempty, tok));
            runId = str2double(nums{1});
        end
    end

    % ---------- 4) 过滤无效记录 ----------
    if strlength(alg) == 0 || isnan(scene) || isnan(runId) || isnan(bestFitness)
        warning('跳过无法解析的文件: %s', fpath);
        continue;
    end

    row = table( ...
        scene, cellstr(alg), runId, seed, bestFitness, runtime, feasible, violation, runtime, ...
        'VariableNames', {'Scene','Algorithm','Run','Seed','BestFitness','Runtime','Feasible','Violation','WallClock'} );

    if isempty(rows)
        rows = row;
    else
        rows = [rows; row]; %#ok<AGROW>
    end
end

% 去重
[~, ia] = unique(rows(:, {'Scene','Algorithm','Run'}), 'rows', 'stable');
T = rows(ia, :);
end

%% =======================================================================
function wideT = long_to_wide_summary(longT, algOrder)

sceneList = unique(longT.Scene);
wideT = table();

for s = sceneList'
    row = table(s, 'VariableNames', {'Scene'});

    for i = 1:numel(algOrder)
        alg = algOrder{i};
        mask = longT.Scene == s & strcmpi(longT.Algorithm, alg);

        if any(mask)
            row.([alg '_Mean']) = longT.Mean(mask);
            row.([alg '_Std']) = longT.Std(mask);
            row.([alg '_Rank']) = longT.Rank(mask);
            if ismember('Feasibility', longT.Properties.VariableNames)
                row.([alg '_Feasibility']) = longT.Feasibility(mask);
            end
            if ismember('AvgRuntime', longT.Properties.VariableNames)
                row.([alg '_AvgRuntime']) = longT.AvgRuntime(mask);
            end
        else
            row.([alg '_Mean']) = NaN;
            row.([alg '_Std']) = NaN;
            row.([alg '_Rank']) = NaN;
            row.([alg '_Feasibility']) = NaN;
            row.([alg '_AvgRuntime']) = NaN;
        end
    end

    if isempty(wideT)
        wideT = row;
    else
        wideT = [wideT; row]; %#ok<AGROW>
    end
end
end

%% =======================================================================
function T = build_faeae_wtl(runT, algOrder)

sceneList = unique(runT.Scene);
baseAlgs = algOrder(~strcmpi(algOrder, 'FAEAE'));

rows = table();

for s = sceneList'
    faeaeMask = runT.Scene == s & strcmpi(runT.Algorithm, 'FAEAE');
    faeaeVals = runT.BestFitness(faeaeMask);

    for i = 1:numel(baseAlgs)
        alg = baseAlgs{i};
        mask = runT.Scene == s & strcmpi(runT.Algorithm, alg);
        baseVals = runT.BestFitness(mask);

        n = min(numel(faeaeVals), numel(baseVals));
        if n == 0
            W = NaN; Ties = NaN; L = NaN;
        else
            f = faeaeVals(1:n);
            b = baseVals(1:n);
            W = sum(f < b);
            Ties = sum(f == b);
            L = sum(f > b);
        end

        row = table(s, {alg}, W, Ties, L, ...
            'VariableNames', {'Scene','ComparedAlgorithm','W','T','L'});

        if isempty(rows)
            rows = row;
        else
            rows = [rows; row]; %#ok<AGROW>
        end
    end
end

T = rows;
end
function T = normalize_old_long_table(T)
% 把旧版本 summary_long 统一成新字段体系

vars = T.Properties.VariableNames;

% SceneId -> Scene
if ismember('SceneId', vars) && ~ismember('Scene', vars)
    T.Scene = T.SceneId;
end

% FeasRatio -> Feasibility
if ismember('FeasRatio', vars) && ~ismember('Feasibility', vars)
    T.Feasibility = T.FeasRatio;
end

% 保证这些字段存在
mustHave = {'Scene','Algorithm','Mean','Std','Rank','Feasibility','AvgRuntime', ...
            'AvgEnergy','AvgLength','AvgRisk','AvgSmoothness','AvgViolation','Best','Median','SceneId'};

for i = 1:numel(mustHave)
    name = mustHave{i};
    if ~ismember(name, T.Properties.VariableNames)
        if strcmp(name, 'Algorithm')
            T.(name) = repmat({''}, height(T), 1);
        else
            T.(name) = nan(height(T), 1);
        end
    end
end

% SceneId 保持和 Scene 一致
T.SceneId = T.Scene;

% 统一列顺序
T = T(:, mustHave);
end

function T = normalize_new_long_table(T, newRuns)
% 把新 lite/v2 的 summary_long 扩展到旧表字段体系

vars = T.Properties.VariableNames;

% Scene 已有；补 SceneId
if ~ismember('SceneId', vars)
    T.SceneId = T.Scene;
end

% Feasibility 已有；补旧表风格字段
if ~ismember('Feasibility', vars)
    T.Feasibility = nan(height(T), 1);
end

% 从 newRuns 计算 Best / Median
bestVals = nan(height(T), 1);
medianVals = nan(height(T), 1);

for i = 1:height(T)
    mask = newRuns.Scene == T.Scene(i) & strcmpi(newRuns.Algorithm, T.Algorithm{i});
    vals = newRuns.BestFitness(mask);

    if ~isempty(vals)
        bestVals(i) = min(vals);
        medianVals(i) = median(vals);
    end
end

T.Best = bestVals;
T.Median = medianVals;

% 新 long 没有这些附加指标，先补 NaN
extraNaNCols = {'AvgEnergy','AvgLength','AvgRisk','AvgSmoothness','AvgViolation'};
for i = 1:numel(extraNaNCols)
    name = extraNaNCols{i};
    if ~ismember(name, T.Properties.VariableNames)
        T.(name) = nan(height(T), 1);
    end
end

% 保证 AvgRuntime / Rank / Mean / Std / Algorithm / Scene / Feasibility 都存在
mustHave = {'Scene','Algorithm','Mean','Std','Rank','Feasibility','AvgRuntime', ...
            'AvgEnergy','AvgLength','AvgRisk','AvgSmoothness','AvgViolation','Best','Median','SceneId'};

for i = 1:numel(mustHave)
    name = mustHave{i};
    if ~ismember(name, T.Properties.VariableNames)
        if strcmp(name, 'Algorithm')
            T.(name) = repmat({''}, height(T), 1);
        else
            T.(name) = nan(height(T), 1);
        end
    end
end

T = T(:, mustHave);
end

function [A2, B2] = align_runs_tables(A, B)
aNames = A.Properties.VariableNames;
bNames = B.Properties.VariableNames;
allNames = unique([aNames, bNames], 'stable');

A2 = A;
B2 = B;

for i = 1:numel(allNames)
    name = allNames{i};
    if ~ismember(name, aNames)
        B2Example = B.(name);
        A2.(name) = default_runs_col(B2Example, height(A2));
    end
    if ~ismember(name, bNames)
        A2Example = A.(name);
        B2.(name) = default_runs_col(A2Example, height(B2));
    end
end

A2 = A2(:, allNames);
B2 = B2(:, allNames);
end

function col = default_runs_col(exampleCol, n)
if iscell(exampleCol)
    col = repmat({''}, n, 1);
elseif isstring(exampleCol)
    col = strings(n, 1);
elseif islogical(exampleCol)
    col = false(n, 1);
elseif isnumeric(exampleCol)
    col = nan(n, size(exampleCol, 2));
else
    col = repmat({[]}, n, 1);
end
end