function summary = summarize_ablation_paper_results(resultRoot)
%SUMMARIZE_ABLATION_PAPER_RESULTS Build paper-ready ablation tables.
%
% Usage:
%   summary = summarize_ablation_paper_results();
%   summary = summarize_ablation_paper_results(resultRoot);
%
% Input:
%   resultRoot - folder containing:
%       ablation_scene1_summary.csv
%       ablation_scene2_summary.csv
%       ablation_scene4_summary.csv
%
% Output files:
%   ablation_paper_summary_long.csv
%   ablation_paper_summary_wide.csv
%   ablation_paper_average_rank.csv
%   ablation_paper_faeae_wtl.csv
%   ablation_paper_tables.tex
%   ablation_paper_summary_workspace.mat

    if nargin < 1 || isempty(resultRoot)
        resultRoot = uigetdir(pwd, 'Select folder containing ablation_scene*_summary.csv');
        if isequal(resultRoot, 0)
            error('No folder selected.');
        end
    end

    sceneIds = [1, 2, 4];
    sceneFiles = {
        'ablation_scene1_summary.csv'
        'ablation_scene2_summary.csv'
        'ablation_scene4_summary.csv'
    };

    % ------------------------------------------------------------
    % Load scene tables
    % ------------------------------------------------------------
    Tcell = cell(numel(sceneIds), 1);

    for i = 1:numel(sceneIds)
        fp = fullfile(resultRoot, sceneFiles{i});
        if ~exist(fp, 'file')
            error('Cannot find file: %s', fp);
        end
        Tcell{i} = readtable(fp, 'TextType', 'string');
    end

    % Use scene1 method order as canonical order
    methods = Tcell{1}.Method;
    nScenes = numel(sceneIds);
    nMethods = numel(methods);

    % sanity check: method consistency
    for i = 2:numel(sceneIds)
        if ~isequal(Tcell{i}.Method, methods)
            error('Method order mismatch between scene summaries.');
        end
    end

    % ------------------------------------------------------------
    % Build matrices
    % ------------------------------------------------------------
    bestMat      = nan(nScenes, nMethods);
    meanMat      = nan(nScenes, nMethods);
    stdMat       = nan(nScenes, nMethods);
    worstMat     = nan(nScenes, nMethods);
    medianMat    = nan(nScenes, nMethods);
    feasRatioMat = nan(nScenes, nMethods);
    avgTimeMat   = nan(nScenes, nMethods);

    for s = 1:nScenes
        T = Tcell{s};

        bestMat(s, :)      = T.Best.';
        meanMat(s, :)      = T.Mean.';
        stdMat(s, :)       = T.Std.';
        worstMat(s, :)     = T.Worst.';
        medianMat(s, :)    = T.Median.';
        feasRatioMat(s, :) = T.FeasRatio.';
        avgTimeMat(s, :)   = T.AvgTime.';
    end

    % ------------------------------------------------------------
    % Rank by Mean (lower is better)
    % ------------------------------------------------------------
    rankMat = nan(nScenes, nMethods);
    for s = 1:nScenes
        [~, order] = sort(meanMat(s, :), 'ascend');
        rankMat(s, order) = 1:nMethods;
    end
    avgRank = mean(rankMat, 1, 'omitnan');

    % ------------------------------------------------------------
    % Long table
    % ------------------------------------------------------------
    sceneCol = [];
    methodCol = strings(0,1);
    bestCol = [];
    meanCol = [];
    stdCol = [];
    worstCol = [];
    medianCol = [];
    feasCol = [];
    timeCol = [];
    rankCol = [];

    for s = 1:nScenes
        for m = 1:nMethods
            sceneCol(end+1,1) = sceneIds(s); %#ok<AGROW>
            methodCol(end+1,1) = methods(m); %#ok<AGROW>
            bestCol(end+1,1) = bestMat(s,m); %#ok<AGROW>
            meanCol(end+1,1) = meanMat(s,m); %#ok<AGROW>
            stdCol(end+1,1) = stdMat(s,m); %#ok<AGROW>
            worstCol(end+1,1) = worstMat(s,m); %#ok<AGROW>
            medianCol(end+1,1) = medianMat(s,m); %#ok<AGROW>
            feasCol(end+1,1) = feasRatioMat(s,m); %#ok<AGROW>
            timeCol(end+1,1) = avgTimeMat(s,m); %#ok<AGROW>
            rankCol(end+1,1) = rankMat(s,m); %#ok<AGROW>
        end
    end

    longTable = table(sceneCol, methodCol, bestCol, meanCol, stdCol, worstCol, ...
        medianCol, feasCol, timeCol, rankCol, ...
        'VariableNames', {'SceneId','Method','Best','Mean','Std','Worst','Median','FeasRatio','AvgTime','Rank'});

    writetable(longTable, fullfile(resultRoot, 'ablation_paper_summary_long.csv'));

    % ------------------------------------------------------------
    % Wide table
    % ------------------------------------------------------------
    wideTable = table(sceneIds(:), 'VariableNames', {'SceneId'});
    for m = 1:nMethods
        methodName = matlab.lang.makeValidName(methods(m));

        wideTable.(methodName + "_Mean")      = meanMat(:, m);
        wideTable.(methodName + "_Std")       = stdMat(:, m);
        wideTable.(methodName + "_Best")      = bestMat(:, m);
        wideTable.(methodName + "_Median")    = medianMat(:, m);
        wideTable.(methodName + "_FeasRatio") = feasRatioMat(:, m);
        wideTable.(methodName + "_AvgTime")   = avgTimeMat(:, m);
        wideTable.(methodName + "_Rank")      = rankMat(:, m);
    end

    bestMethodByMean = strings(nScenes, 1);
    for s = 1:nScenes
        [~, idx] = min(meanMat(s,:));
        bestMethodByMean(s) = methods(idx);
    end
    wideTable.BestMethodByMean = bestMethodByMean;

    writetable(wideTable, fullfile(resultRoot, 'ablation_paper_summary_wide.csv'));

    % ------------------------------------------------------------
    % Average rank table
    % ------------------------------------------------------------
    avgRankTable = table(methods(:), avgRank(:), ...
        'VariableNames', {'Method','AverageRank'});
    avgRankTable = sortrows(avgRankTable, 'AverageRank', 'ascend');

    writetable(avgRankTable, fullfile(resultRoot, 'ablation_paper_average_rank.csv'));

    % ------------------------------------------------------------
    % FAE-AE vs other ablations W/T/L
    % ------------------------------------------------------------
    faeIdx = find(strcmp(methods, "FAE-AE"), 1);
    wtlTable = table();

    if ~isempty(faeIdx)
        baselineNames = strings(0,1);
        wins = [];
        ties = [];
        losses = [];

        for m = 1:nMethods
            if m == faeIdx
                continue;
            end

            w = 0; t = 0; l = 0;
            for s = 1:nScenes
                vF = meanMat(s, faeIdx);
                vB = meanMat(s, m);

                tol = 1e-12 * max([1, abs(vF), abs(vB)]);
                if vF < vB - tol
                    w = w + 1;
                elseif vF > vB + tol
                    l = l + 1;
                else
                    t = t + 1;
                end
            end

            baselineNames(end+1,1) = methods(m); %#ok<AGROW>
            wins(end+1,1) = w; %#ok<AGROW>
            ties(end+1,1) = t; %#ok<AGROW>
            losses(end+1,1) = l; %#ok<AGROW>
        end

        wtlTable = table(baselineNames, wins, ties, losses, ...
            'VariableNames', {'Baseline','Win','Tie','Loss'});

        writetable(wtlTable, fullfile(resultRoot, 'ablation_paper_faeae_wtl.csv'));
    end

    % ------------------------------------------------------------
    % Write LaTeX tables
    % ------------------------------------------------------------
    texFile = fullfile(resultRoot, 'ablation_paper_tables.tex');
    writeLatexTables(texFile, sceneIds, methods, meanMat, stdMat, feasRatioMat, avgTimeMat, avgRankTable, wtlTable);

    % ------------------------------------------------------------
    % Save workspace
    % ------------------------------------------------------------
    summary = struct();
    summary.sceneIds = sceneIds;
    summary.methods = methods;

    summary.bestMat = bestMat;
    summary.meanMat = meanMat;
    summary.stdMat = stdMat;
    summary.worstMat = worstMat;
    summary.medianMat = medianMat;
    summary.feasRatioMat = feasRatioMat;
    summary.avgTimeMat = avgTimeMat;
    summary.rankMat = rankMat;
    summary.avgRank = avgRank;

    summary.longTable = longTable;
    summary.wideTable = wideTable;
    summary.avgRankTable = avgRankTable;
    summary.wtlTable = wtlTable;

    save(fullfile(resultRoot, 'ablation_paper_summary_workspace.mat'), 'summary');

    % ------------------------------------------------------------
    % Console output
    % ------------------------------------------------------------
    fprintf('\n=== Ablation Paper Summary ===\n');
    fprintf('Result folder: %s\n', resultRoot);
    fprintf('Scenes: %d\n', nScenes);
    fprintf('Methods: %d\n\n', nMethods);

    fprintf('Average Rank:\n');
    for i = 1:height(avgRankTable)
        fprintf('  %-20s : %.4f\n', avgRankTable.Method(i), avgRankTable.AverageRank(i));
    end

    if ~isempty(wtlTable)
        fprintf('\nFAE-AE vs other ablations (by scene mean):\n');
        for i = 1:height(wtlTable)
            fprintf('  vs %-18s : W/T/L = %d / %d / %d\n', ...
                wtlTable.Baseline(i), wtlTable.Win(i), wtlTable.Tie(i), wtlTable.Loss(i));
        end
    end

    fprintf('\nExported files:\n');
    fprintf('  - ablation_paper_summary_long.csv\n');
    fprintf('  - ablation_paper_summary_wide.csv\n');
    fprintf('  - ablation_paper_average_rank.csv\n');
    fprintf('  - ablation_paper_faeae_wtl.csv\n');
    fprintf('  - ablation_paper_tables.tex\n');
    fprintf('  - ablation_paper_summary_workspace.mat\n');
