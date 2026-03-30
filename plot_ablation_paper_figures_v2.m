function plot_ablation_paper_figures_v2(resultRoot)
%PLOT_ABLATION_PAPER_FIGURES_V2
% Minimal-adaptation version of your old plot_ablation_paper_figures.m
% for the current lite-v2 ablation result layout.
%
% Current expected input layout:
%   resultRoot/
%       run_records/
%           scene1_BASE_AE_run001.mat
%           scene1_AE_INIT_run001.mat
%           scene1_AE_INIT_AOS_run001.mat
%           scene1_AE_INIT_AOS_REPAIR_run001.mat
%           scene1_FAEAE_run001.mat
%           ...
%       uav_comparison_summary_long.csv
%       uav_comparison_results.mat
%
% Output folder:
%   resultRoot/ablation_paper_figures/
%       scene1_ablation_convergence.png/.fig
%       scene2_ablation_convergence.png/.fig
%       scene4_ablation_convergence.png/.fig
%       scene1_ablation_best_paths_3d.png/.fig
%       scene1_ablation_best_paths_top.png/.fig
%       scene2_ablation_best_paths_3d.png/.fig
%       scene2_ablation_best_paths_top.png/.fig
%       scene4_ablation_best_paths_3d.png/.fig
%       scene4_ablation_best_paths_top.png/.fig
%       scene1_ablation_mean_cost_bar.png/.fig
%       scene2_ablation_mean_cost_bar.png/.fig
%       scene4_ablation_mean_cost_bar.png/.fig
%       scene1_ablation_feasratio_bar.png/.fig
%       scene2_ablation_feasratio_bar.png/.fig
%       scene4_ablation_feasratio_bar.png/.fig
%       ablation_selected_best_runs.csv
%
% Usage:
%   plot_ablation_paper_figures_v2
%   plot_ablation_paper_figures_v2(resultRoot)

    if nargin < 1 || isempty(resultRoot)
        resultRoot = uigetdir(pwd, 'Select ablation result root folder');
        if isequal(resultRoot, 0)
            error('No folder selected.');
        end
    end

    runDir = fullfile(resultRoot, 'run_records');
    summaryLongFile = fullfile(resultRoot, 'uav_comparison_summary_long.csv');
    outDir = fullfile(resultRoot, 'ablation_paper_figures');

    if ~exist(runDir, 'dir')
        error('Missing run_records folder: %s', runDir);
    end
    if ~exist(summaryLongFile, 'file')
        error('Missing summary file: %s', summaryLongFile);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    sceneIds = [1 2 4];

    methodNames = { ...
        'Base-AE', ...
        'AE+Init', ...
        'AE+Init+AOS', ...
        'AE+Init+AOS+Repair', ...
        'FAE-AE'};

    methodSafeNames = { ...
        'BASE_AE', ...
        'AE_INIT', ...
        'AE_INIT_AOS', ...
        'AE_INIT_AOS_REPAIR', ...
        'FAEAE'};

    methodColors = lines(numel(methodNames));

    Tsummary = readtable(summaryLongFile);
    if ismember('Algorithm', Tsummary.Properties.VariableNames)
        Tsummary.Algorithm(strcmpi(string(Tsummary.Algorithm), "FAEAE")) = {'FAE-AE'};
    end

    selectedScene = [];
    selectedMethod = strings(0,1);
    selectedBestFit = [];
    selectedFeasible = [];
    selectedSourceFile = strings(0,1);

    fprintf('\n=== Generate Ablation Paper Figures (v2-adapted) ===\n');
    fprintf('Result root : %s\n', resultRoot);
    fprintf('Run dir     : %s\n', runDir);
    fprintf('Output dir  : %s\n\n', outDir);

    for s = 1:numel(sceneIds)
        sceneId = sceneIds(s);

        params = defaultParams();
        params.sceneId = sceneId;
        params.figView = [-37.5, 30];
        map = createMap(params);

        methodRuns = cell(numel(methodNames), 1);
        methodBest = cell(numel(methodNames), 1);

        for m = 1:numel(methodNames)
            runs = localLoadRunsFromRunRecords(runDir, sceneId, methodSafeNames{m});
            methodRuns{m} = runs;

            if ~isempty(runs)
                bestRun = localSelectBestRun(runs);
                methodBest{m} = bestRun;

                selectedScene(end+1,1) = sceneId; %#ok<AGROW>
                selectedMethod(end+1,1) = string(methodNames{m}); %#ok<AGROW>
                selectedBestFit(end+1,1) = localGetField(bestRun, {'bestFit','bestFitness','bestCost'}, NaN); %#ok<AGROW>
                selectedFeasible(end+1,1) = double(localBestRunFeasible(bestRun)); %#ok<AGROW>
                selectedSourceFile(end+1,1) = string(localGetField(bestRun, {'_sourceFile'}, "")); %#ok<AGROW>
            end
        end

        figConv = figure('Color', 'w', 'Position', [100 100 1100 800]);
        hold on; grid on; box on;

        legendHandles = [];
        legendNames = {};

        for m = 1:numel(methodNames)
            runs = methodRuns{m};
            if isempty(runs)
                continue;
            end

            meanCurve = localComputeMeanConvergence(runs);
            if isempty(meanCurve)
                continue;
            end

            h = plot(meanCurve, 'LineWidth', 2.2, 'Color', methodColors(m,:));
            legendHandles(end+1) = h; %#ok<AGROW>
            legendNames{end+1} = methodNames{m}; %#ok<AGROW>
        end

        xlabel('Iteration');
        ylabel('Mean best cost');
        title(sprintf('Scene %d Ablation Convergence', sceneId), 'Interpreter', 'none');

        if ~isempty(legendHandles)
            legend(legendHandles, legendNames, 'Location', 'northeast');
        end

        savefig(figConv, fullfile(outDir, sprintf('scene%d_ablation_convergence.fig', sceneId)));
        saveas(figConv, fullfile(outDir, sprintf('scene%d_ablation_convergence.png', sceneId)));
        close(figConv);

        fig3d = figure('Color', 'w', 'Position', [120 120 1250 900]);
        plotSceneOnly(map, params);
        hold on;

        legendHandles = [];
        legendNames = {};

        for m = 1:numel(methodNames)
            bestRun = methodBest{m};
            if isempty(bestRun)
                continue;
            end

            [bestCtrl, bestPath] = localRecoverBestPath(bestRun, params);
            if isempty(bestPath)
                continue;
            end

            h = plot3(bestPath(:,1), bestPath(:,2), bestPath(:,3), '-', 'LineWidth', 2.4, 'Color', methodColors(m,:));

            if ~isempty(bestCtrl)
                plot3(bestCtrl(:,1), bestCtrl(:,2), bestCtrl(:,3), 'o', 'Color', methodColors(m,:), 'MarkerSize', 4, 'LineWidth', 1.0);
            end

            legendHandles(end+1) = h; %#ok<AGROW>
            legendNames{end+1} = methodNames{m}; %#ok<AGROW>
        end

        title(sprintf('Scene %d Ablation Best Trajectories (3D)', sceneId), 'Interpreter', 'none');
        if ~isempty(legendHandles)
            legend(legendHandles, legendNames, 'Location', 'northeastoutside');
        end

        savefig(fig3d, fullfile(outDir, sprintf('scene%d_ablation_best_paths_3d.fig', sceneId)));
        saveas(fig3d, fullfile(outDir, sprintf('scene%d_ablation_best_paths_3d.png', sceneId)));
        close(fig3d);

        figTop = figure('Color', 'w', 'Position', [140 140 1250 900]);
        paramsTop = params;
        paramsTop.figView = [0, 90];
        plotSceneOnly(map, paramsTop);
        view(2);
        axis equal;
        hold on;

        legendHandles = [];
        legendNames = {};

        for m = 1:numel(methodNames)
            bestRun = methodBest{m};
            if isempty(bestRun)
                continue;
            end

            [bestCtrl, bestPath] = localRecoverBestPath(bestRun, params);
            if isempty(bestPath)
                continue;
            end

            h = plot3(bestPath(:,1), bestPath(:,2), bestPath(:,3), '-', 'LineWidth', 2.4, 'Color', methodColors(m,:));

            if ~isempty(bestCtrl)
                plot3(bestCtrl(:,1), bestCtrl(:,2), bestCtrl(:,3), 'o', 'Color', methodColors(m,:), 'MarkerSize', 4, 'LineWidth', 1.0);
            end

            legendHandles(end+1) = h; %#ok<AGROW>
            legendNames{end+1} = methodNames{m}; %#ok<AGROW>
        end

        title(sprintf('Scene %d Ablation Best Trajectories (Top View)', sceneId), 'Interpreter', 'none');
        if ~isempty(legendHandles)
            legend(legendHandles, legendNames, 'Location', 'northeastoutside');
        end

        savefig(figTop, fullfile(outDir, sprintf('scene%d_ablation_best_paths_top.fig', sceneId)));
        saveas(figTop, fullfile(outDir, sprintf('scene%d_ablation_best_paths_top.png', sceneId)));
        close(figTop);

        figBar = figure('Color', 'w', 'Position', [150 150 1000 700]);
        [means, stds, feas] = localGetSceneStats(Tsummary, sceneId, methodNames); %#ok<ASGLU>
        b = bar(means, 'FaceColor', 'flat');
        for m = 1:min(numel(methodNames), numel(means))
            b.CData(m,:) = methodColors(m,:);
        end
        hold on;
        if any(isfinite(stds))
            errorbar(1:numel(means), means, stds, 'k.', 'LineWidth', 1.2);
        end

        xticks(1:numel(methodNames));
        xticklabels(methodNames);
        xtickangle(20);
        ylabel('Mean cost');
        title(sprintf('Scene %d Ablation Mean Cost', sceneId), 'Interpreter', 'none');
        grid on; box on;

        savefig(figBar, fullfile(outDir, sprintf('scene%d_ablation_mean_cost_bar.fig', sceneId)));
        saveas(figBar, fullfile(outDir, sprintf('scene%d_ablation_mean_cost_bar.png', sceneId)));
        close(figBar);

        figFeas = figure('Color', 'w', 'Position', [160 160 1000 700]);
        b = bar(feas, 'FaceColor', 'flat');
        for m = 1:min(numel(methodNames), numel(feas))
            b.CData(m,:) = methodColors(m,:);
        end

        xticks(1:numel(methodNames));
        xticklabels(methodNames);
        xtickangle(20);
        ylabel('Feasibility ratio');
        ylim([0 1.05]);
        title(sprintf('Scene %d Ablation Feasibility Ratio', sceneId), 'Interpreter', 'none');
        grid on; box on;

        savefig(figFeas, fullfile(outDir, sprintf('scene%d_ablation_feasratio_bar.fig', sceneId)));
        saveas(figFeas, fullfile(outDir, sprintf('scene%d_ablation_feasratio_bar.png', sceneId)));
        close(figFeas);
    end

    Tsel = table(selectedScene, selectedMethod, selectedBestFit, selectedFeasible, selectedSourceFile, ...
        'VariableNames', {'SceneId','Method','BestFit','Feasible','SourceFile'});
    writetable(Tsel, fullfile(outDir, 'ablation_selected_best_runs.csv'));

    fprintf('\nDone. Figures saved to:\n%s\n', outDir);
