function plot_uav_representative_corridor_paths_all(resultDir, manualRunMap, prefix, outDirName)
%PLOT_UAV_REPRESENTATIVE_CORRIDOR_PATHS_ALL
% Select representative low-altitude corridor-like trajectories from run_records,
% then plot all 6 algorithms together for each scene.
%
% 用途：
%   - 支持原始主实验(main)和公平初始化实验(fair_init)共用
%   - 保留“低空代表性优选航迹”筛选逻辑
%   - 每个场景输出：
%       * 3D representative trajectories
%       * top-view representative trajectories
%       * representative selection summary
%       * candidate detail table
%
% Usage:
%   plot_uav_representative_corridor_paths_all
%   plot_uav_representative_corridor_paths_all(resultDir)
%   plot_uav_representative_corridor_paths_all(resultDir, manualRunMap)
%   plot_uav_representative_corridor_paths_all(resultDir, manualRunMap, 'main')
%   plot_uav_representative_corridor_paths_all(resultDir, manualRunMap, 'fair_init')
%   plot_uav_representative_corridor_paths_all(resultDir, manualRunMap, 'main', 'paper_main_representative_paths')
%
% Example:
%   manualRunMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
%   manualRunMap('scene2_FAEAE') = 'scene2_FAEAE_run030.mat';
%   plot_uav_representative_corridor_paths_all('results_uav_6alg_formal_safe', manualRunMap, 'main');

    if nargin < 1 || isempty(resultDir)
        resultDir = uigetdir(pwd, 'Select UAV result folder');
        if isequal(resultDir, 0)
            error('No folder selected.');
        end
    end

    if nargin < 2 || isempty(manualRunMap)
        manualRunMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    end

    if nargin < 3 || isempty(prefix)
        prefix = 'main';
    end

    if nargin < 4 || isempty(outDirName)
        outDirName = sprintf('%s_representative_corridor_figures', prefix);
    end

    masterFile = fullfile(resultDir, 'uav_comparison_results.mat');
    runDir = fullfile(resultDir, 'run_records');
    outDir = fullfile(resultDir, outDirName);

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
    fprintf('Output folder: %s\n', outDir);
    fprintf('Prefix       : %s\n\n', prefix);

    algColors = lines(numel(algorithms));

    for s = 1:numel(sceneIds)
        sceneId = sceneIds(s);

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
            'minZ', NaN, ...
            'stdZ', NaN, ...
            'pathLen', NaN, ...
            'detourRatio', NaN, ...
            'turnPenalty', NaN, ...
            'lowAltFrac', NaN, ...
            'highAltFrac', NaN, ...
            'feasible', false, ...
            'bestCtrl', [], ...
            'bestPath', [], ...
            'candidateTable', localEmptyCandidateTable()), numel(algorithms), 1);

        % ------------------------------------------------------------
        % Find representative run for each algorithm
        % ------------------------------------------------------------
        for a = 1:numel(algorithms)
            algName = upper(algorithms{a});
            repData(a) = localFindRepresentativeRun(runDir, sceneId, algName, params, manualRunMap);
            repData(a).algName = algName;

            if isfinite(repData(a).bestFit)
                fprintf(['Scene %d | %-6s | representative bestFit = %.6f | ' ...
                         'meanZ = %.3f | maxZ = %.3f | detour = %.3f | turn = %.3f | ' ...
                         'lowFrac = %.3f | highFrac = %.3f | file = %s\n'], ...
                    sceneId, algName, repData(a).bestFit, repData(a).meanZ, repData(a).maxZ, ...
                    repData(a).detourRatio, repData(a).turnPenalty, ...
                    repData(a).lowAltFrac, repData(a).highAltFrac, ...
                    localBaseName(repData(a).runFile));
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

        savefig(fig3d, fullfile(outDir, sprintf('%s_fig_scene%d_representative_3d.fig', prefix, sceneId)));
        saveas(fig3d, fullfile(outDir, sprintf('%s_fig_scene%d_representative_3d.png', prefix, sceneId)));

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

        savefig(figTop, fullfile(outDir, sprintf('%s_fig_scene%d_representative_top.fig', prefix, sceneId)));
        saveas(figTop, fullfile(outDir, sprintf('%s_fig_scene%d_representative_top.png', prefix, sceneId)));

        % representative summary
        repTable = localBuildRepresentativeTable(repData);
        writetable(repTable, fullfile(outDir, sprintf('%s_scene%d_representative_selection.csv', prefix, sceneId)));

        % candidate details
        detailTable = localEmptyCandidateTable();
        for a = 1:numel(repData)
            if ~isempty(repData(a).candidateTable) && height(repData(a).candidateTable) > 0
                Ti = localAlignCandidateTable(repData(a).candidateTable);
                detailTable = [detailTable; Ti]; %#ok<AGROW>
            end
        end
        if height(detailTable) > 0
            writetable(detailTable, fullfile(outDir, sprintf('%s_scene%d_representative_candidates_detail.csv', prefix, sceneId)));
        end

        close(fig3d);
        close(figTop);
    end

    fprintf('\nDone. Files saved to:\n%s\n', outDir);
