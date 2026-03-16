function rerun_failed_cec2017_jobs(resultDir)

if nargin < 1 || isempty(resultDir)
    resultDir = uigetdir(pwd, 'Select CEC result folder');
    if isequal(resultDir, 0)
        error('No folder selected.');
    end
end

dataFile = fullfile(resultDir, 'cec2017_batch_results.mat');
if ~exist(dataFile, 'file')
    error('Cannot find %s', dataFile);
end

S = load(dataFile);
allResults = S.allResults;
runStatus = S.runStatus;
errorLog = S.errorLog;
cfg = S.cfg;

nFuncs = numel(cfg.funcIds);
nAlgs  = numel(cfg.algorithms);
nRuns  = cfg.nRuns;

fprintf('\nRe-running failed jobs in: %s\n', resultDir);

for f = 1:nFuncs
    funcId = cfg.funcIds(f);
    for a = 1:nAlgs
        algName = cfg.algorithms{a};
        for r = 1:nRuns
            if strcmp(runStatus{f, a, r}, 'failed')
                fprintf('Retry: F%d | %s | run %d ... ', funcId, algName, r);
                try
                    result = run_cec2017_single(algName, funcId, cfg, r);
                    result = normalizeCECResult_local(result, algName, funcId, r);

                    if isempty(allResults{f, a})
                        allResults{f, a} = repmat(result, 1, nRuns);
                    end
                    allResults{f, a}(r) = result;
                    runStatus{f, a, r} = 'done';

                    fprintf('OK\n');
                catch ME
                    fprintf('FAILED again: %s\n', ME.message);

                    errEntry.funcId = funcId;
                    errEntry.algName = algName;
                    errEntry.runId = r;
                    errEntry.message = ME.message;
                    errEntry.identifier = ME.identifier;
                    errEntry.stack = ME.stack;
                    errEntry.time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
                    errorLog(end+1) = errEntry; %#ok<AGROW>
                end

                save(dataFile, 'allResults', 'runStatus', 'errorLog', 'cfg', '-v7.3');
            end
        end
    end
end

fprintf('Retry finished.\n');

end

function result = normalizeCECResult_local(result, algName, funcId, runId)
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
        result.runtime = NaN;
    end
    if ~isfield(result, 'nFEs')
        result.nFEs = NaN;
    end

    result.algName = algName;
    result.funcId = funcId;
    result.runId = runId;
end