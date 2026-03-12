function result = run_single_FAEAE_case(expCfg, runId)
%RUN_SINGLE_FAEAE_CASE Single independent run of FAE-AE / ablation variant.

params = defaultParams();

params.seed = expCfg.baseSeed + runId - 1;
params.sceneId = expCfg.sceneId;

params.useInit = expCfg.useInit;
params.useAOS = expCfg.useAOS;
params.useRepair = expCfg.useRepair;
params.useRegen = expCfg.useRegen;
params.useHeightTerm = expCfg.useHeightTerm;
params.useBoundaryTerm = expCfg.useBoundaryTerm;

rng(params.seed);

map = createMap(params);

% ---------- Reference path / reference control ----------
if params.useInit
    refCtrl = generateReferencePath(map, params);
else
    refCtrl = simpleReferencePath(params);
end
refX = encodeControlPoints(refCtrl);

% ---------- Initialization ----------
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

tStart = tic;

for t = 1:params.maxIter
    for i = 1:params.popSize
        if params.useAOS
            opIdx = selectOperator_UCB(aos, t, params);
        else
            opIdx = 2;   % fixed balanced operator when AOS is disabled
        end

        Xold = pop(i, :);
        fold = fit(i);
        dold = detail(i);

        Xnew = applyOperator_FAEAE(i, pop, fit, bestX, refX, opIdx, t, params);

        if params.useRepair
            [Xnew, ~] = repairPath(Xnew, map, params);
        end

        [fnew, dnew] = fitnessFAEAE(Xnew, map, params);

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

    for i = 1:params.popSize
        if debBetter(fit(i), detail(i), bestFit, bestDetail)
            bestFit = fit(i);
            bestX = pop(i, :);
            bestDetail = detail(i);
        end
    end

    bestHist(t) = bestFit;

    if params.useRegen
        if stagnationDetected(bestHist, pop, detail, t, params)
            [pop, fit, detail] = regeneratePopulation(pop, fit, detail, bestX, map, params);
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

bestCtrl = decodeSolution(bestX, params);
bestPath = bsplinePath(bestCtrl, params.degree, params.nSamples);

result.runId = runId;
result.seed = params.seed;
result.algorithmName = expCfg.algorithmName;

result.bestFit = bestFit;
result.bestDetail = bestDetail;
result.bestX = bestX;
result.bestCtrl = bestCtrl;
result.bestPath = bestPath;
result.bestHist = bestHist;
result.runTime = runTime;

result.finalFeasible = bestDetail.isFeasible;
result.finalViolation = bestDetail.V;

if params.useAOS
    result.aosCounts = aos.counts;
    result.aosMeanReward = aos.meanReward;
else
    result.aosCounts = [0 0 0];
    result.aosMeanReward = [0 0 0];
end

if expCfg.showSingleRunFigure
    figure('Color','w');
    plot(bestHist,'LineWidth',1.8); grid on;
    xlabel('Iteration'); ylabel('Best objective');
    title(sprintf('%s Run %d', expCfg.algorithmName, runId));

    plotSceneAndPath(map, bestPath, bestCtrl, params);
end
end

function refCtrl = simpleReferencePath(params)
% Straight-line low-altitude reference for baseline/non-init versions.

nFull = params.nCtrl + 2;
refCtrl = zeros(nFull, 3);

for i = 1:nFull
    tau = (i - 1) / (nFull - 1);
    p = (1 - tau) * params.start + tau * params.goal;
    p(3) = (1 - tau) * params.start(3) + tau * params.goal(3);
    refCtrl(i,:) = p;
end

refCtrl(1,:) = params.start;
refCtrl(end,:) = params.goal;
end