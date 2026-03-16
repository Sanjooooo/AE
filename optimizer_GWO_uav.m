function result = optimizer_GWO_uav(objFun, params, map, refX, algCfg, runSeed)
%OPTIMIZER_GWO_UAV Grey Wolf Optimizer baseline for UAV path planning.
%
% Inputs:
%   objFun   - objective handle: [fit, detail] = objFun(x)
%   params   - parameter struct from defaultParams(), already scene-ready
%   map      - map struct (reserved for compatibility)
%   refX     - reference solution vector, may be []
%   algCfg   - algorithm config from getUAVAlgorithmConfig()
%   runSeed  - RNG seed
%
% Output:
%   result.bestFit
%   result.bestDetail
%   result.bestX
%   result.bestCtrl
%   result.bestPath
%   result.bestHist
%   result.runTime
%   result.finalFeasible
%   result.finalViolation
%   result.nEvals
%
% Notes:
%   - Clean GWO baseline
%   - No FAE-AE-specific modules
%   - Same spline encoding and same objective as FAE-AE

    if nargin >= 6 && ~isempty(runSeed)
        rng(runSeed, 'twister');
    end

    % ------------------------------------------------------------
    % Basic settings
    % ------------------------------------------------------------
    dim = algCfg.dim;
    lb = algCfg.lb(:)';
    ub = algCfg.ub(:)';

    popSize = algCfg.popSize;
    maxIter = algCfg.maxIter;

    useReferenceInit = false;
    referenceInitRatio = 0.0;
    referenceNoiseScale = 0.05;
    usePublicProjection = true;

    if isfield(algCfg, 'useReferenceInit')
        useReferenceInit = logical(algCfg.useReferenceInit);
    end
    if isfield(algCfg, 'referenceInitRatio')
        referenceInitRatio = algCfg.referenceInitRatio;
    end
    if isfield(algCfg, 'referenceNoiseScale')
        referenceNoiseScale = algCfg.referenceNoiseScale;
    end
    if isfield(algCfg, 'usePublicProjection')
        usePublicProjection = logical(algCfg.usePublicProjection);
    end

    % ------------------------------------------------------------
    % Initialization
    % ------------------------------------------------------------
    X = localInitPopulation(popSize, dim, lb, ub, refX, ...
        useReferenceInit, referenceInitRatio, referenceNoiseScale);

    fit = zeros(popSize, 1);

    % Evaluate first wolf to obtain full detail schema
    x1 = X(1, :);
    if usePublicProjection
        x1 = localProjectSolution(x1, lb, ub);
        X(1, :) = x1;
    end
    [fit(1), detail1] = objFun(x1);
    nEvals = 1;

    detail = repmat(detail1, popSize, 1);
    detail(1) = detail1;

    for i = 2:popSize
        xi = X(i, :);

        if usePublicProjection
            xi = localProjectSolution(xi, lb, ub);
            X(i, :) = xi;
        end

        [fit(i), detail(i)] = objFun(xi);
        nEvals = nEvals + 1;
    end

    % ------------------------------------------------------------
    % Initialize alpha / beta / delta by Deb rule
    % ------------------------------------------------------------
    [alphaX, alphaFit, alphaDetail, ...
     betaX, betaFit, betaDetail, ...
     deltaX, deltaFit, deltaDetail] = localTop3ByDeb(X, fit, detail);

    bestX = alphaX;
    bestFit = alphaFit;
    bestDetail = alphaDetail;

    bestHist = inf(maxIter, 1);

    tStart = tic;

    % ------------------------------------------------------------
    % Main loop
    % ------------------------------------------------------------
    for t = 1:maxIter
        a = 2 - 2 * (t - 1) / max(maxIter - 1, 1);

        for i = 1:popSize
            Xi = X(i, :);

            % alpha influence
            r1 = rand(1, dim);
            r2 = rand(1, dim);
            A1 = 2 * a .* r1 - a;
            C1 = 2 * r2;
            D_alpha = abs(C1 .* alphaX - Xi);
            X1 = alphaX - A1 .* D_alpha;

            % beta influence
            r1 = rand(1, dim);
            r2 = rand(1, dim);
            A2 = 2 * a .* r1 - a;
            C2 = 2 * r2;
            D_beta = abs(C2 .* betaX - Xi);
            X2 = betaX - A2 .* D_beta;

            % delta influence
            r1 = rand(1, dim);
            r2 = rand(1, dim);
            A3 = 2 * a .* r1 - a;
            C3 = 2 * r2;
            D_delta = abs(C3 .* deltaX - Xi);
            X3 = deltaX - A3 .* D_delta;

            Xnew = (X1 + X2 + X3) / 3;

            if usePublicProjection
                Xnew = localProjectSolution(Xnew, lb, ub);
            end

            [fNew, dNew] = objFun(Xnew);
            nEvals = nEvals + 1;

            % Standard GWO usually updates the population position directly
            X(i, :) = Xnew;
            fit(i) = fNew;
            detail(i) = dNew;
        end

        % Refresh alpha / beta / delta
        [alphaX, alphaFit, alphaDetail, ...
         betaX, betaFit, betaDetail, ...
         deltaX, deltaFit, deltaDetail] = localTop3ByDeb(X, fit, detail);

        bestX = alphaX;
        bestFit = alphaFit;
        bestDetail = alphaDetail;

        bestHist(t) = bestFit;
    end

    runTime = toc(tStart);

    % ------------------------------------------------------------
    % Decode best solution
    % ------------------------------------------------------------
    bestCtrl = [];
    bestPath = [];

    if exist('decodeSolution', 'file') == 2
        try
            bestCtrl = decodeSolution(bestX, params);
        catch
            bestCtrl = [];
        end
    end

    if ~isempty(bestCtrl) && exist('bsplinePath', 'file') == 2
        try
            bestPath = bsplinePath(bestCtrl, params.degree, params.nSamples);
        catch
            bestPath = [];
        end
    end

    % ------------------------------------------------------------
    % Output
    % ------------------------------------------------------------
    result = struct();

    result.bestFit = bestFit;
    result.bestDetail = bestDetail;
    result.bestX = bestX;
    result.bestCtrl = bestCtrl;
    result.bestPath = bestPath;
    result.bestHist = bestHist;
    result.runTime = runTime;
    result.finalFeasible = localGetField(bestDetail, {'isFeasible', 'feasible'}, NaN);
    result.finalViolation = localGetField(bestDetail, {'V', 'violation'}, NaN);
    result.nEvals = nEvals;

    % Compatibility aliases for unified batch layer
    result.bestFitness = bestFit;
    result.bestPosition = bestX(:);
    result.convergence = bestHist(:);
    result.runtime = runTime;
