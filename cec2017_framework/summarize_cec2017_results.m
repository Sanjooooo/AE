function summary = summarize_cec2017_results(resultDir)

if nargin < 1 || isempty(resultDir)
    resultDir = uigetdir(pwd, 'Select CEC result folder');
    if isequal(resultDir, 0)
        error('No folder selected.');
    end
end

dataFile = fullfile(resultDir, 'cec2017_batch_results.mat');
if ~exist(dataFile, 'file')
    error('Cannot find file: %s', dataFile);
end

S = load(dataFile);
allResults = S.allResults;
cfg = S.cfg;

funcIds = cfg.funcIds;
algorithms = cfg.algorithms;

nFuncs = numel(funcIds);
nAlgs = numel(algorithms);

meanMat   = nan(nFuncs, nAlgs);
stdMat    = nan(nFuncs, nAlgs);
bestMat   = nan(nFuncs, nAlgs);
medianMat = nan(nFuncs, nAlgs);
runtimeMat = nan(nFuncs, nAlgs);

for f = 1:nFuncs
    for a = 1:nAlgs
        runs = allResults{f, a};
        vals = nan(numel(runs), 1);
        times = nan(numel(runs), 1);

        for r = 1:numel(runs)
            vals(r) = runs(r).bestFitness;
            times(r) = runs(r).runtime;
        end

        meanMat(f, a)   = mean(vals);
        stdMat(f, a)    = std(vals);
        bestMat(f, a)   = min(vals);
        medianMat(f, a) = median(vals);
        runtimeMat(f, a) = mean(times);
    end
end

% Rank by mean value on each function (smaller is better)
rankMat = nan(nFuncs, nAlgs);
for f = 1:nFuncs
    [~, order] = sort(meanMat(f, :), 'ascend');
    rankMat(f, order) = 1:nAlgs;
end
avgRank = mean(rankMat, 1);

% Build long summary table
funcCol = [];
algCol = {};
meanCol = [];
stdCol = [];
bestCol = [];
medianCol = [];
runtimeCol = [];
rankCol = [];

for f = 1:nFuncs
    for a = 1:nAlgs
        funcCol(end+1, 1) = funcIds(f);
        algCol{end+1, 1} = algorithms{a};
        meanCol(end+1, 1) = meanMat(f, a);
        stdCol(end+1, 1) = stdMat(f, a);
        bestCol(end+1, 1) = bestMat(f, a);
        medianCol(end+1, 1) = medianMat(f, a);
        runtimeCol(end+1, 1) = runtimeMat(f, a);
        rankCol(end+1, 1) = rankMat(f, a);
    end
end

summaryTable = table(funcCol, algCol, meanCol, stdCol, bestCol, ...
    medianCol, runtimeCol, rankCol, ...
    'VariableNames', {'FuncId','Algorithm','Mean','Std','Best','Median','AvgRuntime','Rank'});

writetable(summaryTable, fullfile(resultDir, 'cec2017_summary_long.csv'));

% Average-rank table
avgRankTable = table(algorithms(:), avgRank(:), ...
    'VariableNames', {'Algorithm', 'AverageRank'});
avgRankTable = sortrows(avgRankTable, 'AverageRank', 'ascend');
writetable(avgRankTable, fullfile(resultDir, 'cec2017_average_rank.csv'));

% FAEAE vs baselines: win/tie/loss by mean
faeIdx = find(strcmpi(algorithms, 'FAEAE'), 1);
wtlTable = table();

if ~isempty(faeIdx)
    baselineNames = {};
    wins = [];
    ties = [];
    losses = [];

    for a = 1:nAlgs
        if a == faeIdx
            continue;
        end

        w = 0; t = 0; l = 0;

        for f = 1:nFuncs
            vF = meanMat(f, faeIdx);
            vB = meanMat(f, a);

            tol = 1e-12 * max([1, abs(vF), abs(vB)]);
            if vF < vB - tol
                w = w + 1;
            elseif vF > vB + tol
                l = l + 1;
            else
                t = t + 1;
            end
        end

        baselineNames{end+1,1} = algorithms{a};
        wins(end+1,1) = w;
        ties(end+1,1) = t;
        losses(end+1,1) = l;
    end

    wtlTable = table(baselineNames, wins, ties, losses, ...
        'VariableNames', {'Baseline','Win','Tie','Loss'});

    writetable(wtlTable, fullfile(resultDir, 'cec2017_faeae_wtl.csv'));
end

% Print concise report
fprintf('\n=== CEC2017 Summary ===\n');
fprintf('Result folder: %s\n', resultDir);
fprintf('Functions: %d\n', nFuncs);
fprintf('Algorithms: %d\n\n', nAlgs);

fprintf('Average Rank:\n');
for i = 1:height(avgRankTable)
    fprintf('  %-10s : %.4f\n', avgRankTable.Algorithm{i}, avgRankTable.AverageRank(i));
end

if ~isempty(wtlTable)
    fprintf('\nFAEAE vs baselines (by function mean):\n');
    for i = 1:height(wtlTable)
        fprintf('  vs %-8s : W/T/L = %d / %d / %d\n', ...
            wtlTable.Baseline{i}, wtlTable.Win(i), wtlTable.Tie(i), wtlTable.Loss(i));
    end
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
summary.wtlTable = wtlTable;

save(fullfile(resultDir, 'cec2017_summary_workspace.mat'), 'summary');
end