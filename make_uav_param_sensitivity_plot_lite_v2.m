function fig = make_uav_param_sensitivity_plot_lite_v2(resultDir)
%MAKE_UAV_PARAM_SENSITIVITY_PLOT_LITE_V2
% Draw a 2x2 sensitivity figure from param_sensitivity_summary_long.csv.
%
% Usage:
%   make_uav_param_sensitivity_plot_lite_v2('results_uav_param_sensitivity_lite_v2_xxx');

    if nargin < 1 || isempty(resultDir)
        error('Please provide resultDir.');
    end

    csvFile = fullfile(resultDir, 'param_sensitivity_summary_long.csv');
    if ~exist(csvFile, 'file')
        error('Cannot find file: %s', csvFile);
    end

    T = readtable(csvFile);

    paramOrder = {'aos_c', 'aosFreezeFrac', 'repairEliteFrac', 'regenWindow'};
    titleText = { ...
        'UCB coefficient c', ...
        'AOS freeze fraction', ...
        'Repair elite fraction', ...
        'Stagnation window W'};

    fig = figure('Color', 'w', 'Position', [100, 100, 1000, 760]);
    tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    for i = 1:numel(paramOrder)
        nexttile;
        hold on;
        box on;

        maskP = strcmp(T.ParamKey, paramOrder{i});

        for paperScene = [2, 3]
            mask = maskP & T.PaperScene == paperScene;
            Ts = sortrows(T(mask, :), 'ParamValue');

            plot(Ts.ParamValue, Ts.MeanCost, '-o', ...
                'LineWidth', 1.4, ...
                'MarkerSize', 6, ...
                'DisplayName', sprintf('Scene %d', paperScene));
        end

        xlabel(titleText{i}, 'Interpreter', 'none');
        ylabel('Mean cost');
        title(titleText{i}, 'FontWeight', 'normal');
        legend('Location', 'best');
        grid on;
        hold off;
    end

    exportgraphics(fig, fullfile(resultDir, 'fig_param_sensitivity_lite_v2.pdf'), 'ContentType', 'vector');
    exportgraphics(fig, fullfile(resultDir, 'fig_param_sensitivity_lite_v2.png'), 'Resolution', 300);

    fprintf('Saved:\n');
    fprintf(' %s\n', fullfile(resultDir, 'fig_param_sensitivity_lite_v2.pdf'));
    fprintf(' %s\n', fullfile(resultDir, 'fig_param_sensitivity_lite_v2.png'));
end