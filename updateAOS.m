function aos = updateAOS(aos, opIdx, reward)
%UPDATEAOS Incremental mean update for operator rewards.

aos.counts(opIdx) = aos.counts(opIdx) + 1;
n = aos.counts(opIdx);
aos.meanReward(opIdx) = aos.meanReward(opIdx) + (reward - aos.meanReward(opIdx)) / n;
aos.lastReward(opIdx) = reward;
end