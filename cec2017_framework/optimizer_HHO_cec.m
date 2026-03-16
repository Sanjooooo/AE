function result = optimizer_HHO_cec(funHandle, lb, ub, dim, algCfg, runSeed)

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

[bestFit, bestIdx] = min(fit);
rabbit = X(bestIdx, :);

curve = nan(maxIter, 1);
iter = 1;

while FEs < maxFEs && iter <= maxIter
    E1 = 2 * (1 - iter / max(maxIter, 1));

    Xmean = mean(X, 1);

    for i = 1:popSize
        E0 = 2 * rand - 1;
        EscapingEnergy = E1 * E0;

        Xi = X(i, :);

        if abs(EscapingEnergy) >= 1
            % Exploration phase
            q = rand;
            randIdx = randi(popSize);
            Xrand = X(randIdx, :);

            if q < 0.5
                newX = Xrand - rand(1, dim) .* abs(Xrand - 2 * rand(1, dim) .* Xi);
            else
                newX = (rabbit - Xmean) - rand(1, dim) .* (lb + rand(1, dim) .* (ub - lb));
            end

            newX = min(max(newX, lb), ub);
            newFit = funHandle(newX');
            FEs = FEs + 1;

            X(i, :) = newX;
            fit(i) = newFit;
        else
            % Exploitation phase
            r = rand;
            J = 2 * (1 - rand);

            if r >= 0.5 && abs(EscapingEnergy) < 0.5
                % Hard besiege
                newX = rabbit - EscapingEnergy .* abs(rabbit - Xi);

                newX = min(max(newX, lb), ub);
                newFit = funHandle(newX');
                FEs = FEs + 1;

                X(i, :) = newX;
                fit(i) = newFit;

            elseif r >= 0.5 && abs(EscapingEnergy) >= 0.5
                % Soft besiege
                newX = (rabbit - Xi) - EscapingEnergy .* abs(J .* rabbit - Xi);

                newX = min(max(newX, lb), ub);
                newFit = funHandle(newX');
                FEs = FEs + 1;

                X(i, :) = newX;
                fit(i) = newFit;

            elseif r < 0.5 && abs(EscapingEnergy) >= 0.5
                % Soft besiege with progressive rapid dives
                Y = rabbit - EscapingEnergy .* abs(J .* rabbit - Xi);
                Y = min(max(Y, lb), ub);
                FY = funHandle(Y');
                FEs = FEs + 1;

                if FY < fit(i)
                    X(i, :) = Y;
                    fit(i) = FY;
                else
                    Z = Y + randn(1, dim) .* levyFlight(dim);
                    Z = min(max(Z, lb), ub);
                    FZ = funHandle(Z');
                    FEs = FEs + 1;

                    if FZ < fit(i)
                        X(i, :) = Z;
                        fit(i) = FZ;
                    end
                end

            else
                % Hard besiege with progressive rapid dives
                Y = rabbit - EscapingEnergy .* abs(J .* rabbit - Xmean);
                Y = min(max(Y, lb), ub);
                FY = funHandle(Y');
                FEs = FEs + 1;

                if FY < fit(i)
                    X(i, :) = Y;
                    fit(i) = FY;
                else
                    Z = Y + randn(1, dim) .* levyFlight(dim);
                    Z = min(max(Z, lb), ub);
                    FZ = funHandle(Z');
                    FEs = FEs + 1;

                    if FZ < fit(i)
                        X(i, :) = Z;
                        fit(i) = FZ;
                    end
                end
            end
        end

        if FEs >= maxFEs
            break;
        end
    end

    [currBestFit, bestIdx] = min(fit);
    if currBestFit < bestFit
        bestFit = currBestFit;
        rabbit = X(bestIdx, :);
    else
        rabbit = X(bestIdx, :);
        bestFit = currBestFit;
    end

    curve(iter) = bestFit;
    iter = iter + 1;
end

curve = curve(1:iter-1);

result = struct();
result.bestFitness = bestFit;
result.bestPosition = rabbit(:);
result.convergence = curve;
result.runtime = toc(tStart);
result.nFEs = FEs;

end

function step = levyFlight(dim)
beta = 1.5;
sigma = (gamma(1 + beta) * sin(pi * beta / 2) / ...
    (gamma((1 + beta) / 2) * beta * 2^((beta - 1) / 2)))^(1 / beta);

u = randn(1, dim) * sigma;
v = randn(1, dim);
step = u ./ (abs(v).^(1 / beta));
end