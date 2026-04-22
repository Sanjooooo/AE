function make_uav_ablation_convergence_paper_v2(resultDir, outFigDir)
%MAKE_UAV_ABLATION_CONVERGENCE_PAPER_V2
% 仅用于 UAV 消融实验收敛曲线图。
%
% 数据场景：
%   1 / 2 / 4
% 论文显示：
%   1 / 2 / 3
%
% 出图策略：
%   Scene 1 : 线性主图 + inset
%   Scene 2 : semilogy 主图 + 线性 inset
%   Scene 3 : semilogy 主图 + 线性 inset
%
% 精确匹配 run_records 中的安全文件名：
%   BASE_AE
%   AE_INIT
%   AE_INIT_AOS
%   AE_INIT_AOS_REPAIR
%   FAEAE
%
% 用法：
%   make_uav_ablation_convergence_paper_v2(resultDir)
%   make_uav_ablation_convergence_paper_v2(resultDir, outFigDir)

    if nargin < 1 || isempty(resultDir)
        error('Please provide resultDir.');
    end
    if nargin < 2 || isempty(outFigDir)
        outFigDir = resultDir;
    end
    if ~exist(outFigDir, 'dir')
        mkdir(outFigDir);
    end

    runDir = fullfile(resultDir, 'run_records');
    if ~exist(runDir, 'dir')
        error('Cannot find run_records folder: %s', runDir);
    end

    algMap = { ...
        'Base-AE',            'BASE_AE'; ...
        'AE+Init',            'AE_INIT'; ...
        'AE+Init+AOS',        'AE_INIT_AOS'; ...
        'AE+Init+AOS+Repair', 'AE_INIT_AOS_REPAIR'; ...
        'FAEAE',              'FAEAE'};

    % 保留真实数据场景编号
    sceneList = [1 2 4];

    fprintf('\n=== Make UAV Ablation Convergence Figures ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Run folder   : %s\n', runDir);
    fprintf('Output folder: %s\n\n', outFigDir);

    for s = 1:numel(sceneList)
        sid = sceneList(s);                     % 真实数据场景：1/2/4
        displaySid = localDisplaySceneId(sid); % 论文显示：1/2/3

        fprintf('Scene %d (data scene %d):\n', displaySid, sid);

        % ================================================================
        % 先收集当前场景下所有算法的平均收敛曲线
        % ================================================================
        meanCurves = cell(1, size(algMap,1));
        validMask = false(1, size(algMap,1));
        commonLen = 0;

        for a = 1:size(algMap,1)
            showName = algMap{a,1};
            safeName = algMap{a,2};

            files = dir(fullfile(runDir, sprintf('scene%d_%s_run*.mat', sid, safeName)));
            if isempty(files)
                fprintf('  %-18s | no run files found.\n', showName);
                continue;
            end

            curves = {};
            for k = 1:numel(files)
                try
                    S = load(fullfile(files(k).folder, files(k).name));
                    rr = localExtractResultStruct(S);
                    conv = localExtractConvergenceCurve(rr);
                    if ~isempty(conv)
                        curves{end+1} = conv(:); %#ok<AGROW>
                    end
                catch
                    % ignore broken file
                end
            end

            if isempty(curves)
                fprintf('  %-18s | no valid convergence data.\n', showName);
                continue;
            end

            meanCurve = localMeanCurve(curves);
            meanCurves{a} = meanCurve(:);
            validMask(a) = true;
            commonLen = max(commonLen, numel(meanCurve));

            fprintf('  %-18s | valid runs used = %d | curve length = %d\n', ...
                showName, numel(curves), numel(meanCurve));
        end

        if commonLen == 0
            warning('UAV:AblationNoCurve', ...
                'Scene %d (data scene %d) 未提取到任何有效曲线，跳过。', ...
                displaySid, sid);
            continue;
        end

        % 补齐长度，避免曲线提前结束
        for a = 1:size(algMap,1)
            if validMask(a)
                meanCurves{a} = localPadCurveToLength(meanCurves{a}, commonLen);
            end
        end

        % ================================================================
        % 绘图
        % ================================================================
        fig = figure('Color', 'w', 'Position', [80 80 1100 700]);
        axMain = axes(fig);
        hold(axMain, 'on');
        grid(axMain, 'on');
        box(axMain, 'on');

        legendHandles = [];
        legendNames = {};

        useSemiLogMain = (displaySid == 2 || displaySid == 3);

        for a = 1:size(algMap,1)
            if ~validMask(a)
                continue;
            end

            showName = algMap{a,1};
            y = meanCurves{a};
            style = localAlgStyleAblation(showName, algMap(:,1));

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
            legendNames{end+1} = showName; %#ok<AGROW>
        end

        xlabel(axMain, 'Iteration', 'FontName', 'Times New Roman', 'FontSize', 13);
        ylabel(axMain, 'Best-so-far cost', 'FontName', 'Times New Roman', 'FontSize', 13);
        title(axMain, sprintf('Scene %d Ablation Convergence', displaySid), ...
            'FontName', 'Times New Roman', 'FontSize', 13, 'FontWeight', 'bold');

        set(axMain, ...
            'FontName', 'Times New Roman', ...
            'FontSize', 11, ...
            'LineWidth', 1.0, ...
            'GridAlpha', 0.18, ...
            'MinorGridAlpha', 0.10);

        xlim(axMain, [1, commonLen]);

        % Scene 1 用线性主图时，自动稍微收紧纵轴
        if displaySid == 1
            yy = [];
            for a = 1:size(algMap,1)
                if validMask(a)
                    yy = [yy; meanCurves{a}(:)]; %#ok<AGROW>
                end
            end
            ymin = min(yy);
            ymax = max(yy);
            if ymax > ymin
                pad = 0.05 * (ymax - ymin);
                ylim(axMain, [ymin - pad, ymax + pad]);
            end
        end

        if ~isempty(legendHandles)
            legend(axMain, legendHandles, legendNames, ...
                'Location', 'northeast', ...
                'Interpreter', 'none', ...
                'Box', 'on', ...
                'FontSize', 10);
        end

        % ================================================================
        % inset：统一用线性局部放大
        % ================================================================
        [xInset, yInset, insetPos] = localSceneInsetParamsAblation(displaySid);

        axInset = axes('Parent', fig, 'Position', insetPos);
        hold(axInset, 'on');
        grid(axInset, 'on');
        box(axInset, 'on');

        for a = 1:size(algMap,1)
            if ~validMask(a)
                continue;
            end

            showName = algMap{a,1};
            y = meanCurves{a};
            style = localAlgStyleAblation(showName, algMap(:,1));

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

        axInset.TickDir = 'in';

        set(axMain, 'LooseInset', max(get(axMain, 'TightInset'), 0.02));

        [pngName, figName] = localAblationFilenames(displaySid);
        savefig(fig, fullfile(outFigDir, figName));
        exportgraphics(fig, fullfile(outFigDir, pngName), 'Resolution', 300);
        close(fig);

        fprintf('  Saved: %s\n', fullfile(outFigDir, pngName));
        fprintf('  Saved: %s\n\n', fullfile(outFigDir, figName));
    end
