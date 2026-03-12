function postplot_batch_results(resultDir)
%POSTPLOT_BATCH_RESULTS Replot figures from saved batch_results.mat
%
% Usage:
%   postplot_batch_results
%   postplot_batch_results('results_scene4_faeae')

if nargin < 1
    resultDir = 'results_scene4_faeae';
end

matFile = fullfile(resultDir, 'batch_results.mat');
if ~exist(matFile, 'file')
    error('Cannot find file: %s', matFile);
end

S = load(matFile);
batchResult = S.batchResult;

expCfg = batchResult.expCfg;
results = batchResult.results;

% Rebuild params/map
params = defaultParams();
params.sceneId = expCfg.sceneId;
map = createMap(params);

% ---------- Find best run ----------
bestVals = [results.bestFit];
[~, bestRunIdx] = min(bestVals);

bestPath = results(bestRunIdx).bestPath;
bestCtrl = results(bestRunIdx).bestCtrl;

% ---------- Plot best 3D path ----------
fig1 = figure('Color', 'w');
plotSceneAndPath(map, bestPath, bestCtrl, params);
title(sprintf('%s Best Path (Scene %d, Run %d)', ...
    expCfg.algorithmName, expCfg.sceneId, bestRunIdx));
saveas(fig1, fullfile(resultDir, 'best_path_3d_post.png'));

% ---------- Plot best top view ----------
fig2 = figure('Color', 'w');
plotSceneAndPath(map, bestPath, bestCtrl, params);
view(2);
axis equal;
title(sprintf('%s Best Path Top View (Scene %d, Run %d)', ...
    expCfg.algorithmName, expCfg.sceneId, bestRunIdx));
saveas(fig2, fullfile(resultDir, 'best_path_topview_post.png'));

% ---------- Plot mean convergence ----------
nRuns = numel(results);
maxIter = numel(results(1).bestHist);
histMat = zeros(nRuns, maxIter);

for i = 1:nRuns
    histMat(i, :) = results(i).bestHist(:).';
end

meanHist = mean(histMat, 1);
stdHist = std(histMat, 0, 1);

fig3 = figure('Color', 'w'); hold on; grid on;
x = 1:maxIter;
upper = meanHist + stdHist;
lower = meanHist - stdHist;

fill([x fliplr(x)], [upper fliplr(lower)], [0.85 0.88 0.95], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.6);
plot(x, meanHist, 'b-', 'LineWidth', 2);

xlabel('Iteration');
ylabel('Objective');
title(sprintf('%s Mean Convergence (Scene %d)', ...
    expCfg.algorithmName, expCfg.sceneId));

saveas(fig3, fullfile(resultDir, 'mean_convergence_post.png'));

fprintf('Post-plot finished.\n');
fprintf('Best run index: %d\n', bestRunIdx);
fprintf('Saved files:\n');
fprintf('  %s\n', fullfile(resultDir, 'best_path_3d_post.png'));
fprintf('  %s\n', fullfile(resultDir, 'best_path_topview_post.png'));
fprintf('  %s\n', fullfile(resultDir, 'mean_convergence_post.png'));
end