end

% ========================================================================
function rep = localFindRepresentativeRun(runDir, sceneId, algName, params, manualRunMap)

    rep = struct( ...
        'algName', algName, ...
        'runFile', '', ...
        'bestFit', inf, ...
        'score', inf, ...
        'meanZ', NaN, ...
        'maxZ', NaN, ...
        'minZ', NaN, ...
        'stdZ', NaN, ...
        'pathLen', NaN, ...
        'detourRatio', NaN, ...
        'turnPenalty', NaN, ...
        'lowAltFrac', NaN, ...
        'highAltFrac', NaN, ...
        'feasible', false, ...
        'bestCtrl', [], ...
        'bestPath', [], ...
        'candidateTable', localEmptyCandidateTable());

    % ------------------------------------------------------------
    % 0) manual override
    % ------------------------------------------------------------
    key = sprintf('scene%d_%s', sceneId, upper(algName));
    if isKey(manualRunMap, key)
        manualFile = manualRunMap(key);
        fp = fullfile(runDir, manualFile);
        if exist(fp, 'file')
            R = load(fp);
            if isfield(R, 'result')
                rr = R.result;
                [bestCtrl, bestPath] = localRecoverBestPath(rr, params);
                if ~isempty(bestPath)
                    metrics = localComputePathMetrics(bestPath, params);

                    rep.runFile      = fp;
                    rep.bestFit      = localGetField(rr, {'bestFit','bestFitness','bestCost'}, inf);
                    rep.score        = -1;
                    rep.meanZ        = metrics.meanZ;
                    rep.maxZ         = metrics.maxZ;
                    rep.minZ         = metrics.minZ;
                    rep.stdZ         = metrics.stdZ;
                    rep.pathLen      = metrics.pathLen;
                    rep.detourRatio  = metrics.detourRatio;
                    rep.turnPenalty  = metrics.turnPenalty;
                    rep.lowAltFrac   = metrics.lowAltFrac;
                    rep.highAltFrac  = metrics.highAltFrac;
                    rep.feasible     = localLogical(localGetField(rr, {'finalFeasible','isFeasible'}, NaN));
                    rep.bestCtrl     = bestCtrl;
                    rep.bestPath     = bestPath;

                    T = localEmptyCandidateTable();
                    T = [T; localMakeCandidateRow( ...
                        algName, sceneId, localBaseName(fp), rep.bestFit, rep.feasible, ...
                        rep.meanZ, rep.maxZ, rep.minZ, rep.stdZ, rep.pathLen, ...
                        rep.detourRatio, rep.turnPenalty, rep.lowAltFrac, rep.highAltFrac, ...
                        NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
                        -1, false, true, true)];
                    rep.candidateTable = T;
                    return;
                end
            end
        end
    end

    pattern = fullfile(runDir, sprintf('scene%d_%s_run*.mat', sceneId, upper(algName)));
    files = dir(pattern);

    if isempty(files)
        return;
    end

    candidates = struct([]);
    detailRows = localEmptyCandidateTable();

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
            feasible = localLogical(localGetField(rr, {'finalFeasible','isFeasible'}, NaN));

            [bestCtrl, bestPath] = localRecoverBestPath(rr, params);
            if isempty(bestPath) || size(bestPath,1) < 3
                continue;
            end

            metrics = localComputePathMetrics(bestPath, params);

            cand.bestFit      = bestFit;
            cand.feasible     = feasible;
            cand.meanZ        = metrics.meanZ;
            cand.maxZ         = metrics.maxZ;
            cand.minZ         = metrics.minZ;
            cand.stdZ         = metrics.stdZ;
            cand.pathLen      = metrics.pathLen;
            cand.detourRatio  = metrics.detourRatio;
            cand.turnPenalty  = metrics.turnPenalty;
            cand.lowAltFrac   = metrics.lowAltFrac;
            cand.highAltFrac  = metrics.highAltFrac;
            cand.file         = fp;
            cand.bestCtrl     = bestCtrl;
            cand.bestPath     = bestPath;

            if isempty(candidates)
                candidates = cand;
            else
                candidates(end+1) = cand; %#ok<AGROW>
            end

            detailRows = [detailRows; localMakeCandidateRow( ...
                algName, sceneId, files(k).name, bestFit, feasible, ...
                metrics.meanZ, metrics.maxZ, metrics.minZ, metrics.stdZ, metrics.pathLen, ...
                metrics.detourRatio, metrics.turnPenalty, metrics.lowAltFrac, metrics.highAltFrac, ...
                NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
                NaN, false, false, false)]; %#ok<AGROW>

        catch
        end
    end

    if isempty(candidates)
        rep.candidateTable = detailRows;
        return;
    end

    % ------------------------------------------------------------
    % feasible first
    % ------------------------------------------------------------
    feasMask = [candidates.feasible] == 1;
    if any(feasMask)
        candUse = candidates(feasMask);
    else
        candUse = candidates;
    end

    % ------------------------------------------------------------
    % cost gate
    % ------------------------------------------------------------
    costVals = [candUse.bestFit];
    bestCost = min(costVals);
    worstCost = max(costVals);

    if abs(worstCost - bestCost) < 1e-12
        gateMask = true(size(costVals));
    else
        if sceneId == 2
            relTol = 0.10;
        else
            relTol = 0.18;
        end
        costThreshold = bestCost + relTol * (worstCost - bestCost);
        gateMask = costVals <= costThreshold;

        if ~any(gateMask)
            [~, idxBest] = min(costVals);
            gateMask(idxBest) = true;
        end
    end

    gated = candUse(gateMask);

    % ------------------------------------------------------------
    % representative score
    % ------------------------------------------------------------
    costVals   = [gated.bestFit];
    meanZVals  = [gated.meanZ];
    maxZVals   = [gated.maxZ];
    stdZVals   = [gated.stdZ];
    detourVals = [gated.detourRatio];
    turnVals   = [gated.turnPenalty];
    lowVals    = [gated.lowAltFrac];
    highVals   = [gated.highAltFrac];

    costN   = localNormalize(costVals);
    meanZN  = localNormalize(meanZVals);
    maxZN   = localNormalize(maxZVals);
    stdZN   = localNormalize(stdZVals);
    detourN = localNormalize(detourVals);
    turnN   = localNormalize(turnVals);
    lowPref = 1 - localNormalize(lowVals);
    highN   = localNormalize(highVals);

    if sceneId == 2
        score = ...
            0.35 * costN   + ...
            0.95 * meanZN  + ...
            0.85 * maxZN   + ...
            0.35 * stdZN   + ...
            0.90 * detourN + ...
            0.55 * turnN   + ...
            1.20 * lowPref + ...
            1.10 * highN;
    else
        score = ...
            0.40 * costN   + ...
            0.75 * meanZN  + ...
            0.55 * maxZN   + ...
            0.25 * stdZN   + ...
            0.55 * detourN + ...
            0.40 * turnN   + ...
            0.95 * lowPref + ...
            0.80 * highN;
    end

    [bestScore, idx] = min(score);
    chosen = gated(idx);

    rep.runFile      = chosen.file;
    rep.bestFit      = chosen.bestFit;
    rep.score        = bestScore;
    rep.meanZ        = chosen.meanZ;
    rep.maxZ         = chosen.maxZ;
    rep.minZ         = chosen.minZ;
    rep.stdZ         = chosen.stdZ;
    rep.pathLen      = chosen.pathLen;
    rep.detourRatio  = chosen.detourRatio;
    rep.turnPenalty  = chosen.turnPenalty;
    rep.lowAltFrac   = chosen.lowAltFrac;
    rep.highAltFrac  = chosen.highAltFrac;
    rep.feasible     = logical(chosen.feasible);
    rep.bestCtrl     = chosen.bestCtrl;
    rep.bestPath     = chosen.bestPath;

    detailTable = detailRows;

    filesUse = string(cellfun(@localBaseName, {candUse.file}, 'UniformOutput', false));
    filesGated = string(cellfun(@localBaseName, {gated.file}, 'UniformOutput', false));
    chosenFile = string(localBaseName(chosen.file));

    costN_all   = localNormalize([candUse.bestFit]);
    meanZN_all  = localNormalize([candUse.meanZ]);
    maxZN_all   = localNormalize([candUse.maxZ]);
    stdZN_all   = localNormalize([candUse.stdZ]);
    detourN_all = localNormalize([candUse.detourRatio]);
    turnN_all   = localNormalize([candUse.turnPenalty]);
    lowPref_all = 1 - localNormalize([candUse.lowAltFrac]);
    highN_all   = localNormalize([candUse.highAltFrac]);

    if sceneId == 2
        score_all = ...
            0.35 * costN_all   + ...
            0.95 * meanZN_all  + ...
            0.85 * maxZN_all   + ...
            0.35 * stdZN_all   + ...
            0.90 * detourN_all + ...
            0.55 * turnN_all   + ...
            1.20 * lowPref_all + ...
            1.10 * highN_all;
    else
        score_all = ...
            0.40 * costN_all   + ...
            0.75 * meanZN_all  + ...
            0.55 * maxZN_all   + ...
            0.25 * stdZN_all   + ...
            0.55 * detourN_all + ...
            0.40 * turnN_all   + ...
            0.95 * lowPref_all + ...
            0.80 * highN_all;
    end

    for i = 1:numel(filesUse)
        mask = detailTable.runFile == filesUse(i);
        if any(mask)
            detailTable.costNorm(mask)     = costN_all(i);
            detailTable.meanZNorm(mask)    = meanZN_all(i);
            detailTable.maxZNorm(mask)     = maxZN_all(i);
            detailTable.stdZNorm(mask)     = stdZN_all(i);
            detailTable.detourNorm(mask)   = detourN_all(i);
            detailTable.turnNorm(mask)     = turnN_all(i);
            detailTable.lowFracNorm(mask)  = lowPref_all(i);
            detailTable.highFracNorm(mask) = highN_all(i);
            detailTable.repScore(mask)     = score_all(i);
        end
    end

    for i = 1:numel(filesGated)
        mask = detailTable.runFile == filesGated(i);
        if any(mask)
            detailTable.inCostGate(mask) = true;
        end
    end

    maskChosen = detailTable.runFile == chosenFile;
    if any(maskChosen)
        detailTable.isSelected(maskChosen) = true;
    end

    rep.candidateTable = detailTable;
