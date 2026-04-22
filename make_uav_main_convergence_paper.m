function make_uav_main_convergence_paper(resultDir, outDir)
%MAKE_UAV_MAIN_CONVERGENCE_PAPER
% 只基于已有 run_records 结果，生成 UAV 主实验 3 张收敛曲线图：
%   - 数据场景 1 -> 论文显示 Scene 1
%   - 数据场景 2 -> 论文显示 Scene 2
%   - 数据场景 4 -> 论文显示 Scene 3
%
% 不会重新跑实验。
%
% 出图策略：
%   Scene 1 : 线性主图 + inset
%   Scene 2 : semilogy 主图 + 线性 inset
%   Scene 3 : semilogy 主图 + 线性 inset
%
% 输出：
%   fig4_4_scene1_convergence_main.png/.fig
%   fig4_5_scene2_convergence_main.png/.fig
%   fig4_6_scene3_convergence_main.png/.fig

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

    runDir = fullfile(resultDir, 'run_records');
    if ~exist(runDir, 'dir')
        error('未找到 run_records 目录：%s', runDir);
    end

    % 保留真实数据场景编号
    sceneIds = [1, 2, 4];
    algOrder = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};

    fprintf('\n=== Make UAV Main Convergence Figures ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Run folder   : %s\n', runDir);
    fprintf('Output folder: %s\n\n', outDir);

    for s = 1:numel(sceneIds)
        sceneId = sceneIds(s);                          % 真实数据场景：1/2/4
        displaySceneId = localDisplaySceneId(sceneId); % 论文显示：1/2/3

        fprintf('Scene %d (data scene %d):\n', displaySceneId, sceneId);

        % ================================================================
        % 先收集当前场景下所有算法的平均收敛曲线
        % ================================================================
        meanCurves = cell(1, numel(algOrder));
        commonLen = 0;
        validMask = false(1, numel(algOrder));

        for a = 1:numel(algOrder)
            algName = algOrder{a};
            files = localFindRunFiles(runDir, sceneId, algName);

            if isempty(files)
                fprintf('  %-6s | no run files found.\n', algName);
                continue;
            end

            curves = {};
            for k = 1:numel(files)
                fp = fullfile(files(k).folder, files(k).name);
                try
                    S = load(fp);
                    rr = localExtractResultStruct(S);
                    curve = localExtractConvergenceCurve(rr);
                    if ~isempty(curve)
                        curves{end+1} = curve(:); %#ok<AGROW>
                    end
                catch
                    % ignore broken file
                end
            end

            if isempty(curves)
                fprintf('  %-6s | no valid convergence curve found.\n', algName);
                continue;
            end

            meanCurve = localMeanCurve(curves);
            meanCurves{a} = meanCurve(:);
            validMask(a) = true;
            commonLen = max(commonLen, numel(meanCurve));

            fprintf('  %-6s | valid runs used = %d | curve length = %d\n', ...
                algName, numel(curves), numel(meanCurve));
        end

        if commonLen == 0
            warning('UAV:NoCurve', ...
                'Scene %d (data scene %d) 未提取到任何有效曲线，跳过。', ...
                displaySceneId, sceneId);
            continue;
        end

        % 统一补齐长度，避免曲线提前结束
        for a = 1:numel(algOrder)
            if validMask(a)
                meanCurves{a} = localPadCurveToLength(meanCurves{a}, commonLen);
            end
        end

        % ================================================================
        % 开始绘图
        % ================================================================
        fig = figure('Color', 'w', 'Position', [80 80 1100 700]);
        axMain = axes(fig);
        hold(axMain, 'on');
        grid(axMain, 'on');
        box(axMain, 'on');

        legendHandles = [];
        legendNames = {};

        % 主图画法
        useSemiLogMain = (displaySceneId == 2 || displaySceneId == 3);

        for a = 1:numel(algOrder)
            if ~validMask(a)
                continue;
            end

            algName = algOrder{a};
            style = localAlgStyle(algName, algOrder);
            y = meanCurves{a};

            if useSemiLogMain
                yMain = y;
                yMain(yMain <= 0) = eps;
                h = semilogy(axMain, 1:commonLen, yMain, ...
                    'LineWidth', style.LineWidth, ...
                    'Color', style.Color);
            else
                h = plot(axMain, 1:commonLen, y, ...
                    'LineWidth', style.LineWidth, ...
                    'Color', style.Color);
            end

            legendHandles(end+1) = h; %#ok<AGROW>
            legendNames{end+1} = algName; %#ok<AGROW>
        end

        xlabel(axMain, 'Iteration', 'FontName', 'Times New Roman', 'FontSize', 13);
        ylabel(axMain, 'Best-so-far cost', 'FontName', 'Times New Roman', 'FontSize', 13);
        title(axMain, sprintf('Scene %d Convergence', displaySceneId), ...
            'FontName', 'Times New Roman', 'FontSize', 13, 'FontWeight', 'bold');

        set(axMain, ...
            'FontName', 'Times New Roman', ...
            'FontSize', 11, ...
            'LineWidth', 1.0, ...
            'GridAlpha', 0.18, ...
            'MinorGridAlpha', 0.10);

        xlim(axMain, [1, commonLen]);

        if displaySceneId == 1
            % Scene 1 用线性主图，纵轴自动稍微收紧
            yy = [];
            for a = 1:numel(algOrder)
                if validMask(a)
                    yy = [yy; meanCurves{a}(:)]; %#ok<AGROW>
                end
            end
            ymin = min(yy);
            ymax = max(yy);
            pad = 0.05 * (ymax - ymin);
            ylim(axMain, [ymin - pad, ymax + pad]);
        else
            % Scene 2/3 主图用 semilogy，通常不用强行设 ylim
        end

            if ~isempty(legendHandles)
            if displaySceneId == 1
                legend(axMain, legendHandles, legendNames, ...
                    'Location', 'northeast', ...
                    'Interpreter', 'none', ...
                    'Box', 'on', ...
                    'FontSize', 10);
            else
                legend(axMain, legendHandles, legendNames, ...
                    'Location', 'northeast', ...
                    'Interpreter', 'none', ...
                    'Box', 'on', ...
                    'FontSize', 10);
            end
        end

        % ================================================================
        % inset：统一用线性局部放大
        % ================================================================
        [xInset, yInset, insetPos] = localSceneInsetParams(displaySceneId);

        axInset = axes('Parent', fig, 'Position', insetPos);
        hold(axInset, 'on');
        grid(axInset, 'on');
        box(axInset, 'on');

        for a = 1:numel(algOrder)
            if ~validMask(a)
                continue;
            end

            algName = algOrder{a};
            style = localAlgStyle(algName, algOrder);
            y = meanCurves{a};

            plot(axInset, 1:commonLen, y, ...
                'LineWidth', style.LineWidth * 0.95, ...
                'Color', style.Color);
        end

        xlim(axInset, xInset);
        ylim(axInset, yInset);

        set(axInset, ...
            'FontName', 'Times New Roman', ...
            'FontSize', 9, ...
            'LineWidth', 0.9, ...
            'GridAlpha', 0.16, ...
            'MinorGridAlpha', 0.08);

        % inset 不显示坐标标签，只保留刻度
        axInset.TickDir = 'in';

        set(axMain, 'LooseInset', max(get(axMain, 'TightInset'), 0.02));

        [pngName, figName] = localSceneConvFilenames(displaySceneId);
        savefig(fig, fullfile(outDir, figName));
        exportgraphics(fig, fullfile(outDir, pngName), 'Resolution', 300);
        close(fig);

        fprintf('  Saved: %s\n', fullfile(outDir, pngName));
        fprintf('  Saved: %s\n\n', fullfile(outDir, figName));
    end

    fprintf('Done.\n');
