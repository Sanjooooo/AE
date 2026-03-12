function summaryTable = summarizeAblationResults(allBatchResults)
%SUMMARIZEABLATIONRESULTS Summarize multiple ablation groups.

nGroups = numel(allBatchResults);
summaryTable = cell(nGroups + 1, 8);

summaryTable(1,:) = {'Method','Best','Mean','Std','Worst','Median','FeasRatio','AvgTime'};

for i = 1:nGroups
    s = allBatchResults(i).summary;
    summaryTable{i+1,1} = allBatchResults(i).expCfg.algorithmName;
    summaryTable{i+1,2} = s.best;
    summaryTable{i+1,3} = s.mean;
    summaryTable{i+1,4} = s.std;
    summaryTable{i+1,5} = s.worst;
    summaryTable{i+1,6} = s.median;
    summaryTable{i+1,7} = s.feasibleRatio;
    summaryTable{i+1,8} = s.avgTime;
end
end