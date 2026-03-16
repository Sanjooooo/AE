function run_uav_comparison_batch(cfg)
%RUN_UAV_COMPARISON_BATCH Robust multi-algorithm UAV comparison batch runner.
%
% Features:
%   1) Resume existing batch
%   2) Corrupted MAT auto-recovery
%   3) Atomic save
%   4) Per-run record files
%   5) Lightweight master results to reduce crash risk
%
% Usage:
%   run_uav_comparison_batch
%   run_uav_comparison_batch(cfg)

    if nargin < 1 || isempty(cfg)
        cfg = getUAVComparisonConfig('formal');
    end

    validateUAVComparisonConfig(cfg);

    if ~exist(cfg.resultDir, 'dir')
        mkdir(cfg.resultDir);
    end

    dataFile = fullfile(cfg.resultDir, 'uav_comparison_results.mat');
    logFile  = fullfile(cfg.resultDir, 'uav_comparison_log.txt');
    errFile  = fullfile(cfg.resultDir, 'uav_comparison_error_log.mat');
    runDir   = fullfile(cfg.resultDir, 'run_records');

    if ~exist(runDir, 'dir')
        mkdir(runDir);
    end

    nScenes = numel(cfg.sceneIds);
    nAlgs   = numel(cfg.algorithms);
    nRuns   = cfg.nRuns;

    % ------------------------------------------------------------
    % Init / resume
    % ------------------------------------------------------------
    if exist(dataFile, 'file') && cfg.resumeExisting
        try
            S = load(dataFile);

            if isfield(S, 'allResults')
                allResults = S.allResults;
            else
                allResults = cell(nScenes, nAlgs);
            end

            if isfield(S, 'runStatus')
                runStatus = S.runStatus;
            else
                runStatus = initRunStatus(nScenes, nAlgs, nRuns);
            end

            if isfield(S, 'errorLog')
                errorLog = S.errorLog;
            else
                errorLog = struct('sceneId', {}, 'algName', {}, 'runId', {}, ...
                                  'message', {}, 'identifier', {}, 'stack', {}, 'time', {});
            end

            appendLog(logFile, sprintf('Resuming batch: %s', dataFile));

        catch
            corruptedName = fullfile(cfg.resultDir, ...
                ['uav_comparison_results_corrupted_' datestr(now,'yyyymmdd_HHMMSS') '.mat']);
            movefile(dataFile, corruptedName);

            warning('Existing MAT file is corrupted. Renamed to:\n%s', corruptedName);

            allResults = cell(nScenes, nAlgs);
            runStatus = initRunStatus(nScenes, nAlgs, nRuns);
            errorLog = struct('sceneId', {}, 'algName', {}, 'runId', {}, ...
                              'message', {}, 'identifier', {}, 'stack', {}, 'time', {});

            atomicSave(dataFile, allResults, runStatus, errorLog, cfg);
            appendLog(logFile, sprintf('Corrupted batch file detected. Renamed to: %s', corruptedName));
        end
    else
        allResults = cell(nScenes, nAlgs);
        runStatus = initRunStatus(nScenes, nAlgs, nRuns);
        errorLog = struct('sceneId', {}, 'algName', {}, 'runId', {}, ...
                          'message', {}, 'identifier', {}, 'stack', {}, 'time', {});

        atomicSave(dataFile, allResults, runStatus, errorLog, cfg);
        appendLog(logFile, sprintf('Starting new batch: %s', dataFile));
    end

    totalJobs = nScenes * nAlgs * nRuns;
    totalDone = nnz(strcmp(runStatus, 'done'));
    totalFail = nnz(strcmp(runStatus, 'failed'));

    fprintf('\n============================================================\n');
    fprintf('UAV Multi-Algorithm Comparison\n');
    fprintf('Result folder : %s\n', cfg.resultDir);
    fprintf('Scenes        : %d\n', nScenes);
    fprintf('Algorithms    : %d\n', nAlgs);
    fprintf('Runs          : %d\n', nRuns);
    fprintf('Total jobs    : %d\n', totalJobs);
    fprintf('Done / Failed : %d / %d\n', totalDone, totalFail);
    fprintf('============================================================\n\n');

    tBatch = tic;

    % ------------------------------------------------------------
    % Main loops
    % ------------------------------------------------------------
    for s = 1:nScenes
        sceneId = cfg.sceneIds(s);

        for a = 1:nAlgs
            algName = cfg.algorithms{a};

            fprintf('\n------------------------------------------------------------\n');
            fprintf('Scene %d | Algorithm %s\n', sceneId, algName);
            fprintf('------------------------------------------------------------\n');

            appendLog(logFile, sprintf('Entering block: Scene %d | %s', sceneId, algName));

            if isempty(allResults{s, a})
                allResults{s, a} = [];
            end

            for r = 1:nRuns
                status = runStatus{s, a, r};

                if strcmp(status, 'done')
                    if cfg.verbose
                        fprintf('  [Skip] Run %d/%d already done.\n', r, nRuns);
                    end
                    continue;
                end

                runFile = fullfile(runDir, sprintf('scene%d_%s_run%03d.mat', sceneId, upper(algName), r));

                % If per-run file already exists and status is not done,
                % try to recover from it.
                if exist(runFile, 'file') && ~strcmp(status, 'done')
                    try
                        R = load(runFile);
                        if isfield(R, 'result')
                            result = R.result;
                            result = normalizeUAVResult(result, algName, sceneId, r);

                            if isempty(allResults{s, a})
                                allResults{s, a} = repmat(makeLightweightResult(result), 1, nRuns);
                            end
                            allResults{s, a}(r) = makeLightweightResult(result);
                            runStatus{s, a, r} = 'done';

                            fprintf('  [Load] Scene %d | %-6s | run %2d/%2d recovered from run file.\n', ...
                                sceneId, algName, r, nRuns);

                            atomicSave(dataFile, allResults, runStatus, errorLog, cfg);
                            continue;
                        end
                    catch
                        % ignore bad run file and recompute
                    end
                end

                fprintf('  [Run ] Scene %d | %-6s | run %2d/%2d ... ', sceneId, algName, r, nRuns);
                tRun = tic;

                try
                    result = run_single_uav_algorithm_case(algName, sceneId, cfg, r);
                    result = normalizeUAVResult(result, algName, sceneId, r);

                    % Save full per-run record first
                    save(runFile, 'result', '-v7.3');

                    % Save lightweight result into master cell
                    if isempty(allResults{s, a})
                        allResults{s, a} = repmat(makeLightweightResult(result), 1, nRuns);
                    end
                    allResults{s, a}(r) = makeLightweightResult(result);

                    runStatus{s, a, r} = 'done';

                    elapsedRun = toc(tRun);
                    fprintf('OK | best = %.6f | time = %.3fs\n', result.bestFit, elapsedRun);

                    appendLog(logFile, sprintf( ...
                        'DONE: Scene %d | %s | run %d | best=%.6f | time=%.3fs', ...
                        sceneId, algName, r, result.bestFit, elapsedRun));

                catch ME
                    elapsedRun = toc(tRun);
                    runStatus{s, a, r} = 'failed';

                    errEntry.sceneId = sceneId;
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
                        'FAILED: Scene %d | %s | run %d | time=%.3fs | msg=%s', ...
                        sceneId, algName, r, elapsedRun, ME.message));
                end

                % Save after every run (atomic)
                atomicSave(dataFile, allResults, runStatus, errorLog, cfg);
                atomicSaveError(errFile, errorLog);
            end

            blockDone = sum(strcmp(runStatus(s, a, :), 'done'));
            blockFail = sum(strcmp(runStatus(s, a, :), 'failed'));
            fprintf('  Block summary: done = %d, failed = %d, total = %d\n', ...
                blockDone, blockFail, nRuns);

            appendLog(logFile, sprintf( ...
                'Block finished: Scene %d | %s | done=%d | failed=%d', ...
                sceneId, algName, blockDone, blockFail));
        end
    end

    elapsedBatch = toc(tBatch);
    totalDone = nnz(strcmp(runStatus, 'done'));
    totalFail = nnz(strcmp(runStatus, 'failed'));
    totalTodo = totalJobs - totalDone - totalFail;

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