end

function runs = localLoadRunsFromRunRecords(runDir, sceneId, safeName)
    runs = [];
    files = dir(fullfile(runDir, sprintf('scene%d_%s_run*.mat', sceneId, safeName)));
    if isempty(files)
        return;
    end

    runs = struct([]);
    for i = 1:numel(files)
        fp = fullfile(files(i).folder, files(i).name);
        try
            D = load(fp);
            rr = localExtractResultStruct(D);
            rr.sourceFile = fp;
            if isempty(runs)
                runs = rr;
            else
                [runs, rr] = localAlignStructArrayAndScalar(runs, rr);
                runs(end+1) = rr; %#ok<AGROW>
            end
        catch
        end
    end
end

function rr = localExtractResultStruct(D)
    rr = [];
    if isfield(D, 'result') && isstruct(D.result)
        rr = D.result;
        return;
    end
    fns = fieldnames(D);
    for i = 1:numel(fns)
        val = D.(fns{i});
        if isstruct(val) && ~isempty(val)
            rr = val;
            return;
        end
    end
end

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

function bestRun = localSelectBestRun(runs)
    bestRun = [];
    if isempty(runs)
        return;
    end

    feasibleMask = false(numel(runs),1);
    costVals = inf(numel(runs),1);

    for i = 1:numel(runs)
        feasibleMask(i) = localBestRunFeasible(runs(i));
        costVals(i) = localGetField(runs(i), {'bestFit','bestFitness','bestCost'}, inf);
    end

    idxCandidates = find(feasibleMask);
    if isempty(idxCandidates)
        idxCandidates = 1:numel(runs);
    end

    [~, idxLocal] = min(costVals(idxCandidates));
    idx = idxCandidates(idxLocal);
    bestRun = runs(idx);
