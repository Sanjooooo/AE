function summary = summarizeBatchResults(results)
%SUMMARIZEBATCHRESULTS Summarize multi-run results.

nRuns = numel(results);

bestVals = zeros(nRuns,1);
runTimes = zeros(nRuns,1);
feas = zeros(nRuns,1);

L = zeros(nRuns,1);
E = zeros(nRuns,1);
R = zeros(nRuns,1);
S = zeros(nRuns,1);
V = zeros(nRuns,1);

for i = 1:nRuns
    bestVals(i) = results(i).bestFit;
    runTimes(i) = results(i).runTime;
    feas(i) = results(i).finalFeasible;

    L(i) = results(i).bestDetail.L;
    E(i) = results(i).bestDetail.E;
    R(i) = results(i).bestDetail.R;
    S(i) = results(i).bestDetail.S;
    V(i) = results(i).bestDetail.V;
end

summary.best = min(bestVals);
summary.mean = mean(bestVals);
summary.std = std(bestVals);
summary.worst = max(bestVals);
summary.median = median(bestVals);
summary.feasibleRatio = mean(feas);
summary.avgTime = mean(runTimes);

summary.bestVals = bestVals;
summary.runTimes = runTimes;
summary.feas = feas;

summary.L_mean = mean(L);
summary.E_mean = mean(E);
summary.R_mean = mean(R);
summary.S_mean = mean(S);
summary.V_mean = mean(V);

summary.tableData = [
    summary.best, ...
    summary.mean, ...
    summary.std, ...
    summary.worst, ...
    summary.median, ...
    summary.feasibleRatio, ...
    summary.avgTime, ...
    summary.L_mean, ...
    summary.E_mean, ...
    summary.R_mean, ...
    summary.S_mean, ...
    summary.V_mean
];
end