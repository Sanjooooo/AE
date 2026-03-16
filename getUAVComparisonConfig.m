function cfg = getUAVComparisonConfig(mode)
%GETUAVCOMPARISONCONFIG Configuration for multi-algorithm UAV comparison.
%
% Usage:
%   cfg = getUAVComparisonConfig();
%   cfg = getUAVComparisonConfig('smoke');
%   cfg = getUAVComparisonConfig('mid');
%   cfg = getUAVComparisonConfig('formal');
%
% Modes:
%   smoke  - very small test for framework validation
%   mid    - medium-scale validation
%   formal - final paper-level comparison
%
% Output:
%   cfg.sceneIds
%   cfg.algorithms
%   cfg.nRuns
%   cfg.baseSeed
%   cfg.resultDir
%   cfg.resumeExisting
%   cfg.verbose
%   cfg.paramsOverride (optional overrides written into defaultParams)

    if nargin < 1 || isempty(mode)
        mode = 'formal';
    end
    mode = lower(mode);

    cfg = struct();

    % ------------------------------------------------------------
    % Core comparison settings
    % ------------------------------------------------------------
    cfg.sceneIds = [1, 2, 4];
    cfg.algorithms = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};

    cfg.baseSeed = 20260316;
    cfg.resumeExisting = true;
    cfg.verbose = true;

    % Turn off heavy plotting in batch stage
    cfg.saveFigures = false;
    cfg.showSingleRunFigure = false;
    cfg.showBatchFigure = false;
    cfg.saveBestPathFigure = false;
    cfg.saveBestTopViewFigure = false;

    % Optional parameter overrides written into defaultParams()
    % Leave empty unless you want to force comparison-wide settings.
    cfg.paramsOverride = struct();

    switch mode
        case 'smoke'
            cfg.nRuns = 3;
            cfg.sceneIds = [1];
            cfg.algorithms = {'AE', 'PSO', 'FAEAE'};
            modeTag = 'smoke';

        case 'mid'
            cfg.nRuns = 10;
            cfg.sceneIds = [1, 2, 4];
            cfg.algorithms = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};
            modeTag = 'mid';

        case 'formal'
            cfg.nRuns = 30;
            cfg.sceneIds = [1, 2, 4];
            cfg.algorithms = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};
            modeTag = 'formal';

        otherwise
            error('Unknown mode: %s', mode);
    end

    cfg.mode = modeTag;

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    cfg.resultDir = fullfile(pwd, sprintf('results_uav_comparison_%s_%s', modeTag, timestamp));

end