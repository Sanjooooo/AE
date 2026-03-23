function make_fig2_2_control_bspline_demo(outDir)
%MAKE_FIG2_2_CONTROL_BSPLINE_DEMO
% 生成图2-2：路径控制点表示与样条解码示意图
%
% 输出：
%   fig2_2_control_bspline_demo.png
%   fig2_2_control_bspline_demo.fig
%
% 用法：
%   make_fig2_2_control_bspline_demo
%   make_fig2_2_control_bspline_demo('paper_final_figures')
%
% 说明：
% - 不重新跑实验
% - 只生成说明图
% - 优先调用工程中的 bsplinePath
% - 若 bsplinePath 调用失败，则退化为 spline 插值示意
% - 该版本针对中文论文排版做了轻量优化：
%   * 去掉英文大标题
%   * 调整为更平缓的 3D 视角
%   * 缩小图例和标注，提升版面适配性

    if nargin < 1 || isempty(outDir)
        outDir = 'paper_final_figures';
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % ------------------------------------------------------------
    % 1) 构造一组示意性控制点
    % ------------------------------------------------------------
    p_s = [5,   8,  10];
    q1  = [18, 14, 12];
    q2  = [28, 24, 11];
    q3  = [42, 20, 14];
    q4  = [55, 34, 13];
    q5  = [70, 42, 15];
    p_g = [85, 55, 12];

    ctrlPts = [
        p_s;
        q1;
        q2;
        q3;
        q4;
        q5;
        p_g
    ];

    % 为了让说明图更有“曲线解码”的视觉差异，内部插值时采用轻微抬升的示意控制高度
    ctrlPtsDemo = ctrlPts;
    ctrlPtsDemo(2,3) = 6;
    ctrlPtsDemo(3,3) = 1;
    ctrlPtsDemo(4,3) = 7;
    ctrlPtsDemo(5,3) = 17;
    ctrlPtsDemo(6,3) = 28;
    ctrlPtsDemo(7,3) = 35;

    % ------------------------------------------------------------
    % 2) 样条解码
    % ------------------------------------------------------------
    smoothPath = localGenerateSmoothPath(ctrlPtsDemo);

    % ------------------------------------------------------------
    % 3) 绘图
    % ------------------------------------------------------------
    fig = figure('Color', 'w', 'Position', [120 120 980 700]);
    hold on;
    grid on;
    box on;
    axis equal;

    % 更适合说明图的视角：略俯视、不过分陡峭
    view(42, 22);

    % 控制点折线
    h1 = plot3(ctrlPtsDemo(:,1), ctrlPtsDemo(:,2), ctrlPtsDemo(:,3), ...
        '--o', ...
        'LineWidth', 1.4, ...
        'MarkerSize', 5.5, ...
        'Color', [0.30 0.30 0.30], ...
        'MarkerFaceColor', [0.30 0.30 0.30]);

    % 平滑轨迹
    h2 = plot3(smoothPath(:,1), smoothPath(:,2), smoothPath(:,3), ...
        '-', ...
        'LineWidth', 2.6, ...
        'Color', [0.00 0.45 0.74]);

    % 起点终点
    h3 = plot3(p_s(1), p_s(2), ctrlPtsDemo(1,3), ...
        's', 'MarkerSize', 9, ...
        'MarkerFaceColor', [0.10 0.70 0.10], ...
        'MarkerEdgeColor', 'k');

    h4 = plot3(p_g(1), p_g(2), ctrlPtsDemo(end,3), ...
        'p', 'MarkerSize', 11, ...
        'MarkerFaceColor', [0.85 0.10 0.10], ...
        'MarkerEdgeColor', 'k');

    % 标注
    text(p_s(1), p_s(2), ctrlPtsDemo(1,3), '  p_s', ...
        'FontName', 'Times New Roman', 'FontSize', 11, 'FontWeight', 'bold');

    for i = 2:size(ctrlPtsDemo,1)-1
        text(ctrlPtsDemo(i,1), ctrlPtsDemo(i,2), ctrlPtsDemo(i,3), sprintf('  q_%d', i-1), ...
            'FontName', 'Times New Roman', 'FontSize', 10);
    end

    text(p_g(1), p_g(2), ctrlPtsDemo(end,3), '  p_g', ...
        'FontName', 'Times New Roman', 'FontSize', 11, 'FontWeight', 'bold');

    xlabel('X', 'FontName', 'Times New Roman', 'FontSize', 12);
    ylabel('Y', 'FontName', 'Times New Roman', 'FontSize', 12);
    zlabel('Z', 'FontName', 'Times New Roman', 'FontSize', 12);

    % 不在图内放英文大标题，交给正文图题处理
    title('');

    lgd = legend([h1, h2, h3, h4], ...
        {'Control polygon', 'B-spline path', 'Start point', 'Goal point'}, ...
        'Location', 'northeastoutside', 'Interpreter', 'none');
    lgd.FontName = 'Times New Roman';
    lgd.FontSize = 10;
    lgd.Box = 'on';

    set(gca, ...
        'FontName', 'Times New Roman', ...
        'FontSize', 11, ...
        'LineWidth', 1.0);

    % 让坐标范围更紧凑
    xlim([0, 90]);
    ylim([0, 60]);
    zlim([0, 40]);

    camlight headlight;
    lighting gouraud;

    outFig = fullfile(outDir, 'fig2_2_control_bspline_demo.fig');
    outPng = fullfile(outDir, 'fig2_2_control_bspline_demo.png');

    savefig(fig, outFig);
    exportgraphics(fig, outPng, 'Resolution', 300);
    close(fig);

    fprintf('Saved: %s\n', outPng);
    fprintf('Saved: %s\n', outFig);
end

%% ========================================================================
function smoothPath = localGenerateSmoothPath(ctrlPts)
% 优先调用项目里的 bsplinePath；失败时用 spline 插值回退

    smoothPath = [];

    if exist('bsplinePath', 'file') == 2
        try
            smoothPath = bsplinePath(ctrlPts);
        catch
            smoothPath = [];
        end

        if isempty(smoothPath)
            try
                smoothPath = bsplinePath(ctrlPts, 3);
            catch
                smoothPath = [];
            end
        end

        if isempty(smoothPath)
            try
                smoothPath = bsplinePath(ctrlPts, 3, 200);
            catch
                smoothPath = [];
            end
        end
    end

    if isempty(smoothPath)
        t = 1:size(ctrlPts,1);
        tt = linspace(1, size(ctrlPts,1), 200);

        xx = spline(t, ctrlPts(:,1), tt);
        yy = spline(t, ctrlPts(:,2), tt);
        zz = spline(t, ctrlPts(:,3), tt);

        smoothPath = [xx(:), yy(:), zz(:)];
    end

    if size(smoothPath,2) < 3 && size(smoothPath,1) >= 3
        smoothPath = smoothPath(1:3,:)';
    elseif size(smoothPath,2) > 3
        smoothPath = smoothPath(:,1:3);
    end
end