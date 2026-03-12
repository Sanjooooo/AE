function allResults = run_cec2017_batch()
%RUN_CEC2017_BATCH Batch test for CEC2017.

clc;
cfg = getCEC2017Config();

rootDir = fileparts(mfilename('fullpath'));
outputDir = fullfile(rootDir, cfg.outputDir);

if cfg.saveResults && ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

allResults = struct();

fprintf('==============================\n');
fprintf('CEC2017 Batch Started\n');
fprintf('Dim      : %d\n', cfg.dim);
fprintf('Runs     : %d\n', cfg.nRuns);
fprintf('Functions: %s\n', mat2str(cfg.funcIds));
fprintf('Algorithms: %s\n', strjoin(cfg.algorithms, ', '));
fprintf('OutputDir: %s\n', outputDir);
fprintf('==============================\n');

idx = 0;
for f = cfg.funcIds
    for a = 1:numel(cfg.algorithms)
        algName = cfg.algorithms{a};

        fprintf('\nFunction F%d | Algorithm %s\n', f, algName);

        % ---------- Run first trial to initialize struct array correctly ----------
        fprintf('  Run %d / %d\n', 1, cfg.nRuns);
        firstResult = run_cec2017_single(f, algName, 1, cfg);

        fprintf('  Summary of run 1 | bestFit = %.6e | FEs = %d | Time = %.4f s\n', ...
            firstResult.bestFit, firstResult.FEsUsed, firstResult.runTime);

        results = repmat(firstResult, cfg.nRuns, 1);
        results(1) = firstResult;

        % ---------- Remaining runs ----------
        for runId = 2:cfg.nRuns
            fprintf('  Run %d / %d\n', runId, cfg.nRuns);
            results(runId) = run_cec2017_single(f, algName, runId, cfg);

            fprintf('  Summary of run %d | bestFit = %.6e | FEs = %d | Time = %.4f s\n', ...
                runId, results(runId).bestFit, results(runId).FEsUsed, results(runId).runTime);
        end

        idx = idx + 1;
        allResults(idx).funcId = f;
        allResults(idx).algName = algName;
        allResults(idx).results = results;

        bestVals = [results.bestFit];
        allResults(idx).mean = mean(bestVals);
        allResults(idx).std = std(bestVals);
        allResults(idx).best = min(bestVals);
        allResults(idx).worst = max(bestVals);
        allResults(idx).median = median(bestVals);

        fprintf('  Overall Summary | mean = %.6e | std = %.6e | best = %.6e | worst = %.6e\n', ...
            allResults(idx).mean, allResults(idx).std, allResults(idx).best, allResults(idx).worst);
    end
end

if cfg.saveResults
    save(fullfile(outputDir, 'cec2017_batch_results.mat'), 'allResults', 'cfg');
end
end