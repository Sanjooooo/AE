function result = optimizer_FAEAE_uav(objFun, params, map, refX, algCfg, runSeed)
%OPTIMIZER_FAEAE_UAV Full FAE-AE optimizer for UAV path planning.
%
% This is the optimizer-layer extraction of the existing FAE-AE logic used
% in run_single_FAEAE_case.m, rewritten to fit the unified multi-algorithm
% UAV framework.
%
% Inputs:
%   objFun   - objective handle: [fit, detail] = objFun(x)
%   params   - parameter struct from defaultParams(), already scene-ready
%   map      - map struct from createMap(params)
%   refX     - reference solution vector (encoded control points). May be []
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
%   result.aosCounts
%   result.aosMeanReward

    if nargin >= 6 && ~isempty(runSeed)
        rng(runSeed, 'twister');
    end

    % ------------------------------------------------------------
    % Write semantic flags into params, so existing helper functions
    % behave exactly like your ablation version.
    % ------------------------------------------------------------
    params.useInit = true;
    params.useAOS = true;
    params.useRepair = true;
    params.useRegen = true;

    if isfield(algCfg, 'useReferenceInit')
        params.useInit = logical(algCfg.useReferenceInit);
    end
    if isfield(algCfg, 'useAOS')
        params.useAOS = logical(algCfg.useAOS);
    end
    if isfield(algCfg, 'useRepair')
        params.useRepair = logical(algCfg.useRepair);
    end
    if isfield(algCfg, 'useRegen')
        params.useRegen = logical(algCfg.useRegen);
    end

    % Keep optional terms aligned with your existing fitness logic.
    if ~isfield(params, 'useHeightTerm')
        params.useHeightTerm = true;
    end
    if ~isfield(params, 'useBoundaryTerm')
        params.useBoundaryTerm = true;
    end

    % Shared search size
    if isfield(algCfg, 'popSize')
        params.popSize = algCfg.popSize;
    end
    if isfield(algCfg, 'maxIter')
        params.maxIter = algCfg.maxIter;
    end

    % ------------------------------------------------------------
    % Reference solution
    % ------------------------------------------------------------
    if isempty(refX)
        refCtrl = localSimpleReferencePath(params);
        refX = encodeControlPoints(refCtrl);
    else
        try
            refCtrl = decodeSolution(refX, params);
        catch
            refCtrl = localSimpleReferencePath(params);
            refX = encodeControlPoints(refCtrl);
        end
    end

    % ------------------------------------------------------------
    % Initialization
    % Keep exactly the same branch logic as your ablation runner.
    % ------------------------------------------------------------
    if params.useInit
        [pop, fit, detail] = init_FAEAE(params, map, refCtrl);
    else
        [pop, fit, detail] = init_baseline_AE(params, map, refCtrl);
    end

    aos = initAOS(params);

    bestHist = inf(params.maxIter, 1);

    [bestFit, bestIdx] = min(fit);
    bestX = pop(bestIdx, :);
    bestDetail = detail(bestIdx);

    nEvals = numel(fit);

    tStart = tic;

    % ------------------------------------------------------------
    % Main loop
    % ------------------------------------------------------------
    for t = 1:params.maxIter

        for i = 1:params.popSize

            if params.useAOS
                opIdx = selectOperator_UCB(aos, t, params);
            else
                % Keep the same fixed balanced operator convention
                opIdx = 2;
            end

            Xold = pop(i, :);
            fold = fit(i);
            dold = detail(i);

            Xnew = applyOperator_FAEAE(i, pop, fit, bestX, refX, opIdx, t, params);

            if params.useRepair
                [Xnew, ~] = repairPath(Xnew, map, params);
            end

            [fnew, dnew] = objFun(Xnew);
            nEvals = nEvals + 1;

            if params.useAOS
                reward = computeReward(fold, dold, fnew, dnew, params);
                aos = updateAOS(aos, opIdx, reward);
            end

            if debBetter(fnew, dnew, fold, dold)
                pop(i, :) = Xnew;
                fit(i) = fnew;
                detail(i) = dnew;
            end
        end

        % --------------------------------------------------------
        % Global best update
        % --------------------------------------------------------
        for i = 1:params.popSize
            if debBetter(fit(i), detail(i), bestFit, bestDetail)
                bestFit = fit(i);
                bestX = pop(i, :);
                bestDetail = detail(i);
            end
        end

        bestHist(t) = bestFit;

        % --------------------------------------------------------
        % Regeneration
        % --------------------------------------------------------
        if params.useRegen
            if stagnationDetected(bestHist, pop, detail, t, params)
                [pop, fit, detail] = regeneratePopulation(pop, fit, detail, bestX, map, params);
                nEvals = nEvals + params.popSize;  % conservative accounting

                for i = 1:params.popSize
                    if debBetter(fit(i), detail(i), bestFit, bestDetail)
                        bestFit = fit(i);
                        bestX = pop(i, :);
                        bestDetail = detail(i);
                    end
                end

                bestHist(t) = bestFit;
            end
        end
    end

    runTime = toc(tStart);

    % ------------------------------------------------------------
    % Decode best solution
    % ------------------------------------------------------------
    bestCtrl = decodeSolution(bestX, params);
    bestPath = bsplinePath(bestCtrl, params.degree, params.nSamples);

    % ------------------------------------------------------------
    % Standardized output
    % ------------------------------------------------------------
    result = struct();

    result.bestFit = bestFit;
    result.bestDetail = bestDetail;
    result.bestX = bestX;
    result.bestCtrl = bestCtrl;
    result.bestPath = bestPath;
    result.bestHist = bestHist;
    result.runTime = runTime;
    result.finalFeasible = bestDetail.isFeasible;
    result.finalViolation = bestDetail.V;
    result.nEvals = nEvals;

    if params.useAOS
        result.aosCounts = aos.counts;
        result.aosMeanReward = aos.meanReward;
    else
        result.aosCounts = zeros(1, 3);
        result.aosMeanReward = zeros(1, 3);
    end

    % Compatibility aliases for the new unified batch layer
    result.bestFitness = bestFit;
    result.bestPosition = bestX(:);
    result.convergence = bestHist(:);
    result.runtime = runTime;
end


% ========================================================================
function refCtrl = localSimpleReferencePath(params)
% Straight-line low-altitude reference, same logic as your current runner.

    nFull = params.nCtrl + 2;
    refCtrl = zeros(nFull, 3);

    for i = 1:nFull
        tau = (i - 1) / (nFull - 1);
        p = (1 - tau) * params.start + tau * params.goal;
        p(3) = (1 - tau) * params.start(3) + tau * params.goal(3);
        refCtrl(i, :) = p;
    end

    refCtrl(1, :) = params.start;
    refCtrl(end, :) = params.goal;
end