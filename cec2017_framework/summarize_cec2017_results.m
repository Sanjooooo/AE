function summary = summarize_cec2017_results(matFile)
%SUMMARIZE_CEC2017_RESULTS Summarize saved CEC2017 batch results.
%
% Usage:
%   summarize_cec2017_results
%   summarize_cec2017_results('cec2017_30D_results/cec2017_batch_results.mat')
%
% Output:
%   summary.tableCell   - detailed cell table
%   summary.winTieLoss  - win/tie/loss statistics
%   summary.avgRank     - average rank of each algorithm

if nargin < 1
    rootDir = fileparts(mfilename('fullpath'));
    matFile = fullfile(rootDir, 'cec2017_30D_results', 'cec2017_batch_results.mat');
end

if ~exist(matFile, 'file')
    error('Result file not found: %s', matFile);
end

S = load(matFile);

if ~isfield(S, 'allResults')
    error('The MAT file does not contain variable "allResults".');
end
if ~isfield(S, 'cfg')
    error('The MAT file does not contain variable "cfg".');
end

allResults = S.allResults;
cfg = S.cfg;

algNames = cfg.algorithms(:)';
funcIds = unique([allResults.funcId]);
nFuncs = numel(funcIds);
nAlgs = numel(algNames);

% ---------- Build quick lookup ----------
meanMat   = nan(nFuncs, nAlgs);
stdMat    = nan(nFuncs, nAlgs);
bestMat   = nan(nFuncs, nAlgs);
worstMat  = nan(nFuncs, nAlgs);
medianMat = nan(nFuncs, nAlgs);

for i = 1:numel(allResults)
    f = allResults(i).funcId;
    aName = allResults(i).algName;

    fIdx = find(funcIds == f, 1);
    aIdx = find(strcmpi(algNames, aName), 1);

    meanMat(fIdx, aIdx)   = allResults(i).mean;
    stdMat(fIdx, aIdx)    = allResults(i).std;
    bestMat(fIdx, aIdx)   = allResults(i).best;
    worstMat(fIdx, aIdx)  = allResults(i).worst;
    medianMat(fIdx, aIdx) = allResults(i).median;
end

% ---------- Build detailed table ----------
header = {'Function'};
for a = 1:nAlgs
    header{end+1} = sprintf('%s Mean', algNames{a}); %#ok<AGROW>
    header{end+1} = sprintf('%s Std', algNames{a}); %#ok<AGROW>
    header{end+1} = sprintf('%s Best', algNames{a}); %#ok<AGROW>
    header{end+1} = sprintf('%s Worst', algNames{a}); %#ok<AGROW>
    header{end+1} = sprintf('%s Median', algNames{a}); %#ok<AGROW>
end

tableCell = cell(nFuncs + 1, numel(header));
tableCell(1, :) = header;

for i = 1:nFuncs
    row = {sprintf('F%d', funcIds(i))};
    for a = 1:nAlgs
        row{end+1} = meanMat(i, a); %#ok<AGROW>
        row{end+1} = stdMat(i, a); %#ok<AGROW>
        row{end+1} = bestMat(i, a); %#ok<AGROW>
        row{end+1} = worstMat(i, a); %#ok<AGROW>
        row{end+1} = medianMat(i, a); %#ok<AGROW>
    end
    tableCell(i + 1, :) = row;
end

% ---------- Win / Tie / Loss ----------
% Here we compare the first algorithm against the second algorithm.
% If later you add more algorithms, this part can be extended.
winTieLoss = [];
if nAlgs == 2
    tol = 1e-12;
    wins = 0;
    ties = 0;
    losses = 0;

    for i = 1:nFuncs
        v1 = meanMat(i, 1);
        v2 = meanMat(i, 2);

        scaleVal = max([1, abs(v1), abs(v2)]);
        if abs(v1 - v2) <= tol * scaleVal
            ties = ties + 1;
        elseif v1 < v2
            wins = wins + 1;
        else
            losses = losses + 1;
        end
    end

    winTieLoss = struct();
    winTieLoss.referenceAlgorithm = algNames{1};
    winTieLoss.comparedAlgorithm = algNames{2};
    winTieLoss.firstAlgWin  = wins;
    winTieLoss.tie          = ties;
    winTieLoss.firstAlgLoss = losses;
end

% ---------- Average Rank ----------
rankMat = nan(nFuncs, nAlgs);
for i = 1:nFuncs
    vals = meanMat(i, :);
    [~, order] = sort(vals, 'ascend');

    ranks = zeros(1, nAlgs);
    for r = 1:nAlgs
        ranks(order(r)) = r;
    end
    rankMat(i, :) = ranks;
end
avgRank = mean(rankMat, 1);

% ---------- Print concise summary ----------
fprintf('\n========================================\n');
fprintf('CEC2017 Summary from saved MAT file\n');
fprintf('File: %s\n', matFile);
fprintf('Dim = %d | Runs = %d | Functions = %s\n', ...
    cfg.dim, cfg.nRuns, mat2str(cfg.funcIds));
fprintf('Algorithms: %s\n', strjoin(algNames, ', '));
fprintf('========================================\n');

for i = 1:nFuncs
    fprintf('F%d\n', funcIds(i));
    for a = 1:nAlgs
        fprintf('  %-10s mean = %.6e | std = %.6e | best = %.6e | median = %.6e\n', ...
            algNames{a}, meanMat(i, a), stdMat(i, a), bestMat(i, a), medianMat(i, a));
    end
end

fprintf('----------------------------------------\n');
fprintf('Average Rank:\n');
for a = 1:nAlgs
    fprintf('  %-10s rank = %.4f\n', algNames{a}, avgRank(a));
end

if ~isempty(winTieLoss)
    fprintf('----------------------------------------\n');
    fprintf('Win/Tie/Loss (by mean, %s vs %s): %d / %d / %d\n', ...
        winTieLoss.referenceAlgorithm, ...
        winTieLoss.comparedAlgorithm, ...
        winTieLoss.firstAlgWin, ...
        winTieLoss.tie, ...
        winTieLoss.firstAlgLoss);
end
fprintf('========================================\n');

% ---------- Save summary csv ----------
[matFolder, ~, ~] = fileparts(matFile);
csvFile = fullfile(matFolder, 'cec2017_summary_table.csv');
writecell(tableCell, csvFile);

fprintf('Saved summary table to:\n%s\n', csvFile);

summary = struct();
summary.tableCell = tableCell;
summary.meanMat = meanMat;
summary.stdMat = stdMat;
summary.bestMat = bestMat;
summary.worstMat = worstMat;
summary.medianMat = medianMat;
summary.rankMat = rankMat;
summary.avgRank = avgRank;
summary.winTieLoss = winTieLoss;
summary.algNames = algNames;
summary.funcIds = funcIds;
summary.csvFile = csvFile;
end