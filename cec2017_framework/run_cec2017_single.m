function result = run_cec2017_single(funcId, algName, runId, cfg)
%RUN_CEC2017_SINGLE Run one independent trial on one CEC2017 function.

rng(cfg.baseSeed + runId - 1);

dim = cfg.dim;
lb = -100 * ones(dim, 1);
ub =  100 * ones(dim, 1);

% ---------- Enter CEC folder once per run ----------
rootDir = fileparts(mfilename('fullpath'));
cecDir = fullfile(rootDir, 'third_party', 'cec2017');

oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir));
cd(cecDir);

funHandle = @(x) cec_wrapper(x, funcId);

switch upper(algName)
    case 'AE'
        result = optimizer_AE_cec(funHandle, lb, ub, dim, cfg.maxFEs, cfg.baseSeed + runId - 1);
    case 'FAEAE'
        result = optimizer_FAEAE_cec(funHandle, lb, ub, dim, cfg.maxFEs, cfg.baseSeed + runId - 1);
    otherwise
        error('Unknown algorithm: %s', algName);
end

result.funcId = funcId;
result.algName = algName;
result.runId = runId;
end