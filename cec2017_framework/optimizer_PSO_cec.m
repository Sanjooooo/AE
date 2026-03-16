function result = optimizer_PSO_cec(funHandle, lb, ub, dim, algCfg, runSeed)

if nargin >= 6
    rng(runSeed, 'twister');
end

popSize = algCfg.popSize;
maxFEs  = algCfg.maxFEs;
maxIter = algCfg.maxIter;

w  = algCfg.w;
c1 = algCfg.c1;
c2 = algCfg.c2;
vmax = algCfg.vmaxRatio * (ub - lb);

tStart = tic;

% Initialization
X = lb + (ub - lb) * rand(popSize, dim);
V = -vmax + 2 * vmax * rand(popSize, dim);

fit = zeros(popSize, 1);
for i = 1:popSize
    fit(i) = funHandle(X(i, :)');
end
FEs = popSize;

pbest = X;
pbestFit = fit;

[gbestFit, gbestIdx] = min(fit);
gbest = X(gbestIdx, :);

curve = nan(maxIter, 1);
iter = 1;

while FEs < maxFEs && iter <= maxIter
    for i = 1:popSize
        r1 = rand(1, dim);
        r2 = rand(1, dim);

        V(i, :) = w * V(i, :) ...
            + c1 * r1 .* (pbest(i, :) - X(i, :)) ...
            + c2 * r2 .* (gbest - X(i, :));

        V(i, :) = min(max(V(i, :), -vmax), vmax);

        X(i, :) = X(i, :) + V(i, :);
        X(i, :) = min(max(X(i, :), lb), ub);

        fit_i = funHandle(X(i, :)');
        FEs = FEs + 1;

        fit(i) = fit_i;

        if fit_i < pbestFit(i)
            pbest(i, :) = X(i, :);
            pbestFit(i) = fit_i;
        end

        if fit_i < gbestFit
            gbest = X(i, :);
            gbestFit = fit_i;
        end

        if FEs >= maxFEs
            break;
        end
    end

    curve(iter) = gbestFit;
    iter = iter + 1;
end

curve = curve(1:iter-1);

result = struct();
result.bestFitness = gbestFit;
result.bestPosition = gbest(:);
result.convergence = curve;
result.runtime = toc(tStart);
result.nFEs = FEs;

end