% ========================================================================
function validateUAVComparisonConfig(cfg)
    requiredFields = {'sceneIds','algorithms','nRuns','baseSeed','resultDir','resumeExisting','verbose'};
    for i = 1:numel(requiredFields)
        if ~isfield(cfg, requiredFields{i})
            error('Missing cfg field: %s', requiredFields{i});
        end
    end

    if isempty(cfg.sceneIds)
        error('cfg.sceneIds cannot be empty.');
    end
    if isempty(cfg.algorithms)
        error('cfg.algorithms cannot be empty.');
    end
    if cfg.nRuns <= 0
        error('cfg.nRuns must be positive.');
    end
end

% ========================================================================
function runStatus = initRunStatus(nScenes, nAlgs, nRuns)
    runStatus = cell(nScenes, nAlgs, nRuns);
    for s = 1:nScenes
        for a = 1:nAlgs
            for r = 1:nRuns
                runStatus{s, a, r} = 'pending';
            end
        end
    end
end

% ========================================================================
function result = normalizeUAVResult(result, algName, sceneId, runId)

    if ~isfield(result, 'bestFit')
        if isfield(result, 'bestFitness')
            result.bestFit = result.bestFitness;
        else
            error('Result missing field: bestFit');
        end
    end

    if ~isfield(result, 'bestX')
        if isfield(result, 'bestPosition')
            result.bestX = result.bestPosition(:);
        else
            result.bestX = [];
        end
    end

    if ~isfield(result, 'bestHist')
        if isfield(result, 'convergence')
            result.bestHist = result.convergence(:);
        else
            result.bestHist = [];
        end
    end

    if ~isfield(result, 'runTime')
        if isfield(result, 'runtime')
            result.runTime = result.runtime;
        else
            result.runTime = NaN;
        end
    end

    if ~isfield(result, 'algorithmName')
        result.algorithmName = upper(algName);
    end

    if ~isfield(result, 'sceneId')
        result.sceneId = sceneId;
    end

    if ~isfield(result, 'runId')
        result.runId = runId;
    end

    if ~isfield(result, 'finalFeasible')
        result.finalFeasible = NaN;
    end

    if ~isfield(result, 'finalViolation')
        result.finalViolation = NaN;
    end
