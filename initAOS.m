function aos = initAOS(params)
%INITAOS Initialize adaptive operator selection statistics.

aos.counts = zeros(1, params.aos.nOps);
aos.meanReward = zeros(1, params.aos.nOps);
aos.lastReward = zeros(1, params.aos.nOps);
end