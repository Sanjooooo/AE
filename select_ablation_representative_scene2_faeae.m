function candTbl = select_ablation_representative_scene2_faeae(resultDir)
% 手动筛选消融实验中 FAEAE 在代码 Scene 2（论文 Scene 2）的代表航迹
%
% 用法：
%   candTbl = select_ablation_representative_scene2_faeae(resultDir);
%
% 输入：
%   resultDir - 消融实验结果文件夹，里面应有 uav_comparison_results.mat
%
% 输出：
%   candTbl   - 候选运行的排序表

    if nargin < 1 || isempty(resultDir)
        error('Please provide resultDir.');
    end

    matFile = fullfile(resultDir, 'uav_comparison_results.mat');
    if ~exist(matFile, 'file')
        error('Cannot find file: %s', matFile);
    end

    S = load(matFile, 'allResults', 'cfg');
    allResults = S.allResults;

    % 消融实验算法顺序：
    % 1 Base-AE
    % 2 AE+Init
    % 3 AE+Init+AOS
    % 4 AE+Init+AOS+Repair
    % 5 FAEAE
    algIdx = 5;

    % 场景顺序按 sceneIds = [1, 2, 4]
    % 代码 Scene 2 -> 第 2 行
    sceneRow = 2;

    % 注意：allResults 的维度是 {scene, algorithm}
    runs = allResults{sceneRow, algIdx};
    nRuns = numel(runs);

    runId = zeros(nRuns, 1);
    feasible = false(nRuns, 1);
    fit = nan(nRuns, 1);
    meanZ = nan(nRuns, 1);
    maxZ = nan(nRuns, 1);
    stdZ = nan(nRuns, 1);
    smoothS = nan(nRuns, 1);
    pathL = nan(nRuns, 1);

    for i = 1:nRuns
        r = runs(i);

        runId(i) = r.runId;
        feasible(i) = logical(r.finalFeasible);
        fit(i) = r.bestFitness;

        P = r.bestPath;   % 3 x Ns
        z = P(3, :);

        meanZ(i) = mean(z);
        maxZ(i) = max(z);
        stdZ(i) = std(z);

        if isfield(r, 'bestDetail') && ~isempty(r.bestDetail)
            if isfield(r.bestDetail, 'S')
                smoothS(i) = r.bestDetail.S;
            end
            if isfield(r.bestDetail, 'L')
                pathL(i) = r.bestDetail.L;
            end
        end
    end

    T = table(runId, feasible, fit, meanZ, maxZ, stdZ, smoothS, pathL);

    % 只看可行解
    Tfeas = T(T.feasible, :);
    if isempty(Tfeas)
        error('No feasible FAEAE runs found for code Scene 2.');
    end

    % 先保留代价接近最优的一小批（2%窗口，可自行改成1%或3%）
    bestFit = min(Tfeas.fit);
    fitTol = 1.02;
    Tnear = Tfeas(Tfeas.fit <= bestFit * fitTol, :);

    % 在“接近最优”的候选里优先选更低空的
    % 先按 meanZ，再按 maxZ，再按 smoothS，再按 fit
    Tnear = sortrows(Tnear, {'meanZ', 'maxZ', 'smoothS', 'fit'}, ...
                            {'ascend', 'ascend', 'ascend', 'ascend'});

    candTbl = Tnear;

    fprintf('\n=== FAEAE representative selection for code Scene 2 (paper Scene 2) ===\n');
    fprintf('Feasible runs         : %d / %d\n', height(Tfeas), nRuns);
    fprintf('Best feasible fitness : %.6f\n', bestFit);
    fprintf('Near-optimal window   : <= %.6f (%.0f%% of best)\n', bestFit * fitTol, (fitTol - 1) * 100);
    fprintf('\nTop candidates:\n');
    disp(candTbl(1:min(10, height(candTbl)), :));

    % 可视化前6个候选，方便你人工二次挑选
    nShow = min(6, height(candTbl));
    figure('Color', 'w', 'Position', [100, 100, 1200, 700]);
    tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

    for k = 1:nShow
        rid = candTbl.runId(k);
        idx = find([runs.runId] == rid, 1, 'first');
        r = runs(idx);
        P = r.bestPath;

        nexttile;
        plot3(P(1, :), P(2, :), P(3, :), 'LineWidth', 1.5);
        grid on; box on; axis tight;
        xlabel('X'); ylabel('Y'); zlabel('Z');
        title(sprintf('run %d | fit=%.2f | meanZ=%.2f | maxZ=%.2f', ...
            rid, candTbl.fit(k), candTbl.meanZ(k), candTbl.maxZ(k)), ...
            'FontWeight', 'normal');
        view(3);
    end

    % 保存候选表
    outCsv = fullfile(resultDir, 'scene2_faeae_representative_candidates.csv');
    writetable(candTbl, outCsv);
    fprintf('\nSaved candidate table to:\n%s\n', outCsv);
end