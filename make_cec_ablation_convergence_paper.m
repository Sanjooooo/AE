function make_cec_ablation_convergence_paper(resultDir, outDir)
%MAKE_CEC_ABLATION_CONVERGENCE_PAPER
% 基于已有 CEC 消融结果，生成总收敛图。
% 不重新跑实验。
%
% 读取优先级：
%   1) cec_ablation_export_workspace.mat
%   2) cec_ablation_batch_results.mat
%   3) run_records/   （仅 fallback）
%
% 方法顺序固定：
%   Base-AE / AE+Init / AE+Init+AOS / AE+Init+AOS+Repair / FAE-AE
%
% 输出：
%   fig4_16_cec_ablation_convergence.png/.fig
%
% 用法：
%   make_cec_ablation_convergence_paper
%   make_cec_ablation_convergence_paper('results_cec2017_ablation')
%   make_cec_ablation_convergence_paper('results_cec2017_ablation', 'paper_final_figures')

    if nargin < 1 || isempty(resultDir)
        resultDir = 'results_cec2017_ablation';
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

    exportWsFile = fullfile(resultDir, 'cec_ablation_export_workspace.mat');
    batchMatFile = fullfile(resultDir, 'cec_ablation_batch_results.mat');
    runDir = fullfile(resultDir, 'run_records');

    methodOrder = {'Base-AE', 'AE+Init', 'AE+Init+AOS', 'AE+Init+AOS+Repair', 'FAE-AE'};

    fprintf('\n=== Make CEC Ablation Convergence Figure ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Output folder: %s\n\n', outDir);

    curvesByMethod = [];

    % ---------------------------------------------------------------------
    % 1) export workspace
    % ---------------------------------------------------------------------
    if exist(exportWsFile, 'file')
        fprintf('Trying export workspace: %s\n', exportWsFile);
        try
            S = load(exportWsFile);
            curvesByMethod = localExtractCurvesFromWorkspace(S, methodOrder);
            if ~isempty(curvesByMethod)
                fprintf('Successfully extracted convergence data from export workspace.\n');
            end
        catch ME
            warning('读取 export workspace 失败：%s', ME.message);
        end
    end

    % ---------------------------------------------------------------------
    % 2) batch results
    % ---------------------------------------------------------------------
    if isempty(curvesByMethod) && exist(batchMatFile, 'file')
        fprintf('Trying batch results: %s\n', batchMatFile);
        try
            S = load(batchMatFile);
            curvesByMethod = localExtractCurvesFromWorkspace(S, methodOrder);
            if ~isempty(curvesByMethod)
                fprintf('Successfully extracted convergence data from batch results.\n');
            end
        catch ME
            warning('读取 batch results 失败：%s', ME.message);
        end
    end

    % ---------------------------------------------------------------------
    % 3) fallback: run_records
    % ---------------------------------------------------------------------
    if isempty(curvesByMethod) && exist(runDir, 'dir')
        fprintf('Trying fallback run_records: %s\n', runDir);
        curvesByMethod = localExtractCurvesFromRunRecords(runDir, methodOrder);
        if ~isempty(curvesByMethod)
            fprintf('Successfully extracted convergence data from run_records.\n');
        end
    end

    if isempty(curvesByMethod)
        error(['无法从以下位置提取 CEC 消融收敛曲线：\n' ...
               '  %s\n  %s\n  %s'], ...
               exportWsFile, batchMatFile, runDir);
    end

    fig = figure('Color', 'w', 'Position', [80 80 1100 780]);
    hold on;
    grid on;
    box on;

    legendHandles = [];
    legendNames = {};

    for a = 1:numel(methodOrder)
        methodName = methodOrder{a};
        idx = find(strcmpi({curvesByMethod.methodName}, methodName), 1);
        if isempty(idx)
            fprintf('%-18s | no curve extracted.\n', methodName);
            continue;
        end

        curveCell = curvesByMethod(idx).curves;
        if isempty(curveCell)
            fprintf('%-18s | empty curve set.\n', methodName);
            continue;
        end

        meanCurve = localMeanCurve(curveCell);

        style = localMethodStyle(methodName, methodOrder);
        h = plot(1:numel(meanCurve), meanCurve, ...
            'LineWidth', style.LineWidth, ...
            'Color', style.Color);

        legendHandles(end+1) = h; %#ok<AGROW>
        legendNames{end+1} = methodName; %#ok<AGROW>

        fprintf('%-18s | curves used = %d | final length = %d\n', ...
            methodName, numel(curveCell), numel(meanCurve));
    end

    xlabel('Iteration', 'FontName', 'Times New Roman', 'FontSize', 13);
    ylabel('Best-so-far value', 'FontName', 'Times New Roman', 'FontSize', 13);
    title('CEC2017 Ablation Average Convergence Curves', ...
        'FontName', 'Times New Roman', 'FontSize', 14, 'FontWeight', 'bold');

    set(gca, ...
        'FontName', 'Times New Roman', ...
        'FontSize', 12, ...
        'LineWidth', 1.0);

    if ~isempty(legendHandles)
        legend(legendHandles, legendNames, ...
            'Location', 'northeast', ...
            'Interpreter', 'none');
    end

    outFig = fullfile(outDir, 'fig4_16_cec_ablation_convergence.fig');
    outPng = fullfile(outDir, 'fig4_16_cec_ablation_convergence.png');

    savefig(fig, outFig);
    exportgraphics(fig, outPng, 'Resolution', 300);
    close(fig);

    fprintf('Saved: %s\n', outPng);
    fprintf('Saved: %s\n', outFig);
end

