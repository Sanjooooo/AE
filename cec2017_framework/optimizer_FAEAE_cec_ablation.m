function result = optimizer_FAEAE_cec_ablation(funHandle, lb, ub, dim, algCfg, runSeed)
%OPTIMIZER_FAEAE_CEC_ABLATION
% Ablation-capable CEC optimizer derived from the current FAEAE-CEC design.
%
% Required flags in algCfg:
%   useStructuredInit
%   useAOS
%   useLocalRefine
%   useRegen
%
% Output fields:
%   result.bestFitness
%   result.bestPosition
%   result.convergence
%   result.runtime
%   result.nFEs

    rng(runSeed, 'twister');

    popSize = algCfg.popSize;
    maxFEs = algCfg.maxFEs;
    maxIter = algCfg.maxIter;

    useStructuredInit = localGetFlag(algCfg, 'useStructuredInit', true);
    useAOS = localGetFlag(algCfg, 'useAOS', true);
    useLocalRefine = localGetFlag(algCfg, 'useLocalRefine', true);
    useRegen = localGetFlag(algCfg, 'useRegen', true);

    nOps = 3;
    ucbC = 0.75;
    ucbEps = 1e-9;
    betaJ = 1.0;

    regenWindow = 25;
    regenTol = 1e-12;
    regenRatio = 0.18;
    eliteFrac = 0.25;

    % ---------------------------------------------------------------------
    % Initialization
    % ---------------------------------------------------------------------
    if useStructuredInit
        pop = localStructuredInitialization(lb, ub, dim, popSize);
    else
        pop = repmat(lb, 1, popSize) + rand(dim, popSize) .* repmat((ub - lb), 1, popSize);
    end

    fit = inf(1, popSize);
    FEs = 0;
    for i = 1:popSize
        fit(i) = funHandle(pop(:, i));
        FEs = FEs + 1;
    end

    [bestFit, bestIdx] = min(fit);
    bestX = pop(:, bestIdx);

    convergence = inf(maxIter, 1);
    aos.counts = zeros(1, nOps);
    aos.meanReward = zeros(1, nOps);

    tStart = tic;

    for t = 1:maxIter
        if FEs >= maxFEs
            convergence(t:end) = bestFit;
            break;
        end

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

            dirBest = bestX - x;
            dirElite = eliteMean - x;
            dirSample = xElite - x;
            diff12 = xr1 - xr2;
            diff34 = xr3 - xr4;

            randVec1 = 2 * rand(dim, 1) - 1;
            randVec2 = randn(dim, 1);

            if useAOS
                opIdx = localSelectOpUCB(aos, t, maxIter, ucbC, ucbEps);
            else
                % 固定使用中等平衡算子，作为“无 AOS”的消融替代
                opIdx = 2;
            end

            switch opIdx
                case 1  % Global exploration
                    a1 = 0.18 + 0.18 * (1 - tau);
                    a2 = 0.10 + 0.12 * (1 - tau);
                    a3 = 0.40 + 0.15 * (1 - tau);
                    a4 = 0.08;
                    a5 = 0.06 + 0.08 * (1 - tau);

                    step = ...
                        a1 * rand(dim,1) .* dirElite + ...
                        a2 * rand(dim,1) .* dirBest + ...
                        a3 * (0.6 * diff12 + 0.4 * diff34) + ...
                        a4 * rand(dim,1) .* dirSample + ...
                        a5 * rho * randVec1 .* (ub - lb);

                case 2  % Balanced search
                    a1 = 0.30 + 0.10 * (1 - tau);
                    a2 = 0.24 + 0.10 * tau;
                    a3 = 0.14 + 0.05 * (1 - tau);
                    a4 = 0.12;
                    a5 = 0.035 + 0.02 * (1 - tau);

                    step = ...
                        a1 * rand(dim,1) .* dirElite + ...
                        a2 * rand(dim,1) .* dirBest + ...
                        a3 * diff12 + ...
                        a4 * rand(dim,1) .* dirSample + ...
                        a5 * rho * randVec2 .* (ub - lb);

                case 3  % Local exploitation
                    localScale = 0.05 + 0.10 * (1 - tau)^0.8;
                    a1 = 0.38 + 0.15 * tau;
                    a2 = 0.35 + 0.15 * tau;
                    a3 = 0.04 + 0.04 * (1 - tau);
                    a4 = 0.05;
                    a5 = 0.015;

                    step = ...
                        a1 * rand(dim,1) .* dirElite + ...
                        a2 * rand(dim,1) .* dirBest + ...
                        a3 * (0.7 * diff12 + 0.3 * dirSample) + ...
                        a4 * rand(dim,1) .* dirSample + ...
                        a5 * localScale * randVec2 .* (ub - lb);
            end

            xNew = x + step;

            % Mild recombination / contraction
            eta = 0.25 + 0.25 * (1 - tau);
            mixElite = 0.08 + 0.12 * tau;
            xNew = (1 - eta - mixElite) * xNew + eta * x + mixElite * xElite;

            shrink = 0.03 + 0.07 * tau;
            xNew = xNew + shrink * (0.6 * dirBest + 0.4 * dirElite);

            % Boundary handling
            xNew = min(max(xNew, lb), ub);

            % Local refinement (used here as the unconstrained analogue of the
            % "repair/refinement" stage for CEC ablation)
            if useLocalRefine
                xNew = localRefinementCEC(xNew, x, bestX, lb, ub, tau);
            end

            fNew = funHandle(xNew);
            FEs = FEs + 1;

            if useAOS
                reward = betaJ * ((oldFit - fNew) / (abs(oldFit) + 1e-12));
                reward = max(min(reward, 1.0), -1.0);
                aos = localUpdateAOS(aos, opIdx, reward);
            end

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

        % Structured regeneration
        if useRegen && t > regenWindow && FEs < maxFEs
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
                          0.08 * randn(dim,1) .* (ub - lb);

                    xRe = min(max(xRe, lb), ub);
                    fRe = funHandle(xRe);
                    FEs = FEs + 1;

                    if fRe < fit(iBad)
                        pop(:, iBad) = xRe;
                        fit(iBad) = fRe;
                        if fRe < bestFit
                            bestFit = fRe;
                            bestX = xRe;
                        end
                    end
                end
            end
        end
    end

    % Trim convergence to actual iteration count if needed
    lastValid = find(isfinite(convergence), 1, 'last');
    if isempty(lastValid)
        convergence = bestFit;
    else
        convergence = convergence(1:lastValid);
    end

    result.bestFitness = bestFit;
    result.bestPosition = bestX(:);
    result.convergence = convergence(:);
    result.runtime = toc(tStart);
    result.nFEs = FEs;
