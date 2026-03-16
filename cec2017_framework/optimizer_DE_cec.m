function result = optimizer_DE_cec(funHandle, lb, ub, dim, algCfg, runSeed)

if nargin >= 6
    rng(runSeed, 'twister');
end

popSize = algCfg.popSize;
maxFEs  = algCfg.maxFEs;
maxIter = algCfg.maxIter;
F  = algCfg.F;
CR = algCfg.CR;

tStart = tic;

% Initialization
pop = lb + (ub - lb) * rand(popSize, dim);
fit = zeros(popSize, 1);
for i = 1:popSize
    fit(i) = funHandle(pop(i, :)');
end
FEs = popSize;

[bestFit, bestIdx] = min(fit);
bestSol = pop(bestIdx, :);

curve = nan(maxIter, 1);
iter = 1;

while FEs < maxFEs && iter <= maxIter
    for i = 1:popSize
        % Mutation: DE/rand/1
        idxs = randperm(popSize, 4);
        idxs(idxs == i) = [];
        idxs = idxs(1:3);

        r1 = idxs(1);
        r2 = idxs(2);
        r3 = idxs(3);

        v = pop(r1, :) + F * (pop(r2, :) - pop(r3, :));

        % Binomial crossover
        u = pop(i, :);
        jrand = randi(dim);
        for j = 1:dim
            if rand < CR || j == jrand
                u(j) = v(j);
            end
        end

        % Bound handling
        u = min(max(u, lb), ub);

        fu = funHandle(u');
        FEs = FEs + 1;

        if fu < fit(i)
            pop(i, :) = u;
            fit(i) = fu;

            if fu < bestFit
                bestFit = fu;
                bestSol = u;
            end
        end

        if FEs >= maxFEs
            break;
        end
    end

    curve(iter) = bestFit;
    iter = iter + 1;
end

curve = curve(1:iter-1);

result = struct();
result.bestFitness = bestFit;
result.bestPosition = bestSol(:);
result.convergence = curve;
result.runtime = toc(tStart);
result.nFEs = FEs;

end