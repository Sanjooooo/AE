function plot_ablation_scene2_manual_v2(resultRoot, manualRunMap)
% manualRunMap 例子：
% manualRunMap('BASE_AE') = 'scene2_BASE_AE_run012.mat';
% manualRunMap('AE_INIT') = 'scene2_AE_INIT_run018.mat';
% manualRunMap('AE_INIT_AOS') = 'scene2_AE_INIT_AOS_run007.mat';
% manualRunMap('AE_INIT_AOS_REPAIR') = 'scene2_AE_INIT_AOS_REPAIR_run011.mat';
% manualRunMap('FAEAE') = 'scene2_FAEAE_run029.mat';

    if nargin < 2 || isempty(manualRunMap)
        error('Please provide manualRunMap.');
    end

    runDir = fullfile(resultRoot, 'run_records');
    outDir = fullfile(resultRoot, 'ablation_paper_figures_manual_scene2');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    sceneId = 2;
    params = defaultParams();
    params.sceneId = sceneId;
    params.figView = [-37.5, 30];
    map = createMap(params);

    methodNames = {'Base-AE','AE+Init','AE+Init+AOS','AE+Init+AOS+Repair','FAE-AE'};
    safeNames = {'BASE_AE','AE_INIT','AE_INIT_AOS','AE_INIT_AOS_REPAIR','FAEAE'};
    methodColors = lines(numel(methodNames));

    bestRuns = cell(numel(methodNames),1);

    for i = 1:numel(safeNames)
        key = safeNames{i};
        if ~isKey(manualRunMap, key)
            continue;
        end
        fp = fullfile(runDir, manualRunMap(key));
        if ~exist(fp, 'file')
            error('File not found: %s', fp);
        end
        S = load(fp);
        bestRuns{i} = localExtractResultStruct(S);
    end

    % 3D
    fig3d = figure('Color', 'w', 'Position', [120 120 1250 900]);
    plotSceneOnly(map, params);
    hold on;

    legendHandles = [];
    legendNames = {};

    for i = 1:numel(methodNames)
        rr = bestRuns{i};
        if isempty(rr), continue; end
        [bestCtrl, bestPath] = localRecoverBestPath(rr, params);
        if isempty(bestPath), continue; end

        h = plot3(bestPath(:,1), bestPath(:,2), bestPath(:,3), ...
            '-', 'LineWidth', 2.4, 'Color', methodColors(i,:));

        if ~isempty(bestCtrl)
            plot3(bestCtrl(:,1), bestCtrl(:,2), bestCtrl(:,3), ...
                'o', 'Color', methodColors(i,:), 'MarkerSize', 4, 'LineWidth', 1.0);
        end

        legendHandles(end+1) = h; %#ok<AGROW>
        legendNames{end+1} = methodNames{i}; %#ok<AGROW>
    end

    title('Scene 2 Ablation Representative Trajectories (3D)', 'Interpreter', 'none');
    if ~isempty(legendHandles)
        legend(legendHandles, legendNames, 'Location', 'northeastoutside');
    end
    savefig(fig3d, fullfile(outDir, 'scene2_ablation_representative_3d.fig'));
    saveas(fig3d, fullfile(outDir, 'scene2_ablation_representative_3d.png'));
    close(fig3d);

    % Top
    figTop = figure('Color', 'w', 'Position', [140 140 1250 900]);
    paramsTop = params;
    paramsTop.figView = [0, 90];
    plotSceneOnly(map, paramsTop);
    view(2); axis equal; hold on;

    legendHandles = [];
    legendNames = {};

    for i = 1:numel(methodNames)
        rr = bestRuns{i};
        if isempty(rr), continue; end
        [bestCtrl, bestPath] = localRecoverBestPath(rr, params);
        if isempty(bestPath), continue; end

        h = plot3(bestPath(:,1), bestPath(:,2), bestPath(:,3), ...
            '-', 'LineWidth', 2.4, 'Color', methodColors(i,:));

        if ~isempty(bestCtrl)
            plot3(bestCtrl(:,1), bestCtrl(:,2), bestCtrl(:,3), ...
                'o', 'Color', methodColors(i,:), 'MarkerSize', 4, 'LineWidth', 1.0);
        end

        legendHandles(end+1) = h; %#ok<AGROW>
        legendNames{end+1} = methodNames{i}; %#ok<AGROW>
    end

    title('Scene 2 Ablation Representative Trajectories (Top View)', 'Interpreter', 'none');
    if ~isempty(legendHandles)
        legend(legendHandles, legendNames, 'Location', 'northeastoutside');
    end
    savefig(figTop, fullfile(outDir, 'scene2_ablation_representative_top.fig'));
    saveas(figTop, fullfile(outDir, 'scene2_ablation_representative_top.png'));
    close(figTop);
end

function rr = localExtractResultStruct(S)
    if isfield(S, 'result') && isstruct(S.result)
        rr = S.result; return;
    end
    fns = fieldnames(S);
    for i = 1:numel(fns)
        if isstruct(S.(fns{i}))
            rr = S.(fns{i}); return;
        end
    end
    error('Cannot find result struct.');
end

function [bestCtrl, bestPath] = localRecoverBestPath(result, params)
    bestCtrl = [];
    bestPath = [];
    if isfield(result, 'bestCtrl') && ~isempty(result.bestCtrl), bestCtrl = result.bestCtrl; end
    if isfield(result, 'bestPath') && ~isempty(result.bestPath), bestPath = result.bestPath; end

    if isempty(bestCtrl)
        bestX = [];
        if isfield(result, 'bestX'), bestX = result.bestX; end
        if isempty(bestX) && isfield(result, 'bestPosition'), bestX = result.bestPosition; end
        if ~isempty(bestX)
            try, bestCtrl = decodeSolution(bestX, params); catch, bestCtrl = []; end
        end
    end
    if isempty(bestPath) && ~isempty(bestCtrl)
        try, bestPath = bsplinePath(bestCtrl, params.degree, params.nSamples); catch, bestPath = []; end
    end
end