end

% ========================================================================
function lite = makeLightweightResult(result)
% Keep master MAT lighter. Large objects are kept in per-run files.

    lite = struct();

    lite.algorithmName = localGetField(result, {'algorithmName'}, '');
    lite.sceneId       = localGetField(result, {'sceneId'}, NaN);
    lite.runId         = localGetField(result, {'runId'}, NaN);
    lite.seed          = localGetField(result, {'seed'}, NaN);

    lite.bestFit       = localGetField(result, {'bestFit','bestFitness'}, NaN);
    lite.bestX         = localGetField(result, {'bestX','bestPosition'}, []);
    lite.bestHist      = localGetField(result, {'bestHist','convergence'}, []);
    lite.runTime       = localGetField(result, {'runTime','runtime'}, NaN);

    lite.bestDetail    = localGetField(result, {'bestDetail'}, struct());
    lite.finalFeasible = localGetField(result, {'finalFeasible'}, NaN);
    lite.finalViolation= localGetField(result, {'finalViolation'}, NaN);
    lite.nEvals        = localGetField(result, {'nEvals'}, NaN);

    % Do NOT keep bestPath / bestCtrl in master MAT to reduce size.
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
function atomicSave(dataFile, allResults, runStatus, errorLog, cfg)
    tmpFile = [dataFile '.tmp'];
    save(tmpFile, 'allResults', 'runStatus', 'errorLog', 'cfg', '-v7.3');

    if exist(dataFile, 'file')
        delete(dataFile);
    end
    movefile(tmpFile, dataFile);
end

% ========================================================================
function atomicSaveError(errFile, errorLog)
    tmpFile = [errFile '.tmp'];
    save(tmpFile, 'errorLog', '-v7.3');

    if exist(errFile, 'file')
        delete(errFile);
    end
    movefile(tmpFile, errFile);
end

% ========================================================================
function appendLog(logFile, msg)
    fid = fopen(logFile, 'a');
    if fid < 0
        warning('Cannot open log file: %s', logFile);
        return;
    end
    fprintf(fid, '[%s] %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), msg);
    fclose(fid);
end