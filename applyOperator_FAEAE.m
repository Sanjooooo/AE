function Xnew = applyOperator_FAEAE(i, pop, fit, bestX, refX, opIdx, iter, params)
%APPLYOPERATOR_FAEAE Operator pool for FAE-AE.
% Note: this is a runnable framework implementation. If you later want the
% exact AE core equations from the original paper, replace the update laws here.

[N, D] = size(pop);
idxPool = setdiff(1:N, i);
perm = idxPool(randperm(numel(idxPool), min(3, numel(idxPool))));
while numel(perm) < 3
    perm(end+1) = idxPool(randi(numel(idxPool))); %#ok<AGROW>
end
r1 = perm(1); r2 = perm(2); r3 = perm(3);

[~, order] = sort(fit, 'ascend');
eliteNum = max(2, ceil(params.core.eliteFrac * N));
eliteMean = mean(pop(order(1:eliteNum), :), 1);

x   = pop(i, :);
xr1 = pop(r1, :);
xr2 = pop(r2, :);
xr3 = pop(r3, :);
span = params.ub - params.lb;
phase = 1 - iter / params.maxIter;

switch opIdx
    case 1
        % Global exploration operator
        step = params.core.alpha1 * (xr1 - xr2) + ...
               0.25 * rand(1, D) .* (bestX - x) + ...
               0.10 * (2 * rand(1, D) - 1) .* span;
        Xnew = x + step;

    case 2
        % Feasibility-promoting operator
        feasibleBias = 0.50 * (bestX + eliteMean) - x;
        corridorBias = 0.35 * (refX - x);
        diffBias     = params.core.alpha2 * (xr1 - xr2);
        Xnew = x + 0.55 * feasibleBias + 0.30 * corridorBias + 0.15 * diffBias;

    case 3
        % Local exploitation operator
        localAmp = (0.12 + 0.10 * phase) * span;
        Xnew = x + 0.65 * (eliteMean - x) + ...
                   0.35 * (bestX - x) + ...
                   0.08 * (xr3 - x) + ...
                   (2 * rand(1, D) - 1) .* localAmp;

    otherwise
        Xnew = x;
end

Xnew = boundSolution(Xnew, params);
end