end

% ========================================================================
function metrics = localComputePathMetrics(bestPath, params)

    bestPath = localNormalizeXYZ(bestPath);
    zVals = bestPath(:,3);

    meanZ = mean(zVals, 'omitnan');
    maxZ  = max(zVals);
    minZ  = min(zVals);
    stdZ  = std(zVals, 'omitnan');

    seg = diff(bestPath, 1, 1);
    segLen = sqrt(sum(seg.^2, 2));
    pathLen = sum(segLen);

    startPt = bestPath(1,:);
    endPt   = bestPath(end,:);
    straightDist = norm(endPt - startPt);

    if straightDist < 1e-12
        detourRatio = 1;
    else
        detourRatio = pathLen / straightDist;
    end

    turnPenalty = localTurningPenalty(bestPath);

    [zMin, zMax] = localGetAltitudeRange(params);
    zSpan = max(zMax - zMin, 1e-12);

    lowThreshold  = zMin + 0.35 * zSpan;
    highThreshold = zMin + 0.65 * zSpan;

    lowAltFrac  = mean(zVals <= lowThreshold, 'omitnan');
    highAltFrac = mean(zVals >= highThreshold, 'omitnan');

    metrics.meanZ = meanZ;
    metrics.maxZ = maxZ;
    metrics.minZ = minZ;
    metrics.stdZ = stdZ;
    metrics.pathLen = pathLen;
    metrics.detourRatio = detourRatio;
    metrics.turnPenalty = turnPenalty;
    metrics.lowAltFrac = lowAltFrac;
    metrics.highAltFrac = highAltFrac;
