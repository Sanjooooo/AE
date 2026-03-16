function run_cec2017_batch(cfg)
%RUN_CEC2017_BATCH Multi-algorithm batch experiment on CEC2017.
%
% Usage:
%   run_cec2017_batch
%   run_cec2017_batch(cfg)
%
% Features:
%   1) Auto-create result folder
%   2) Save progress after each algorithm-function block
%   3) Save progress after each run
%   4) Continue from existing partial results
%   5) Per-run try/catch, single failure will not kill entire batch
%   6) Save error logs for failed runs
%
% Expected result fields from each optimizer:
%   result.bestFitness
%   result.bestPosition
%   result.convergence
%   result.runtime
%   result.nFEs
%   result.funcId
%   result.algName
%   result.runId
%   result.seed

    if nargin < 1 || isempty(cfg)
        cfg = getCEC2017Config();
    end

    % ---------- Basic checks ----------
    validateCECConfig(cfg);

    if ~exist(cfg.resultDir, 'dir')
        mkdir(cfg.resultDir);
    end

    dataFile = fullfile(cfg.resultDir, 'cec2017_batch_results.mat');
    logFile  = fullfile(cfg.resultDir, 'cec2017_batch_log.txt');
    errFile  = fullfile(cfg.resultDir, 'cec2017_error_log.mat');

    % ---------- Initialize or resume ----------
    if exist(dataFile, 'file')
        S = load(dataFile);

        if isfield(S, 'allResults')
            allResults = S.allResults;
        else
            allResults = cell(numel(cfg.funcIds), numel(cfg.algorithms));
        end

        if isfield(S, 'runStatus')
            runStatus = S.runStatus;
        else
            runStatus = initRunStatus(cfg);
        end

        if isfield(S, 'errorLog')
            errorLog = S.errorLog;
        else
            errorLog = struct('funcId', {}, 'algName', {}, 'runId', {}, ...
                              'message', {}, 'identifier', {}, 'stack', {}, ...
                              'time', {});
        end

        if isfield(S, 'cfg')
            oldCfg = S.cfg;
            checkConfigCompatibility(oldCfg, cfg);
        end

        appendLog(logFile, sprintf('Resuming existing batch: %s', dataFile));
    else
        allResults = cell(numel(cfg.funcIds), numel(cfg.algorithms));
        runStatus = initRunStatus(cfg);
        errorLog = struct('funcId', {}, 'algName', {}, 'runId', {}, ...
                          'message', {}, 'identifier', {}, 'stack', {}, ...
                          'time', {});
        appendLog(logFile, sprintf('Starting new batch: %s', dataFile));

        save(dataFile, 'allResults', 'runStatus', 'errorLog', 'cfg', '-v7.3');
    end

    % ---------- Summary header ----------
    nFuncs = numel(cfg.funcIds);
    nAlgs  = numel(cfg.algorithms);
    nRuns  = cfg.nRuns;
    totalJobs = nFuncs * nAlgs * nRuns;

    completedJobs = nnz(strcmp(runStatus, 'done'));
    failedJobs = nnz(strcmp(runStatus, 'failed'));

    fprintf('\n============================================================\n');
    fprintf('CEC2017 Batch Experiment\n');
    fprintf('Result folder : %s\n', cfg.resultDir);
    fprintf('Functions     : %d\n', nFuncs);
    fprintf('Algorithms    : %d\n', nAlgs);
    fprintf('Runs          : %d\n', nRuns);
    fprintf('Total jobs    : %d\n', totalJobs);
    fprintf('Done / Failed : %d / %d\n', completedJobs, failedJobs);
    fprintf('============================================================\n\n');

    tBatch = tic;

    % ---------- Main loops ----------
    for f = 1:nFuncs
        funcId = cfg.funcIds(f);

        for a = 1:nAlgs
            algName = cfg.algorithms{a};

            fprintf('\n------------------------------------------------------------\n');
            fprintf('Function F%d | Algorithm %s | (%d/%d funcs, %d/%d algs)\n', ...
                funcId, algName, f, nFuncs, a, nAlgs);
            fprintf('------------------------------------------------------------\n');

            appendLog(logFile, sprintf('Entering block: F%d | %s', funcId, algName));

            % Ensure storage is allocated as struct array when first successful run appears
            if isempty(allResults{f, a})
                allResults{f, a} = [];
            end

            for r = 1:nRuns
                status = runStatus{f, a, r};

                if strcmp(status, 'done')
                    if cfg.verbose
                        fprintf('  [Skip] Run %d/%d already done.\n', r, nRuns);
                    end
                    continue;
                end

                fprintf('  [Run ] F%d | %-6s | run %2d/%2d ... ', funcId, algName, r, nRuns);
                tRun = tic;

                try
                    result = run_cec2017_single(algName, funcId, cfg, r);
                    result = normalizeCECResult(result, algName, funcId, r);

                    % First-success allocation pattern to avoid struct assignment mismatch
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
                            funcId, algName, r, result.bestFitness, elapsedRun));
                    end

                catch ME
                    elapsedRun = toc(tRun);
                    runStatus{f, a, r} = 'failed';

                    errEntry.funcId = funcId;
                    errEntry.algName = algName;
                    errEntry.runId = r;
                    errEntry.message = ME.message;
                    errEntry.identifier = ME.identifier;
                    errEntry.stack = ME.stack;
                    errEntry.time = datestr(now, 'yyyy-mm-dd HH:MM:SS');

                    errorLog(end+1) = errEntry; %#ok<AGROW>

                    fprintf('FAILED | time = %.3fs\n', elapsedRun);
                    fprintf('         %s\n', ME.message);

                    appendLog(logFile, sprintf( ...
                        'FAILED: F%d | %s | run %d | time=%.3fs | msg=%s', ...
                        funcId, algName, r, elapsedRun, ME.message));
                end

                % Save after every run
                save(dataFile, 'allResults', 'runStatus', 'errorLog', 'cfg', '-v7.3');
                save(errFile, 'errorLog', '-v7.3');
            end

            % Block summary
            blockDone = sum(strcmp(runStatus(f, a, :), 'done'));
            blockFail = sum(strcmp(runStatus(f, a, :), 'failed'));
            fprintf('  Block summary: done = %d, failed = %d, total = %d\n', ...
                blockDone, blockFail, nRuns);

            appendLog(logFile, sprintf( ...
                'Block finished: F%d | %s | done=%d | failed=%d', ...
                funcId, algName, blockDone, blockFail));
        end
    end

    % ---------- Final summary ----------
    totalDone = nnz(strcmp(runStatus, 'done'));
    totalFail = nnz(strcmp(runStatus, 'failed'));
    totalTodo = totalJobs - totalDone - totalFail;

    elapsedBatch = toc(tBatch);

    fprintf('\n============================================================\n');
    fprintf('Batch finished.\n');
    fprintf('Done    : %d\n', totalDone);
    fprintf('Failed  : %d\n', totalFail);
    fprintf('Pending : %d\n', totalTodo);
    fprintf('Elapsed : %.2f s (%.2f min)\n', elapsedBatch, elapsedBatch / 60);
    fprintf('Saved to: %s\n', dataFile);
    fprintf('============================================================\n');

    appendLog(logFile, sprintf( ...
        'Batch finished | done=%d | failed=%d | pending=%d | elapsed=%.2fs', ...
        totalDone, totalFail, totalTodo, elapsedBatch));

