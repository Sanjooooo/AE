function Xnew = applyOperator_FAEAE_lite_v2(i, pop, bestX, refX, eliteMean, xElite, opIdx, iter, params)
%APPLYOPERATOR_FAEAE_LITE_V2 轻量化版（论文主实验）
% Slightly cleaner operator wrapper for the staged lite-v2 optimizer.
% Core search behavior is kept close to lite-v1 so the main speed-up still
% comes from staged repair / stricter regeneration / AOS freezing.

[N, D] = size(pop); %#ok<ASGLU>
x = pop(i, :);

allIdx = 1:size(pop, 1);
allIdx(i) = [];
perm = allIdx(randperm(numel(allIdx), min(4, numel(allIdx))));
while numel(perm) < 4
    perm(end+1) = allIdx(randi(numel(allIdx))); %#ok<AGROW>
end

xr1 = pop(perm(1), :);
xr2 = pop(perm(2), :);
xr3 = pop(perm(3), :);
xr4 = pop(perm(4), :);

tau = iter / params.maxIter;
phaseExploration = 1 - tau;
phaseExploitation = tau;
span = params.ub - params.lb;
rho = 0.15 + 0.85 * (1 - tau)^1.2;

diff12 = xr1 - xr2;
diff34 = xr3 - xr4;
dirBest = bestX - x;
dirElite = eliteMean - x;
dirSample = xElite - x;

if isempty(refX) || (isfield(params, 'useInit') && ~params.useInit)
    dirRef = zeros(1, D);
    mixRef = 0;
else
    dirRef = refX - x;
    mixRef = 0.04 + 0.08 * phaseExploration;
end

randVec1 = 2 * rand(1, D) - 1;
randVec2 = randn(1, D);

switch opIdx
    case 1
        a1 = 0.18 + 0.24 * phaseExploration;
        a2 = 0.10 + 0.18 * phaseExploration;
        a3 = 0.52 + 0.20 * phaseExploration;
        a4 = 0.10;
        a5 = 0.08 + 0.12 * phaseExploration;

        step = ...
            a1 * rand(1, D) .* dirElite + ...
            a2 * rand(1, D) .* dirBest  + ...
            a3 * (0.6 * diff12 + 0.4 * diff34) + ...
            a4 * rand(1, D) .* dirRef + ...
            a5 * rho * randVec1 .* span;

    case 2
        a1 = 0.28 + 0.14 * phaseExploration;
        a2 = 0.20 + 0.08 * phaseExploitation;
        a3 = 0.16 + 0.06 * phaseExploration;
        a4 = 0.40 + 0.12 * phaseExploration;
        a5 = 0.03 + 0.03 * phaseExploration;

        step = ...
            a1 * rand(1, D) .* dirElite + ...
            a2 * rand(1, D) .* dirBest  + ...
            a3 * diff12 + ...
            a4 * rand(1, D) .* dirRef + ...
            a5 * rho * randVec2 .* span;

    case 3
        localScale = 0.08 + 0.16 * (1 - tau)^0.8;
        a1 = 0.45 + 0.15 * phaseExploitation;
        a2 = 0.38 + 0.20 * phaseExploitation;
        a3 = 0.05 + 0.05 * phaseExploration;
        a4 = 0.10;
        a5 = 0.02;

        step = ...
            a1 * rand(1, D) .* dirElite + ...
            a2 * rand(1, D) .* dirBest  + ...
            a3 * (0.7 * diff12 + 0.3 * dirSample) + ...
            a4 * rand(1, D) .* dirRef + ...
            a5 * localScale * randVec2 .* span;

    otherwise
        step = zeros(1, D);
end

Xnew = x + step;

eta = 0.22 + 0.30 * (1 - tau);
mixElite = 0.10 + 0.12 * phaseExploitation;

Xnew = (1 - eta - mixElite - mixRef) * Xnew + ...
       eta * x + ...
       mixElite * xElite + ...
       mixRef * refX;

shrink = 0.04 + 0.08 * phaseExploitation;
Xnew = Xnew + shrink * (0.5 * dirBest + 0.5 * dirRef);

Xnew = boundSolution(Xnew, params);
end
