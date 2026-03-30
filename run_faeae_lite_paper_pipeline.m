function out = run_faeae_lite_paper_pipeline(cecStage, cecBudget, uavMode)
%RUN_FAEAE_LITE_PAPER_PIPELINE
% One-stop pipeline for:
% 1) CEC2017 benchmark
% 2) UAV 3-scene main experiment
% 3) runtime + feasibility export
%
% Recommended:
%   out = run_faeae_lite_paper_pipeline('formal', 'high', 'formal');

if nargin < 1 || isempty(cecStage),  cecStage = 'formal'; end
if nargin < 2 || isempty(cecBudget), cecBudget = 'high'; end
if nargin < 3 || isempty(uavMode),   uavMode = 'formal'; end

rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);
addpath(fullfile(rootDir, 'cec2017_framework'));

ts = datestr(now, 'yyyymmdd_HHMMSS');

% -------------------- CEC --------------------
cecCfg = getCEC2017Config(cecStage, cecBudget);
cecCfg.resultDir = fullfile(rootDir, sprintf('results_cec2017_%s_%s_lite_%s', cecStage, cecBudget, ts));
cecCfg.algorithms = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};
cecSummary = run_cec2017_batch_lite(cecCfg);

% Existing paper exporters can still be used because the algorithm label
% stays "FAEAE".
try
    make_tab4_4_cec_main_results(cecCfg.resultDir, fullfile(rootDir, 'paper_final_tables'));
catch
end
try
    make_tab4_5_cec_main_wilcoxon(cecCfg.resultDir, fullfile(rootDir, 'paper_final_tables'));
catch
end

% -------------------- UAV --------------------
uavCfg = getUAVComparisonConfig(uavMode);
uavCfg.resultDir = fullfile(rootDir, sprintf('results_uav_lite_%s_%s', uavMode, ts));
uavCfg.algorithms = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};
uavCfg.sceneIds = [1, 2, 4];   % code-side scene ids
uavCfg.useLiteFAEAE = true;
uavSummary = run_uav_comparison_lite_batch(uavCfg);

try
    make_tab_runtime_feasibility(uavCfg.resultDir, fullfile(rootDir, 'paper_final_tables'), 'main');
catch
end
try
    make_tab4_1_uav_main_results(uavCfg.resultDir, fullfile(rootDir, 'paper_final_tables'));
catch
end

out = struct();
out.cecResultDir = cecCfg.resultDir;
out.uavResultDir = uavCfg.resultDir;
out.cecSummary = cecSummary;
out.uavSummary = uavSummary;
end
