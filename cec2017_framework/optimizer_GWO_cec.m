function result = optimizer_GWO_cec(funHandle, lb, ub, dim, algCfg, runSeed)

if nargin >= 6
    rng(runSeed, 'twister');
end

popSize = algCfg.popSize;
maxFEs  = algCfg.maxFEs;
maxIter = algCfg.maxIter;

tStart = tic;

% Initialization
X = lb + (ub - lb) * rand(popSize, dim);
fit = zeros(popSize, 1);
for i = 1:popSize
    fit(i) = funHandle(X(i, :)');
end
FEs = popSize;

[fitSorted, idx] = sort(fit);
alpha = X(idx(1), :);
beta  = X(idx(2), :);
delta = X(idx(3), :);

alphaFit = fitSorted(1);

curve = nan(maxIter, 1);
iter = 1;

while FEs < maxFEs && iter <= maxIter
    a = 2 - 2 * (iter - 1) / max(maxIter - 1, 1);

    for i = 1:popSize
        r1 = rand(1, dim); r2 = rand(1, dim);
        A1 = 2 * a * r1 - a;
        C1 = 2 * r2;
        D_alpha = abs(C1 .* alpha - X(i, :));
        X1 = alpha - A1 .* D_alpha;

        r1 = rand(1, dim); r2 = rand(1, dim);
        A2 = 2 * a * r1 - a;
        C2 = 2 * r2;
        D_beta = abs(C2 .* beta - X(i, :));
        X2 = beta - A2 .* D_beta;

        r1 = rand(1, dim); r2 = rand(1, dim);
        A3 = 2 * a * r1 - a;
        C3 = 2 * r2;
        D_delta = abs(C3 .* delta - X(i, :));
        X3 = delta - A3 .* D_delta;

        newX = (X1 + X2 + X3) / 3;
        newX = min(max(newX, lb), ub);

        newFit = funHandle(newX');
        FEs = FEs + 1;

        X(i, :) = newX;
        fit(i) = newFit;

        if FEs >= maxFEs
            break;
        end
    end

    [fitSorted, idx] = sort(fit);
    alpha = X(idx(1), :);
    beta  = X(idx(2), :);
    delta = X(idx(3), :);
    alphaFit = fitSorted(1);

    curve(iter) = alphaFit;
    iter = iter + 1;
end

curve = curve(1:iter-1);

result = struct();
result.bestFitness = alphaFit;
result.bestPosition = alpha(:);
result.convergence = curve;
result.runtime = toc(tStart);
result.nFEs = FEs;

end