end

% ========================================================================
function [zMin, zMax] = localGetAltitudeRange(params)
    zMin = 0;
    zMax = 100;

    if isfield(params, 'zRange') && isnumeric(params.zRange) && numel(params.zRange) >= 2
        zMin = min(params.zRange(:));
        zMax = max(params.zRange(:));
        return;
    end
    if isfield(params, 'zMin'), zMin = params.zMin; end
    if isfield(params, 'zMax'), zMax = params.zMax; end
end

% ========================================================================
function p = localTurningPenalty(pathPts)
    pathPts = localNormalizeXYZ(pathPts);

    if size(pathPts,1) < 3
        p = 0;
        return;
    end

    v1 = diff(pathPts(1:end-1,:), 1, 1);
    v2 = diff(pathPts(2:end,:),   1, 1);

    n1 = sqrt(sum(v1.^2, 2));
    n2 = sqrt(sum(v2.^2, 2));

    valid = n1 > 1e-12 & n2 > 1e-12;
    if ~any(valid)
        p = 0;
        return;
    end

    v1 = v1(valid,:);
    v2 = v2(valid,:);
    n1 = n1(valid);
    n2 = n2(valid);

    cosang = sum(v1 .* v2, 2) ./ (n1 .* n2);
    cosang = max(min(cosang, 1), -1);
    ang = acos(cosang);

    p = mean(ang, 'omitnan');
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
            if isfield(params, 'degree') && isfield(params, 'nSamples')
                bestPath = bsplinePath(bestCtrl, params.degree, params.nSamples);
            elseif isfield(params, 'degree')
                bestPath = bsplinePath(bestCtrl, params.degree);
            else
                bestPath = bsplinePath(bestCtrl);
            end
        catch
            bestPath = [];
        end
    end

    bestCtrl = localNormalizeXYZ(bestCtrl);
    bestPath = localNormalizeXYZ(bestPath);