end

%% ========================================================================
function rr = localExtractResultStruct(S)
    if isfield(S, 'result') && isstruct(S.result)
        rr = S.result;
        return;
    end

    fns = fieldnames(S);
    for i = 1:numel(fns)
        if isstruct(S.(fns{i}))
            rr = S.(fns{i});
            return;
        end
    end

    error('Cannot find result struct in mat file.');
end

%% ========================================================================
function conv = localExtractConvergenceCurve(rr)
    conv = [];

    candidateFields = { ...
        'convergence', ...
        'bestHist', ...
        'bestCostHistory', ...
        'bestFitHistory', ...
        'bestFitnessHistory', ...
        'curve', ...
        'costHistory', ...
        'fitnessCurve', ...
        'gbestHistory', ...
        'fbestHistory'};

    for i = 1:numel(candidateFields)
        fn = candidateFields{i};
        if isfield(rr, fn)
            v = rr.(fn);
            if isnumeric(v) && ~isempty(v)
                conv = localForceVector(v);
                conv = conv(isfinite(conv));
                if ~isempty(conv)
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
                        conv = localForceVector(v);
                        conv = conv(isfinite(conv));
                        if ~isempty(conv)
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
function style = localAlgStyleAblation(showName, allNames)
    algColors = lines(numel(allNames));
    idx = find(strcmpi(allNames, showName), 1);
    if isempty(idx)
        idx = 1;
    end

    style.Color = algColors(idx,:);
    style.LineWidth = 1.6;

    if strcmpi(showName, 'FAEAE')
        style.LineWidth = 2.2;
    end
end

%% ========================================================================
function displaySid = localDisplaySceneId(sid)
    switch sid
        case 4
            displaySid = 3;   % 数据 scene 4 -> 论文 Scene 3
        otherwise
            displaySid = sid;
    end
end

%% ========================================================================
function [xInset, yInset, insetPos] = localSceneInsetParamsAblation(displaySid)
% inset 范围按你当前论文消融图的有效比较区间设置

    switch displaySid
        case 1
            xInset = [230, 300];
            yInset = [302, 304];
            insetPos = [0.40, 0.45, 0.40, 0.40];

        case 2
            xInset = [230, 300];
            yInset = [315, 350];
            insetPos = [0.40, 0.45, 0.40, 0.40];

        case 3
            xInset = [269, 272];
            yInset = [329.5, 331];
            insetPos = [0.40, 0.55, 0.35, 0.35];

        otherwise
            xInset = [1, 10];
            yInset = [0, 1];
            insetPos = [0.50, 0.55, 0.27, 0.27];
    end
end

%% ========================================================================
function [pngName, figName] = localAblationFilenames(displaySid)
    switch displaySid
        case 1
            stem = 'fig_scene1_ablation_convergence';
        case 2
            stem = 'fig_scene2_ablation_convergence';
        case 3
            stem = 'fig_scene3_ablation_convergence';
        otherwise
            stem = sprintf('scene%d_ablation_convergence', displaySid);
    end

    pngName = [stem, '.png'];
    figName = [stem, '.fig'];
end