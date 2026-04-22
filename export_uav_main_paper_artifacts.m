function export_uav_main_paper_artifacts(resultDir, outTableDir, outFigDir)
%EXPORT_UAV_MAIN_PAPER_ARTIFACTS
% 一键导出主实验（非 fair-init）的论文表图产物，并统一使用论文场景编号
% Scene 1 / 2 / 3（其中代码场景 4 对应论文 Scene 3）。
%
% 依赖：
%   - summarize_uav_comparison_results.m
%   - make_tab4_1_uav_main_results.m
%   - make_tab4_2_uav_main_wtl.m
%   - make_uav_main_mean_cost_bar.m
%   - make_uav_main_convergence_paper.m   (可选)
%   - make_uav_wilcoxon_table.m
%   - make_tab_runtime_feasibility.m
%
% 输入：
%   resultDir   - 主实验结果目录（包含 uav_comparison_results.mat）
%   outTableDir - 输出表格目录
%   outFigDir   - 输出图目录
%
% 输出：
%   [Tables]
%     main_tab4_1_uav_main_results.csv/.xlsx
%     main_tab4_2_uav_main_wtl.csv/.xlsx
%     main_tab_wilcoxon.csv/.xlsx
%     main_tab_runtime_feasibility.csv/.xlsx
%
%   [Figures]
%     main_fig_uav_main_mean_cost.png/.fig
%     main_fig_scene1_convergence.png/.fig
%     main_fig_scene2_convergence.png/.fig
%     main_fig_scene3_convergence.png/.fig
%
% 用法：
%   export_uav_main_paper_artifacts
%   export_uav_main_paper_artifacts(resultDir)
%   export_uav_main_paper_artifacts(resultDir, outTableDir, outFigDir)

    if nargin < 1 || isempty(resultDir)
        resultDir = uigetdir(pwd, 'Select MAIN result folder');
        if isequal(resultDir, 0)
            error('No result folder selected.');
        end
    end
    if nargin < 2 || isempty(outTableDir)
        outTableDir = fullfile(resultDir, 'paper_main_tables');
    end
    if nargin < 3 || isempty(outFigDir)
        outFigDir = fullfile(resultDir, 'paper_main_figures');
    end

    if ~exist(resultDir, 'dir')
        error('结果目录不存在：%s', resultDir);
    end
    if ~exist(outTableDir, 'dir')
        mkdir(outTableDir);
    end
    if ~exist(outFigDir, 'dir')
        mkdir(outFigDir);
    end

    fprintf('\n============================================================\n');
    fprintf('Export MAIN paper artifacts\n');
    fprintf('Result folder : %s\n', resultDir);
    fprintf('Table folder  : %s\n', outTableDir);
    fprintf('Figure folder : %s\n', outFigDir);
    fprintf('============================================================\n\n');

    % ------------------------------------------------------------
    % Step 1: summarize
    % ------------------------------------------------------------
    fprintf('[1/6] Summarizing main results...\n');
    summarize_uav_comparison_results(resultDir);

    % ------------------------------------------------------------
    % Step 2: main result table (mean ± std + rank)
    % ------------------------------------------------------------
    fprintf('[2/6] Exporting main results table...\n');
    make_tab4_1_uav_main_results(resultDir, outTableDir);
    localRenameIfExists(outTableDir, 'tab4_1_uav_main_results.csv',  'main_tab4_1_uav_main_results.csv');
    localRenameIfExists(outTableDir, 'tab4_1_uav_main_results.xlsx', 'main_tab4_1_uav_main_results.xlsx');

    % ------------------------------------------------------------
    % Step 3: W/T/L table
    % ------------------------------------------------------------
    fprintf('[3/6] Exporting W/T/L table...\n');
    make_tab4_2_uav_main_wtl(resultDir, outTableDir);
    localRenameIfExists(outTableDir, 'tab4_2_uav_main_wtl.csv',  'main_tab4_2_uav_main_wtl.csv');
    localRenameIfExists(outTableDir, 'tab4_2_uav_main_wtl.xlsx', 'main_tab4_2_uav_main_wtl.xlsx');

    % ------------------------------------------------------------
    % Step 4: Wilcoxon table
    % ------------------------------------------------------------
    fprintf('[4/6] Exporting Wilcoxon table...\n');
    make_uav_wilcoxon_table(resultDir, outTableDir, 'ranksum');
    localRenameIfExists(outTableDir, 'tab_wilcoxon.csv',  'main_tab_wilcoxon.csv');
    localRenameIfExists(outTableDir, 'tab_wilcoxon.xlsx', 'main_tab_wilcoxon.xlsx');
    localRenameIfExists(outTableDir, 'uav_wilcoxon_table.csv',  'main_tab_wilcoxon.csv');
    localRenameIfExists(outTableDir, 'uav_wilcoxon_table.xlsx', 'main_tab_wilcoxon.xlsx');

    % ------------------------------------------------------------
    % Step 5: runtime + feasibility table
    % ------------------------------------------------------------
    fprintf('[5/6] Exporting runtime + feasibility table...\n');
    make_tab_runtime_feasibility(resultDir, outTableDir);
    localRenameIfExists(outTableDir, 'tab_runtime_feasibility.csv',  'main_tab_runtime_feasibility.csv');
    localRenameIfExists(outTableDir, 'tab_runtime_feasibility.xlsx', 'main_tab_runtime_feasibility.xlsx');

    % ------------------------------------------------------------
    % Step 6: figures
    % ------------------------------------------------------------
    fprintf('[6/6] Exporting figures...\n');
    make_uav_main_mean_cost_bar(resultDir, outFigDir);
    localRenameIfExists(outFigDir, 'fig4_7_uav_main_mean_cost.png', 'main_fig_uav_main_mean_cost.png');
    localRenameIfExists(outFigDir, 'fig4_7_uav_main_mean_cost.fig', 'main_fig_uav_main_mean_cost.fig');
    localRenameIfExists(outFigDir, 'fig_uav_main_mean_cost.png', 'main_fig_uav_main_mean_cost.png');
    localRenameIfExists(outFigDir, 'fig_uav_main_mean_cost.fig', 'main_fig_uav_main_mean_cost.fig');

    % Optional convergence figures: only if run_records exists
    runDir = fullfile(resultDir, 'run_records');
    if exist(runDir, 'dir')
        make_uav_main_convergence_paper(resultDir, outFigDir);

        % Scene 1
        localRenameIfExists(outFigDir, 'fig4_4_scene1_convergence_main.png', 'main_fig_scene1_convergence.png');
        localRenameIfExists(outFigDir, 'fig4_4_scene1_convergence_main.fig', 'main_fig_scene1_convergence.fig');
        localRenameIfExists(outFigDir, 'fig_scene1_convergence_main.png', 'main_fig_scene1_convergence.png');
        localRenameIfExists(outFigDir, 'fig_scene1_convergence_main.fig', 'main_fig_scene1_convergence.fig');

        % Scene 2
        localRenameIfExists(outFigDir, 'fig4_5_scene2_convergence_main.png', 'main_fig_scene2_convergence.png');
        localRenameIfExists(outFigDir, 'fig4_5_scene2_convergence_main.fig', 'main_fig_scene2_convergence.fig');
        localRenameIfExists(outFigDir, 'fig_scene2_convergence_main.png', 'main_fig_scene2_convergence.png');
        localRenameIfExists(outFigDir, 'fig_scene2_convergence_main.fig', 'main_fig_scene2_convergence.fig');

        % Code Scene 4 -> Paper Scene 3
        localRenameIfExists(outFigDir, 'fig4_6_scene4_convergence_main.png', 'main_fig_scene3_convergence.png');
        localRenameIfExists(outFigDir, 'fig4_6_scene4_convergence_main.fig', 'main_fig_scene3_convergence.fig');
        localRenameIfExists(outFigDir, 'fig_scene4_convergence_main.png', 'main_fig_scene3_convergence.png');
        localRenameIfExists(outFigDir, 'fig_scene4_convergence_main.fig', 'main_fig_scene3_convergence.fig');
    else
        fprintf('  [Skip] run_records not found, convergence figures not exported.\n');
    end

    fprintf('\nDone. MAIN paper artifacts exported.\n');
end

%% ========================================================================
function localRenameIfExists(folderPath, oldName, newName)
    oldFile = fullfile(folderPath, oldName);
    newFile = fullfile(folderPath, newName);

    if exist(oldFile, 'file')
        if exist(newFile, 'file')
            delete(newFile);
        end
        movefile(oldFile, newFile);
        fprintf('Renamed: %s -> %s\n', oldName, newName);
    end
end