%% ========================================================================
function curvesByMethod = localExtractCurvesFromWorkspace(S, methodOrder)

    curvesByMethod = struct('methodName', {}, 'curves', {});
    for i = 1:numel(methodOrder)
        curvesByMethod(i).methodName = methodOrder{i}; %#ok<AGROW>
        curvesByMethod(i).curves = {};
    end

    foundAnything = false;

    fns = fieldnames(S);
    for i = 1:numel(fns)
        value = S.(fns{i});
        curvesByMethod = localScanAny(value, curvesByMethod, methodOrder);
    end

    for i = 1:numel(curvesByMethod)
        if ~isempty(curvesByMethod(i).curves)
            foundAnything = true;
            break;
        end
    end

    if ~foundAnything
        curvesByMethod = [];
    end
end

%% ========================================================================
function curvesByMethod = localScanAny(value, curvesByMethod, methodOrder)

    if isstruct(value)
        if numel(value) > 1
            for k = 1:numel(value)
                curvesByMethod = localScanAny(value(k), curvesByMethod, methodOrder);
            end
            return;
        end

        methodName = localDetectMethodName(value, methodOrder);
        curve = localExtractConvergenceCurve(value);
        if ~isempty(methodName) && ~isempty(curve)
            idx = find(strcmpi({curvesByMethod.methodName}, methodName), 1);
            if ~isempty(idx)
                curvesByMethod(idx).curves{end+1} = curve(:);
            end
        end

        fns = fieldnames(value);
        for i = 1:numel(fns)
            try
                curvesByMethod = localScanAny(value.(fns{i}), curvesByMethod, methodOrder);
            catch
            end
        end
        return;
    end

    if iscell(value)
        for i = 1:numel(value)
            try
                curvesByMethod = localScanAny(value{i}, curvesByMethod, methodOrder);
            catch
            end
        end
        return;
    end

    if istable(value)
        vn = lower(string(value.Properties.VariableNames));
        methodIdx = find(ismember(vn, ["algorithm","alg","algname","method","methodname"]), 1);
        curveIdx = find(ismember(vn, ["curve","convergence","history","bestfithistory","bestfitnesshistory","bestcosthistory"]), 1);

        if ~isempty(methodIdx) && ~isempty(curveIdx)
            methodCol = value.Properties.VariableNames{methodIdx};
            curveCol = value.Properties.VariableNames{curveIdx};

            for r = 1:height(value)
                methodName = localNormalizeMethodName(value.(methodCol)(r), methodOrder);
                curve = value.(curveCol)(r);
                if iscell(curve), curve = curve{1}; end
                if ~isempty(methodName) && isnumeric(curve) && ~isempty(curve)
                    idx = find(strcmpi({curvesByMethod.methodName}, methodName), 1);
                    if ~isempty(idx)
                        curvesByMethod(idx).curves{end+1} = curve(:);
                    end
                end
            end
        end
        return;
    end
end

%% ========================================================================
function curvesByMethod = localExtractCurvesFromRunRecords(runDir, methodOrder)

    curvesByMethod = struct('methodName', {}, 'curves', {});
    for i = 1:numel(methodOrder)
        curvesByMethod(i).methodName = methodOrder{i}; %#ok<AGROW>
        curvesByMethod(i).curves = {};
    end

    for a = 1:numel(methodOrder)
        methodName = methodOrder{a};
        files = dir(fullfile(runDir, '*.mat'));
        if isempty(files)
            continue;
        end

        names = upper(string({files.name}));
        mask = contains(names, upper(string(methodName)));
        files = files(mask);

        for k = 1:numel(files)
            fp = fullfile(files(k).folder, files(k).name);
            try
                S = load(fp);
                rr = localExtractResultStruct(S);
                curve = localExtractConvergenceCurve(rr);
                if ~isempty(curve)
                    curvesByMethod(a).curves{end+1} = curve(:);
                end
            catch
            end
        end
    end

    hasAny = false;
    for i = 1:numel(curvesByMethod)
        if ~isempty(curvesByMethod(i).curves)
            hasAny = true;
            break;
        end
    end
    if ~hasAny
        curvesByMethod = [];
    end
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
function methodName = localDetectMethodName(rr, methodOrder)
    methodName = '';

    candidateFields = {'algorithm','alg','algName','algorithmName','method','methodName','optimizer','name'};
    for i = 1:numel(candidateFields)
        fn = candidateFields{i};
        if isfield(rr, fn)
            methodName = localNormalizeMethodName(rr.(fn), methodOrder);
            if ~isempty(methodName)
                return;
            end
        end
    end

    nestedFields = {'params','config','meta','setting'};
    for i = 1:numel(nestedFields)
        nf = nestedFields{i};
        if isfield(rr, nf) && isstruct(rr.(nf))
            sub = rr.(nf);
            for j = 1:numel(candidateFields)
                fn = candidateFields{j};
                if isfield(sub, fn)
                    methodName = localNormalizeMethodName(sub.(fn), methodOrder);
                    if ~isempty(methodName)
                        return;
                    end
                end
            end
        end
    end
end

%% ========================================================================
function methodName = localNormalizeMethodName(v, methodOrder)
    methodName = '';

    if iscell(v) && numel(v) == 1
        v = v{1};
    end

    if isstring(v) || ischar(v)
        s = upper(strtrim(char(string(v))));
        for i = 1:numel(methodOrder)
            if strcmpi(s, methodOrder{i})
                methodName = methodOrder{i};
                return;
            end
        end
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
function style = localMethodStyle(methodName, methodOrder)
    methodColors = lines(numel(methodOrder));
    idx = find(strcmpi(methodOrder, methodName), 1);
    if isempty(idx)
        idx = 1;
    end

    style.Color = methodColors(idx,:);
    style.LineWidth = 2.0;
    if strcmpi(methodName, 'FAE-AE')
        style.LineWidth = 2.4;
    end
end