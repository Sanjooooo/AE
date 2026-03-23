function make_uav_ablation_mean_cost_bar(resultDir, outDir)
%MAKE_UAV_ABLATION_MEAN_COST_BAR
% 读取已有 ablation summary 文件，生成 UAV 消融实验 mean cost 合并柱状图。
% 不重新跑实验。
%
% 颜色与 plot_ablation_paper_figures.m 完全一致：
%   methodNames = {'Base-AE','AE+Init','AE+Init+AOS','AE+Init+AOS+Repair','FAE-AE'}
%   methodColors = lines(numel(methodNames))
%
% 输出：
%   fig4_14_uav_ablation_mean_cost.png/.fig
%
% 用法：
%   make_uav_ablation_mean_cost_bar
%   make_uav_ablation_mean_cost_bar(pwd)
%   make_uav_ablation_mean_cost_bar(pwd, 'paper_final_figures')

    if nargin < 1 || isempty(resultDir)
        resultDir = pwd;
    end
    if nargin < 2 || isempty(outDir)
        outDir = 'paper_final_figures';
    end

    if ~exist(resultDir, 'dir')
        error('目录不存在：%s', resultDir);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    summaryLong = fullfile(resultDir, 'ablation_paper_figures', 'ablation_paper_summary_long.csv');
    summaryWide = fullfile(resultDir, 'ablation_paper_figures', 'ablation_paper_summary_wide.csv');

    if exist(summaryLong, 'file')
        T = readtable(summaryLong);
        sourceUsed = summaryLong;
    elseif exist(summaryWide, 'file')
        T = readtable(summaryWide);
        sourceUsed = summaryWide;
    else
        error('未找到 ablation summary 文件。请确认存在：\n%s\n或\n%s', summaryLong, summaryWide);
    end

    fprintf('\n=== Make UAV Ablation Mean Cost Bar Figure ===\n');
    fprintf('Source used: %s\n', sourceUsed);
    fprintf('Output dir : %s\n\n', outDir);

    sceneOrder = [1, 2, 4];
    sceneLabels = {'Scene 1', 'Scene 2', 'Scene 4'};

    % 与 plot_ablation_paper_figures 完全一致的顺序
    methodNames = { ...
        'Base-AE', ...
        'AE+Init', ...
        'AE+Init+AOS', ...
        'AE+Init+AOS+Repair', ...
        'FAE-AE'};

    % 与 plot_ablation_paper_figures 完全一致的颜色
    methodColors = lines(numel(methodNames));

    [sceneCol, algCol, meanCol, stdCol] = localDetectColumns(T);

    means = nan(numel(sceneOrder), numel(methodNames));
    stds  = nan(numel(sceneOrder), numel(methodNames));

    for i = 1:numel(sceneOrder)
        sid = sceneOrder(i);
        for j = 1:numel(methodNames)
            method = methodNames{j};

            mask = localMatchScene(T.(sceneCol), sid) & localMatchMethod(T.(algCol), method);
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

    fig = figure('Color', 'w', 'Position', [100 100 1260 760]);
    hold on;
    box on;
    grid on;

    bh = bar(means, 'grouped', 'LineWidth', 1.0);

    % 明确逐方法着色，确保与 plot_ablation_paper_figures 一致
    for j = 1:numel(methodNames)
        bh(j).FaceColor = methodColors(j,:);
        bh(j).EdgeColor = 'k';
    end

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
    title('UAV Ablation Experiment Mean Cost Comparison', ...
        'FontName', 'Times New Roman', 'FontSize', 14, 'FontWeight', 'bold');

    legend(methodNames, 'Location', 'northeastoutside', 'Interpreter', 'none');

    outFig = fullfile(outDir, 'fig4_14_uav_ablation_mean_cost.fig');
    outPng = fullfile(outDir, 'fig4_14_uav_ablation_mean_cost.png');

    savefig(fig, outFig);
    exportgraphics(fig, outPng, 'Resolution', 300);
    close(fig);

    fprintf('Saved: %s\n', outPng);
    fprintf('Saved: %s\n', outFig);
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
    if ~isempty(idx), sceneCol = varNames{idx}; else, error('未识别到 scene 列。'); end

    idx = find(ismember(vnLower, ["algorithm","alg","algname","method","methodname"]), 1);
    if ~isempty(idx), algCol = varNames{idx}; else, error('未识别到 algorithm/method 列。'); end

    idx = find(ismember(vnLower, ["mean","avg","meancost","average"]), 1);
    if ~isempty(idx), meanCol = varNames{idx}; else, error('未识别到 mean 列。'); end

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
function tf = localMatchMethod(methodSeries, methodName)
    s = upper(string(methodSeries));
    tf = s == upper(string(methodName));
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