end


% ========================================================================
function writeLatexTables(texFile, sceneIds, methods, meanMat, stdMat, ...
    feasRatioMat, avgTimeMat, avgRankTable, wtlTable)

    fid = fopen(texFile, 'w');
    if fid < 0
        error('Cannot open file for writing: %s', texFile);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '%% Auto-generated LaTeX tables for ablation results\n\n');

    % --------------------------------------------------
    % Table 1: Mean +- Std
    % --------------------------------------------------
    fprintf(fid, '\\begin{table*}[t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{Ablation results on the UAV path planning task (Mean $\\pm$ Std). Lower is better.}\n');
    fprintf(fid, '\\resizebox{\\textwidth}{!}{%%\n');
    fprintf(fid, '\\begin{tabular}{c');
    for m = 1:numel(methods)
        fprintf(fid, 'c');
    end
    fprintf(fid, '}\n');
    fprintf(fid, '\\hline\n');

    fprintf(fid, 'Scene');
    for m = 1:numel(methods)
        fprintf(fid, ' & %s', escapeLatex(char(methods(m))));
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\hline\n');

    for s = 1:numel(sceneIds)
        [~, bestIdx] = min(meanMat(s,:));
        fprintf(fid, 'Scene %d', sceneIds(s));
        for m = 1:numel(methods)
            cellStr = sprintf('%.3f $\\pm$ %.3f', meanMat(s,m), stdMat(s,m));
            if m == bestIdx
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
    fprintf(fid, '\\begin{table*}[t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{Feasibility ratio and average runtime of ablation variants.}\n');
    fprintf(fid, '\\resizebox{\\textwidth}{!}{%%\n');
    fprintf(fid, '\\begin{tabular}{c');
    for m = 1:numel(methods)
        fprintf(fid, 'cc');
    end
    fprintf(fid, '}\n');
    fprintf(fid, '\\hline\n');

    fprintf(fid, 'Scene');
    for m = 1:numel(methods)
        fprintf(fid, ' & \\multicolumn{2}{c}{%s}', escapeLatex(char(methods(m))));
    end
    fprintf(fid, ' \\\\\n');

    fprintf(fid, ' ');
    for m = 1:numel(methods)
        fprintf(fid, ' & Feas. & Time');
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\hline\n');

    for s = 1:numel(sceneIds)
        fprintf(fid, 'Scene %d', sceneIds(s));
        for m = 1:numel(methods)
            fprintf(fid, ' & %.3f & %.3f', feasRatioMat(s,m), avgTimeMat(s,m));
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
    fprintf(fid, '\\begin{table}[t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{Average rank of ablation variants across UAV scenes. Lower is better.}\n');
    fprintf(fid, '\\begin{tabular}{cc}\n');
    fprintf(fid, '\\hline\n');
    fprintf(fid, 'Method & Average Rank \\\\\n');
    fprintf(fid, '\\hline\n');

    for i = 1:height(avgRankTable)
        methodName = char(avgRankTable.Method(i));
        val = avgRankTable.AverageRank(i);

        if i == 1
            fprintf(fid, '\\textbf{%s} & \\textbf{%.4f} \\\\\n', escapeLatex(methodName), val);
        else
            fprintf(fid, '%s & %.4f \\\\\n', escapeLatex(methodName), val);
        end
    end

    fprintf(fid, '\\hline\n');
    fprintf(fid, '\\end{tabular}\n');
    fprintf(fid, '\\end{table}\n\n');

    % --------------------------------------------------
    % Table 4: FAE-AE vs other ablations
    % --------------------------------------------------
    if ~isempty(wtlTable)
        fprintf(fid, '\\begin{table}[t]\n');
        fprintf(fid, '\\centering\n');
        fprintf(fid, '\\caption{Win/Tie/Loss statistics of FAE-AE against other ablation variants based on scene-wise mean values.}\n');
        fprintf(fid, '\\begin{tabular}{cccc}\n');
        fprintf(fid, '\\hline\n');
        fprintf(fid, 'Baseline & Win & Tie & Loss \\\\\n');
        fprintf(fid, '\\hline\n');

        for i = 1:height(wtlTable)
            fprintf(fid, '%s & %d & %d & %d \\\\\n', ...
                escapeLatex(char(wtlTable.Baseline(i))), ...
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
    s = strrep(s, '+', '{+}');
end