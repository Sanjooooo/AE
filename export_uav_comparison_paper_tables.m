function export_uav_comparison_paper_tables(resultDir)
%EXPORT_UAV_COMPARISON_PAPER_TABLES Export UAV comparison results for paper.
% Main tables must follow the original algorithm order in meanMat/stdMat.
%
% Usage:
%   export_uav_comparison_paper_tables
%   export_uav_comparison_paper_tables(resultDir)
%
% Input:
%   resultDir - folder containing uav_comparison_results.mat
%
% Output files:
%   uav_paper_summary_long.csv
%   uav_paper_summary_wide.csv
%   uav_paper_average_rank.csv
%   uav_paper_faeae_wtl.csv
%   uav_paper_tables.tex
%   uav_paper_export_workspace.mat

    if nargin < 1 || isempty(resultDir)
        resultDir = uigetdir(pwd, 'Select UAV comparison result folder');
        if isequal(resultDir, 0)
            error('No folder selected.');
        end
    end

    % Reuse the existing summary script first
    summary = summarize_uav_comparison_results(resultDir);

    longTable = summary.longTable;
    wideTable = summary.wideTable;
    avgRankTable = summary.avgRankTable;
    wtlTable = summary.wtlTable;

    meanMat = summary.meanMat;
    stdMat = summary.stdMat;
    feasRatioMat = summary.feasRatioMat;
    avgRuntimeMat = summary.avgRuntimeMat;
    sceneIds = unique(longTable.SceneId, 'stable');
    
    % IMPORTANT:
    % Use original algorithm order, not the rank-sorted order.
    algorithms = unique(longTable.Algorithm, 'stable')';
    algorithms = algorithms(:)';

    % Rename/export standardized paper files
    writetable(longTable, fullfile(resultDir, 'uav_paper_summary_long.csv'));
    writetable(wideTable, fullfile(resultDir, 'uav_paper_summary_wide.csv'));
    writetable(avgRankTable, fullfile(resultDir, 'uav_paper_average_rank.csv'));
    if ~isempty(wtlTable)
        writetable(wtlTable, fullfile(resultDir, 'uav_paper_faeae_wtl.csv'));
    end

    texFile = fullfile(resultDir, 'uav_paper_tables.tex');
    writeLatexTables(texFile, sceneIds, algorithms, meanMat, stdMat, ...
        feasRatioMat, avgRuntimeMat, avgRankTable, wtlTable);

    save(fullfile(resultDir, 'uav_paper_export_workspace.mat'), 'summary');

    fprintf('\n=== UAV Paper Export Finished ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Exported files:\n');
    fprintf('  - uav_paper_summary_long.csv\n');
    fprintf('  - uav_paper_summary_wide.csv\n');
    fprintf('  - uav_paper_average_rank.csv\n');
    fprintf('  - uav_paper_faeae_wtl.csv\n');
    fprintf('  - uav_paper_tables.tex\n');
    fprintf('  - uav_paper_export_workspace.mat\n');
end


% ========================================================================
function writeLatexTables(texFile, sceneIds, algorithms, meanMat, stdMat, ...
    feasRatioMat, avgRuntimeMat, avgRankTable, wtlTable)

    fid = fopen(texFile, 'w');
    if fid < 0
        error('Cannot open file for writing: %s', texFile);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '%% Auto-generated LaTeX tables for UAV comparison results\n\n');

    % --------------------------------------------------
    % Table 1: main performance table
    % --------------------------------------------------
    fprintf(fid, '%% =====================================================\n');
    fprintf(fid, '%% Table 1: Main UAV comparison results\n');
    fprintf(fid, '%% =====================================================\n');
    fprintf(fid, '\\begin{table*}[t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{Main comparison results on the UAV path planning task. Lower values of Mean $\\pm$ Std are better.}\n');
    fprintf(fid, '\\resizebox{\\textwidth}{!}{%%\n');

    fprintf(fid, '\\begin{tabular}{c');
    for a = 1:numel(algorithms)
        fprintf(fid, 'c');
    end
    fprintf(fid, '}\n');

    fprintf(fid, '\\hline\n');
    fprintf(fid, 'Scene');
    for a = 1:numel(algorithms)
        fprintf(fid, ' & %s', escapeLatex(algorithms{a}));
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\hline\n');

    for s = 1:numel(sceneIds)
        [~, bestIdx] = min(meanMat(s, :));
        fprintf(fid, 'Scene %d', sceneIds(s));

        for a = 1:numel(algorithms)
            cellStr = sprintf('%.3f $\\pm$ %.3f', meanMat(s, a), stdMat(s, a));
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
    % Table 2: Feasibility + runtime
    % --------------------------------------------------
    fprintf(fid, '%% =====================================================\n');
    fprintf(fid, '%% Table 2: Feasibility and runtime\n');
    fprintf(fid, '%% =====================================================\n');
    fprintf(fid, '\\begin{table*}[t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{Feasibility ratio and average runtime on the UAV path planning task.}\n');
    fprintf(fid, '\\resizebox{\\textwidth}{!}{%%\n');

    fprintf(fid, '\\begin{tabular}{c');
    for a = 1:numel(algorithms)
        fprintf(fid, 'cc');
    end
    fprintf(fid, '}\n');

    fprintf(fid, '\\hline\n');
    fprintf(fid, 'Scene');
    for a = 1:numel(algorithms)
        fprintf(fid, ' & \\multicolumn{2}{c}{%s}', escapeLatex(algorithms{a}));
    end
    fprintf(fid, ' \\\\\n');

    fprintf(fid, ' ');
    for a = 1:numel(algorithms)
        fprintf(fid, ' & Feas. & Time');
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\hline\n');

    for s = 1:numel(sceneIds)
        fprintf(fid, 'Scene %d', sceneIds(s));
        for a = 1:numel(algorithms)
            fprintf(fid, ' & %.3f & %.3f', feasRatioMat(s, a), avgRuntimeMat(s, a));
        end
        fprintf(fid, ' \\\\\n');
    end

    fprintf(fid, '\\hline\n');
    fprintf(fid, '\\end{tabular}%%\n');
    fprintf(fid, '}\n');
    fprintf(fid, '\\end{table*}\n\n');

    % --------------------------------------------------
    % Table 3: Average rank
    % --------------------------------------------------
    fprintf(fid, '%% =====================================================\n');
    fprintf(fid, '%% Table 3: Average rank\n');
    fprintf(fid, '%% =====================================================\n');
    fprintf(fid, '\\begin{table}[t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{Average rank of all compared algorithms across UAV scenes. Lower is better.}\n');
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
    % Table 4: FAEAE vs baseline W/T/L
    % --------------------------------------------------
    if ~isempty(wtlTable)
        fprintf(fid, '%% =====================================================\n');
        fprintf(fid, '%% Table 4: FAEAE vs baselines\n');
        fprintf(fid, '%% =====================================================\n');
        fprintf(fid, '\\begin{table}[t]\n');
        fprintf(fid, '\\centering\n');
        fprintf(fid, '\\caption{Win/Tie/Loss statistics of FAE-AE against baseline algorithms based on scene-wise mean values.}\n');
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