end

%% ========================================================================
function files = localFindRunFiles(runDir, sceneId, algName)
    pattern1 = fullfile(runDir, sprintf('scene%d_%s_run*.mat', sceneId, upper(algName)));
    files = dir(pattern1);

    if ~isempty(files)
        return;
    end

    allSceneFiles = dir(fullfile(runDir, sprintf('scene%d_*run*.mat', sceneId)));
    if isempty(allSceneFiles)
        files = [];
        return;
    end

    names = upper(string({allSceneFiles.name}));
    mask = contains(names, upper(string(algName)));
    files = allSceneFiles(mask);
end

%% ========================================================================
function rr = localExtractResultStruct(S)
    rr = [];

    if isfield(S, 'result') && isstruct(S.result)
        rr = S.result;
        return;
    end

    fns = fieldnames(S);
    if numel(fns) == 1 && isstruct(S.(fns{1}))
        rr = S.(fns{1});
        return;
    end

    if isstruct(S)
        rr = S;
    end
end

%% ========================================================================
function curve = localExtractConvergenceCurve(rr)
    curve = [];

    candidateFields = { ...
        'bestFitHistory', ...
        'bestFitnessHistory', ...
        'bestCostHistory', ...
        'convergence', ...
        'curve', ...
        'fitnessCurve', ...
        'costHistory', ...
        'gbestHistory', ...
        'fbestHistory'};

    for i = 1:numel(candidateFields)
        fn = candidateFields{i};
        if isfield(rr, fn)
            v = rr.(fn);
            if isnumeric(v) && ~isempty(v)
                curve = localForceVector(v);
                curve = curve(isfinite(curve));
                if ~isempty(curve)
                    return;
                end
            end
        end
    end

    nestedFields = {'history', 'stats', 'resultHistory', 'summary'};
    for i = 1:numel(nestedFields)
        nf = nestedFields{i};
        if isfield(rr, nf) && isstruct(rr.(nf))
            sub = rr.(nf);
            for j = 1:numel(candidateFields)
                fn = candidateFields{j};
                if isfield(sub, fn)
                    v = sub.(fn);
                    if isnumeric(v) && ~isempty(v)
                        curve = localForceVector(v);
                        curve = curve(isfinite(curve));
                        if ~isempty(curve)
                            return;
                        end
                    end
                end
            end
        end
    end