end


% ========================================================================
function X = localInitPopulation(popSize, dim, lb, ub, refX, ...
    useReferenceInit, referenceInitRatio, referenceNoiseScale)

    X = repmat(lb, popSize, 1) + rand(popSize, dim) .* repmat((ub - lb), popSize, 1);

    if useReferenceInit && ~isempty(refX)
        refX = refX(:)';
        nRef = max(1, round(referenceInitRatio * popSize));
        nRef = min(nRef, popSize);

        sigma = referenceNoiseScale * (ub - lb);

        for i = 1:nRef
            xi = refX + randn(1, dim) .* sigma;
            xi = min(max(xi, lb), ub);
            X(i, :) = xi;
        end
    end
end

% ========================================================================
function x = localProjectSolution(x, lb, ub)
% Lightweight public projection only.
    x = min(max(x, lb), ub);
end

% ========================================================================
function [alphaX, alphaFit, alphaDetail, ...
          betaX, betaFit, betaDetail, ...
          deltaX, deltaFit, deltaDetail] = localTop3ByDeb(X, fit, detail)

    popSize = size(X, 1);
    order = 1:popSize;

    % simple Deb-based selection sort for top-3
    for i = 1:popSize-1
        bestIdx = i;
        for j = i+1:popSize
            if debBetter(fit(order(j)), detail(order(j)), fit(order(bestIdx)), detail(order(bestIdx)))
                bestIdx = j;
            end
        end
        if bestIdx ~= i
            tmp = order(i);
            order(i) = order(bestIdx);
            order(bestIdx) = tmp;
        end
    end

    idx1 = order(1);
    idx2 = order(min(2, popSize));
    idx3 = order(min(3, popSize));

    alphaX = X(idx1, :);
    alphaFit = fit(idx1);
    alphaDetail = detail(idx1);

    betaX = X(idx2, :);
    betaFit = fit(idx2);
    betaDetail = detail(idx2);

    deltaX = X(idx3, :);
    deltaFit = fit(idx3);
    deltaDetail = detail(idx3);
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