end

% ========================================================================
function arr = localNormalizeXYZ(arr)
    if isempty(arr) || ~isnumeric(arr)
        return;
    end

    if size(arr,2) >= 3
        arr = arr(:,1:3);
    elseif size(arr,1) >= 3
        arr = arr(1:3,:).';
    end
end

% ========================================================================
function x = localNormalize(v)
    v = double(v(:));
    if isempty(v)
        x = v;
        return;
    end

    finiteMask = isfinite(v);
    if ~any(finiteMask)
        x = zeros(size(v));
        return;
    end

    vf = v(finiteMask);
    vmin = min(vf);
    vmax = max(vf);

    x = zeros(size(v));
    if abs(vmax - vmin) < 1e-12
        x(finiteMask) = 0;
    else
        x(finiteMask) = (vf - vmin) ./ (vmax - vmin);
    end
end

% ========================================================================
function tf = localLogical(v)
    if islogical(v)
        tf = any(v(:));
    elseif isnumeric(v)
        tf = any(v(:) ~= 0);
    else
        tf = false;
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

% ========================================================================
function T = localBuildRepresentativeTable(repData)

    n = numel(repData);

    algName      = strings(n,1);
    runFile      = strings(n,1);
    bestFit      = nan(n,1);
    score        = nan(n,1);
    feasible     = false(n,1);
    meanZ        = nan(n,1);
    maxZ         = nan(n,1);
    minZ         = nan(n,1);
    stdZ         = nan(n,1);
    pathLen      = nan(n,1);
    detourRatio  = nan(n,1);
    turnPenalty  = nan(n,1);
    lowAltFrac   = nan(n,1);
    highAltFrac  = nan(n,1);

    for i = 1:n
        algName(i)     = string(repData(i).algName);
        runFile(i)     = string(localBaseName(repData(i).runFile));
        bestFit(i)     = repData(i).bestFit;
        score(i)       = repData(i).score;
        feasible(i)    = logical(repData(i).feasible);
        meanZ(i)       = repData(i).meanZ;
        maxZ(i)        = repData(i).maxZ;
        minZ(i)        = repData(i).minZ;
        stdZ(i)        = repData(i).stdZ;
        pathLen(i)     = repData(i).pathLen;
        detourRatio(i) = repData(i).detourRatio;
        turnPenalty(i) = repData(i).turnPenalty;
        lowAltFrac(i)  = repData(i).lowAltFrac;
        highAltFrac(i) = repData(i).highAltFrac;
    end

    T = table(algName, runFile, feasible, bestFit, score, ...
        meanZ, maxZ, minZ, stdZ, pathLen, detourRatio, turnPenalty, lowAltFrac, highAltFrac);
