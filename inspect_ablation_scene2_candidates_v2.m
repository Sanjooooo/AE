function T = inspect_ablation_scene2_candidates_v2(resultRoot)
%INSPECT_ABLATION_SCENE2_CANDIDATES_V2
% 列出 Scene 2 下 5 个消融组所有候选 run 的低空指标，便于手动挑图。
%
% 输出：
%   resultRoot/ablation_paper_figures/scene2_ablation_candidates_detail.csv
%
% 返回：
%   T 详细表

    if nargin < 1 || isempty(resultRoot)
        resultRoot = uigetdir(pwd, 'Select ablation result root folder');
        if isequal(resultRoot, 0)
            error('No folder selected.');
        end
    end

    runDir = fullfile(resultRoot, 'run_records');
    outDir = fullfile(resultRoot, 'ablation_paper_figures');
    if ~exist(runDir, 'dir')
        error('Missing run_records folder: %s', runDir);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    sceneId = 2;

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

    params = defaultParams();
    params.sceneId = sceneId;

    T = table();

    for m = 1:numel(methodNames)
        method = methodNames{m};
        safeName = methodSafeNames{m};

        files = dir(fullfile(runDir, sprintf('scene%d_%s_run*.mat', sceneId, safeName)));
        for k = 1:numel(files)
            fp = fullfile(files(k).folder, files(k).name);
            S = load(fp);
            rr = localExtractResultStruct(S);

            [bestCtrl, bestPath] = localRecoverBestPath(rr, params);
            if isempty(bestPath)
                continue;
            end

            metrics = localComputePathMetrics(bestPath, params);

            bestFit = localGetField(rr, {'bestFit','bestFitness','bestCost'}, NaN);
            feasible = localBestRunFeasible(rr);
            runId = localParseRunId(files(k).name);

            row = table( ...
                sceneId, string(method), string(safeName), string(files(k).name), runId, ...
                feasible, bestFit, ...
                metrics.meanZ, metrics.maxZ, metrics.minZ, metrics.stdZ, ...
                metrics.pathLen, metrics.detourRatio, metrics.turnPenalty, ...
                metrics.lowAltFrac, metrics.highAltFrac, ...
                'VariableNames', {'SceneId','Method','SafeName','RunFile','RunId', ...
                'Feasible','BestFit', ...
                'MeanZ','MaxZ','MinZ','StdZ', ...
                'PathLen','DetourRatio','TurnPenalty', ...
                'LowAltFrac','HighAltFrac'} );

            if isempty(T)
                T = row;
            else
                T = [T; row]; %#ok<AGROW>
            end
        end
    end

    % 额外给一个低空综合排序分数：越小越好
    T.LowAltScore = ...
        1.2 * normalizeVec(T.MeanZ) + ...
        1.0 * normalizeVec(T.MaxZ) + ...
        0.5 * normalizeVec(T.StdZ) + ...
        0.6 * normalizeVec(T.DetourRatio) + ...
        0.4 * normalizeVec(T.TurnPenalty) + ...
        1.2 * (1 - normalizeVec(T.LowAltFrac)) + ...
        1.2 * normalizeVec(T.HighAltFrac) + ...
        0.2 * normalizeVec(T.BestFit);

    % 先可行，再按低空分数、成本排序
    T = sortrows(T, {'Method','Feasible','LowAltScore','BestFit'}, {'ascend','descend','ascend','ascend'});

    outCsv = fullfile(outDir, 'scene2_ablation_candidates_detail.csv');
    writetable(T, outCsv);

    fprintf('Saved: %s\n', outCsv);
end

% ========================================================================
function rr = localExtractResultStruct(S)
    if isfield(S, 'result') && isstruct(S.result)
        rr = S.result;
        return;
    end
    fns = fieldnames(S);
    for i = 1:numel(fns)
        if isstruct(S.(fns{i}))
            rr = S.(fns{i});
            return;
        end
    end
    error('Cannot find result struct.');
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
        if ~isempty(bestX)
            try
                bestCtrl = decodeSolution(bestX, params);
            catch
                bestCtrl = [];
            end
        end
    end

    if isempty(bestPath) && ~isempty(bestCtrl)
        try
            bestPath = bsplinePath(bestCtrl, params.degree, params.nSamples);
        catch
            bestPath = [];
        end
    end
