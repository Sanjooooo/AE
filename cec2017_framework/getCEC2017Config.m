function cfg = getCEC2017Config(stage, budgetLevel)
%GETCEC2017CONFIG Configuration for CEC2017 experiments.
%
% Usage:
%   cfg = getCEC2017Config();
%   cfg = getCEC2017Config('smoke', 'medium');
%   cfg = getCEC2017Config('mid', 'high');
%   cfg = getCEC2017Config('formal', 'high');
%
% stage:
%   'smoke'  - very small test, only for framework validation
%   'mid'    - medium-scale validation before full formal run
%   'formal' - final formal benchmark experiment
%
% budgetLevel:
%   'medium' - development/intermediate budget
%   'high'   - final formal budget
%
% Notes:
%   medium budget: maxFEs = 30000   (for quick validation)
%   high budget  : maxFEs = 300000  (for 30D final benchmark)

    if nargin < 1 || isempty(stage)
        stage = 'formal';
    end
    if nargin < 2 || isempty(budgetLevel)
        budgetLevel = 'medium';
    end

    stage = lower(stage);
    budgetLevel = lower(budgetLevel);

    % ---------- Common settings ----------
    cfg = struct();

    cfg.dim = 30;
    cfg.lb = -100;
    cfg.ub = 100;

    cfg.algorithms = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};

    cfg.baseSeed = 20260312;
    cfg.verbose = true;
    cfg.resumeExisting = true;

    % ---------- Budget settings ----------
    switch budgetLevel
        case 'medium'
            cfg.maxFEs = 30000;
            budgetTag = 'medium';
        case 'high'
            cfg.maxFEs = 300000;
            budgetTag = 'high';
        otherwise
            error('Unknown budgetLevel: %s. Use ''medium'' or ''high''.', budgetLevel);
    end

    % ---------- Stage settings ----------
    switch stage
        case 'smoke'
            cfg.nRuns = 3;
            cfg.funcIds = [1, 3];
            stageTag = 'smoke';

        case 'mid'
            cfg.nRuns = 10;
            cfg.funcIds = [1, 3, 4, 5, 6];
            stageTag = 'mid';

        case 'formal'
            cfg.nRuns = 30;
            cfg.funcIds = [1, 3:30];   % F2 removed in CEC2017
            stageTag = 'formal';

        otherwise
            error('Unknown stage: %s. Use ''smoke'', ''mid'', or ''formal''.', stage);
    end

    % ---------- Result folder ----------
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    cfg.resultDir = fullfile(pwd, sprintf('results_cec2017_%s_%s_%s', stageTag, budgetTag, timestamp));

    % ---------- Meta info ----------
    cfg.stage = stageTag;
    cfg.budgetLevel = budgetTag;

end