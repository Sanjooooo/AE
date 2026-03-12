function ablationCfgs = getAblationConfigs(sceneId)
%GETABLATIONCONFIGS Build the main ablation settings for FAE-AE.

if nargin < 1
    sceneId = 1;
end

base = getDefaultExperimentConfig();
base.sceneId = sceneId;
base.nRuns = 20;
base.showSingleRunFigure = false;
base.showBatchFigure = false;
base.saveBestPathFigure = false;
base.saveBestTopViewFigure = false;

ablationCfgs = repmat(base, 5, 1);

% 1) Base-AE
ablationCfgs(1) = base;
ablationCfgs(1).algorithmName = 'Base-AE';
ablationCfgs(1).outputDir = sprintf('ablation_scene%d_base_ae', sceneId);
ablationCfgs(1).useInit = false;
ablationCfgs(1).useAOS = false;
ablationCfgs(1).useRepair = false;
ablationCfgs(1).useRegen = false;

% 2) AE + Init
ablationCfgs(2) = base;
ablationCfgs(2).algorithmName = 'AE+Init';
ablationCfgs(2).outputDir = sprintf('ablation_scene%d_init', sceneId);
ablationCfgs(2).useInit = true;
ablationCfgs(2).useAOS = false;
ablationCfgs(2).useRepair = false;
ablationCfgs(2).useRegen = false;

% 3) AE + Init + AOS
ablationCfgs(3) = base;
ablationCfgs(3).algorithmName = 'AE+Init+AOS';
ablationCfgs(3).outputDir = sprintf('ablation_scene%d_init_aos', sceneId);
ablationCfgs(3).useInit = true;
ablationCfgs(3).useAOS = true;
ablationCfgs(3).useRepair = false;
ablationCfgs(3).useRegen = false;

% 4) AE + Init + AOS + Repair
ablationCfgs(4) = base;
ablationCfgs(4).algorithmName = 'AE+Init+AOS+Repair';
ablationCfgs(4).outputDir = sprintf('ablation_scene%d_init_aos_repair', sceneId);
ablationCfgs(4).useInit = true;
ablationCfgs(4).useAOS = true;
ablationCfgs(4).useRepair = true;
ablationCfgs(4).useRegen = false;

% 5) Full FAE-AE
ablationCfgs(5) = base;
ablationCfgs(5).algorithmName = 'FAE-AE';
ablationCfgs(5).outputDir = sprintf('ablation_scene%d_full_faeae', sceneId);
ablationCfgs(5).useInit = true;
ablationCfgs(5).useAOS = true;
ablationCfgs(5).useRepair = true;
ablationCfgs(5).useRegen = true;
end