end

%% ========================================================================
function v = localForceVector(x)
    if isempty(x) || ~isnumeric(x)
        v = [];
        return;
    end

    if isvector(x)
        v = x(:);
    else
        if size(x,1) >= size(x,2)
            v = x(:,1);
        else
            v = x(1,:).';
        end
    end
end

%% ========================================================================
function meanCurve = localMeanCurve(curves)
    n = numel(curves);
    maxLen = max(cellfun(@numel, curves));

    M = nan(n, maxLen);

    for i = 1:n
        c = curves{i}(:);
        L = numel(c);
        M(i,1:L) = c(:);
        if L < maxLen
            M(i,L+1:end) = c(end);
        end
    end

    meanCurve = mean(M, 1, 'omitnan');
end

%% ========================================================================
function c = localPadCurveToLength(c, targetLen)
    c = c(:);
    L = numel(c);

    if L >= targetLen
        c = c(1:targetLen);
        return;
    end

    c(L+1:targetLen) = c(end);
end

%% ========================================================================
function style = localAlgStyle(algName, algOrder)
    algColors = lines(numel(algOrder));
    idx = find(strcmpi(algOrder, algName), 1);

    if isempty(idx)
        idx = 1;
    end

    style.Color = algColors(idx,:);
    style.LineWidth = 1.6;

    if strcmpi(algName, 'FAEAE')
        style.LineWidth = 2.2;
    end
end

%% ========================================================================
function displaySceneId = localDisplaySceneId(sceneId)
    switch sceneId
        case 4
            displaySceneId = 3;   % 数据里的 Scene 4，在论文里显示为 Scene 3
        otherwise
            displaySceneId = sceneId;
    end
end

function [xInset, yInset, insetPos] = localSceneInsetParams(displaySceneId)
% inset 坐标范围与位置
% insetPos = [left bottom width height]，相对于 figure 归一化坐标

    switch displaySceneId
        case 1
            % Scene 1：线性主图 + 尾部放大
            xInset = [220, 300];
            yInset = [280, 350];
            insetPos = [0.40, 0.45, 0.40, 0.40];

        case 2
            % Scene 2：semilogy 主图 + 尾部线性放大
            xInset = [230, 300];
            yInset = [300, 900];
            insetPos = [0.40, 0.42, 0.40, 0.40];

        case 3
            % Scene 3：semilogy 主图 + 尾部线性放大
            xInset = [220, 300];
            yInset = [270, 1800];
            insetPos = [0.40, 0.42, 0.40, 0.40];

        otherwise
            xInset = [1, 10];
            yInset = [0, 1];
            insetPos = [0.50, 0.55, 0.27, 0.27];
    end
end

%% ========================================================================
function [pngName, figName] = localSceneConvFilenames(displaySceneId)
    switch displaySceneId
        case 1
            stem = 'fig4_4_scene1_convergence_main';
        case 2
            stem = 'fig4_5_scene2_convergence_main';
        case 3
            stem = 'fig4_6_scene3_convergence_main';
        otherwise
            stem = sprintf('scene%d_convergence_main', displaySceneId);
    end

    pngName = [stem, '.png'];
    figName = [stem, '.fig'];
end