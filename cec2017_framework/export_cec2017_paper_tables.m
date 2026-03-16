function export_cec2017_paper_tables(resultDir)
%EXPORT_CEC2017_PAPER_TABLES Export CEC2017 results for paper tables.
%
% Usage:
%   export_cec2017_paper_tables
%   export_cec2017_paper_tables(resultDir)
%
% Input:
%   resultDir - folder containing cec2017_batch_results.mat
%
% Output files:
%   cec2017_summary_long.csv
%   cec2017_summary_wide.csv
%   cec2017_average_rank.csv
%   cec2017_faeae_wtl.csv
%   cec2017_paper_tables.tex
%   cec2017_export_workspace.mat

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

    % -----------------------------
    % Collect statistics
    % -----------------------------
    for f = 1:nFuncs
        for a = 1:nAlgs
            runs = allResults{f, a};

            vals = nan(numel(runs), 1);
            times = nan(numel(runs), 1);

            for r = 1:numel(runs)
                vals(r) = getFieldSafe(runs(r), {'bestFitness','bestFit','bestCost'});
                times(r) = getFieldSafe(runs(r), {'runtime','runTime','time'}, NaN);
            end

            meanMat(f, a)   = mean(vals, 'omitnan');
            stdMat(f, a)    = std(vals, 'omitnan');
            bestMat(f, a)   = min(vals);
            medianMat(f, a) = median(vals, 'omitnan');
            runtimeMat(f, a)= mean(times, 'omitnan');
        end
    end

    % -----------------------------
    % Ranking
    % -----------------------------
    rankMat = nan(nFuncs, nAlgs);
    for f = 1:nFuncs
        [~, order] = sort(meanMat(f, :), 'ascend');
        rankMat(f, order) = 1:nAlgs;
    end
    avgRank = mean(rankMat, 1, 'omitnan');

    % -----------------------------
    % Long table
    % -----------------------------
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
            funcCol(end+1, 1) = funcIds(f); %#ok<AGROW>
            algCol{end+1, 1} = algorithms{a}; %#ok<AGROW>
            meanCol(end+1, 1) = meanMat(f, a); %#ok<AGROW>
            stdCol(end+1, 1) = stdMat(f, a); %#ok<AGROW>
            bestCol(end+1, 1) = bestMat(f, a); %#ok<AGROW>
            medianCol(end+1, 1) = medianMat(f, a); %#ok<AGROW>
            runtimeCol(end+1, 1) = runtimeMat(f, a); %#ok<AGROW>
            rankCol(end+1, 1) = rankMat(f, a); %#ok<AGROW>
        end
    end

    summaryLong = table(funcCol, algCol, meanCol, stdCol, bestCol, ...
        medianCol, runtimeCol, rankCol, ...
        'VariableNames', {'FuncId','Algorithm','Mean','Std','Best','Median','AvgRuntime','Rank'});

    writetable(summaryLong, fullfile(resultDir, 'cec2017_summary_long.csv'));

    % -----------------------------
    % Wide table
    % -----------------------------
    wideTable = table(funcIds(:), 'VariableNames', {'FuncId'});

    for a = 1:nAlgs
        alg = algorithms{a};
        wideTable.(sprintf('%s_Mean', alg)) = meanMat(:, a);
        wideTable.(sprintf('%s_Std', alg)) = stdMat(:, a);
        wideTable.(sprintf('%s_Best', alg)) = bestMat(:, a);
        wideTable.(sprintf('%s_Median', alg)) = medianMat(:, a);
        wideTable.(sprintf('%s_Rank', alg)) = rankMat(:, a);
    end

    % Best algorithm by mean
    bestAlgByMean = strings(nFuncs, 1);
    for f = 1:nFuncs
        [~, idx] = min(meanMat(f, :));
        bestAlgByMean(f) = string(algorithms{idx});
    end
    wideTable.BestAlgByMean = bestAlgByMean;

    writetable(wideTable, fullfile(resultDir, 'cec2017_summary_wide.csv'));

    % -----------------------------
    % Average rank table
    % -----------------------------
    avgRankTable = table(algorithms(:), avgRank(:), ...
        'VariableNames', {'Algorithm','AverageRank'});
    avgRankTable = sortrows(avgRankTable, 'AverageRank', 'ascend');

    writetable(avgRankTable, fullfile(resultDir, 'cec2017_average_rank.csv'));

    % -----------------------------
    % FAEAE vs baselines
    % -----------------------------
    faeIdx = find(strcmpi(algorithms, 'FAEAE'), 1);
    if isempty(faeIdx)
        warning('FAEAE not found in algorithm list. Skip W/T/L export.');
        wtlTable = table();
    else
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

            baselineNames{end+1,1} = algorithms{a}; %#ok<AGROW>
            wins(end+1,1) = w; %#ok<AGROW>
            ties(end+1,1) = t; %#ok<AGROW>
            losses(end+1,1) = l; %#ok<AGROW>
        end

        wtlTable = table(baselineNames, wins, ties, losses, ...
            'VariableNames', {'Baseline','Win','Tie','Loss'});

        writetable(wtlTable, fullfile(resultDir, 'cec2017_faeae_wtl.csv'));
    end

    % -----------------------------
    % LaTeX table export
    % -----------------------------
    texFile = fullfile(resultDir, 'cec2017_paper_tables.tex');
    writeLatexTables(texFile, funcIds, algorithms, meanMat, stdMat, rankMat, avgRankTable, wtlTable);

    % -----------------------------
    % Save workspace
    % -----------------------------
    exportData = struct();
    exportData.meanMat = meanMat;
    exportData.stdMat = stdMat;
    exportData.bestMat = bestMat;
    exportData.medianMat = medianMat;
    exportData.runtimeMat = runtimeMat;
    exportData.rankMat = rankMat;
    exportData.avgRank = avgRank;
    exportData.summaryLong = summaryLong;
    exportData.wideTable = wideTable;
    exportData.avgRankTable = avgRankTable;
    exportData.wtlTable = wtlTable;

    save(fullfile(resultDir, 'cec2017_export_workspace.mat'), 'exportData');

    % -----------------------------
    % Console report
    % -----------------------------
    fprintf('\n=== CEC2017 Paper Export Finished ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Exported files:\n');
    fprintf('  - cec2017_summary_long.csv\n');
    fprintf('  - cec2017_summary_wide.csv\n');
    fprintf('  - cec2017_average_rank.csv\n');
    fprintf('  - cec2017_faeae_wtl.csv\n');
    fprintf('  - cec2017_paper_tables.tex\n');
    fprintf('  - cec2017_export_workspace.mat\n');

