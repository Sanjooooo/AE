function plot_uav_representative_corridor_paths_all(resultDir)
%PLOT_UAV_REPRESENTATIVE_CORRIDOR_PATHS_ALL
% Select representative low-altitude corridor-like trajectories from formal
% run_records, then plot all 6 algorithms together for each scene.
%
% Outputs for each scene:
%   - one rotatable 3D figure (.fig + .png)
%   - one top-view figure (.fig + .png)
%
% Usage:
%   plot_uav_representative_corridor_paths_all
%   plot_uav_representative_corridor_paths_all(resultDir)

    if nargin < 1 || isempty(resultDir)
        resultDir = uigetdir(pwd, 'Select UAV formal result folder');
        if isequal(resultDir, 0)
            error('No folder selected.');
        end
    end

    masterFile = fullfile(resultDir, 'uav_comparison_results.mat');
    runDir = fullfile(resultDir, 'run_records');
    outDir = fullfile(resultDir, 'representative_corridor_figures');

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

    fprintf('\n=== Plot Representative Corridor Paths (All Algorithms Together) ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Output folder: %s\n\n', outDir);

    % Consistent line colors for algorithms
    algColors = lines(numel(algorithms));

    for s = 1:numel(sceneIds)
        sceneId = sceneIds(s);

        % rebuild scene
        params = defaultParams();
        params.sceneId = sceneId;
        params.figView = [-37.5, 30];
        map = createMap(params);

        repData = repmat(struct( ...
            'algName', '', ...
            'runFile', '', ...
            'bestFit', inf, ...
            'score', inf, ...
            'meanZ', NaN, ...
            'maxZ', NaN, ...
            'feasible', false, ...
            'bestCtrl', [], ...
            'bestPath', []), numel(algorithms), 1);

        % ------------------------------------------------------------
        % Find representative run for each algorithm
        % ------------------------------------------------------------
        for a = 1:numel(algorithms)
            algName = upper(algorithms{a});
            repData(a) = localFindRepresentativeRun(runDir, sceneId, algName, params);
            repData(a).algName = algName;

            if isfinite(repData(a).bestFit)
                fprintf('Scene %d | %-6s | representative bestFit = %.6f | meanZ = %.3f | maxZ = %.3f\n', ...
                    sceneId, algName, repData(a).bestFit, repData(a).meanZ, repData(a).maxZ);
            else
                fprintf('Scene %d | %-6s | no valid representative run found.\n', sceneId, algName);
            end
        end

        % ------------------------------------------------------------
        % 3D combined figure
        % ------------------------------------------------------------
        fig3d = figure('Color', 'w', 'Position', [80 80 1300 900]);
        plotSceneOnly(map, params);
        hold on;

        legendHandles = [];
        legendNames = {};

        for a = 1:numel(algorithms)
            if isempty(repData(a).bestPath)
                continue;
            end

            h = plot3(repData(a).bestPath(:,1), repData(a).bestPath(:,2), repData(a).bestPath(:,3), ...
                '-', 'LineWidth', 2.3, 'Color', algColors(a,:));

            % optional control points
            if ~isempty(repData(a).bestCtrl)
                plot3(repData(a).bestCtrl(:,1), repData(a).bestCtrl(:,2), repData(a).bestCtrl(:,3), ...
                    'o', 'Color', algColors(a,:), 'MarkerSize', 4, 'LineWidth', 1.0);
            end

            legendHandles(end+1) = h; %#ok<AGROW>
            legendNames{end+1} = repData(a).algName; %#ok<AGROW>
        end

        title(sprintf('Scene %d | Representative Low-Altitude Corridor Trajectories (3D)', sceneId), ...
            'Interpreter', 'none');

        if ~isempty(legendHandles)
            legend(legendHandles, legendNames, 'Location', 'northeastoutside');
        end

        savefig(fig3d, fullfile(outDir, sprintf('scene%d_all_algorithms_representative_3d.fig', sceneId)));
        saveas(fig3d, fullfile(outDir, sprintf('scene%d_all_algorithms_representative_3d.png', sceneId)));

        % ------------------------------------------------------------
        % Top-view combined figure
        % ------------------------------------------------------------
        figTop = figure('Color', 'w', 'Position', [100 100 1300 900]);
        paramsTop = params;
        paramsTop.figView = [0, 90];
        plotSceneOnly(map, paramsTop);
        view(2);
        axis equal;
        hold on;

        legendHandles2 = [];
        legendNames2 = {};

        for a = 1:numel(algorithms)
            if isempty(repData(a).bestPath)
                continue;
            end

            h = plot3(repData(a).bestPath(:,1), repData(a).bestPath(:,2), repData(a).bestPath(:,3), ...
                '-', 'LineWidth', 2.3, 'Color', algColors(a,:));

            if ~isempty(repData(a).bestCtrl)
                plot3(repData(a).bestCtrl(:,1), repData(a).bestCtrl(:,2), repData(a).bestCtrl(:,3), ...
                    'o', 'Color', algColors(a,:), 'MarkerSize', 4, 'LineWidth', 1.0);
            end

            legendHandles2(end+1) = h; %#ok<AGROW>
            legendNames2{end+1} = repData(a).algName; %#ok<AGROW>
        end

        title(sprintf('Scene %d | Representative Low-Altitude Corridor Trajectories (Top View)', sceneId), ...
            'Interpreter', 'none');

        if ~isempty(legendHandles2)
            legend(legendHandles2, legendNames2, 'Location', 'northeastoutside');
        end

        savefig(figTop, fullfile(outDir, sprintf('scene%d_all_algorithms_representative_top.fig', sceneId)));
        saveas(figTop, fullfile(outDir, sprintf('scene%d_all_algorithms_representative_top.png', sceneId)));

        % also save selected representative summary
        repTable = localBuildRepresentativeTable(repData);
        writetable(repTable, fullfile(outDir, sprintf('scene%d_representative_selection.csv', sceneId)));

        close(fig3d);
        close(figTop);
    end

    fprintf('\nDone. Files saved to:\n%s\n', outDir);
