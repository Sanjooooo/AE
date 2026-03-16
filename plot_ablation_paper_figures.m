function plot_ablation_paper_figures(resultRoot)
%PLOT_ABLATION_PAPER_FIGURES Generate paper-ready ablation figures.
%
% Usage:
%   plot_ablation_paper_figures
%   plot_ablation_paper_figures(resultRoot)
%
% Input:
%   resultRoot - folder containing:
%       ablation_scene1_base_ae/
%       ablation_scene1_init/
%       ablation_scene1_init_aos/
%       ablation_scene1_init_aos_repair/
%       ablation_scene1_full_faeae/
%       ...
%       ablation_scene1_summary.csv
%       ablation_scene2_summary.csv
%       ablation_scene4_summary.csv
%
% Output folder:
%   ablation_paper_figures/
%       scene1_ablation_convergence.png/.fig
%       scene2_ablation_convergence.png/.fig
%       scene4_ablation_convergence.png/.fig
%       scene1_ablation_best_paths_3d.png/.fig
%       scene1_ablation_best_paths_top.png/.fig
%       ...
%       scene1_ablation_mean_cost_bar.png/.fig
%       scene2_ablation_mean_cost_bar.png/.fig
%       scene4_ablation_mean_cost_bar.png/.fig
%       scene1_ablation_feasratio_bar.png/.fig
%       scene2_ablation_feasratio_bar.png/.fig
%       scene4_ablation_feasratio_bar.png/.fig
%       ablation_selected_best_runs.csv

    if nargin < 1 || isempty(resultRoot)
        resultRoot = uigetdir(pwd, 'Select ablation result root folder');
        if isequal(resultRoot, 0)
            error('No folder selected.');
        end
    end

    outDir = fullfile(resultRoot, 'ablation_paper_figures');
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

    methodFolders = { ...
        'base_ae', ...
        'init', ...
        'init_aos', ...
        'init_aos_repair', ...
        'full_faeae'};

    methodColors = lines(numel(methodNames));

    % record selected best runs for traceability
    selectedScene = [];
    selectedMethod = strings(0,1);
    selectedBestFit = [];
    selectedFeasible = [];
    selectedSourceFile = strings(0,1);

    fprintf('\n=== Generate Ablation Paper Figures ===\n');
    fprintf('Result root : %s\n', resultRoot);
    fprintf('Output dir  : %s\n\n', outDir);

    for s = 1:numel(sceneIds)
        sceneId = sceneIds(s);

        % ------------------------------------------------------------
        % exact map rendering from repository
        % ------------------------------------------------------------
        params = defaultParams();
        params.sceneId = sceneId;
        params.figView = [-37.5, 30];
        map = createMap(params);

        % per-method loaded runs
        methodRuns = cell(numel(methodNames), 1);
        methodBest = cell(numel(methodNames), 1);

        for m = 1:numel(methodNames)
            folderName = sprintf('ablation_scene%d_%s', sceneId, methodFolders{m});
            folderPath = fullfile(resultRoot, folderName);

            if ~exist(folderPath, 'dir')
                warning('Missing folder: %s', folderPath);
                continue;
            end

            runs = localLoadRunsFromFolder(folderPath);
            methodRuns{m} = runs;

            if ~isempty(runs)
                bestRun = localSelectBestRun(runs);
                methodBest{m} = bestRun;

                selectedScene(end+1,1) = sceneId; %#ok<AGROW>
                selectedMethod(end+1,1) = string(methodNames{m}); %#ok<AGROW>
                selectedBestFit(end+1,1) = localGetField(bestRun, {'bestFit','bestFitness','bestCost'}, NaN); %#ok<AGROW>
                selectedFeasible(end+1,1) = double(localBestRunFeasible(bestRun)); %#ok<AGROW>
                selectedSourceFile(end+1,1) = string(folderPath); %#ok<AGROW>
            end
        end

        % ------------------------------------------------------------
        % 1) Convergence figure
        % ------------------------------------------------------------
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

        % ------------------------------------------------------------
        % 2) Best-path overlay (3D)
        % ------------------------------------------------------------
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

            h = plot3(bestPath(:,1), bestPath(:,2), bestPath(:,3), ...
                '-', 'LineWidth', 2.4, 'Color', methodColors(m,:));

            if ~isempty(bestCtrl)
                plot3(bestCtrl(:,1), bestCtrl(:,2), bestCtrl(:,3), ...
                    'o', 'Color', methodColors(m,:), 'MarkerSize', 4, 'LineWidth', 1.0);
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

        % ------------------------------------------------------------
        % 3) Best-path overlay (Top View)
        % ------------------------------------------------------------
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

            h = plot3(bestPath(:,1), bestPath(:,2), bestPath(:,3), ...
                '-', 'LineWidth', 2.4, 'Color', methodColors(m,:));

            if ~isempty(bestCtrl)
                plot3(bestCtrl(:,1), bestCtrl(:,2), bestCtrl(:,3), ...
                    'o', 'Color', methodColors(m,:), 'MarkerSize', 4, 'LineWidth', 1.0);
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

        % ------------------------------------------------------------
        % 4) Mean cost bar chart (from scene summary csv)
        % ------------------------------------------------------------
        summaryCsv = fullfile(resultRoot, sprintf('ablation_scene%d_summary.csv', sceneId));
        if exist(summaryCsv, 'file')
            T = readtable(summaryCsv, 'TextType', 'string');

            figBar = figure('Color', 'w', 'Position', [150 150 1000 700]);
            b = bar(T.Mean, 'FaceColor', 'flat');
            for m = 1:min(numel(methodNames), numel(T.Mean))
                b.CData(m,:) = methodColors(m,:);
            end
            hold on;
            errorbar(1:height(T), T.Mean, T.Std, 'k.', 'LineWidth', 1.2);

            xticks(1:height(T));
            xticklabels(T.Method);
            xtickangle(20);
            ylabel('Mean cost');
            title(sprintf('Scene %d Ablation Mean Cost', sceneId), 'Interpreter', 'none');
            grid on; box on;

            savefig(figBar, fullfile(outDir, sprintf('scene%d_ablation_mean_cost_bar.fig', sceneId)));
            saveas(figBar, fullfile(outDir, sprintf('scene%d_ablation_mean_cost_bar.png', sceneId)));
            close(figBar);

            % --------------------------------------------------------
            % 5) Feasibility ratio bar chart (extra recommended)
            % --------------------------------------------------------
            figFeas = figure('Color', 'w', 'Position', [160 160 1000 700]);
            b = bar(T.FeasRatio, 'FaceColor', 'flat');
            for m = 1:min(numel(methodNames), numel(T.FeasRatio))
                b.CData(m,:) = methodColors(m,:);
            end

            xticks(1:height(T));
            xticklabels(T.Method);
            xtickangle(20);
            ylabel('Feasibility ratio');
            ylim([0 1.05]);
            title(sprintf('Scene %d Ablation Feasibility Ratio', sceneId), 'Interpreter', 'none');
            grid on; box on;

            savefig(figFeas, fullfile(outDir, sprintf('scene%d_ablation_feasratio_bar.fig', sceneId)));
            saveas(figFeas, fullfile(outDir, sprintf('scene%d_ablation_feasratio_bar.png', sceneId)));
            close(figFeas);
        end
    end

    % ------------------------------------------------------------
    % Save selected best-run traceability
    % ------------------------------------------------------------
    Tsel = table(selectedScene, selectedMethod, selectedBestFit, selectedFeasible, selectedSourceFile, ...
        'VariableNames', {'SceneId','Method','BestFit','Feasible','SourceFolder'});
    writetable(Tsel, fullfile(outDir, 'ablation_selected_best_runs.csv'));

    fprintf('\nDone. Figures saved to:\n%s\n', outDir);
