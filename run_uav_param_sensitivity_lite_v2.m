function summary = run_uav_param_sensitivity_lite_v2(cfg)
%RUN_UAV_PARAM_SENSITIVITY_LITE_V2
% Parameter sensitivity analysis for light_v2 FAEAE on UAV scenes.
%
% Recommended usage:
%   summary = run_uav_param_sensitivity_lite_v2();
%
% Output files:
%   - param_sensitivity_runs.csv
%   - param_sensitivity_summary_long.csv
%   - param_sensitivity_workspace.mat
%   - run_records/*.mat

    if nargin < 1 || isempty(cfg)
        cfg = localDefaultConfig();
    end

    if ~exist(cfg.resultDir, 'dir')
        mkdir(cfg.resultDir);
    end
    runDir = fullfile(cfg.resultDir, 'run_records');
    if ~exist(runDir, 'dir')
        mkdir(runDir);
    end

    specs = localBuildParamSpecs();

    fprintf('\n============================================================\n');
    fprintf('UAV Parameter Sensitivity (light_v2)\n');
    fprintf('Result folder : %s\n', cfg.resultDir);
    fprintf('Run folder    : %s\n', runDir);
    fprintf('Scenes        : %s\n', mat2str(cfg.sceneIds));
    fprintf('Runs/value    : %d\n', cfg.nRuns);
    fprintf('============================================================\n\n');

    runRows = table();
    allResults = cell(numel(specs), numel(cfg.sceneIds));

    for p = 1:numel(specs)
        spec = specs(p);
        fprintf('\n================ Parameter: %s ================\n', spec.key);

        for s = 1:numel(cfg.sceneIds)
            sceneId = cfg.sceneIds(s);
            paperScene = localPaperScene(sceneId);

            paramsBase = defaultParams();
            paramsBase.sceneId = sceneId;

            map = createMap(paramsBase);
            refCtrl = generateReferencePath(map, paramsBase);
            refX = encodeControlPoints(refCtrl);

            runsThisScene = cell(numel(spec.values), 1);

            fprintf('--- Code Scene %d (Paper Scene %d) ---\n', sceneId, paperScene);

            for v = 1:numel(spec.values)
                val = spec.values(v);
                fprintf('  %s = %.4g\n', spec.key, val);

                runs = struct([]);

                for r = 1:cfg.nRuns
                    params = paramsBase;
                    algCfg = getUAVAlgorithmConfig('FAEAE', params, struct());

                    [params, algCfg] = localApplyParamOverride(params, algCfg, spec, val);

                    objFun = @(x) fitnessFAEAE(x, map, params);

                    runSeed = cfg.baseSeed + 100000 * p + 10000 * sceneId + 100 * v + r;
                    tRun = tic;

                    try
                        result = optimizer_FAEAE_lite_v2_uav(objFun, params, map, refX, algCfg, runSeed);
                        wallClock = toc(tRun);

                        save(fullfile(runDir, ...
                            sprintf('param_%s_scene%d_val%g_run%03d.mat', ...
                            spec.key, sceneId, val, r)), 'result', 'spec', 'sceneId', 'paperScene', 'val', 'runSeed');

                        row = table( ...
                            {spec.key}, val, sceneId, paperScene, r, runSeed, ...
                            result.bestFitness, result.runtime, ...
                            logical(result.finalFeasible), result.finalViolation, ...
                            wallClock, ...
                            'VariableNames', { ...
                            'ParamKey','ParamValue','Scene','PaperScene','Run','Seed', ...
                            'BestFitness','Runtime','Feasible','Violation','WallClock'});

                        if isempty(runRows)
                            runRows = row;
                        else
                            runRows = [runRows; row]; %#ok<AGROW>
                        end

                        if isempty(runs)
                            runs = result;
                        else
                            runs(end+1) = result; %#ok<AGROW>
                        end

                        fprintf('    run %2d/%2d | best = %.6f | feas = %d | time = %.3fs\n', ...
                            r, cfg.nRuns, result.bestFitness, logical(result.finalFeasible), result.runtime);

                    catch ME
                        warning('Param %s=%.4g | scene %d | run %d failed: %s', ...
                            spec.key, val, sceneId, r, ME.message);
                    end
                end

                runsThisScene{v} = runs;
            end

            allResults{p, s} = runsThisScene;
        end
    end

    if isempty(runRows)
        error('No sensitivity results were produced.');
    end

    summaryLong = localBuildSummary(runRows, specs, cfg.sceneIds);

    writetable(runRows, fullfile(cfg.resultDir, 'param_sensitivity_runs.csv'));
    writetable(summaryLong, fullfile(cfg.resultDir, 'param_sensitivity_summary_long.csv'));

    summary = struct();
    summary.cfg = cfg;
    summary.specs = specs;
    summary.runTable = runRows;
    summary.longTable = summaryLong;
    summary.allResults = allResults;

    save(fullfile(cfg.resultDir, 'param_sensitivity_workspace.mat'), 'summary', '-v7.3');

    fprintf('\nSaved:\n');
    fprintf(' %s\n', fullfile(cfg.resultDir, 'param_sensitivity_runs.csv'));
    fprintf(' %s\n', fullfile(cfg.resultDir, 'param_sensitivity_summary_long.csv'));
    fprintf(' %s\n', fullfile(cfg.resultDir, 'param_sensitivity_workspace.mat'));
    fprintf(' %s\n', runDir);
end

% ========================================================================
function cfg = localDefaultConfig()
    cfg = struct();
    cfg.sceneIds = [2, 4];   % code scenes: paper Scene 2 and Scene 3
    cfg.nRuns = 30;
    cfg.baseSeed = 20260419;
    cfg.resultDir = fullfile(pwd, ['results_uav_param_sensitivity_lite_v2_' datestr(now, 'yyyymmdd_HHMMSS')]);
end

% ========================================================================
function specs = localBuildParamSpecs()
    specs = struct([]);

    specs(1).key = 'aos_c';
    specs(1).label = 'UCB coefficient c';
    specs(1).values = [0.30, 0.60, 0.90, 1.20, 1.50];
    specs(1).target = 'params';

    specs(2).key = 'aosFreezeFrac';
    specs(2).label = 'AOS freeze fraction';
    specs(2).values = [0.30, 0.40, 0.50, 0.60, 0.70];
    specs(2).target = 'algCfgLite';

    specs(3).key = 'repairEliteFrac';
    specs(3).label = 'Repair elite fraction';
    specs(3).values = [0.10, 0.20, 0.25, 0.30, 0.40];
    specs(3).target = 'algCfgLite';

    specs(4).key = 'regenWindow';
    specs(4).label = 'Stagnation window W';
    specs(4).values = [10, 14, 18, 22, 26];
    specs(4).target = 'params';
end

% ========================================================================
function [params, algCfg] = localApplyParamOverride(params, algCfg, spec, val)
    switch spec.key
        case 'aos_c'
            params.aos.c = val;

        case 'aosFreezeFrac'
            if ~isfield(algCfg, 'lite') || ~isstruct(algCfg.lite)
                algCfg.lite = struct();
            end
            algCfg.lite.aosFreezeFrac = val;

        case 'repairEliteFrac'
            if ~isfield(algCfg, 'lite') || ~isstruct(algCfg.lite)
                algCfg.lite = struct();
            end
            algCfg.lite.repairEliteFrac = val;

        case 'regenWindow'
            params.regen.window = val;

        otherwise
            error('Unknown sensitivity parameter: %s', spec.key);
    end
end

% ========================================================================
function summaryLong = localBuildSummary(runRows, specs, sceneIds)
    rows = table();

    for p = 1:numel(specs)
        key = specs(p).key;
        vals = specs(p).values;

        for s = 1:numel(sceneIds)
            sceneId = sceneIds(s);
            paperScene = localPaperScene(sceneId);

            for v = 1:numel(vals)
                val = vals(v);
                mask = strcmp(runRows.ParamKey, key) & ...
                       runRows.Scene == sceneId & ...
                       abs(runRows.ParamValue - val) < 1e-12;

                fitnessVals = runRows.BestFitness(mask);
                runtimeVals = runRows.Runtime(mask);
                feasVals = runRows.Feasible(mask);

                row = table( ...
                    {key}, {specs(p).label}, val, sceneId, paperScene, ...
                    mean(fitnessVals, 'omitnan'), std(fitnessVals, 'omitnan'), ...
                    mean(runtimeVals, 'omitnan'), ...
                    mean(double(feasVals), 'omitnan'), ...
                    sum(mask), ...
                    'VariableNames', { ...
                    'ParamKey','ParamLabel','ParamValue','Scene','PaperScene', ...
                    'MeanCost','StdCost','MeanRuntime','FeasibilityRatio','NumRuns'});

                if isempty(rows)
                    rows = row;
                else
                    rows = [rows; row]; %#ok<AGROW>
                end
            end
        end
    end

    summaryLong = rows;
end

% ========================================================================
function paperScene = localPaperScene(sceneId)
    if sceneId == 4
        paperScene = 3;
    else
        paperScene = sceneId;
    end
end