function result = run_cec2017_ablation_single(methodName, funcId, cfg, runId)
%RUN_CEC2017_ABLATION_SINGLE Run one CEC2017 ablation job.
%
% Standardized output fields:
%   result.bestFitness
%   result.bestPosition
%   result.convergence
%   result.runtime
%   result.nFEs
%   result.funcId
%   result.algName
%   result.runId
%   result.seed

    dim = cfg.dim;
    lb = cfg.lb;
    ub = cfg.ub;

    runSeed = cfg.baseSeed + 1000 * funcId + runId;
    rng(runSeed, 'twister');

    oldDir = pwd;
    cecDir = fullfile(fileparts(mfilename('fullpath')), 'third_party', 'cec2017');
    cleanupObj = onCleanup(@() cd(oldDir)); %#ok<NASGU>
    cd(cecDir);

    funHandle = @(x) cec_wrapper(x, funcId);

    switch upper(strtrim(methodName))
        case 'BASE-AE'
            algCfg = getAlgorithmConfig('AE', dim, cfg.maxFEs);
            result = optimizer_AE_cec(funHandle, lb, ub, dim, algCfg, runSeed);

        case 'AE+INIT'
            algCfg = getAlgorithmConfig('FAEAE', dim, cfg.maxFEs);
            algCfg.useStructuredInit = true;
            algCfg.useAOS = false;
            algCfg.useLocalRefine = false;
            algCfg.useRegen = false;
            result = optimizer_FAEAE_cec_ablation(funHandle, lb, ub, dim, algCfg, runSeed);

        case 'AE+INIT+AOS'
            algCfg = getAlgorithmConfig('FAEAE', dim, cfg.maxFEs);
            algCfg.useStructuredInit = true;
            algCfg.useAOS = true;
            algCfg.useLocalRefine = false;
            algCfg.useRegen = false;
            result = optimizer_FAEAE_cec_ablation(funHandle, lb, ub, dim, algCfg, runSeed);

        case 'AE+INIT+AOS+REPAIR'
            algCfg = getAlgorithmConfig('FAEAE', dim, cfg.maxFEs);
            algCfg.useStructuredInit = true;
            algCfg.useAOS = true;
            algCfg.useLocalRefine = true;
            algCfg.useRegen = false;
            result = optimizer_FAEAE_cec_ablation(funHandle, lb, ub, dim, algCfg, runSeed);

        case 'FAE-AE'
            algCfg = getAlgorithmConfig('FAEAE', dim, cfg.maxFEs);
            algCfg.useStructuredInit = true;
            algCfg.useAOS = true;
            algCfg.useLocalRefine = true;
            algCfg.useRegen = true;
            result = optimizer_FAEAE_cec_ablation(funHandle, lb, ub, dim, algCfg, runSeed);

        otherwise
            error('Unknown ablation method: %s', methodName);
    end

    result = localNormalizeResult(result, methodName, funcId, runId, runSeed);
end

%% ========================================================================
function result = localNormalizeResult(result, methodName, funcId, runId, runSeed)

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

    result.funcId = funcId;
    result.algName = methodName;
    result.runId = runId;
    result.seed = runSeed;
end