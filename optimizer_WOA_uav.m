function result = optimizer_WOA_uav(objFun, params, map, refX, algCfg, runSeed)
%OPTIMIZER_WOA_UAV Whale Optimization Algorithm baseline for UAV path planning.
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
%   - Clean WOA baseline
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
    b = algCfg.b;

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
    % Global best by Deb rule
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
    % ------------------------------------------------------------
    for t = 1:maxIter
        a = 2 - 2 * (t - 1) / max(maxIter - 1, 1);

        for i = 1:popSize
            Xi = X(i, :);

            r1 = rand;
            r2 = rand;

            A = 2 * a * r1 - a;
            C = 2 * r2;
            p = rand;

            if p < 0.5
                if abs(A) < 1
                    % Encircling prey
                    D = abs(C * bestX - Xi);
                    Xnew = bestX - A * D;
                else
                    % Search for prey
                    randIdx = randi(popSize);
                    Xrand = X(randIdx, :);
                    D = abs(C * Xrand - Xi);
                    Xnew = Xrand - A * D;
                end
            else
                % Spiral updating
                D = abs(bestX - Xi);
                l = -1 + 2 * rand;  % in [-1,1]
                Xnew = D .* exp(b * l) .* cos(2 * pi * l) + bestX;
            end

            if usePublicProjection
                Xnew = localProjectSolution(Xnew, lb, ub);
            end

            [fNew, dNew] = objFun(Xnew);
            nEvals = nEvals + 1;

            X(i, :) = Xnew;
            fit(i) = fNew;
            detail(i) = dNew;

            if debBetter(fNew, dNew, bestFit, bestDetail)
                bestFit = fNew;
                bestDetail = dNew;
                bestX = Xnew;
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