function figs = make_uav_param_sensitivity_plot_lite_v2(resultDir)
%MAKE_UAV_PARAM_SENSITIVITY_PLOT_LITE_V2
% Draw four separate sensitivity figures from param_sensitivity_summary_long.csv.
%
% Usage:
%   make_uav_param_sensitivity_plot_lite_v2('results_uav_param_sensitivity_lite_v2_xxx');
%
% Output:
%   figs: handles of the four generated figures.
%
% Generated files:
%   fig_param_sensitivity_a_ucb_c.fig/.pdf/.png
%   fig_param_sensitivity_b_aos_freeze_frac.fig/.pdf/.png
%   fig_param_sensitivity_c_repair_elite_frac.fig/.pdf/.png
%   fig_param_sensitivity_d_stagnation_window.fig/.pdf/.png

    if nargin < 1 || isempty(resultDir)
        error('Please provide resultDir.');
    end

    csvFile = fullfile(resultDir, 'param_sensitivity_summary_long.csv');
    if ~exist(csvFile, 'file')
        error('Cannot find file: %s', csvFile);
    end

    T = readtable(csvFile);

    paramOrder = {'aos_c', 'aosFreezeFrac', 'repairEliteFrac', 'regenWindow'};

    xLabelText = { ...
        'UCB coefficient c', ...
        'AOS freeze fraction', ...
        'Repair elite fraction', ...
        'Stagnation window W'};

    fileSuffix = { ...
        'a_ucb_c', ...
        'b_aos_freeze_frac', ...
        'c_repair_elite_frac', ...
        'd_stagnation_window'};

    figs = gobjects(numel(paramOrder), 1);

    for i = 1:numel(paramOrder)

        figs(i) = figure('Color', 'w', 'Position', [100, 100, 560, 420]);
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

        xlabel(xLabelText{i}, 'Interpreter', 'none');
        ylabel('Mean cost');

        % No title is used here, following journal figure-format guidelines.
        lgd = legend('Location', 'best');
        set(lgd, 'Box', 'on');   % 如果你希望图例带方框，可保留；不需要可删掉
        grid on;

        set(gca, 'FontName', 'Times New Roman', 'FontSize', 11);
        set(gca, 'LineWidth', 0.8);

        hold off;

        baseName = sprintf('fig_param_sensitivity_%s', fileSuffix{i});
        figFile = fullfile(resultDir, [baseName, '.fig']);
        pdfFile = fullfile(resultDir, [baseName, '.pdf']);
        pngFile = fullfile(resultDir, [baseName, '.png']);

        % 保存 MATLAB 原始图文件
        savefig(figs(i), figFile);

        % 导出 PDF 和 PNG
        exportgraphics(figs(i), pdfFile, 'ContentType', 'vector');
        exportgraphics(figs(i), pngFile, 'Resolution', 300);

        fprintf('Saved:\n');
        fprintf(' %s\n', figFile);
        fprintf(' %s\n', pdfFile);
        fprintf(' %s\n', pngFile);
    end
end