end


% ========================= Helpers =========================

function validateCECConfig(cfg)
    requiredFields = {'dim','nRuns','funcIds','maxFEs','lb','ub','algorithms','resultDir','baseSeed','verbose'};
    for i = 1:numel(requiredFields)
        if ~isfield(cfg, requiredFields{i})
            error('Config missing required field: %s', requiredFields{i});
        end
    end

    if ~isscalar(cfg.dim) || cfg.dim <= 0
        error('cfg.dim must be a positive scalar.');
    end
    if ~isscalar(cfg.nRuns) || cfg.nRuns <= 0
        error('cfg.nRuns must be a positive scalar.');
    end
    if isempty(cfg.funcIds)
        error('cfg.funcIds cannot be empty.');
    end
    if isempty(cfg.algorithms)
        error('cfg.algorithms cannot be empty.');
    end
    if cfg.lb >= cfg.ub
        error('cfg.lb must be smaller than cfg.ub.');
    end
end

function runStatus = initRunStatus(cfg)
    nFuncs = numel(cfg.funcIds);
    nAlgs  = numel(cfg.algorithms);
    nRuns  = cfg.nRuns;

    runStatus = cell(nFuncs, nAlgs, nRuns);
    for f = 1:nFuncs
        for a = 1:nAlgs
            for r = 1:nRuns
                runStatus{f, a, r} = 'pending';
            end
        end
    end
end

function checkConfigCompatibility(oldCfg, newCfg)
    sameFuncs = isequal(oldCfg.funcIds, newCfg.funcIds);
    sameAlgs  = isequal(oldCfg.algorithms, newCfg.algorithms);
    sameRuns  = isequal(oldCfg.nRuns, newCfg.nRuns);
    sameDim   = isequal(oldCfg.dim, newCfg.dim);
    sameFEs   = isequal(oldCfg.maxFEs, newCfg.maxFEs);

    if ~(sameFuncs && sameAlgs && sameRuns && sameDim && sameFEs)
        warning(['Existing result file was created with a different config.\n' ...
                 'Resume may be unsafe. Consider using a new resultDir.']);
    end
end

function result = normalizeCECResult(result, algName, funcId, runId)
    % Fill missing standard fields when possible
    if ~isfield(result, 'bestFitness')
        if isfield(result, 'bestCost')
            result.bestFitness = result.bestCost;
        else
            error('Result missing field: bestFitness');
        end
    end

    if ~isfield(result, 'bestPosition')
        if isfield(result, 'bestSol')
            result.bestPosition = result.bestSol(:);
        elseif isfield(result, 'bestX')
            result.bestPosition = result.bestX(:);
        else
            error('Result missing field: bestPosition');
        end
    end

    if ~isfield(result, 'convergence')
        if isfield(result, 'curve')
            result.convergence = result.curve(:);
        else
            result.convergence = [];
        end
    end

    if ~isfield(result, 'runtime')
        if isfield(result, 'time')
            result.runtime = result.time;
        else
            result.runtime = NaN;
        end
    end

    if ~isfield(result, 'nFEs')
        if isfield(result, 'FEs')
            result.nFEs = result.FEs;
        else
            result.nFEs = NaN;
        end
    end

    result.algName = algName;
    result.funcId = funcId;
    result.runId = runId;
end

function appendLog(logFile, msg)
    fid = fopen(logFile, 'a');
    if fid < 0
        warning('Cannot open log file: %s', logFile);
        return;
    end
    fprintf(fid, '[%s] %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), msg);
    fclose(fid);
end