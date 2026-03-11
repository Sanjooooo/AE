function flag = stagnationDetected(bestHist, pop, detail, iter, params)
%STAGNATIONDETECTED Stagnation detector using improvement, diversity and feasibility.

flag = false;
W = params.regen.window;
if iter <= W
    return;
end

improveSmall = abs(bestHist(iter - W) - bestHist(iter)) < params.regen.epsF;
popStd = std(pop, 0, 1);
H = mean(popStd ./ (params.ub - params.lb + 1e-9));
lowDiversity = H < params.regen.epsH;
feasibleRatio = mean([detail.isFeasible]);
lowFeasible = feasibleRatio < params.regen.epsPi;

score = improveSmall + lowDiversity + lowFeasible;
flag = (score >= params.regen.tau);
end