end

% ========================================================================
function T = localEmptyCandidateTable()
    T = table( ...
        strings(0,1), ...
        zeros(0,1),   ...
        strings(0,1), ...
        zeros(0,1),   ...
        false(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        zeros(0,1),   ...
        false(0,1),   ...
        false(0,1),   ...
        false(0,1),   ...
        'VariableNames', { ...
            'algorithm','sceneId','runFile','bestFit','feasible', ...
            'meanZ','maxZ','minZ','stdZ','pathLen','detourRatio','turnPenalty', ...
            'lowAltFrac','highAltFrac', ...
            'costNorm','meanZNorm','maxZNorm','stdZNorm','detourNorm','turnNorm', ...
            'lowFracNorm','highFracNorm','repScore','inCostGate','manualSelected','isSelected'});
end

% ========================================================================
function row = localMakeCandidateRow( ...
    algorithm, sceneId, runFile, bestFit, feasible, ...
    meanZ, maxZ, minZ, stdZ, pathLen, detourRatio, turnPenalty, ...
    lowAltFrac, highAltFrac, ...
    costNorm, meanZNorm, maxZNorm, stdZNorm, detourNorm, turnNorm, ...
    lowFracNorm, highFracNorm, repScore, inCostGate, manualSelected, isSelected)

    row = table( ...
        string(algorithm), ...
        sceneId, ...
        string(runFile), ...
        bestFit, ...
        logical(feasible), ...
        meanZ, ...
        maxZ, ...
        minZ, ...
        stdZ, ...
        pathLen, ...
        detourRatio, ...
        turnPenalty, ...
        lowAltFrac, ...
        highAltFrac, ...
        costNorm, ...
        meanZNorm, ...
        maxZNorm, ...
        stdZNorm, ...
        detourNorm, ...
        turnNorm, ...
        lowFracNorm, ...
        highFracNorm, ...
        repScore, ...
        logical(inCostGate), ...
        logical(manualSelected), ...
        logical(isSelected), ...
        'VariableNames', { ...
            'algorithm','sceneId','runFile','bestFit','feasible', ...
            'meanZ','maxZ','minZ','stdZ','pathLen','detourRatio','turnPenalty', ...
            'lowAltFrac','highAltFrac', ...
            'costNorm','meanZNorm','maxZNorm','stdZNorm','detourNorm','turnNorm', ...
            'lowFracNorm','highFracNorm','repScore','inCostGate','manualSelected','isSelected'});
end

% ========================================================================
function T = localAlignCandidateTable(T)
    template = localEmptyCandidateTable();
    wantNames = template.Properties.VariableNames;
    haveNames = T.Properties.VariableNames;

    for i = 1:numel(wantNames)
        vn = wantNames{i};
        if ~ismember(vn, haveNames)
            T.(vn) = template.(vn);
        end
    end

    T = T(:, wantNames);
end

% ========================================================================
function b = localBaseName(fp)
    if isempty(fp)
        b = "";
        return;
    end
    [~, name, ext] = fileparts(char(fp));
    b = [name, ext];
end