end

function tf = localBestRunFeasible(runStruct)
    tf = false;
    v = localGetField(runStruct, {'finalFeasible'}, NaN);
    if ~isnan(v)
        tf = logical(v);
        return;
    end

    if isfield(runStruct, 'bestDetail') && isstruct(runStruct.bestDetail)
        bd = runStruct.bestDetail;
        v = localGetField(bd, {'isFeasible','feasible'}, NaN);
        if ~isnan(v)
            tf = logical(v);
        end
    end
end

function meanCurve = localComputeMeanConvergence(runs)
    curves = cell(numel(runs),1);
    maxLen = 0;

    for i = 1:numel(runs)
        c = localGetField(runs(i), {'bestHist','convergence'}, []);
        if isempty(c)
            continue;
        end
        c = c(:);
        curves{i} = c;
        maxLen = max(maxLen, numel(c));
    end

    if maxLen == 0
        meanCurve = [];
        return;
    end

    M = nan(numel(runs), maxLen);
    for i = 1:numel(runs)
        c = curves{i};
        if isempty(c)
            continue;
        end
        M(i,1:numel(c)) = c(:).';
        if numel(c) < maxLen
            M(i,numel(c)+1:end) = c(end);
        end
    end

    meanCurve = mean(M, 1, 'omitnan');
