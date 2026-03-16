function result = optimizer_WOA_cec(funHandle, lb, ub, dim, algCfg, runSeed)
%OPTIMIZER_WOA_CEC Whale Optimization Algorithm for CEC2017.
%
% Standardized output:
%   result.bestFitness
%   result.bestPosition
%   result.convergence
%   result.runtime
%   result.nFEs

    if nargin >= 6
        rng(runSeed, 'twister');
    end

    popSize = algCfg.popSize;
    maxFEs  = algCfg.maxFEs;
    maxIter = algCfg.maxIter;
    b       = algCfg.b;

    tStart = tic;

    % ---------- Initialization ----------
    X = lb + (ub - lb) * rand(popSize, dim);
    fit = zeros(popSize, 1);

    for i = 1:popSize
        fit(i) = funHandle(X(i, :)');
    end
    FEs = popSize;

    [bestFit, bestIdx] = min(fit);
    bestX = X(bestIdx, :);

    curve = nan(maxIter, 1);
    iter = 1;

    while FEs < maxFEs && iter <= maxIter
        a = 2 - 2 * (iter - 1) / max(maxIter - 1, 1);

        for i = 1:popSize
            r1 = rand;
            r2 = rand;

            A = 2 * a * r1 - a;
            C = 2 * r2;
            p = rand;

            Xi = X(i, :);

            if p < 0.5
                if abs(A) < 1
                    % Encircling prey
                    D = abs(C * bestX - Xi);
                    newX = bestX - A * D;
                else
                    % Search for prey
                    randIdx = randi(popSize);
                    Xrand = X(randIdx, :);
                    D = abs(C * Xrand - Xi);
                    newX = Xrand - A * D;
                end
            else
                % Spiral updating position
                D = abs(bestX - Xi);
                l = -1 + 2 * rand;   % random in [-1, 1]
                newX = D .* exp(b * l) .* cos(2 * pi * l) + bestX;
            end

            % Boundary handling
            newX = min(max(newX, lb), ub);

            newFit = funHandle(newX');
            FEs = FEs + 1;

            X(i, :) = newX;
            fit(i) = newFit;

            if newFit < bestFit
                bestFit = newFit;
                bestX = newX;
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
    result.bestPosition = bestX(:);
    result.convergence = curve;
    result.runtime = toc(tStart);
    result.nFEs = FEs;

    % legacy compatibility
    result.bestFit = bestFit;
    result.bestX = bestX(:);
    result.runTime = result.runtime;
    result.FEsUsed = FEs;
end