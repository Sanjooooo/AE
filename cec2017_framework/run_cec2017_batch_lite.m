function summary = run_cec2017_batch_lite(cfg)
%RUN_CEC2017_BATCH_LITE Simpler batch runner that swaps FAEAE -> lite CEC optimizer.
if nargin < 1 || isempty(cfg)
    cfg = getCEC2017Config('formal', 'high');
end

if ~exist(cfg.resultDir, 'dir')
    mkdir(cfg.resultDir);
end

nFuncs = numel(cfg.funcIds);
nAlgs  = numel(cfg.algorithms);
nRuns  = cfg.nRuns;
allResults = cell(nFuncs, nAlgs);

fprintf('\n============================================================\n');
fprintf('CEC2017 Lite Batch Experiment\n');
fprintf('Result folder : %s\n', cfg.resultDir);
fprintf('Functions     : %d\n', nFuncs);
fprintf('Algorithms    : %d\n', nAlgs);
fprintf('Runs          : %d\n', nRuns);
fprintf('============================================================\n\n');

for f = 1:nFuncs
    funcId = cfg.funcIds(f);
    for a = 1:nAlgs
        algName = cfg.algorithms{a};
        runs = repmat(struct('bestFitness',nan,'bestPosition',[],'convergence',[],'runtime',nan,'nFEs',nan), 1, nRuns);

        fprintf('F%d | %s\n', funcId, algName);
        for r = 1:nRuns
            runs(r) = run_cec2017_single_lite(algName, funcId, cfg, r);
            fprintf('  run %2d/%2d | best = %.6e | time = %.3fs\n', ...
                r, nRuns, runs(r).bestFitness, runs(r).runtime);
        end
        allResults{f, a} = runs;
        save(fullfile(cfg.resultDir, 'cec2017_batch_results.mat'), 'allResults', 'cfg', '-v7.3');
    end
end

summary = summarize_cec2017_results(cfg.resultDir);
end
