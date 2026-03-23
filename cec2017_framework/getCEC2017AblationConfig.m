function cfg = getCEC2017AblationConfig(stage, budgetLevel, resultDir)
%GETCEC2017ABLATIONCONFIG Configuration for CEC2017 ablation experiments.
%
% Usage:
%   cfg = getCEC2017AblationConfig();
%   cfg = getCEC2017AblationConfig('formal', 'high');
%   cfg = getCEC2017AblationConfig('formal', 'high', 'results_cec2017_ablation_formal_high');
%
% Output methods:
%   Base-AE
%   AE+Init
%   AE+Init+AOS
%   AE+Init+AOS+Repair
%   FAE-AE
%
% Notes:
% - Uses the same CEC2017 formal settings as your existing framework:
%   dim = 30, formal functions = [1, 3:30], nRuns = 30 for formal.
% - The "Repair" label in CEC ablation is implemented as local refinement,
%   because CEC2017 is unconstrained.

    if nargin < 1 || isempty(stage)
        stage = 'formal';
    end
    if nargin < 2 || isempty(budgetLevel)
        budgetLevel = 'high';
    end

    baseCfg = getCEC2017Config(stage, budgetLevel);

    cfg = baseCfg;
    cfg.methods = { ...
        'Base-AE', ...
        'AE+Init', ...
        'AE+Init+AOS', ...
        'AE+Init+AOS+Repair', ...
        'FAE-AE'};

    % Keep a separate result folder from the main comparison
    if nargin < 3 || isempty(resultDir)
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        cfg.resultDir = fullfile(pwd, sprintf('results_cec2017_ablation_%s_%s_%s', ...
            cfg.stage, cfg.budgetLevel, timestamp));
    else
        cfg.resultDir = resultDir;
    end

    cfg.verbose = true;
    cfg.resumeExisting = true;
end