end

function metrics = localComputePathMetrics(bestPath, params)
    zVals = bestPath(:,3);

    metrics.meanZ = mean(zVals, 'omitnan');
    metrics.maxZ  = max(zVals);
    metrics.minZ  = min(zVals);
    metrics.stdZ  = std(zVals, 'omitnan');

    seg = diff(bestPath, 1, 1);
    segLen = sqrt(sum(seg.^2, 2));
    metrics.pathLen = sum(segLen);

    startPt = bestPath(1,:);
    endPt   = bestPath(end,:);
    straightDist = norm(endPt - startPt);
    if straightDist < 1e-12
        metrics.detourRatio = 1;
    else
        metrics.detourRatio = metrics.pathLen / straightDist;
    end

    metrics.turnPenalty = localTurningPenalty(bestPath);

    [zMin, zMax] = localGetAltitudeRange(params);
    zSpan = max(zMax - zMin, 1e-12);

    lowThreshold  = zMin + 0.35 * zSpan;
    highThreshold = zMin + 0.65 * zSpan;

    metrics.lowAltFrac  = mean(zVals <= lowThreshold, 'omitnan');
    metrics.highAltFrac = mean(zVals >= highThreshold, 'omitnan');
end

function [zMin, zMax] = localGetAltitudeRange(params)
    zMin = 0; zMax = 100;
    if isfield(params, 'zRange') && isnumeric(params.zRange) && numel(params.zRange) >= 2
        zMin = min(params.zRange(:));
        zMax = max(params.zRange(:));
        return;
    end
    if isfield(params, 'zMin'), zMin = params.zMin; end
    if isfield(params, 'zMax'), zMax = params.zMax; end
end

function p = localTurningPenalty(pathPts)
    if size(pathPts,1) < 3
        p = 0; return;
    end
    v1 = diff(pathPts(1:end-1,:), 1, 1);
    v2 = diff(pathPts(2:end,:),   1, 1);
    n1 = sqrt(sum(v1.^2, 2));
    n2 = sqrt(sum(v2.^2, 2));
    valid = n1 > 1e-12 & n2 > 1e-12;
    if ~any(valid)
        p = 0; return;
    end
    v1 = v1(valid,:); v2 = v2(valid,:);
    n1 = n1(valid);   n2 = n2(valid);
    cosang = sum(v1 .* v2, 2) ./ (n1 .* n2);
    cosang = max(min(cosang, 1), -1);
    ang = acos(cosang);
    p = mean(ang, 'omitnan');
end

function tf = localBestRunFeasible(runStruct)
    tf = false;
    v = localGetField(runStruct, {'finalFeasible'}, NaN);
    if ~isnan(v)
        tf = logical(v); return;
    end
    if isfield(runStruct, 'bestDetail') && isstruct(runStruct.bestDetail)
        bd = runStruct.bestDetail;
        v = localGetField(bd, {'isFeasible','feasible'}, NaN);
        if ~isnan(v), tf = logical(v); end
    end
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

function rid = localParseRunId(fname)
    tok = regexp(fname, 'run(\\d+)', 'tokens', 'once');
    if isempty(tok)
        rid = NaN;
    else
        rid = str2double(tok{1});
    end
end

function x = normalizeVec(v)
    v = double(v(:));
    x = nan(size(v));
    mask = isfinite(v);
    if ~any(mask)
        x(:) = 0; return;
    end
    vmin = min(v(mask));
    vmax = max(v(mask));
    if abs(vmax - vmin) < 1e-12
        x(mask) = 0;
    else
        x(mask) = (v(mask) - vmin) ./ (vmax - vmin);
    end
end