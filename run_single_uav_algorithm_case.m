    function result = run_single_uav_algorithm_case(algName, sceneId, cfg, runId)
%RUN_SINGLE_UAV_ALGORITHM_CASE Run one UAV planning case for one algorithm.
%
% Inputs:
%   algName - 'AE','PSO','GWO','HHO','WOA','FAEAE'
%   sceneId - scene id, e.g. 1/2/4
%   cfg     - comparison config from getUAVComparisonConfig()
%   runId   - run index
%
% Output:
%   result  - standardized result struct

    % ------------------------------------------------------------
    % Reproducible seed
    % ------------------------------------------------------------
    runSeed = cfg.baseSeed + 1000 * sceneId + runId;
    rng(runSeed, 'twister');

    % ------------------------------------------------------------
    % Base params
    % ------------------------------------------------------------
    params = defaultParams();
    params.sceneId = sceneId;

    % Batch-stage plotting off
    params.saveFigures = cfg.saveFigures;
    params.showSingleRunFigure = cfg.showSingleRunFigure;
    params.showBatchFigure = cfg.showBatchFigure;
    params.saveBestPathFigure = cfg.saveBestPathFigure;
    params.saveBestTopViewFigure = cfg.saveBestTopViewFigure;

    % Optional overrides
    if isfield(cfg, 'paramsOverride') && ~isempty(cfg.paramsOverride)
        overrideFields = fieldnames(cfg.paramsOverride);
        for k = 1:numel(overrideFields)
            params.(overrideFields{k}) = cfg.paramsOverride.(overrideFields{k});
        end
    end
        % ---------- Scene-4 low-altitude corridor override ----------
    if params.sceneId == 4
        params.altMin = 8;
        params.altMax = 26;
        params.heightRef = 14;
        params.weights.H = 1.20;
    
        % IMPORTANT:
        % also update the z-bounds used by the control-point decision variables
        params.lbSingle(3) = params.altMin;
        params.ubSingle(3) = params.altMax;
        params.lb = repmat(params.lbSingle, 1, params.nCtrl);
        params.ub = repmat(params.ubSingle, 1, params.nCtrl);
    end
    % ------------------------------------------------------------
    % Scene
    % ------------------------------------------------------------
    map = createMap(params);

    % ------------------------------------------------------------
    % Reference path / reference solution
    % ------------------------------------------------------------
    refCtrl = [];
    refX = [];

    if exist('generateReferencePath', 'file') == 2
        try
            refCtrl = generateReferencePath(map, params);
        catch
            refCtrl = [];
        end
    end

    if isempty(refCtrl) && exist('initReferencePath', 'file') == 2
        try
            refCtrl = initReferencePath(map, params);
        catch
            refCtrl = [];
        end
    end

    if ~isempty(refCtrl)
        % IMPORTANT:
        % Use repository-standard encoding: only interior control points.
        refX = encodeControlPoints(refCtrl);
    end

    % ------------------------------------------------------------
    % Objective function
    % ------------------------------------------------------------
    objFun = @(x) localEvaluateUAV(x, map, params);

    % ------------------------------------------------------------
    % Algorithm config
    % ------------------------------------------------------------
    algCfg = getUAVAlgorithmConfig(algName, params, cfg);

    % ------------------------------------------------------------
    % Dispatch
    % ------------------------------------------------------------
    switch upper(algName)
        case 'AE'
            result = optimizer_AE_uav(objFun, params, map, refX, algCfg, runSeed);

        case 'PSO'
            result = optimizer_PSO_uav(objFun, params, map, refX, algCfg, runSeed);

        case 'GWO'
            result = optimizer_GWO_uav(objFun, params, map, refX, algCfg, runSeed);

        case 'HHO'
            result = optimizer_HHO_uav(objFun, params, map, refX, algCfg, runSeed);

        case 'WOA'
            result = optimizer_WOA_uav(objFun, params, map, refX, algCfg, runSeed);

        case 'FAEAE'
            result = optimizer_FAEAE_uav(objFun, params, map, refX, algCfg, runSeed);

        otherwise
            error('Unknown algorithm: %s', algName);
    end

    % ------------------------------------------------------------
    % Decode best solution to path representation if possible
    % ------------------------------------------------------------
    bestCtrl = [];
    bestPath = [];
    bestDetail = struct();

    if isfield(result, 'bestDetail')
        bestDetail = result.bestDetail;
    end

    if isfield(result, 'bestX') && ~isempty(result.bestX)
        try
            bestCtrl = reshape(result.bestX(:), [], 3);
        catch
            bestCtrl = [];
        end
    end

    % If your repository has a standard control-point decode function, use it.
    if isempty(bestCtrl) && exist('decodeSolution', 'file') == 2
        try
            bestCtrl = decodeSolution(result.bestX, params);
        catch
            bestCtrl = [];
        end
    end

    % If your repository has a path generator, use it.
    if ~isempty(bestCtrl) && exist('bsplinePath', 'file') == 2
        try
            bestPath = bsplinePath(bestCtrl, params.degree, params.nSamples);
        catch
            bestPath = [];
        end
    end

    % ------------------------------------------------------------
    % Standardize output metadata
    % ------------------------------------------------------------
    result.algorithmName = upper(algName);
    result.sceneId = sceneId;
    result.runId = runId;
    result.seed = runSeed;

    if ~isfield(result, 'bestCtrl')
        result.bestCtrl = bestCtrl;
    end
    if ~isfield(result, 'bestPath')
        result.bestPath = bestPath;
    end
    if ~isfield(result, 'bestDetail')
        result.bestDetail = bestDetail;
    end

    if ~isfield(result, 'finalFeasible')
        if isfield(bestDetail, 'feasible')
            result.finalFeasible = logical(bestDetail.feasible);
        elseif isfield(bestDetail, 'isFeasible')
            result.finalFeasible = logical(bestDetail.isFeasible);
        else
            result.finalFeasible = NaN;
        end
    end

    if ~isfield(result, 'finalViolation')
        if isfield(bestDetail, 'violation')
            result.finalViolation = bestDetail.violation;
        elseif isfield(bestDetail, 'V')
            result.finalViolation = bestDetail.V;
        else
            result.finalViolation = NaN;
        end
    end

    if ~isfield(result, 'nEvals')
        result.nEvals = NaN;
    end
end


% ========================================================================
function [fit, detail] = localEvaluateUAV(x, map, params)
% Unified adapter around your existing UAV fitness evaluator.

    if size(x, 2) > 1 && size(x, 1) > 1
        x = x(:);
    end

    % Your current repository uses fitnessFAEAE as the main evaluator.
    [fit, detail] = fitnessFAEAE(x, map, params);
end