%% batch_export_fig_to_pdf.m
% 批量将同一文件夹中的 .fig 文件导出为高质量 PDF
% 用法：
% 1) 把本脚本放到保存 .fig 的文件夹里，直接运行
% 2) 或者修改 inputFolder 为你的 .fig 文件夹路径

clc; clear; close all;

%% ===== 1. 输入/输出文件夹 =====
% 方法A：当前脚本所在文件夹
inputFolder = "F:\MATLAB_Project\FAEAE_matlab\figure";

% 方法B：手动指定文件夹（需要时取消注释）
% inputFolder = 'F:\MATLAB_Project\your_fig_folder';

outputFolder = fullfile(inputFolder, 'pdf_export');
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

%% ===== 2. 获取所有 .fig 文件 =====
figFiles = dir(fullfile(inputFolder, '*.fig'));

if isempty(figFiles)
    error('在文件夹中没有找到 .fig 文件：%s', inputFolder);
end

fprintf('找到 %d 个 .fig 文件。\n', numel(figFiles));
fprintf('输出文件夹：%s\n\n', outputFolder);

%% ===== 3. 批量导出 =====
for k = 1:numel(figFiles)
    figName = figFiles(k).name;
    figPath = fullfile(inputFolder, figName);

    [~, baseName, ~] = fileparts(figName);
    pdfPath = fullfile(outputFolder, [baseName, '.pdf']);

    fprintf('[%d/%d] 正在导出：%s\n', k, numel(figFiles), figName);

    try
        % 隐藏打开 .fig
        hFig = openfig(figPath, 'invisible');

        % 保证白底，避免透明背景带来问题
        set(hFig, 'Color', 'w');

        % 让导出尺寸尽量保持和 figure 当前显示一致
        set(hFig, 'PaperPositionMode', 'auto');

        % 推荐：优先用 exportgraphics 导出矢量 PDF
        try
            exportgraphics(hFig, pdfPath, ...
                'ContentType', 'vector', ...
                'BackgroundColor', 'white');
        catch
            % 如果 exportgraphics 不可用或失败，退回 print
            set(hFig, 'Renderer', 'painters');   % 矢量渲染
            print(hFig, pdfPath, '-dpdf', '-painters', '-bestfit');
        end

        close(hFig);
        fprintf('    导出成功 -> %s\n\n', pdfPath);

    catch ME
        fprintf('    导出失败：%s\n', figName);
        fprintf('    错误信息：%s\n\n', ME.message);

        % 防止异常时图窗残留
        try
            close(hFig);
        catch
        end
    end
end

fprintf('全部导出完成。\n');