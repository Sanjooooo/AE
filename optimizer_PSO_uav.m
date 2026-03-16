function result = optimizer_PSO_uav(objFun, params, map, refX, algCfg, runSeed)
%OPTIMIZER_PSO_UAV PSO baseline for UAV path planning.
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
%   - This is a clean PSO baseline.
%   - It does NOT use FAE-AE-specific AOS / repair / regen.
%   - It shares the same encoding and objective function as FAE-AE.

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

    w  = algCfg.w;
    c1 = algCfg.c1;
    c2 = algCfg.c2;
    vmax = algCfg.vmaxRatio * (ub - lb);

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

    V = -repmat(vmax, popSize, 1) + 2 * repmat(vmax, popSize, 1) .* rand(popSize, dim);

    fit = zeros(popSize, 1);

    % Evaluate first particle to get the full detail struct schema
    xi = X(1, :);
    if usePublicProjection
        xi = localProjectSolution(xi, lb, ub);
        X(1, :) = xi;
    end

    [fit(1), detail1] = objFun(xi);
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

    % Personal best
    pbestX = X;
    pbestFit = fit;
    pbestDetail = detail;

    % Global best by Deb rule
    bestIdx = 1;
    bestFit = fit(1);
    bestDetail = detail(1);
    bestX = X(1, :);

    for i = 2:popSize
        if debBetter(fit(i), detail(i), bestFit, bestDetail)
            bestFit = fit(i);
            bestDetail = detail(i);
            bestX = X(i, :);
            bestIdx = i; %#ok<NASGU>
        end
    end

    bestHist = inf(maxIter, 1);

    tStart = tic;

    % ------------------------------------------------------------
    % Main loop
    % ------------------------------------------------------------
    for t = 1:maxIter

        for i = 1:popSize
            r1 = rand(1, dim);
            r2 = rand(1, dim);

            % Velocity update
            V(i, :) = w * V(i, :) ...
                + c1 * r1 .* (pbestX(i, :) - X(i, :)) ...
                + c2 * r2 .* (bestX - X(i, :));

            % Velocity clamp
            V(i, :) = min(max(V(i, :), -vmax), vmax);

            % Position update
            Xnew = X(i, :) + V(i, :);

            if usePublicProjection
                Xnew = localProjectSolution(Xnew, lb, ub);
            end

            [fnew, dnew] = objFun(Xnew);
            nEvals = nEvals + 1;

            % Accept new state unconditionally as particle state
            X(i, :) = Xnew;
            fit(i) = fnew;
            detail(i) = dnew;

            % Personal best by Deb rule
            if debBetter(fnew, dnew, pbestFit(i), pbestDetail(i))
                pbestX(i, :) = Xnew;
                pbestFit(i) = fnew;
                pbestDetail(i) = dnew;
            end

            % Global best by Deb rule
            if debBetter(fnew, dnew, bestFit, bestDetail)
                bestFit = fnew;
                bestDetail = dnew;
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
% Lightweight public projection only.
% No FAE-AE-specific repair is used here.

    x = min(max(x, lb), ub);
end

% ========================================================================
% function detail = localDefaultDetail()
%     detail = struct();
%     detail.isFeasible = false;
%     detail.V = inf;
% end

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