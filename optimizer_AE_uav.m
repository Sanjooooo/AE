function result = optimizer_AE_uav(objFun, params, map, refX, algCfg, runSeed)
%OPTIMIZER_AE_UAV Baseline AE-style optimizer for UAV path planning.
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
%   - This is a clean AE baseline.
%   - No AOS / no Repair / no Regen.
%   - Same spline encoding and same objective as FAE-AE.

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

    % evaluate first particle to get full detail schema
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
    % Global best initialization by Deb rule
    % ------------------------------------------------------------
    bestFit = fit(1);
    bestDetail = detail(1);
    bestX = X(1, :);

    for i = 2:popSize
        if debBetter(fit(i), detail(i), bestFit, bestDetail)
            bestFit = fit(i);
            bestDetail = detail(i);
            bestX = X(i, :);
        end
    end

    bestHist = inf(maxIter, 1);

    tStart = tic;

    % ------------------------------------------------------------
    % Main loop
    % Clean AE baseline: fixed balanced operator, no adaptive modules
    % ------------------------------------------------------------
    for t = 1:maxIter
        tau = t / maxIter;
        rho = 0.15 + 0.85 * (1 - tau)^1.2;

        [~, order] = sort(fit, 'ascend');
        eliteNum = max(2, ceil(0.25 * popSize));
        eliteSet = X(order(1:eliteNum), :);
        eliteMean = mean(eliteSet, 1);

        for i = 1:popSize
            x = X(i, :);

            idxPool = setdiff(1:popSize, i);
            perm = idxPool(randperm(numel(idxPool), min(4, numel(idxPool))));
            while numel(perm) < 4
                perm(end+1) = idxPool(randi(numel(idxPool))); %#ok<AGROW>
            end

            xr1 = X(perm(1), :);
            xr2 = X(perm(2), :);
            xr3 = X(perm(3), :);
            xr4 = X(perm(4), :);

            xElite = X(order(randi(eliteNum)), :);

            dirBest = bestX - x;
            dirElite = eliteMean - x;
            dirSample = xElite - x;

            diff12 = xr1 - xr2;
            diff34 = xr3 - xr4;

            randVec1 = 2 * rand(1, dim) - 1;

            % fixed balanced AE-style operator
            a1 = 0.30 + 0.10 * (1 - tau);
            a2 = 0.25 + 0.10 * tau;
            a3 = 0.22 + 0.08 * (1 - tau);
            a4 = 0.08;
            a5 = 0.06;

            step = ...
                a1 * rand(1, dim) .* dirElite + ...
                a2 * rand(1, dim) .* dirBest  + ...
                a3 * (0.6 * diff12 + 0.4 * diff34) + ...
                a4 * rand(1, dim) .* dirSample + ...
                a5 * rho * randVec1 .* (ub - lb);

            xNew = x + step;

            % convex recombination refinement
            eta = 0.20 + 0.35 * (1 - tau);
            mixElite = 0.10 + 0.10 * tau;

            xNew = (1 - eta - mixElite) * xNew + ...
                   eta * x + ...
                   mixElite * xElite;

            if usePublicProjection
                xNew = localProjectSolution(xNew, lb, ub);
            end

            [fNew, dNew] = objFun(xNew);
            nEvals = nEvals + 1;

            if debBetter(fNew, dNew, fit(i), detail(i))
                X(i, :) = xNew;
                fit(i) = fNew;
                detail(i) = dNew;

                if debBetter(fNew, dNew, bestFit, bestDetail)
                    bestFit = fNew;
                    bestDetail = dNew;
                    bestX = xNew;
                end
            end
        end

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

    % compatibility aliases for unified batch layer
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
% lightweight public projection only
    x = min(max(x, lb), ub);
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