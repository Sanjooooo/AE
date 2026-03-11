function opIdx = selectOperator_UCB(aos, iter, params)
%SELECTOPERATOR_UCB Improved UCB-based operator selection.
% Main improvements:
% 1) each operator is forced to be used at least minUse times
% 2) after warm-up, standard UCB is applied
% 3) a mild random exploration is retained in early/middle stages

nOps = numel(aos.counts);

% ---------- Stage 1: forced minimum usage ----------
minUse = 20;
underUsed = find(aos.counts < minUse);

if ~isempty(underUsed)
    % choose the least-used operator first
    [~, idx] = min(aos.counts(underUsed));
    opIdx = underUsed(idx);
    return;
end

% ---------- Stage 2: UCB scoring ----------
scores = zeros(1, nOps);
for k = 1:nOps
    scores(k) = aos.meanReward(k) + ...
        params.aos.c * sqrt(log(iter + 1) / (aos.counts(k) + params.aos.eps));
end

% ---------- Stage 3: mild exploration ----------
% Keep a small probability of random exploration in earlier search stage
exploreProb = max(0.05, 0.20 * (1 - iter / params.maxIter));

if rand < exploreProb
    opIdx = randi(nOps);
else
    [~, opIdx] = max(scores);
end

end