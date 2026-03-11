function [pop, fit, detail] = regeneratePopulation(pop, fit, detail, bestX, map, params)
%REGENERATEPOPULATION Structured regeneration for inferior individuals.

N = size(pop, 1);
regenNum = max(1, round(params.regen.ratio * N));
rankScore = localRankScore(fit, detail);
[~, order] = sort(rankScore, 'ascend');

eliteK = min(params.regen.eliteK, N);
eliteIdx = order(1:eliteK);
worstIdx = order(end-regenNum+1:end);
span = params.ub - params.lb;

for ii = 1:numel(worstIdx)
    w = worstIdx(ii);
    alpha = rand(1, eliteK);
    alpha = alpha / sum(alpha);
    Xnew = zeros(1, size(pop, 2));
    for k = 1:eliteK
        Xnew = Xnew + alpha(k) * pop(eliteIdx(k), :);
    end
    noise = (2 * rand(1, size(pop, 2)) - 1) .* (params.regen.sigma * span);
    Xnew = 0.6 * Xnew + 0.4 * bestX + noise;
    Xnew = boundSolution(Xnew, params);
    [Xnew, ~] = repairPath(Xnew, map, params);
    [newFit, newDetail] = fitnessFAEAE(Xnew, map, params);

    pop(w, :) = Xnew;
    fit(w) = newFit;
    detail(w) = newDetail;
end
end

function s = localRankScore(fit, detail)
viol = [detail.V].';
feas = [detail.isFeasible].';
s = fit + 1e6 * (~feas) + 1e3 * viol;
end