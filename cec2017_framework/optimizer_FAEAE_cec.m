function result = optimizer_FAEAE_cec(funHandle, lb, ub, dim, maxFEs, runSeed)
%OPTIMIZER_FAEAE_CEC FAE-AE for CEC2017 continuous optimization.
%
% Revised version:
% 1) milder structured initialization
% 2) softer local refinement
% 3) more conservative regeneration
% 4) more stable operator balance for single-peak functions

rng(runSeed);

% ---------- Parameters ----------
popSize = 30;
maxIter = ceil(maxFEs / popSize);

nOps = 3;
ucbC = 0.75;
ucbEps = 1e-9;

betaJ = 1.0;

regenWindow = 25;
regenTol = 1e-12;
regenRatio = 0.18;
eliteFrac = 0.25;

% ---------- Structured diversified initialization ----------
pop = structuredInitializationCEC_v2(lb, ub, dim, popSize);
fit = inf(1, popSize);

FEs = 0;
for i = 1:popSize
    fit(i) = funHandle(pop(:, i));
    FEs = FEs + 1;
end

[bestFit, bestIdx] = min(fit);
bestX = pop(:, bestIdx);

convergence = inf(maxIter, 1);

% AOS states
aos.counts = zeros(1, nOps);
aos.meanReward = zeros(1, nOps);

tStart = tic;

for t = 1:maxIter
    tau = t / maxIter;
    rho = 0.10 + 0.90 * (1 - tau)^1.3;

    [~, order] = sort(fit, 'ascend');
    eliteNum = max(2, ceil(eliteFrac * popSize));
    eliteSet = pop(:, order(1:eliteNum));
    eliteMean = mean(eliteSet, 2);

    for i = 1:popSize
        if FEs >= maxFEs
            break;
        end

        x = pop(:, i);
        oldFit = fit(i);

        % ---------- AOS ----------
        opIdx = selectOpUCB_CEC_v2(aos, t, maxIter, ucbC, ucbEps);

        idxPool = setdiff(1:popSize, i);
        perm = idxPool(randperm(numel(idxPool), min(4, numel(idxPool))));
        while numel(perm) < 4
            perm(end+1) = idxPool(randi(numel(idxPool))); %#ok<AGROW>
        end

        xr1 = pop(:, perm(1));
        xr2 = pop(:, perm(2));
        xr3 = pop(:, perm(3));
        xr4 = pop(:, perm(4));

        xElite = pop(:, order(randi(eliteNum)));

        dirBest   = bestX - x;
        dirElite  = eliteMean - x;
        dirSample = xElite - x;

        diff12 = xr1 - xr2;
        diff34 = xr3 - xr4;

        randVec1 = 2 * rand(dim, 1) - 1;
        randVec2 = randn(dim, 1);

        switch opIdx
            case 1
                % Global exploration (softer than previous version)
                a1 = 0.18 + 0.18 * (1 - tau);
                a2 = 0.10 + 0.12 * (1 - tau);
                a3 = 0.40 + 0.15 * (1 - tau);
                a4 = 0.08;
                a5 = 0.06 + 0.08 * (1 - tau);

                step = ...
                    a1 * rand(dim,1) .* dirElite + ...
                    a2 * rand(dim,1) .* dirBest  + ...
                    a3 * (0.6 * diff12 + 0.4 * diff34) + ...
                    a4 * rand(dim,1) .* dirSample + ...
                    a5 * rho * randVec1 .* (ub - lb);

            case 2
                % Balanced search (main operator)
                a1 = 0.30 + 0.10 * (1 - tau);
                a2 = 0.24 + 0.10 * tau;
                a3 = 0.14 + 0.05 * (1 - tau);
                a4 = 0.12;
                a5 = 0.035 + 0.02 * (1 - tau);

                step = ...
                    a1 * rand(dim,1) .* dirElite + ...
                    a2 * rand(dim,1) .* dirBest  + ...
                    a3 * diff12 + ...
                    a4 * rand(dim,1) .* dirSample + ...
                    a5 * rho * randVec2 .* (ub - lb);

            case 3
                % Local exploitation (more conservative)
                localScale = 0.05 + 0.10 * (1 - tau)^0.8;

                a1 = 0.38 + 0.15 * tau;
                a2 = 0.35 + 0.15 * tau;
                a3 = 0.04 + 0.04 * (1 - tau);
                a4 = 0.05;
                a5 = 0.015;

                step = ...
                    a1 * rand(dim,1) .* dirElite + ...
                    a2 * rand(dim,1) .* dirBest  + ...
                    a3 * (0.7 * diff12 + 0.3 * dirSample) + ...
                    a4 * rand(dim,1) .* dirSample + ...
                    a5 * localScale * randVec2 .* (ub - lb);
        end

        xNew = x + step;

        % Convex recombination refinement
        eta = 0.25 + 0.25 * (1 - tau);
        mixElite = 0.08 + 0.12 * tau;

        xNew = (1 - eta - mixElite) * xNew + ...
               eta * x + ...
               mixElite * xElite;

        % Gentle contraction
        shrink = 0.03 + 0.07 * tau;
        xNew = xNew + shrink * (0.6 * dirBest + 0.4 * dirElite);

        % Boundary handling
        xNew = min(max(xNew, lb), ub);

        % ---------- Local refinement ----------
        xNew = localRefinementCEC_v2(xNew, x, bestX, lb, ub, tau);

        fNew = funHandle(xNew);
        FEs = FEs + 1;

        % ---------- AOS reward ----------
        reward = betaJ * ((oldFit - fNew) / (abs(oldFit) + 1e-12));
        reward = max(min(reward, 1.0), -1.0);
        aos = updateAOS_CEC_v2(aos, opIdx, reward);

        if fNew < fit(i)
            pop(:, i) = xNew;
            fit(i) = fNew;

            if fNew < bestFit
                bestFit = fNew;
                bestX = xNew;
            end
        end
    end

    convergence(t) = bestFit;

    % ---------- Conservative regeneration ----------
    if t > regenWindow && FEs < maxFEs
        recent = convergence(max(1, t-regenWindow+1):t);
        relImprove = (max(recent) - min(recent)) / (abs(max(recent)) + 1e-12);

        if relImprove < regenTol
            nRegen = max(1, round(regenRatio * popSize));

            [~, order] = sort(fit, 'ascend');
            eliteNum = max(2, ceil(eliteFrac * popSize));
            elites = pop(:, order(1:eliteNum));

            worstIdx = order(end-nRegen+1:end);

            for kk = 1:numel(worstIdx)
                if FEs >= maxFEs
                    break;
                end

                iBad = worstIdx(kk);

                e1 = elites(:, randi(eliteNum));
                e2 = elites(:, randi(eliteNum));

                alpha = 0.5 + 0.2 * (rand(dim,1) - 0.5);
                xRe = alpha .* e1 + (1 - alpha) .* e2 + ...
                      0.03 * randn(dim,1) .* (ub - lb);

                xRe = min(max(xRe, lb), ub);

                fRe = funHandle(xRe);
                FEs = FEs + 1;

                pop(:, iBad) = xRe;
                fit(iBad) = fRe;

                if fRe < bestFit
                    bestFit = fRe;
                    bestX = xRe;
                end
            end

            convergence(t) = bestFit;
        end
    end

    if mod(t, max(1, floor(maxIter/5))) == 0 || t == 1
        fprintf('    Iter %d / %d | Best = %.6e | FEs = %d\n', t, maxIter, bestFit, FEs);
    end

    if FEs >= maxFEs
        convergence(t:end) = bestFit;
        break;
    end