end

function [bestCtrl, bestPath] = localRecoverBestPath(result, params)
    bestCtrl = [];
    bestPath = [];

    if isfield(result, 'bestCtrl') && ~isempty(result.bestCtrl)
        bestCtrl = result.bestCtrl;
    end

    if isfield(result, 'bestPath') && ~isempty(result.bestPath)
        bestPath = result.bestPath;
    end

    if isempty(bestCtrl)
        bestX = localGetField(result, {'bestX','bestPosition'}, []);
        if ~isempty(bestX) && exist('decodeSolution', 'file') == 2
            try
                bestCtrl = decodeSolution(bestX, params);
            catch
                bestCtrl = [];
            end
        end
    end

    if isempty(bestPath) && ~isempty(bestCtrl) && exist('bsplinePath', 'file') == 2
        try
            bestPath = bsplinePath(bestCtrl, params.degree, params.nSamples);
        catch
            bestPath = [];
        end
    end
end

function [means, stds, feas] = localGetSceneStats(T, sceneId, methodNames)

    [sceneCol, algCol, meanCol, stdCol, feasCol] = localDetectSummaryColumns(T);

    means = nan(numel(methodNames),1);
    stds  = nan(numel(methodNames),1);
    feas  = nan(numel(methodNames),1);

    for i = 1:numel(methodNames)
        method = methodNames{i};

        mask = localMatchScene(T.(sceneCol), sceneId) & localMatchMethod(T.(algCol), method);
        rows = T(mask,:);

        if isempty(rows)
            continue;
        end

        means(i) = localToScalar(rows.(meanCol)(1));

        if ~isempty(stdCol)
            stds(i) = localToScalar(rows.(stdCol)(1));
        end

        if ~isempty(feasCol)
            feas(i) = localToScalar(rows.(feasCol)(1));
        end
    end
end

function [sceneCol, algCol, meanCol, stdCol, feasCol] = localDetectSummaryColumns(T)
% 自动识别 summary_long 里的列名，兼容不同版本导出的表

    varNames = T.Properties.VariableNames;
    vnLower = lower(string(varNames));

    sceneCol = '';
    algCol   = '';
    meanCol  = '';
    stdCol   = '';
    feasCol  = '';

    idx = find(ismember(vnLower, ["scene","sceneid","scene_id","mapid","scenarioid"]), 1);
    if ~isempty(idx)
        sceneCol = varNames{idx};
    else
        error('未识别到 scene 列。');
    end

    idx = find(ismember(vnLower, ["algorithm","alg","algname","method","methodname"]), 1);
    if ~isempty(idx)
        algCol = varNames{idx};
    else
        error('未识别到 algorithm/method 列。');
    end

    idx = find(ismember(vnLower, ["mean","avg","meancost","average"]), 1);
    if ~isempty(idx)
        meanCol = varNames{idx};
    else
        error('未识别到 mean 列。');
    end

    idx = find(ismember(vnLower, ["std","stdev","stddev","sigma"]), 1);
    if ~isempty(idx)
        stdCol = varNames{idx};
    else
        stdCol = '';
    end

    idx = find(ismember(vnLower, ["feasibility","feasratio","feasible_ratio","feasible"]), 1);
    if ~isempty(idx)
        feasCol = varNames{idx};
    else
        feasCol = '';
    end
end

function tf = localMatchScene(sceneSeries, sceneId)
    if isnumeric(sceneSeries)
        tf = double(sceneSeries) == sceneId;
        return;
    end

    s = string(sceneSeries);
    tf = false(size(s));
    for i = 1:numel(s)
        x = strtrim(s(i));
        num = sscanf(char(x), 'Scene %d');
        if ~isempty(num)
            tf(i) = (num == sceneId);
        else
            num2 = str2double(x);
            if ~isnan(num2)
                tf(i) = (num2 == sceneId);
            end
        end
    end
end

function tf = localMatchMethod(methodSeries, methodName)
    s = upper(string(methodSeries));
    q = upper(string(methodName));

    % 统一 FAEAE / FAE-AE 写法
    s = strrep(s, "FAEAE", "FAE-AE");
    q = strrep(q, "FAEAE", "FAE-AE");

    tf = s == q;
end

function val = localGetField(s, names, defaultVal)
    val = defaultVal;
    for k = 1:numel(names)
        if isfield(s, names{k})
            val = s.(names{k});
            return;
        end
    end
end

function x = localToScalar(v)
    if isnumeric(v)
        x = double(v(1));
    elseif isstring(v) || ischar(v)
        x = str2double(string(v));
    else
        x = NaN;
    end
end
