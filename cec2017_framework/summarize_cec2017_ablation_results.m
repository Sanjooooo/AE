function summary = summarize_cec2017_ablation_results(resultDir)
%SUMMARIZE_CEC2017_ABLATION_RESULTS
% Summarize CEC2017 ablation experiment results.
%
% Output files:
%   cec_ablation_summary_long.csv
%   cec_ablation_average_rank.csv
%   cec_ablation_summary_workspace.mat
%
% Usage:
%   summarize_cec2017_ablation_results
%   summarize_cec2017_ablation_results('results_cec2017_ablation_formal_high')

    if nargin < 1 || isempty(resultDir)
        resultDir = uigetdir(pwd, 'Select CEC ablation result folder');
        if isequal(resultDir, 0)
            error('No folder selected.');
        end
    end

    dataFile = fullfile(resultDir, 'cec_ablation_batch_results.mat');
    if ~exist(dataFile, 'file')
        error('Cannot find file: %s', dataFile);
    end

    S = load(dataFile);
    allResults = S.allResults;
    cfg = S.cfg;

    funcIds = cfg.funcIds;
    methods = cfg.methods;

    nFuncs = numel(funcIds);
    nMethods = numel(methods);

    meanMat = nan(nFuncs, nMethods);
    stdMat = nan(nFuncs, nMethods);
    bestMat = nan(nFuncs, nMethods);
    medianMat = nan(nFuncs, nMethods);
    runtimeMat = nan(nFuncs, nMethods);

    for f = 1:nFuncs
        for a = 1:nMethods
            runs = allResults{f, a};

            if isempty(runs)
                continue;
            end

            vals = nan(numel(runs), 1);
            times = nan(numel(runs), 1);

            for r = 1:numel(runs)
                if isfield(runs(r), 'bestFitness')
                    vals(r) = runs(r).bestFitness;
                end
                if isfield(runs(r), 'runtime')
                    times(r) = runs(r).runtime;
                end
            end

            vals = vals(isfinite(vals));
            times = times(isfinite(times));

            if ~isempty(vals)
                meanMat(f, a) = mean(vals);
                stdMat(f, a) = std(vals);
                bestMat(f, a) = min(vals);
                medianMat(f, a) = median(vals);
            end

            if ~isempty(times)
                runtimeMat(f, a) = mean(times);
            end
        end
    end

    rankMat = nan(nFuncs, nMethods);
    for f = 1:nFuncs
        row = meanMat(f, :);
        valid = isfinite(row);
        if any(valid)
            [~, order] = sort(row(valid), 'ascend');
            tmp = nan(1, nMethods);
            idxValid = find(valid);
            tmp(idxValid(order)) = 1:nnz(valid);
            rankMat(f, :) = tmp;
        end
    end

    avgRank = mean(rankMat, 1, 'omitnan');

    funcCol = [];
    methodCol = {};
    meanCol = [];
    stdCol = [];
    bestCol = [];
    medianCol = [];
    runtimeCol = [];
    rankCol = [];

    for f = 1:nFuncs
        for a = 1:nMethods
            funcCol(end+1, 1) = funcIds(f); %#ok<AGROW>
            methodCol{end+1, 1} = methods{a}; %#ok<AGROW>
            meanCol(end+1, 1) = meanMat(f, a); %#ok<AGROW>
            stdCol(end+1, 1) = stdMat(f, a); %#ok<AGROW>
            bestCol(end+1, 1) = bestMat(f, a); %#ok<AGROW>
            medianCol(end+1, 1) = medianMat(f, a); %#ok<AGROW>
            runtimeCol(end+1, 1) = runtimeMat(f, a); %#ok<AGROW>
            rankCol(end+1, 1) = rankMat(f, a); %#ok<AGROW>
        end
    end

    summaryTable = table(funcCol, methodCol, meanCol, stdCol, bestCol, ...
        medianCol, runtimeCol, rankCol, ...
        'VariableNames', {'FuncId','Method','Mean','Std','Best','Median','AvgRuntime','Rank'});

    writetable(summaryTable, fullfile(resultDir, 'cec_ablation_summary_long.csv'));

    avgRankTable = table(methods(:), avgRank(:), ...
        'VariableNames', {'Method','AverageRank'});
    avgRankTable = sortrows(avgRankTable, 'AverageRank', 'ascend');

    writetable(avgRankTable, fullfile(resultDir, 'cec_ablation_average_rank.csv'));

    fprintf('\n=== CEC2017 Ablation Summary ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Functions: %d\n', nFuncs);
    fprintf('Methods  : %d\n\n', nMethods);
    fprintf('Average Rank:\n');
    for i = 1:height(avgRankTable)
        fprintf(' %-18s : %.4f\n', avgRankTable.Method{i}, avgRankTable.AverageRank(i));
    end

    summary = struct();
    summary.meanMat = meanMat;
    summary.stdMat = stdMat;
    summary.bestMat = bestMat;
    summary.medianMat = medianMat;
    summary.runtimeMat = runtimeMat;
    summary.rankMat = rankMat;
    summary.avgRank = avgRank;
    summary.summaryTable = summaryTable;
    summary.avgRankTable = avgRankTable;

    save(fullfile(resultDir, 'cec_ablation_summary_workspace.mat'), 'summary');
end