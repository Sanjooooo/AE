%% FAE-AE for 3D UAV Path Planning
% MATLAB R2022b
% This is a runnable framework version for your paper experiments.
% If you later decide to strictly reproduce the exact original AE equations,
% only replace the file applyOperator_FAEAE.m and keep the rest unchanged.

clear; clc; close all;

params = defaultParams();
rng(params.seed);
map = createMap(params);
refCtrl = generateReferencePath(map, params);
refX = encodeControlPoints(refCtrl);

[pop, fit, detail] = init_FAEAE(params, map, refCtrl);
aos = initAOS(params);

bestHist = inf(params.maxIter, 1);
[bestFit, bestIdx] = min(fit);
bestX = pop(bestIdx, :);
bestDetail = detail(bestIdx);

fprintf('FAE-AE started: pop=%d, iter=%d, dim=%d\n', params.popSize, params.maxIter, params.dim);
fprintf('Initial best = %.6f, feasible = %d\n', bestFit, bestDetail.isFeasible);

for t = 1:params.maxIter
    for i = 1:params.popSize
        opIdx = selectOperator_UCB(aos, t, params);

        Xold = pop(i, :);
        fold = fit(i);
        dold = detail(i);

        Xnew = applyOperator_FAEAE(i, pop, fit, bestX, refX, opIdx, t, params);
        [Xnew, ~] = repairPath(Xnew, map, params);
        [fnew, dnew] = fitnessFAEAE(Xnew, map, params);

        reward = computeReward(fold, dold, fnew, dnew, params);
        aos = updateAOS(aos, opIdx, reward);

        if debBetter(fnew, dnew, fold, dold)
            pop(i, :) = Xnew;
            fit(i) = fnew;
            detail(i) = dnew;
        end
    end

    % Update global best using Deb's rules
    for i = 1:params.popSize
        if debBetter(fit(i), detail(i), bestFit, bestDetail)
            bestFit = fit(i);
            bestX = pop(i, :);
            bestDetail = detail(i);
        end
    end

    bestHist(t) = bestFit;

    % Stagnation-aware structured regeneration
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

    if mod(t, 20) == 0 || t == 1 || t == params.maxIter
        feasRatio = mean([detail.isFeasible]);
        fprintf('Iter %3d | Best = %.6f | FeasRatio = %.2f | UCB counts = [%d %d %d]\n', ...
            t, bestFit, feasRatio, aos.counts(1), aos.counts(2), aos.counts(3));
    end
end

bestCtrl = decodeSolution(bestX, params);
bestPath = bsplinePath(bestCtrl, params.degree, params.nSamples);

fprintf('\nFinal best objective = %.6f\n', bestFit);
fprintf('Feasible = %d | L = %.4f | E = %.4f | R = %.4f | S = %.4f | V = %.4f\n', ...
    bestDetail.isFeasible, bestDetail.L, bestDetail.E, bestDetail.R, bestDetail.S, bestDetail.V);

figure('Color', 'w');
plot(bestHist, 'LineWidth', 1.8);
grid on; xlabel('Iteration'); ylabel('Best objective');
title('FAE-AE Convergence Curve');

plotSceneAndPath(map, bestPath, bestCtrl, params);