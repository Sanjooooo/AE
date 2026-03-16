function result = run_cec2017_single(algName, funcId, cfg, runId)

dim = cfg.dim;
lb = cfg.lb;
ub = cfg.ub;

% Reproducible seed
runSeed = cfg.baseSeed + 1000 * funcId + runId;
rng(runSeed, 'twister');

% Algorithm config
algCfg = getAlgorithmConfig(algName, dim, cfg.maxFEs);

% Save current path
oldDir = pwd;

% Go to CEC folder only once per run
cecDir = fullfile(fileparts(mfilename('fullpath')), 'third_party', 'cec2017');
cleanupObj = onCleanup(@() cd(oldDir));
cd(cecDir);

% Objective handle
funHandle = @(x) cec_wrapper(x, funcId);

% Dispatch
switch upper(algName)
    case 'AE'
        result = optimizer_AE_cec(funHandle, lb, ub, dim, algCfg, runSeed);

    case 'WOA'
        result = optimizer_WOA_cec(funHandle, lb, ub, dim, algCfg, runSeed);
        
    case 'PSO'
        result = optimizer_PSO_cec(funHandle, lb, ub, dim, algCfg, runSeed);

    case 'GWO'
        result = optimizer_GWO_cec(funHandle, lb, ub, dim, algCfg, runSeed);

    case 'HHO'
        result = optimizer_HHO_cec(funHandle, lb, ub, dim, algCfg, runSeed);

    case 'FAEAE'
        result = optimizer_FAEAE_cec(funHandle, lb, ub, dim, algCfg, runSeed);

    otherwise
        error('Unknown algorithm: %s', algName);
end

% Add metadata
result.funcId = funcId;
result.algName = algName;
result.runId = runId;
result.seed = runSeed;

end