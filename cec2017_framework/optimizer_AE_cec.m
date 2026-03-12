function result = optimizer_AE_cec(funHandle, lb, ub, dim, maxFEs, runSeed)
%OPTIMIZER_AE_CEC Baseline AE-style optimizer for CEC2017.
%
% Inputs:
%   funHandle - objective function handle, accepts column vector
%   lb, ub    - lower/upper bounds (dim x 1)
%   dim       - problem dimension
%   maxFEs    - maximum number of function evaluations
%   runSeed   - random seed
%
% Output:
%   result.bestFit
%   result.bestX
%   result.convergence
%   result.FEsUsed
%   result.runTime

rng(runSeed);

% ---------- Basic parameters ----------
popSize = 30;
maxIter = ceil(maxFEs / popSize);

% ---------- Initialization ----------
pop = repmat(lb, 1, popSize) + rand(dim, popSize) .* repmat((ub - lb), 1, popSize);
fit = inf(1, popSize);

FEs = 0;
for i = 1:popSize
    fit(i) = funHandle(pop(:, i));
    FEs = FEs + 1;
end

[bestFit, bestIdx] = min(fit);
bestX = pop(:, bestIdx);

convergence = inf(maxIter, 1);

tStart = tic;

for t = 1:maxIter
    tau = t / maxIter;
    rho = 0.15 + 0.85 * (1 - tau)^1.2;

    [~, order] = sort(fit, 'ascend');
    eliteNum = max(2, ceil(0.25 * popSize));
    eliteSet = pop(:, order(1:eliteNum));
    eliteMean = mean(eliteSet, 2);

    for i = 1:popSize
        if FEs >= maxFEs
            break;
        end

        x = pop(:, i);

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

        dirBest  = bestX - x;
        dirElite = eliteMean - x;
        dirSample = xElite - x;

        diff12 = xr1 - xr2;
        diff34 = xr3 - xr4;

        randVec1 = 2 * rand(dim, 1) - 1;
        randVec2 = randn(dim, 1);

        % Fixed balanced AE-style search
        a1 = 0.30 + 0.10 * (1 - tau);
        a2 = 0.25 + 0.10 * tau;
        a3 = 0.22 + 0.08 * (1 - tau);
        a4 = 0.08;
        a5 = 0.06;

        step = ...
            a1 * rand(dim,1) .* dirElite + ...
            a2 * rand(dim,1) .* dirBest  + ...
            a3 * (0.6 * diff12 + 0.4 * diff34) + ...
            a4 * rand(dim,1) .* dirSample + ...
            a5 * rho * randVec1 .* (ub - lb);

        xNew = x + step;

        % Convex recombination refinement
        eta = 0.20 + 0.35 * (1 - tau);
        mixElite = 0.10 + 0.10 * tau;

        xNew = (1 - eta - mixElite) * xNew + ...
               eta * x + ...
               mixElite * xElite;

        % Boundary handling
        xNew = min(max(xNew, lb), ub);

        fNew = funHandle(xNew);
        FEs = FEs + 1;

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

    if FEs >= maxFEs
        convergence(t:end) = bestFit;
        break;
    end
    
    if mod(t, max(1, floor(maxIter/5))) == 0 || t == 1
        fprintf('    Iter %d / %d | Best = %.6e | FEs = %d\n', t, maxIter, bestFit, FEs);
    end
end

runTime = toc(tStart);

result.bestFit = bestFit;
result.bestX = bestX;
result.convergence = convergence;
result.FEsUsed = FEs;
result.runTime = runTime;
end