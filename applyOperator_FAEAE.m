function Xnew = applyOperator_FAEAE(i, pop, fit, bestX, refX, opIdx, iter, params)
%APPLYOPERATOR_FAEAE Quasi-formalized AE-style update for FAE-AE.

[N, D] = size(pop);
x = pop(i, :);

idxPool = setdiff(1:N, i);
perm = idxPool(randperm(numel(idxPool), min(4, numel(idxPool))));
while numel(perm) < 4
    perm(end+1) = idxPool(randi(numel(idxPool))); %#ok<AGROW>
end

r1 = perm(1); r2 = perm(2); r3 = perm(3); r4 = perm(4);

xr1 = pop(r1, :);
xr2 = pop(r2, :);
xr3 = pop(r3, :);
xr4 = pop(r4, :);

[~, order] = sort(fit, 'ascend');
eliteNum = max(2, ceil(params.core.eliteFrac * N));
eliteSet = pop(order(1:eliteNum), :);
eliteMean = mean(eliteSet, 1);

eIdx = order(randi(eliteNum));
xElite = pop(eIdx, :);

tau = iter / params.maxIter;
phaseExploration = 1 - tau;
phaseExploitation = tau;

span = params.ub - params.lb;
rho = 0.15 + 0.85 * (1 - tau)^1.2;

diff12 = xr1 - xr2;
diff34 = xr3 - xr4;

dirBest   = bestX - x;
dirElite  = eliteMean - x;
dirSample = xElite - x;

if isfield(params, 'useInit') && ~params.useInit
    dirRef = zeros(1, D);
else
    dirRef = refX - x;
end

randVec1 = 2 * rand(1, D) - 1;
randVec2 = randn(1, D);

switch opIdx
    case 1
        a1 = 0.20 + 0.25 * phaseExploration;
        a2 = 0.10 + 0.20 * phaseExploration;
        a3 = 0.55 + 0.20 * phaseExploration;
        a4 = 0.12;
        a5 = 0.10 + 0.15 * phaseExploration;

        step = ...
            a1 * rand(1, D) .* dirElite + ...
            a2 * rand(1, D) .* dirBest  + ...
            a3 * (0.6 * diff12 + 0.4 * diff34) + ...
            a4 * rand(1, D) .* dirRef   + ...
            a5 * rho * randVec1 .* span;

        Xnew = x + step;

    case 2
        a1 = 0.30 + 0.15 * phaseExploration;
        a2 = 0.20 + 0.10 * phaseExploitation;
        a3 = 0.18 + 0.08 * phaseExploration;
        a4 = 0.45 + 0.15 * phaseExploration;
        a5 = 0.04 + 0.04 * phaseExploration;

        step = ...
            a1 * rand(1, D) .* dirElite + ...
            a2 * rand(1, D) .* dirBest  + ...
            a3 * diff12 + ...
            a4 * rand(1, D) .* dirRef   + ...
            a5 * rho * randVec2 .* span;

        Xnew = x + step;

    case 3
        localScale = 0.10 + 0.20 * (1 - tau)^0.8;

        a1 = 0.45 + 0.15 * phaseExploitation;
        a2 = 0.40 + 0.20 * phaseExploitation;
        a3 = 0.06 + 0.06 * phaseExploration;
        a4 = 0.12;
        a5 = 0.03;

        step = ...
            a1 * rand(1, D) .* dirElite + ...
            a2 * rand(1, D) .* dirBest  + ...
            a3 * (0.7 * diff12 + 0.3 * dirSample) + ...
            a4 * rand(1, D) .* dirRef   + ...
            a5 * localScale * randVec2 .* span;

        Xnew = x + step;

    otherwise
        Xnew = x;
end

eta = 0.20 + 0.35 * (1 - tau);
mixElite = 0.10 + 0.15 * phaseExploitation;

if isfield(params, 'useInit') && ~params.useInit
    mixRef = 0;
else
    mixRef = 0.05 + 0.10 * phaseExploration;
end

Xnew = (1 - eta - mixElite - mixRef) * Xnew + ...
       eta * x + ...
       mixElite * xElite + ...
       mixRef * refX;

shrink = 0.05 + 0.10 * phaseExploitation;
Xnew = Xnew + shrink * (0.5 * dirBest + 0.5 * dirRef);

Xnew = boundSolution(Xnew, params);
end