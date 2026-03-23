function export_uav_fair_init_paper_artifacts(resultDir, outTableDir, outFigDir)
%EXPORT_UAV_FAIR_INIT_PAPER_ARTIFACTS
% 一键导出公平初始化实验的论文表图产物。
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
%   resultDir   - 公平初始化实验结果目录（包含 uav_comparison_results.mat）
%   outTableDir - 输出表格目录
%   outFigDir   - 输出图目录
%
% 输出：
%   [Tables]
%     fair_init_tab4_1_uav_main_results.csv/.xlsx
%     fair_init_tab4_2_uav_main_wtl.csv/.xlsx
%     fair_init_tab_wilcoxon.csv/.xlsx
%     fair_init_tab_runtime_feasibility.csv/.xlsx
%
%   [Figures]
%     fair_init_fig_uav_main_mean_cost.png/.fig
%     fair_init_fig_scene1_convergence.png/.fig
%     fair_init_fig_scene2_convergence.png/.fig
%     fair_init_fig_scene4_convergence.png/.fig
%
% 用法：
%   export_uav_fair_init_paper_artifacts
%   export_uav_fair_init_paper_artifacts(resultDir)
%   export_uav_fair_init_paper_artifacts(resultDir, outTableDir, outFigDir)

    if nargin < 1 || isempty(resultDir)
        resultDir = uigetdir(pwd, 'Select FAIR-INIT result folder');
        if isequal(resultDir, 0)
            error('No result folder selected.');
        end
    end
    if nargin < 2 || isempty(outTableDir)
        outTableDir = fullfile(resultDir, 'paper_fair_init_tables');
    end
    if nargin < 3 || isempty(outFigDir)
        outFigDir = fullfile(resultDir, 'paper_fair_init_figures');
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
    fprintf('Export FAIR-INIT paper artifacts\n');
    fprintf('Result folder : %s\n', resultDir);
    fprintf('Table folder  : %s\n', outTableDir);
    fprintf('Figure folder : %s\n', outFigDir);
    fprintf('============================================================\n\n');

    % ------------------------------------------------------------
    % Step 1: summarize
    % ------------------------------------------------------------
    fprintf('[1/6] Summarizing fair-init results...\n');
    summarize_uav_comparison_results(resultDir);

    % ------------------------------------------------------------
    % Step 2: main result table (mean ± std + rank)
    % ------------------------------------------------------------
    fprintf('[2/6] Exporting main results table...\n');
    make_tab4_1_uav_main_results(resultDir, outTableDir);
    localRenameIfExists(outTableDir, 'tab4_1_uav_main_results.csv',  'fair_init_tab4_1_uav_main_results.csv');
    localRenameIfExists(outTableDir, 'tab4_1_uav_main_results.xlsx', 'fair_init_tab4_1_uav_main_results.xlsx');

    % ------------------------------------------------------------
    % Step 3: W/T/L table
    % ------------------------------------------------------------
    fprintf('[3/6] Exporting W/T/L table...\n');
    make_tab4_2_uav_main_wtl(resultDir, outTableDir);
    localRenameIfExists(outTableDir, 'tab4_2_uav_main_wtl.csv',  'fair_init_tab4_2_uav_main_wtl.csv');
    localRenameIfExists(outTableDir, 'tab4_2_uav_main_wtl.xlsx', 'fair_init_tab4_2_uav_main_wtl.xlsx');

    % ------------------------------------------------------------
    % Step 4: Wilcoxon table
    % ------------------------------------------------------------
    fprintf('[4/6] Exporting Wilcoxon table...\n');
    make_uav_wilcoxon_table(resultDir, outTableDir, 'ranksum');

    % ------------------------------------------------------------
    % Step 5: runtime + feasibility table
    % ------------------------------------------------------------
    fprintf('[5/6] Exporting runtime + feasibility table...\n');
    make_tab_runtime_feasibility(resultDir, outTableDir);

    % ------------------------------------------------------------
    % Step 6: figures
    % ------------------------------------------------------------
    fprintf('[6/6] Exporting figures...\n');
    make_uav_main_mean_cost_bar(resultDir, outFigDir);
    localRenameIfExists(outFigDir, 'fig4_7_uav_main_mean_cost.png', 'fair_init_fig_uav_main_mean_cost.png');
    localRenameIfExists(outFigDir, 'fig4_7_uav_main_mean_cost.fig', 'fair_init_fig_uav_main_mean_cost.fig');

    % Optional convergence figures: only if run_records exists
    runDir = fullfile(resultDir, 'run_records');
    if exist(runDir, 'dir')
        make_uav_main_convergence_paper(resultDir, outFigDir);

        localRenameIfExists(outFigDir, 'fig4_4_scene1_convergence_main.png', 'fair_init_fig_scene1_convergence.png');
        localRenameIfExists(outFigDir, 'fig4_4_scene1_convergence_main.fig', 'fair_init_fig_scene1_convergence.fig');

        localRenameIfExists(outFigDir, 'fig4_5_scene2_convergence_main.png', 'fair_init_fig_scene2_convergence.png');
        localRenameIfExists(outFigDir, 'fig4_5_scene2_convergence_main.fig', 'fair_init_fig_scene2_convergence.fig');

        localRenameIfExists(outFigDir, 'fig4_6_scene4_convergence_main.png', 'fair_init_fig_scene4_convergence.png');
        localRenameIfExists(outFigDir, 'fig4_6_scene4_convergence_main.fig', 'fair_init_fig_scene4_convergence.fig');
    else
        fprintf('  [Skip] run_records not found, convergence figures not exported.\n');
    end

    fprintf('\nDone. FAIR-INIT paper artifacts exported.\n');
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