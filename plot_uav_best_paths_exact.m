function plot_uav_best_paths_exact(resultDir)
%PLOT_UAV_BEST_PATHS_EXACT Plot best UAV trajectories using the repository's
% exact scene plotting logic (createMap + plotSceneOnly).
%
% Usage:
%   plot_uav_best_paths_exact
%   plot_uav_best_paths_exact(resultDir)
%
% Input:
%   resultDir - folder containing:
%               uav_comparison_results.mat
%               run_records/
%
% Output:
%   best_path_figures_exact/
%       scene1_AE_best_3d.png
%       scene1_AE_best_top.png
%       ...
%
% Notes:
%   - Finds the best run (minimum bestFit) for each scene/algorithm pair
%   - Loads the full run result from run_records
%   - Rebuilds the exact scene via defaultParams + createMap
%   - Uses plotSceneOnly(map, params) from your repository
%   - Overlays best path and control points

    if nargin < 1 || isempty(resultDir)
        resultDir = uigetdir(pwd, 'Select UAV formal result folder');
        if isequal(resultDir, 0)
            error('No folder selected.');
        end
    end

    masterFile = fullfile(resultDir, 'uav_comparison_results.mat');
    runDir = fullfile(resultDir, 'run_records');
    outDir = fullfile(resultDir, 'best_path_figures_exact');

    if ~exist(masterFile, 'file')
        error('Cannot find: %s', masterFile);
    end
    if ~exist(runDir, 'dir')
        error('Cannot find run_records folder: %s', runDir);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    S = load(masterFile);
    cfg = S.cfg;

    sceneIds = cfg.sceneIds;
    algorithms = cfg.algorithms;

    fprintf('\n=== Plot UAV Best Paths (Exact Scene Rendering) ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Output folder: %s\n\n', outDir);

    for s = 1:numel(sceneIds)
        sceneId = sceneIds(s);

        for a = 1:numel(algorithms)
            algName = upper(algorithms{a});

            [bestRunFile, bestResult, bestVal] = localFindBestRun(runDir, sceneId, algName);

            if isempty(bestRunFile)
                fprintf('Scene %d | %-6s : no run file found, skip.\n', sceneId, algName);
                continue;
            end

            fprintf('Scene %d | %-6s : bestFit = %.6f\n', sceneId, algName, bestVal);

            % Rebuild params/map for this scene
            params = defaultParams();
            params.sceneId = sceneId;

            % Make sure plotting uses the repository's normal 3D view first
            params.figView = [-37.5, 30];

            map = createMap(params);

            % Recover best control points / path
            [bestCtrl, bestPath] = localRecoverBestPath(bestResult, params);

            if isempty(bestPath)
                warning('Scene %d | %s : bestPath is empty, skip plotting.', sceneId, algName);
                continue;
            end

            % ----------------------------
            % 3D figure
            % ----------------------------
            fig3d = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 850]);
            plotSceneOnly(map, params);
            hold on;

            if ~isempty(bestCtrl)
                plot3(bestCtrl(:,1), bestCtrl(:,2), bestCtrl(:,3), ...
                    'k--o', 'LineWidth', 1.0, 'MarkerSize', 4);
            end

            plot3(bestPath(:,1), bestPath(:,2), bestPath(:,3), ...
                'b-', 'LineWidth', 2.4);

            title(sprintf('Scene %d | %s | Best Path (3D) | Cost = %.3f', ...
                sceneId, algName, bestVal), 'Interpreter', 'none');

            saveas(fig3d, fullfile(outDir, sprintf('scene%d_%s_best_3d.png', sceneId, algName)));
            close(fig3d);

            % ----------------------------
            % Top-view figure
            % ----------------------------
            figTop = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 1200 850]);

            paramsTop = params;
            paramsTop.figView = [0, 90];

            plotSceneOnly(map, paramsTop);
            view(2);
            axis equal;
            hold on;

            if ~isempty(bestCtrl)
                plot3(bestCtrl(:,1), bestCtrl(:,2), bestCtrl(:,3), ...
                    'k--o', 'LineWidth', 1.0, 'MarkerSize', 4);
            end

            plot3(bestPath(:,1), bestPath(:,2), bestPath(:,3), ...
                'b-', 'LineWidth', 2.4);

            title(sprintf('Scene %d | %s | Best Path (Top View) | Cost = %.3f', ...
                sceneId, algName, bestVal), 'Interpreter', 'none');

            saveas(figTop, fullfile(outDir, sprintf('scene%d_%s_best_top.png', sceneId, algName)));
            close(figTop);
        end
    end

    fprintf('\nDone. Exact best-path figures saved to:\n%s\n', outDir);
end


% ========================================================================
function [bestRunFile, bestResult, bestVal] = localFindBestRun(runDir, sceneId, algName)

    pattern = fullfile(runDir, sprintf('scene%d_%s_run*.mat', sceneId, upper(algName)));
    files = dir(pattern);

    bestRunFile = '';
    bestResult = [];
    bestVal = inf;

    for k = 1:numel(files)
        fp = fullfile(files(k).folder, files(k).name);
        try
            R = load(fp);
            if ~isfield(R, 'result')
                continue;
            end
            rr = R.result;

            val = localGetField(rr, {'bestFit','bestFitness','bestCost'}, inf);

            if val < bestVal
                bestVal = val;
                bestRunFile = fp;
                bestResult = rr;
            end
        catch
            % ignore broken run files
        end
    end
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