end


% ========================================================================
function runs = localLoadRunsFromFolder(folderPath)
% Try to find a struct array of run results from MAT files in a folder.

    runs = [];

    % prioritize common filenames
    preferredFiles = { ...
        'batch_results.mat', ...
        'ablation_results.mat', ...
        'results.mat'};

    files = dir(fullfile(folderPath, '*.mat'));
    if isempty(files)
        return;
    end

    ordered = strings(0,1);

    for i = 1:numel(preferredFiles)
        fp = fullfile(folderPath, preferredFiles{i});
        if exist(fp, 'file')
            ordered(end+1,1) = string(fp); %#ok<AGROW>
        end
    end

    for i = 1:numel(files)
        fp = string(fullfile(files(i).folder, files(i).name));
        if ~any(ordered == fp)
            ordered(end+1,1) = fp; %#ok<AGROW>
        end
    end

    for i = 1:numel(ordered)
        try
            D = load(ordered(i));
            runs = localExtractRunsFromLoadedStruct(D);
            if ~isempty(runs)
                return;
            end
        catch
            % ignore bad mat file
        end
    end
end


% ========================================================================
function runs = localExtractRunsFromLoadedStruct(D)
% Search loaded MAT variables for struct arrays containing bestFit/bestHist.

    runs = [];

    fns = fieldnames(D);
    for i = 1:numel(fns)
        val = D.(fns{i});

        % direct struct array
        if isstruct(val) && ~isempty(val)
            if localIsRunStructArray(val)
                runs = val(:);
                return;
            end
        end

        % cell array containing struct arrays
        if iscell(val) && ~isempty(val)
            for j = 1:numel(val)
                vv = val{j};
                if isstruct(vv) && ~isempty(vv) && localIsRunStructArray(vv)
                    runs = vv(:);
                    return;
                end
            end
        end
    end
end


% ========================================================================
function tf = localIsRunStructArray(val)
    tf = false;
    if ~isstruct(val) || isempty(val)
        return;
    end

    candidateFields = {'bestFit','bestFitness','bestHist','convergence','runTime','runtime'};
    hit = false;
    for k = 1:numel(candidateFields)
        if isfield(val, candidateFields{k})
            hit = true;
            break;
        end
    end
    tf = hit;
end


% ========================================================================
function bestRun = localSelectBestRun(runs)
% Prefer feasible runs; among them choose the minimum bestFit.

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


% ========================================================================
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


% ========================================================================
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


% ========================================================================
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


% ========================================================================
function val = localGetField(s, names, defaultVal)
    val = defaultVal;
    for k = 1:numel(names)
        if isfield(s, names{k})
            val = s.(names{k});
            return;
        end
    end
end