end


% ========================================================================
function rep = localFindRepresentativeRun(runDir, sceneId, algName, params)

    rep = struct( ...
        'algName', algName, ...
        'runFile', '', ...
        'bestFit', inf, ...
        'score', inf, ...
        'meanZ', NaN, ...
        'maxZ', NaN, ...
        'feasible', false, ...
        'bestCtrl', [], ...
        'bestPath', []);

    pattern = fullfile(runDir, sprintf('scene%d_%s_run*.mat', sceneId, upper(algName)));
    files = dir(pattern);

    if isempty(files)
        return;
    end

    candidates = [];
    raw = struct([]);

    % ------------------------------------------------------------
    % collect candidate metrics
    % ------------------------------------------------------------
    for k = 1:numel(files)
        fp = fullfile(files(k).folder, files(k).name);

        try
            R = load(fp);
            if ~isfield(R, 'result')
                continue;
            end
            rr = R.result;

            bestFit = localGetField(rr, {'bestFit','bestFitness','bestCost'}, inf);
            feasible = localLogical(localGetField(rr, {'finalFeasible'}, NaN));

            [bestCtrl, bestPath] = localRecoverBestPath(rr, params);
            if isempty(bestPath)
                continue;
            end

            zVals = bestPath(:,3);
            meanZ = mean(zVals, 'omitnan');
            maxZ = max(zVals);

            cand.bestFit = bestFit;
            cand.feasible = feasible;
            cand.meanZ = meanZ;
            cand.maxZ = maxZ;
            cand.file = fp;
            cand.bestCtrl = bestCtrl;
            cand.bestPath = bestPath;

            if isempty(candidates)
                candidates = cand;
            else
                candidates(end+1) = cand; %#ok<AGROW>
            end

        catch
            % ignore broken run file
        end
    end

    if isempty(candidates)
        return;
    end

    % ------------------------------------------------------------
    % prioritize feasible runs
    % ------------------------------------------------------------
    feasMask = [candidates.feasible] == 1;
    if any(feasMask)
        candUse = candidates(feasMask);
    else
        candUse = candidates;
    end

    % ------------------------------------------------------------
    % representative low-altitude score
    % score = normalized cost + alpha * normalized meanZ + beta * normalized maxZ
    % ------------------------------------------------------------
    costVals = [candUse.bestFit];
    meanZVals = [candUse.meanZ];
    maxZVals = [candUse.maxZ];

    costN  = localNormalize(costVals);
    meanZN = localNormalize(meanZVals);
    maxZN  = localNormalize(maxZVals);

    alpha = 0.60;
    beta  = 0.40;

    score = costN + alpha * meanZN + beta * maxZN;

    [bestScore, idx] = min(score);
    chosen = candUse(idx);

    rep.runFile = chosen.file;
    rep.bestFit = chosen.bestFit;
    rep.score = bestScore;
    rep.meanZ = chosen.meanZ;
    rep.maxZ = chosen.maxZ;
    rep.feasible = logical(chosen.feasible);
    rep.bestCtrl = chosen.bestCtrl;
    rep.bestPath = chosen.bestPath;
end


% ========================================================================
function x = localNormalize(v)
    v = double(v(:));
    if isempty(v)
        x = v;
        return;
    end
    vmin = min(v);
    vmax = max(v);
    if abs(vmax - vmin) < 1e-12
        x = zeros(size(v));
    else
        x = (v - vmin) ./ (vmax - vmin);
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
function T = localBuildRepresentativeTable(repData)

    alg = strings(numel(repData),1);
    bestFit = nan(numel(repData),1);
    score = nan(numel(repData),1);
    meanZ = nan(numel(repData),1);
    maxZ = nan(numel(repData),1);
    feasible = nan(numel(repData),1);
    runFile = strings(numel(repData),1);

    for i = 1:numel(repData)
        alg(i) = string(repData(i).algName);
        bestFit(i) = repData(i).bestFit;
        score(i) = repData(i).score;
        meanZ(i) = repData(i).meanZ;
        maxZ(i) = repData(i).maxZ;
        feasible(i) = double(repData(i).feasible);
        runFile(i) = string(repData(i).runFile);
    end

    T = table(alg, bestFit, score, meanZ, maxZ, feasible, runFile, ...
        'VariableNames', {'Algorithm','BestFit','RepresentativeScore','MeanZ','MaxZ','Feasible','RunFile'});
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

% ========================================================================
function y = localLogical(x)
    if islogical(x)
        y = double(x);
    elseif isnumeric(x)
        y = double(x);
    else
        y = NaN;
    end
end