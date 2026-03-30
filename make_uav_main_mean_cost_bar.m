function make_uav_main_mean_cost_bar(resultDir, outDir)
%MAKE_UAV_MAIN_MEAN_COST_BAR
% 优先读取已有的 uav_comparison_summary_long.csv，生成 UAV 主实验 mean cost 柱状图。
% 不重新跑实验。
%
% 颜色映射与 plot_uav_representative_corridor_paths_all 保持一致：
%   algColors = lines(6)
%   顺序固定为：
%   AE / PSO / GWO / HHO / WOA / FAEAE
%
% 用法：
%   make_uav_main_mean_cost_bar
%   make_uav_main_mean_cost_bar('results_uav_6alg_formal_safe')
%   make_uav_main_mean_cost_bar('results_uav_6alg_formal_safe', 'paper_final_figures')
%
% 输出：
%   fig4_7_uav_main_mean_cost.png/.fig

    if nargin < 1 || isempty(resultDir)
        resultDir = 'results_uav_6alg_formal_safe';
    end
    if nargin < 2 || isempty(outDir)
        outDir = 'paper_final_figures';
    end

    if ~exist(resultDir, 'dir')
        error('结果目录不存在：%s', resultDir);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    summaryLong = fullfile(resultDir, 'uav_comparison_summary_long.csv');
    summaryWide = fullfile(resultDir, 'uav_comparison_summary_wide.csv');
    summaryMat  = fullfile(resultDir, 'uav_comparison_summary_workspace.mat');

    if exist(summaryLong, 'file')
        T = readtable(summaryLong);
        sourceUsed = summaryLong;
    elseif exist(summaryWide, 'file')
        T = readtable(summaryWide);
        sourceUsed = summaryWide;
    elseif exist(summaryMat, 'file')
        S = load(summaryMat);
        T = localTableFromWorkspace(S);
        sourceUsed = summaryMat;
    else
        error(['未找到主实验汇总文件。请确认至少存在以下之一：\n' ...
               '  %s\n  %s\n  %s'], summaryLong, summaryWide, summaryMat);
    end

    fprintf('\n=== Make UAV Main Mean Cost Bar Figure ===\n');
    fprintf('Source used: %s\n', sourceUsed);
    fprintf('Output dir : %s\n\n', outDir);

    sceneOrder = [1, 2, 4];
    sceneLabels = {'Scene 1', 'Scene 2', 'Scene 3'};
    algOrder = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};

    [sceneCol, algCol, meanCol, stdCol] = localDetectColumns(T);

    means = nan(numel(sceneOrder), numel(algOrder));
    stds  = nan(numel(sceneOrder), numel(algOrder));

    for i = 1:numel(sceneOrder)
        sid = sceneOrder(i);
        for j = 1:numel(algOrder)
            alg = algOrder{j};

            mask = localMatchScene(T.(sceneCol), sid) & localMatchAlg(T.(algCol), alg);
            rows = T(mask,:);

            if isempty(rows)
                continue;
            end

            means(i,j) = localToScalar(rows.(meanCol)(1));
            if ~isempty(stdCol)
                stds(i,j) = localToScalar(rows.(stdCol)(1));
            end
        end
    end

    fig = figure('Color', 'w', 'Position', [100 100 1180 760]);
    hold on;
    box on;
    grid on;

    bh = bar(means, 'grouped', 'LineWidth', 1.0);

    % 与 representative 轨迹图一致的颜色
    algColors = lines(numel(algOrder));
    for j = 1:numel(algOrder)
        bh(j).FaceColor = algColors(j,:);
        bh(j).EdgeColor = 'k';
    end

    % 误差线
    if ~all(isnan(stds), 'all')
        ngroups = size(means, 1);
        nbars = size(means, 2);

        x = nan(nbars, ngroups);
        for j = 1:nbars
            x(j,:) = bh(j).XEndPoints;
        end

        for j = 1:nbars
            errorbar(x(j,:), means(:,j), stds(:,j), ...
                'k', 'linestyle', 'none', 'LineWidth', 1.0, 'CapSize', 6);
        end
    end

    set(gca, ...
        'XTick', 1:numel(sceneOrder), ...
        'XTickLabel', sceneLabels, ...
        'FontName', 'Times New Roman', ...
        'FontSize', 12, ...
        'LineWidth', 1.0);

    xlabel('Scene', 'FontName', 'Times New Roman', 'FontSize', 13);
    ylabel('Mean cost', 'FontName', 'Times New Roman', 'FontSize', 13);
    title('UAV Main Experiment Mean Cost Comparison', ...
        'FontName', 'Times New Roman', 'FontSize', 14, 'FontWeight', 'bold');

    legend(algOrder, 'Location', 'northeastoutside', 'Interpreter', 'none');

    outFig = fullfile(outDir, 'fig4_7_uav_main_mean_cost.fig');
    outPng = fullfile(outDir, 'fig4_7_uav_main_mean_cost.png');

    savefig(fig, outFig);
    exportgraphics(fig, outPng, 'Resolution', 300);
    close(fig);

    fprintf('Saved: %s\n', outPng);
    fprintf('Saved: %s\n', outFig);
end

%% ========================================================================
function T = localTableFromWorkspace(S)
    T = [];

    fns = fieldnames(S);
    for i = 1:numel(fns)
        v = S.(fns{i});
        if istable(v)
            T = v;
            return;
        end
    end

    error('summary workspace mat 中未找到 table 变量。');
end

%% ========================================================================
function [sceneCol, algCol, meanCol, stdCol] = localDetectColumns(T)
    varNames = T.Properties.VariableNames;
    vnLower = lower(string(varNames));

    sceneCol = '';
    algCol = '';
    meanCol = '';
    stdCol = '';

    idx = find(ismember(vnLower, ["scene","sceneid","scene_id","mapid","scenarioid"]), 1);
    if ~isempty(idx)
        sceneCol = varNames{idx};
    else
        error('未识别到 scene 列。');
    end

    idx = find(ismember(vnLower, ["algorithm","alg","algname","method","methodname"]), 1);
    if ~isempty(idx)
        algCol = varNames{idx};
    else
        error('未识别到 algorithm 列。');
    end

    idx = find(ismember(vnLower, ["mean","avg","meancost","average"]), 1);
    if ~isempty(idx)
        meanCol = varNames{idx};
    else
        error('未识别到 mean 列。');
    end

    idx = find(ismember(vnLower, ["std","stdev","stddev","sigma"]), 1);
    if ~isempty(idx)
        stdCol = varNames{idx};
    else
        stdCol = '';
    end
end

%% ========================================================================
function tf = localMatchScene(sceneSeries, sceneId)
    if isnumeric(sceneSeries)
        tf = double(sceneSeries) == sceneId;
        return;
    end

    s = string(sceneSeries);
    tf = false(size(s));

    for i = 1:numel(s)
        x = strtrim(s(i));
        num = sscanf(char(x), 'Scene %d');
        if ~isempty(num)
            tf(i) = (num == sceneId);
        else
            num2 = str2double(x);
            if ~isnan(num2)
                tf(i) = (num2 == sceneId);
            end
        end
    end
end

%% ========================================================================
function tf = localMatchAlg(algSeries, algName)
    s = upper(string(algSeries));
    tf = s == upper(string(algName));
end

%% ========================================================================
function x = localToScalar(v)
    if isnumeric(v)
        x = double(v(1));
    elseif isstring(v) || ischar(v)
        x = str2double(string(v));
    else
        x = NaN;
    end
end