end

% ========================================================================
function val = getFieldSafe(s, fieldCandidates, defaultVal)
    if nargin < 3
        defaultVal = [];
    end

    val = defaultVal;
    for i = 1:numel(fieldCandidates)
        if isfield(s, fieldCandidates{i})
            val = s.(fieldCandidates{i});
            return;
        end
    end

    if isempty(defaultVal)
        error('Cannot find any expected field in result struct.');
    end
end

% ========================================================================
function writeLatexTables(texFile, funcIds, algorithms, meanMat, stdMat, rankMat, avgRankTable, wtlTable)

    fid = fopen(texFile, 'w');
    if fid < 0
        error('Cannot open file for writing: %s', texFile);
    end

    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '%% Auto-generated LaTeX tables for CEC2017 results\n\n');

    % --------------------------------------------------
    % Table 1: function-wise mean +- std
    % --------------------------------------------------
    fprintf(fid, '%% =====================================================\n');
    fprintf(fid, '%% Table: Function-wise mean and std\n');
    fprintf(fid, '%% =====================================================\n');
    fprintf(fid, '\\begin{table*}[t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{Performance comparison on the CEC2017 benchmark (mean $\\pm$ std). Lower is better.}\n');
    fprintf(fid, '\\resizebox{\\textwidth}{!}{%%\n');

    fprintf(fid, '\\begin{tabular}{c');
    for a = 1:numel(algorithms)
        fprintf(fid, 'c');
    end
    fprintf(fid, '}\n');

    fprintf(fid, '\\hline\n');
    fprintf(fid, 'Func');
    for a = 1:numel(algorithms)
        fprintf(fid, ' & %s', escapeLatex(algorithms{a}));
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\hline\n');

    for f = 1:numel(funcIds)
        [~, bestIdx] = min(meanMat(f, :));

        fprintf(fid, 'F%d', funcIds(f));
        for a = 1:numel(algorithms)
            cellStr = sprintf('%.3e $\\pm$ %.3e', meanMat(f, a), stdMat(f, a));
            if a == bestIdx
                cellStr = ['\textbf{' cellStr '}'];
            end
            fprintf(fid, ' & %s', cellStr);
        end
        fprintf(fid, ' \\\\\n');
    end

    fprintf(fid, '\\hline\n');
    fprintf(fid, '\\end{tabular}%%\n');
    fprintf(fid, '}\n');
    fprintf(fid, '\\end{table*}\n\n');

    % --------------------------------------------------
    % Table 2: average rank
    % --------------------------------------------------
    fprintf(fid, '%% =====================================================\n');
    fprintf(fid, '%% Table: Average Rank\n');
    fprintf(fid, '%% =====================================================\n');
    fprintf(fid, '\\begin{table}[t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{Average rank of all compared algorithms on CEC2017. Lower is better.}\n');
    fprintf(fid, '\\begin{tabular}{cc}\n');
    fprintf(fid, '\\hline\n');
    fprintf(fid, 'Algorithm & Average Rank \\\\\n');
    fprintf(fid, '\\hline\n');

    for i = 1:height(avgRankTable)
        alg = avgRankTable.Algorithm{i};
        val = avgRankTable.AverageRank(i);

        if i == 1
            fprintf(fid, '\\textbf{%s} & \\textbf{%.4f} \\\\\n', escapeLatex(alg), val);
        else
            fprintf(fid, '%s & %.4f \\\\\n', escapeLatex(alg), val);
        end
    end

    fprintf(fid, '\\hline\n');
    fprintf(fid, '\\end{tabular}\n');
    fprintf(fid, '\\end{table}\n\n');

    % --------------------------------------------------
    % Table 3: FAEAE vs baseline W/T/L
    % --------------------------------------------------
    if ~isempty(wtlTable)
        fprintf(fid, '%% =====================================================\n');
        fprintf(fid, '%% Table: FAEAE vs baselines\n');
        fprintf(fid, '%% =====================================================\n');
        fprintf(fid, '\\begin{table}[t]\n');
        fprintf(fid, '\\centering\n');
        fprintf(fid, '\\caption{Win/Tie/Loss statistics of FAE-AE against baseline algorithms based on function-wise mean values.}\n');
        fprintf(fid, '\\begin{tabular}{cccc}\n');
        fprintf(fid, '\\hline\n');
        fprintf(fid, 'Baseline & Win & Tie & Loss \\\\\n');
        fprintf(fid, '\\hline\n');

        for i = 1:height(wtlTable)
            fprintf(fid, '%s & %d & %d & %d \\\\\n', ...
                escapeLatex(wtlTable.Baseline{i}), ...
                wtlTable.Win(i), ...
                wtlTable.Tie(i), ...
                wtlTable.Loss(i));
        end

        fprintf(fid, '\\hline\n');
        fprintf(fid, '\\end{tabular}\n');
        fprintf(fid, '\\end{table}\n\n');
    end
end

% ========================================================================
function s = escapeLatex(str)
    s = strrep(str, '_', '\_');
end