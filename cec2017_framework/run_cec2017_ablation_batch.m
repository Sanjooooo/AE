function run_cec2017_ablation_batch(cfg)
%RUN_CEC2017_ABLATION_BATCH Batch experiment for CEC2017 ablation study.
%
% Output files:
%   cec_ablation_batch_results.mat
%   cec_ablation_error_log.mat
%   cec_ablation_batch_log.txt
%
% Usage:
%   run_cec2017_ablation_batch
%   run_cec2017_ablation_batch(cfg)

    if nargin < 1 || isempty(cfg)
        cfg = getCEC2017AblationConfig();
    end

    validateCECConfig(cfg);

    if ~exist(cfg.resultDir, 'dir')
        mkdir(cfg.resultDir);
    end

    dataFile = fullfile(cfg.resultDir, 'cec_ablation_batch_results.mat');
    logFile  = fullfile(cfg.resultDir, 'cec_ablation_batch_log.txt');
    errFile  = fullfile(cfg.resultDir, 'cec_ablation_error_log.mat');

    if exist(dataFile, 'file')
        S = load(dataFile);
        if isfield(S, 'allResults')
            allResults = S.allResults;
        else
            allResults = cell(numel(cfg.funcIds), numel(cfg.methods));
        end

        if isfield(S, 'runStatus')
            runStatus = S.runStatus;
        else
            runStatus = initRunStatus(cfg);
        end

        if isfield(S, 'errorLog')
            errorLog = S.errorLog;
        else
            errorLog = struct('funcId', {}, 'methodName', {}, 'runId', {}, ...
                'message', {}, 'identifier', {}, 'stack', {}, 'time', {});
        end

        appendLog(logFile, sprintf('Resuming existing batch: %s', dataFile));
    else
        allResults = cell(numel(cfg.funcIds), numel(cfg.methods));
        runStatus = initRunStatus(cfg);
        errorLog = struct('funcId', {}, 'methodName', {}, 'runId', {}, ...
            'message', {}, 'identifier', {}, 'stack', {}, 'time', {});
        appendLog(logFile, sprintf('Starting new batch: %s', dataFile));
        save(dataFile, 'allResults', 'runStatus', 'errorLog', 'cfg', '-v7.3');
    end

    nFuncs = numel(cfg.funcIds);
    nMethods = numel(cfg.methods);
    nRuns = cfg.nRuns;

    totalJobs = nFuncs * nMethods * nRuns;
    completedJobs = nnz(strcmp(runStatus, 'done'));
    failedJobs = nnz(strcmp(runStatus, 'failed'));

    fprintf('\n============================================================\n');
    fprintf('CEC2017 Ablation Batch Experiment\n');
    fprintf('Result folder : %s\n', cfg.resultDir);
    fprintf('Functions     : %d\n', nFuncs);
    fprintf('Methods       : %d\n', nMethods);
    fprintf('Runs          : %d\n', nRuns);
    fprintf('Total jobs    : %d\n', totalJobs);
    fprintf('Done / Failed : %d / %d\n', completedJobs, failedJobs);
    fprintf('============================================================\n\n');

    tBatch = tic;

    for f = 1:nFuncs
        funcId = cfg.funcIds(f);

        for a = 1:nMethods
            methodName = cfg.methods{a};

            fprintf('\n------------------------------------------------------------\n');
            fprintf('Function F%d | Method %s | (%d/%d funcs, %d/%d methods)\n', ...
                funcId, methodName, f, nFuncs, a, nMethods);
            fprintf('------------------------------------------------------------\n');

            appendLog(logFile, sprintf('Entering block: F%d | %s', funcId, methodName));

            if isempty(allResults{f, a})
                allResults{f, a} = [];
            end

            for r = 1:nRuns
                status = runStatus{f, a, r};
                if strcmp(status, 'done')
                    if cfg.verbose
                        fprintf(' [Skip] Run %d/%d already done.\n', r, nRuns);
                    end
                    continue;
                end

                fprintf(' [Run ] F%d | %-18s | run %2d/%2d ... ', ...
                    funcId, methodName, r, nRuns);
                tRun = tic;

                try
                    result = run_cec2017_ablation_single(methodName, funcId, cfg, r);

                    if isempty(allResults{f, a})
                        allResults{f, a} = repmat(result, 1, nRuns);
                    end
                    allResults{f, a}(r) = result;
                    runStatus{f, a, r} = 'done';

                    elapsedRun = toc(tRun);
                    fprintf('OK | best = %.6e | time = %.3fs\n', ...
                        result.bestFitness, elapsedRun);

                    if cfg.verbose
                        appendLog(logFile, sprintf( ...
                            'DONE: F%d | %s | run %d | best=%.6e | time=%.3fs', ...
                            funcId, methodName, r, result.bestFitness, elapsedRun));
                    end

                catch ME
                    elapsedRun = toc(tRun);
                    runStatus{f, a, r} = 'failed';

                    errEntry.funcId = funcId;
                    errEntry.methodName = methodName;
                    errEntry.runId = r;
                    errEntry.message = ME.message;
                    errEntry.identifier = ME.identifier;
                    errEntry.stack = ME.stack;
                    errEntry.time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
                    errorLog(end+1) = errEntry; %#ok<AGROW>

                    fprintf('FAILED | time = %.3fs\n', elapsedRun);
                    fprintf(' %s\n', ME.message);

                    appendLog(logFile, sprintf( ...
                        'FAILED: F%d | %s | run %d | time=%.3fs | msg=%s', ...
                        funcId, methodName, r, elapsedRun, ME.message));
                end

                save(dataFile, 'allResults', 'runStatus', 'errorLog', 'cfg', '-v7.3');
                save(errFile, 'errorLog', '-v7.3');
            end

            blockDone = sum(strcmp(runStatus(f, a, :), 'done'));
            blockFail = sum(strcmp(runStatus(f, a, :), 'failed'));

            fprintf(' Block summary: done = %d, failed = %d, total = %d\n', ...
                blockDone, blockFail, nRuns);

            appendLog(logFile, sprintf( ...
                'Block finished: F%d | %s | done=%d | failed=%d', ...
                funcId, methodName, blockDone, blockFail));
        end
    end

    totalDone = nnz(strcmp(runStatus, 'done'));
    totalFail = nnz(strcmp(runStatus, 'failed'));
    totalTodo = totalJobs - totalDone - totalFail;
    elapsedBatch = toc(tBatch);

    fprintf('\n============================================================\n');
    fprintf('Ablation batch finished.\n');
    fprintf('Done    : %d\n', totalDone);
    fprintf('Failed  : %d\n', totalFail);
    fprintf('Pending : %d\n', totalTodo);
    fprintf('Elapsed : %.2f s (%.2f min)\n', elapsedBatch, elapsedBatch/60);
    fprintf('Saved to: %s\n', dataFile);
    fprintf('============================================================\n');

    appendLog(logFile, sprintf( ...
        'Batch finished | done=%d | failed=%d | pending=%d | elapsed=%.2fs', ...
        totalDone, totalFail, totalTodo, elapsedBatch));
end

%% ========================================================================
function validateCECConfig(cfg)
    requiredFields = {'dim','nRuns','funcIds','maxFEs','lb','ub','methods','resultDir','baseSeed','verbose'};
    for i = 1:numel(requiredFields)
        if ~isfield(cfg, requiredFields{i})
            error('Config missing required field: %s', requiredFields{i});
        end
    end
end

%% ========================================================================
function runStatus = initRunStatus(cfg)
    nFuncs = numel(cfg.funcIds);
    nMethods = numel(cfg.methods);
    nRuns = cfg.nRuns;

    runStatus = cell(nFuncs, nMethods, nRuns);
    for f = 1:nFuncs
        for a = 1:nMethods
            for r = 1:nRuns
                runStatus{f, a, r} = 'pending';
            end
        end
    end
end

%% ========================================================================
function appendLog(logFile, msg)
    fid = fopen(logFile, 'a');
    if fid < 0
        warning('Cannot open log file: %s', logFile);
        return;
    end
    fprintf(fid, '[%s] %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), msg);
    fclose(fid);
end