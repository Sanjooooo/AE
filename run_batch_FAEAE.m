function batchResult = run_batch_FAEAE(sceneId)
%RUN_BATCH_FAEAE Batch experiment entry for FAE-AE.
%
% Usage:
%   run_batch_FAEAE
%   run_batch_FAEAE(1)
%   run_batch_FAEAE(2)
%   run_batch_FAEAE(3)

clc;

if nargin < 1
    sceneId = 1;
end

expCfg = getDefaultExperimentConfig();
expCfg.sceneId = sceneId;
expCfg.outputDir = sprintf('results_scene%d_faeae', sceneId);

if expCfg.saveResults || expCfg.saveFigures
    if ~exist(expCfg.outputDir, 'dir')
        mkdir(expCfg.outputDir);
    end
end

fprintf('==============================\n');
fprintf('Batch experiment started\n');
fprintf('Algorithm : %s\n', expCfg.algorithmName);
fprintf('Scene ID  : %d\n', expCfg.sceneId);
fprintf('Runs      : %d\n', expCfg.nRuns);
fprintf('OutputDir : %s\n', expCfg.outputDir);
fprintf('==============================\n');

% ---------- Run 1 first to initialize the struct array correctly ----------
fprintf('\n--- Run %d / %d ---\n', 1, expCfg.nRuns);
firstResult = run_single_FAEAE_case(expCfg, 1);

fprintf('BestFit = %.6f | Feasible = %d | Time = %.4f s\n', ...
    firstResult.bestFit, firstResult.finalFeasible, firstResult.runTime);

results = repmat(firstResult, expCfg.nRuns, 1);
results(1) = firstResult;

% ---------- Remaining runs ----------
for runId = 2:expCfg.nRuns
    fprintf('\n--- Run %d / %d ---\n', runId, expCfg.nRuns);
    results(runId) = run_single_FAEAE_case(expCfg, runId);

    fprintf('BestFit = %.6f | Feasible = %d | Time = %.4f s\n', ...
        results(runId).bestFit, results(runId).finalFeasible, results(runId).runTime);
end

summary = summarizeBatchResults(results);

fprintf('\n==============================\n');
fprintf('Batch summary\n');
fprintf('Best   = %.6f\n', summary.best);
fprintf('Mean   = %.6f\n', summary.mean);
fprintf('Std    = %.6f\n', summary.std);
fprintf('Worst  = %.6f\n', summary.worst);
fprintf('Median = %.6f\n', summary.median);
fprintf('FeasRatio = %.4f\n', summary.feasibleRatio);
fprintf('AvgTime   = %.4f s\n', summary.avgTime);
fprintf('==============================\n');

batchResult.expCfg = expCfg;
batchResult.results = results;
batchResult.summary = summary;

% ---------- Mean convergence figure ----------
if expCfg.showBatchFigure
    plotBatchConvergence(results, expCfg);
end

% ---------- Save best-run path figures ----------
if expCfg.saveFigures && expCfg.saveBestPathFigure
    bestVals = [results.bestFit];
    [~, bestRunIdx] = min(bestVals);

    params = defaultParams();
    params.sceneId = expCfg.sceneId;
    map = createMap(params);

    bestPath = results(bestRunIdx).bestPath;
    bestCtrl = results(bestRunIdx).bestCtrl;

    % 3D view
    fig1 = figure('Color', 'w');
    plotSceneAndPath(map, bestPath, bestCtrl, params);
    title(sprintf('%s Best Path (Scene %d, Run %d)', ...
        expCfg.algorithmName, expCfg.sceneId, bestRunIdx));
    saveas(fig1, fullfile(expCfg.outputDir, 'best_path_3d.png'));
    close(fig1);

    % Top view
    if expCfg.saveBestTopViewFigure
        fig2 = figure('Color', 'w');
        plotSceneAndPath(map, bestPath, bestCtrl, params);
        view(2);
        axis equal;
        title(sprintf('%s Best Path Top View (Scene %d, Run %d)', ...
            expCfg.algorithmName, expCfg.sceneId, bestRunIdx));
        saveas(fig2, fullfile(expCfg.outputDir, 'best_path_topview.png'));
        close(fig2);
    end
end

% ---------- Save results ----------
if expCfg.saveResults
    save(fullfile(expCfg.outputDir, 'batch_results.mat'), 'batchResult');
    writematrix(summary.tableData, fullfile(expCfg.outputDir, 'summary_metrics.csv'));
end
end