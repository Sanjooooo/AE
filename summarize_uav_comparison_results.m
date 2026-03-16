function summary = summarize_uav_comparison_results(resultDir)
%SUMMARIZE_UAV_COMPARISON_RESULTS Summarize multi-algorithm UAV results.
%
% Usage:
%   summary = summarize_uav_comparison_results();
%   summary = summarize_uav_comparison_results(resultDir);
%
% Input:
%   resultDir - folder containing uav_comparison_results.mat
%
% Output files:
%   uav_comparison_summary_long.csv
%   uav_comparison_summary_wide.csv
%   uav_comparison_average_rank.csv
%   uav_comparison_faeae_wtl.csv
%   uav_comparison_summary_workspace.mat
%
% Returned struct:
%   summary.longTable
%   summary.wideTable
%   summary.avgRankTable
%   summary.wtlTable
%   summary.meanMat
%   summary.stdMat
%   summary.bestMat
%   summary.medianMat
%   summary.feasRatioMat
%   summary.avgRuntimeMat
%   summary.avgViolationMat
%   summary.rankMat
%   summary.avgRank

    if nargin < 1 || isempty(resultDir)
        resultDir = uigetdir(pwd, 'Select UAV comparison result folder');
        if isequal(resultDir, 0)
            error('No folder selected.');
        end
    end

    dataFile = fullfile(resultDir, 'uav_comparison_results.mat');
    if ~exist(dataFile, 'file')
        error('Cannot find file: %s', dataFile);
    end

    S = load(dataFile);
    allResults = S.allResults;
    cfg = S.cfg;

    sceneIds = cfg.sceneIds;
    algorithms = cfg.algorithms;

    nScenes = numel(sceneIds);
    nAlgs = numel(algorithms);

    % ------------------------------------------------------------
    % Stat matrices
    % ------------------------------------------------------------
    meanMat         = nan(nScenes, nAlgs);
    stdMat          = nan(nScenes, nAlgs);
    bestMat         = nan(nScenes, nAlgs);
    medianMat       = nan(nScenes, nAlgs);
    feasRatioMat    = nan(nScenes, nAlgs);
    avgRuntimeMat   = nan(nScenes, nAlgs);
    avgViolationMat = nan(nScenes, nAlgs);

    % Optional detail components (only if available)
    avgLenMat    = nan(nScenes, nAlgs);
    avgEnergyMat = nan(nScenes, nAlgs);
    avgRiskMat   = nan(nScenes, nAlgs);
    avgSmoothMat = nan(nScenes, nAlgs);

    for s = 1:nScenes
        for a = 1:nAlgs
            runs = allResults{s, a};

            if isempty(runs)
                continue;
            end

            nRuns = numel(runs);

            bestVals   = nan(nRuns, 1);
            runTimes   = nan(nRuns, 1);
            feasVals   = nan(nRuns, 1);
            violVals   = nan(nRuns, 1);

            lenVals    = nan(nRuns, 1);
            energyVals = nan(nRuns, 1);
            riskVals   = nan(nRuns, 1);
            smoothVals = nan(nRuns, 1);

            for r = 1:nRuns
                rr = runs(r);

                bestVals(r) = localGetField(rr, {'bestFit','bestFitness','bestCost'}, NaN);
                runTimes(r) = localGetField(rr, {'runTime','runtime','time'}, NaN);
                feasVals(r) = localLogical(localGetField(rr, {'finalFeasible'}, NaN));
                violVals(r) = localGetField(rr, {'finalViolation'}, NaN);

                if isfield(rr, 'bestDetail') && isstruct(rr.bestDetail)
                    bd = rr.bestDetail;
                    lenVals(r)    = localGetField(bd, {'L','length','pathLength'}, NaN);
                    energyVals(r) = localGetField(bd, {'E','energy'}, NaN);
                    riskVals(r)   = localGetField(bd, {'R','risk'}, NaN);
                    smoothVals(r) = localGetField(bd, {'S','smooth','smoothness'}, NaN);

                    % Fallback: if finalFeasible/finalViolation missing but detail has them
                    if isnan(feasVals(r))
                        feasVals(r) = localLogical(localGetField(bd, {'isFeasible','feasible'}, NaN));
                    end
                    if isnan(violVals(r))
                        violVals(r) = localGetField(bd, {'V','violation'}, NaN);
                    end
                end
            end

            meanMat(s, a)         = mean(bestVals, 'omitnan');
            stdMat(s, a)          = std(bestVals, 'omitnan');
            bestMat(s, a)         = min(bestVals);
            medianMat(s, a)       = median(bestVals, 'omitnan');
            feasRatioMat(s, a)    = mean(feasVals, 'omitnan');
            avgRuntimeMat(s, a)   = mean(runTimes, 'omitnan');
            avgViolationMat(s, a) = mean(violVals, 'omitnan');

            avgLenMat(s, a)       = mean(lenVals, 'omitnan');
            avgEnergyMat(s, a)    = mean(energyVals, 'omitnan');
            avgRiskMat(s, a)      = mean(riskVals, 'omitnan');
            avgSmoothMat(s, a)    = mean(smoothVals, 'omitnan');
        end
    end

    % ------------------------------------------------------------
    % Scene-wise rank (lower mean is better)
    % ------------------------------------------------------------
    rankMat = nan(nScenes, nAlgs);
    for s = 1:nScenes
        [~, order] = sort(meanMat(s, :), 'ascend');
        rankMat(s, order) = 1:nAlgs;
    end
    avgRank = mean(rankMat, 1, 'omitnan');

    % ------------------------------------------------------------
    % Long table
    % ------------------------------------------------------------
    sceneCol = [];
    algCol = {};
    meanCol = [];
    stdCol = [];
    bestCol = [];
    medianCol = [];
    feasCol = [];
    runtimeCol = [];
    violationCol = [];
    lenCol = [];
    energyCol = [];
    riskCol = [];
    smoothCol = [];
    rankCol = [];

    for s = 1:nScenes
        for a = 1:nAlgs
            sceneCol(end+1, 1) = sceneIds(s); %#ok<AGROW>
            algCol{end+1, 1} = algorithms{a}; %#ok<AGROW>

            meanCol(end+1, 1)      = meanMat(s, a); %#ok<AGROW>
            stdCol(end+1, 1)       = stdMat(s, a); %#ok<AGROW>
            bestCol(end+1, 1)      = bestMat(s, a); %#ok<AGROW>
            medianCol(end+1, 1)    = medianMat(s, a); %#ok<AGROW>
            feasCol(end+1, 1)      = feasRatioMat(s, a); %#ok<AGROW>
            runtimeCol(end+1, 1)   = avgRuntimeMat(s, a); %#ok<AGROW>
            violationCol(end+1, 1) = avgViolationMat(s, a); %#ok<AGROW>
            lenCol(end+1, 1)       = avgLenMat(s, a); %#ok<AGROW>
            energyCol(end+1, 1)    = avgEnergyMat(s, a); %#ok<AGROW>
            riskCol(end+1, 1)      = avgRiskMat(s, a); %#ok<AGROW>
            smoothCol(end+1, 1)    = avgSmoothMat(s, a); %#ok<AGROW>
            rankCol(end+1, 1)      = rankMat(s, a); %#ok<AGROW>
        end
    end

    longTable = table(sceneCol, algCol, meanCol, stdCol, bestCol, medianCol, ...
        feasCol, runtimeCol, violationCol, lenCol, energyCol, riskCol, smoothCol, rankCol, ...
        'VariableNames', {'SceneId','Algorithm','Mean','Std','Best','Median', ...
        'FeasRatio','AvgRuntime','AvgViolation','AvgLength','AvgEnergy','AvgRisk','AvgSmoothness','Rank'});

    writetable(longTable, fullfile(resultDir, 'uav_comparison_summary_long.csv'));

    % ------------------------------------------------------------
    % Wide table
    % ------------------------------------------------------------
    wideTable = table(sceneIds(:), 'VariableNames', {'SceneId'});

    for a = 1:nAlgs
        alg = algorithms{a};

        wideTable.(sprintf('%s_Mean', alg))      = meanMat(:, a);
        wideTable.(sprintf('%s_Std', alg))       = stdMat(:, a);
        wideTable.(sprintf('%s_Best', alg))      = bestMat(:, a);
        wideTable.(sprintf('%s_Median', alg))    = medianMat(:, a);
        wideTable.(sprintf('%s_FeasRatio', alg)) = feasRatioMat(:, a);
        wideTable.(sprintf('%s_AvgTime', alg))   = avgRuntimeMat(:, a);
        wideTable.(sprintf('%s_AvgV', alg))      = avgViolationMat(:, a);
        wideTable.(sprintf('%s_Rank', alg))      = rankMat(:, a);
    end

    bestAlgByMean = strings(nScenes, 1);
    for s = 1:nScenes
        [~, idx] = min(meanMat(s, :));
        bestAlgByMean(s) = string(algorithms{idx});
    end
    wideTable.BestAlgByMean = bestAlgByMean;

    writetable(wideTable, fullfile(resultDir, 'uav_comparison_summary_wide.csv'));

    % ------------------------------------------------------------
    % Average rank table
    % ------------------------------------------------------------
    avgRankTable = table(algorithms(:), avgRank(:), ...
        'VariableNames', {'Algorithm','AverageRank'});
    avgRankTable = sortrows(avgRankTable, 'AverageRank', 'ascend');

    writetable(avgRankTable, fullfile(resultDir, 'uav_comparison_average_rank.csv'));

    % ------------------------------------------------------------
    % FAEAE vs baselines W/T/L by scene mean
    % ------------------------------------------------------------
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

            for s = 1:nScenes
                vF = meanMat(s, faeIdx);
                vB = meanMat(s, a);

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

        writetable(wtlTable, fullfile(resultDir, 'uav_comparison_faeae_wtl.csv'));
    end

    % ------------------------------------------------------------
    % Save workspace
    % ------------------------------------------------------------
    summary = struct();
    summary.longTable = longTable;
    summary.wideTable = wideTable;
    summary.avgRankTable = avgRankTable;
    summary.wtlTable = wtlTable;

    summary.meanMat = meanMat;
    summary.stdMat = stdMat;
    summary.bestMat = bestMat;
    summary.medianMat = medianMat;
    summary.feasRatioMat = feasRatioMat;
    summary.avgRuntimeMat = avgRuntimeMat;
    summary.avgViolationMat = avgViolationMat;

    summary.avgLenMat = avgLenMat;
    summary.avgEnergyMat = avgEnergyMat;
    summary.avgRiskMat = avgRiskMat;
    summary.avgSmoothMat = avgSmoothMat;

    summary.rankMat = rankMat;
    summary.avgRank = avgRank;

    save(fullfile(resultDir, 'uav_comparison_summary_workspace.mat'), 'summary');

    % ------------------------------------------------------------
    % Console output
    % ------------------------------------------------------------
    fprintf('\n=== UAV Comparison Summary ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Scenes: %d\n', nScenes);
    fprintf('Algorithms: %d\n\n', nAlgs);

    fprintf('Average Rank:\n');
    for i = 1:height(avgRankTable)
        fprintf('  %-10s : %.4f\n', avgRankTable.Algorithm{i}, avgRankTable.AverageRank(i));
    end

    if ~isempty(wtlTable)
        fprintf('\nFAEAE vs baselines (by scene mean):\n');
        for i = 1:height(wtlTable)
            fprintf('  vs %-8s : W/T/L = %d / %d / %d\n', ...
                wtlTable.Baseline{i}, wtlTable.Win(i), wtlTable.Tie(i), wtlTable.Loss(i));
        end
    end

    fprintf('\nExported files:\n');
    fprintf('  - uav_comparison_summary_long.csv\n');
    fprintf('  - uav_comparison_summary_wide.csv\n');
    fprintf('  - uav_comparison_average_rank.csv\n');
    fprintf('  - uav_comparison_faeae_wtl.csv\n');
    fprintf('  - uav_comparison_summary_workspace.mat\n');
end


% ========================================================================
function val = localGetField(s, names, defaultVal)
    val = defaultVal;
    for k = 1:numel(names)
        if isfield(s, names{k})
            val = s.(names{k});
            return;
        end
    end
end

% ========================================================================
function y = localLogical(x)
    if islogical(x)
        y = double(x);
    elseif isnumeric(x)
        y = double(x);
    else
        y = NaN;
    end
end