end

runTime = toc(tStart);

result.bestFit = bestFit;
result.bestX = bestX;
result.convergence = convergence;
result.FEsUsed = FEs;
result.runTime = runTime;
end


% ========================================================================
function pop = structuredInitializationCEC_v2(lb, ub, dim, popSize)
% More neutral structured initialization:
% 85% uniform random + 15% mild center/boundary sampling

n1 = round(0.85 * popSize);
n2 = popSize - n1;

pop = zeros(dim, popSize);

% Uniform random majority
pop(:, 1:n1) = repmat(lb, 1, n1) + rand(dim, n1) .* repmat((ub - lb), 1, n1);

center = 0.5 * (lb + ub);
span = (ub - lb);

for j = 1:n2
    mode = mod(j, 3);
    if mode == 1
        x = center + 0.08 * randn(dim,1) .* span;
    elseif mode == 2
        x = lb + 0.10 * rand(dim,1) .* span;
    else
        x = ub - 0.10 * rand(dim,1) .* span;
    end
    x = min(max(x, lb), ub);
    pop(:, n1 + j) = x;
end
end

% ========================================================================
function xNew = localRefinementCEC_v2(xNew, xOld, bestX, lb, ub, tau)
% Softer local refinement:
% small contraction toward best/current line with low noise

dim = numel(xNew);
sigma = (0.01 + 0.02 * (1 - tau)) .* (ub - lb);

xNew = 0.75 * xNew + 0.15 * xOld + 0.10 * bestX;
xNew = xNew + sigma .* randn(dim,1);
xNew = min(max(xNew, lb), ub);
end

% ========================================================================
function opIdx = selectOpUCB_CEC_v2(aos, iter, maxIter, c, epsVal)
nOps = numel(aos.counts);

minUse = 15;
underUsed = find(aos.counts < minUse);
if ~isempty(underUsed)
    [~, idx] = min(aos.counts(underUsed));
    opIdx = underUsed(idx);
    return;
end

scores = zeros(1, nOps);
for k = 1:nOps
    scores(k) = aos.meanReward(k) + ...
        c * sqrt(log(iter + 1) / (aos.counts(k) + epsVal));
end

exploreProb = max(0.03, 0.12 * (1 - iter / maxIter));

if rand < exploreProb
    opIdx = randi(nOps);
else
    [~, opIdx] = max(scores);
end
end

% ========================================================================
function aos = updateAOS_CEC_v2(aos, opIdx, reward)
aos.counts(opIdx) = aos.counts(opIdx) + 1;
n = aos.counts(opIdx);
aos.meanReward(opIdx) = aos.meanReward(opIdx) + ...
    (reward - aos.meanReward(opIdx)) / n;
end