function plotBatchConvergence(results, expCfg)
%PLOTBATCHCONVERGENCE Plot mean/std convergence over multiple runs.

nRuns = numel(results);
maxIter = numel(results(1).bestHist);

histMat = zeros(nRuns, maxIter);
for i = 1:nRuns
    histMat(i, :) = results(i).bestHist(:).';
end

meanHist = mean(histMat, 1);
stdHist = std(histMat, 0, 1);

figure('Color', 'w'); hold on; grid on;
x = 1:maxIter;

upper = meanHist + stdHist;
lower = meanHist - stdHist;

fill([x fliplr(x)], [upper fliplr(lower)], [0.85 0.88 0.95], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.6);
plot(x, meanHist, 'b-', 'LineWidth', 2);

xlabel('Iteration');
ylabel('Objective');
title(sprintf('%s Mean Convergence (Scene %d)', expCfg.algorithmName, expCfg.sceneId));

if expCfg.saveFigures
    saveas(gcf, fullfile(expCfg.outputDir, 'mean_convergence.png'));
end
end