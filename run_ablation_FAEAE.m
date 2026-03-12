function ablationResult = run_ablation_FAEAE(sceneId)
%RUN_ABLATION_FAEAE Run main ablation groups for a given scene.
%
% Usage:
%   run_ablation_FAEAE
%   run_ablation_FAEAE(1)
%   run_ablation_FAEAE(2)

if nargin < 1
    sceneId = 1;
end

clc;
cfgs = getAblationConfigs(sceneId);
nGroups = numel(cfgs);

allBatchResults = struct([]);

fprintf('====================================\n');
fprintf('FAE-AE Ablation Experiment Started\n');
fprintf('Scene ID : %d\n', sceneId);
fprintf('Groups   : %d\n', nGroups);
fprintf('====================================\n');

for k = 1:nGroups
    expCfg = cfgs(k);

    if expCfg.saveResults || expCfg.saveFigures
        if ~exist(expCfg.outputDir, 'dir')
            mkdir(expCfg.outputDir);
        end
    end

    fprintf('\n====================================\n');
    fprintf('Ablation Group %d / %d : %s\n', k, nGroups, expCfg.algorithmName);
    fprintf('====================================\n');

    % Run first trial to initialize struct array
    firstResult = run_single_FAEAE_case(expCfg, 1);
    results = repmat(firstResult, expCfg.nRuns, 1);
    results(1) = firstResult;

    fprintf('Run %d/%d | BestFit = %.6f | Feasible = %d | Time = %.4f s\n', ...
        1, expCfg.nRuns, firstResult.bestFit, firstResult.finalFeasible, firstResult.runTime);

    for runId = 2:expCfg.nRuns
        results(runId) = run_single_FAEAE_case(expCfg, runId);
        fprintf('Run %d/%d | BestFit = %.6f | Feasible = %d | Time = %.4f s\n', ...
            runId, expCfg.nRuns, results(runId).bestFit, results(runId).finalFeasible, results(runId).runTime);
    end

    summary = summarizeBatchResults(results);

    fprintf('Summary | Best = %.6f | Mean = %.6f | Std = %.6f | FeasRatio = %.4f\n', ...
        summary.best, summary.mean, summary.std, summary.feasibleRatio);

    allBatchResults(k).expCfg = expCfg;
    allBatchResults(k).results = results;
    allBatchResults(k).summary = summary;

    save(fullfile(expCfg.outputDir, 'ablation_batch_results.mat'), 'results', 'summary', 'expCfg');

    % ---------- Resource cleanup for MATLAB R2022b stability ----------
    close all force;
    drawnow;
    java.lang.System.gc();
    pause(0.5);
end

summaryTable = summarizeAblationResults(allBatchResults);

disp(' ');
disp('Ablation Summary Table:');
disp(summaryTable);

ablationResult.sceneId = sceneId;
ablationResult.allBatchResults = allBatchResults;
ablationResult.summaryTable = summaryTable;

save(sprintf('ablation_scene%d_summary.mat', sceneId), 'ablationResult');
writecell(summaryTable, sprintf('ablation_scene%d_summary.csv', sceneId));
end