function cfg = getCEC2017Config()
%GETCEC2017CONFIG Basic config for CEC2017 experiments.

cfg.dim = 30;
cfg.nRuns = 30;
cfg.baseSeed = 3000;

cfg.funcIds = [1, 3:30];

cfg.maxFEs = 30000;   % 先别急着上 300000
cfg.saveResults = true;
cfg.outputDir = 'cec2017_30D_results';

cfg.algorithms = {'AE', 'FAEAE'};
end