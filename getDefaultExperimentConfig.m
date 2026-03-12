function expCfg = getDefaultExperimentConfig()
%GETDEFAULTEXPERIMENTCONFIG Experiment configuration for batch runs.

expCfg.nRuns = 20;
expCfg.baseSeed = 2025;

expCfg.saveResults = true;

% 批量实验阶段先彻底关闭图形相关输出，避免 R2022b 崩溃
expCfg.saveFigures = false;
expCfg.showSingleRunFigure = false;
expCfg.showBatchFigure = false;
expCfg.saveBestPathFigure = false;
expCfg.saveBestTopViewFigure = false;

expCfg.outputDir = 'results_scene1_faeae';

expCfg.sceneId = 1;
expCfg.algorithmName = 'FAE-AE';

% 预留给消融
expCfg.useInit = true;
expCfg.useAOS = true;
expCfg.useRepair = true;
expCfg.useRegen = true;
expCfg.useHeightTerm = true;
expCfg.useBoundaryTerm = true;
end