end

%% ========================================================================
function tf = localGetFlag(s, fn, defaultVal)
    if isfield(s, fn)
        tf = logical(s.(fn));
    else
        tf = defaultVal;
    end
end

%% ========================================================================
function pop = localStructuredInitialization(lb, ub, dim, popSize)
    pop = zeros(dim, popSize);

    center = (lb + ub) / 2;
    span = (ub - lb);

    for i = 1:popSize
        switch mod(i-1, 4)
            case 0
                x = center + 0.15 * randn(dim,1) .* span;
            case 1
                x = lb + rand(dim,1) .* span;
            case 2
                x = center + 0.35 * (2*rand(dim,1)-1) .* span;
            otherwise
                x = center + 0.05 * randn(dim,1) .* span;
        end
        pop(:,i) = min(max(x, lb), ub);
    end
end

%% ========================================================================
function opIdx = localSelectOpUCB(aos, t, ~, c, epsVal)
    if t <= numel(aos.counts)
        opIdx = t;
        return;
    end

    scores = aos.meanReward + c * sqrt(log(t + 1) ./ (aos.counts + epsVal));
    [~, opIdx] = max(scores);
end

%% ========================================================================
function aos = localUpdateAOS(aos, opIdx, reward)
    aos.counts(opIdx) = aos.counts(opIdx) + 1;
    n = aos.counts(opIdx);
    aos.meanReward(opIdx) = aos.meanReward(opIdx) + (reward - aos.meanReward(opIdx)) / n;
end

%% ========================================================================
function xNew = localRefinementCEC(xNew, xOld, bestX, lb, ub, tau)
    % Gentle local refinement
    blend = 0.15 + 0.20 * tau;
    stepLocal = 0.02 + 0.04 * (1 - tau);

    xNew = (1 - blend) * xNew + blend * (0.65 * bestX + 0.35 * xOld);
    xNew = xNew + stepLocal * randn(size(xNew)) .* (ub - lb);
    xNew = min(max(xNew, lb), ub);
end