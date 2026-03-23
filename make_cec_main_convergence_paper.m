function make_cec_main_convergence_paper(resultDir, outDir)
%MAKE_CEC_MAIN_CONVERGENCE_PAPER
% 基于已有 CEC 主对比结果，生成总收敛图。
% 不重新跑实验。
%
% 这版优先适配如下目录结构：
%   results_cec2017_formal_high_woa/
%       cec2017_export_workspace.mat
%       cec2017_batch_results.mat
%       cec2017_summary_long.csv
%       ...
%
% 优先读取：
%   1) cec2017_export_workspace.mat
%   2) cec2017_batch_results.mat
%   3) run_records/   （仅作为 fallback）
%
% 输出：
%   fig4_15_cec_main_convergence.png/.fig
%
% 用法：
%   make_cec_main_convergence_paper
%   make_cec_main_convergence_paper('results_cec2017_formal_high_woa')
%   make_cec_main_convergence_paper('results_cec2017_formal_high_woa', 'paper_final_figures')

    if nargin < 1 || isempty(resultDir)
        resultDir = 'results_cec2017_formal_high_woa';
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

    exportWsFile = fullfile(resultDir, 'cec2017_export_workspace.mat');
    batchMatFile = fullfile(resultDir, 'cec2017_batch_results.mat');
    runDir = fullfile(resultDir, 'run_records');

    algOrder = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};

    fprintf('\n=== Make CEC Main Convergence Figure ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Output folder: %s\n\n', outDir);

    curvesByAlg = [];

    % ---------------------------------------------------------------------
    % 1) 优先尝试 export workspace
    % ---------------------------------------------------------------------
    if exist(exportWsFile, 'file')
        fprintf('Trying export workspace: %s\n', exportWsFile);
        try
            S = load(exportWsFile);
            curvesByAlg = localExtractCurvesFromWorkspace(S, algOrder);
            if ~isempty(curvesByAlg)
                fprintf('Successfully extracted convergence data from export workspace.\n');
            end
        catch ME
            warning('读取 export workspace 失败：%s', ME.message);
        end
    end

    % ---------------------------------------------------------------------
    % 2) 再尝试 batch results
    % ---------------------------------------------------------------------
    if isempty(curvesByAlg) && exist(batchMatFile, 'file')
        fprintf('Trying batch results: %s\n', batchMatFile);
        try
            S = load(batchMatFile);
            curvesByAlg = localExtractCurvesFromWorkspace(S, algOrder);
            if ~isempty(curvesByAlg)
                fprintf('Successfully extracted convergence data from batch results.\n');
            end
        catch ME
            warning('读取 batch results 失败：%s', ME.message);
        end
    end

    % ---------------------------------------------------------------------
    % 3) 最后 fallback 到 run_records
    % ---------------------------------------------------------------------
    if isempty(curvesByAlg) && exist(runDir, 'dir')
        fprintf('Trying fallback run_records: %s\n', runDir);
        curvesByAlg = localExtractCurvesFromRunRecords(runDir, algOrder);
        if ~isempty(curvesByAlg)
            fprintf('Successfully extracted convergence data from run_records.\n');
        end
    end

    if isempty(curvesByAlg)
        error(['无法从以下位置提取收敛曲线：\n' ...
               '  %s\n  %s\n  %s\n' ...
               '建议把 cec2017_export_workspace.mat 的变量名截图或贴给我。'], ...
               exportWsFile, batchMatFile, runDir);
    end

    fig = figure('Color', 'w', 'Position', [80 80 1100 780]);
    hold on;
    grid on;
    box on;

    legendHandles = [];
    legendNames = {};

    for a = 1:numel(algOrder)
        algName = algOrder{a};
        idx = find(strcmpi({curvesByAlg.algName}, algName), 1);
        if isempty(idx)
            fprintf('%-6s | no curve extracted.\n', algName);
            continue;
        end

        curveCell = curvesByAlg(idx).curves;
        if isempty(curveCell)
            fprintf('%-6s | empty curve set.\n', algName);
            continue;
        end

        meanCurve = localMeanCurve(curveCell);

        style = localAlgStyle(algName, algOrder);
        h = plot(1:numel(meanCurve), meanCurve, ...
            'LineWidth', style.LineWidth, ...
            'Color', style.Color);

        legendHandles(end+1) = h; %#ok<AGROW>
        legendNames{end+1} = algName; %#ok<AGROW>

        fprintf('%-6s | curves used = %d | final length = %d\n', ...
            algName, numel(curveCell), numel(meanCurve));
    end

    xlabel('Iteration', 'FontName', 'Times New Roman', 'FontSize', 13);
    ylabel('Best-so-far value', 'FontName', 'Times New Roman', 'FontSize', 13);
    title('CEC2017 Main Comparison Average Convergence Curves', ...
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

    outFig = fullfile(outDir, 'fig4_15_cec_main_convergence.fig');
    outPng = fullfile(outDir, 'fig4_15_cec_main_convergence.png');

    savefig(fig, outFig);
    exportgraphics(fig, outPng, 'Resolution', 300);
    close(fig);

    fprintf('Saved: %s\n', outPng);
    fprintf('Saved: %s\n', outFig);
end

%% ========================================================================
function curvesByAlg = localExtractCurvesFromWorkspace(S, algOrder)
% 从 MAT workspace 中尽量自动抽取“算法 -> 多条收敛曲线”

    curvesByAlg = struct('algName', {}, 'curves', {});

    % 先初始化
    for i = 1:numel(algOrder)
        curvesByAlg(i).algName = algOrder{i}; %#ok<AGROW>
        curvesByAlg(i).curves = {};
    end

    foundAnything = false;

    % 递归扫描所有变量
    fns = fieldnames(S);
    for i = 1:numel(fns)
        value = S.(fns{i});
        curvesByAlg = localScanAny(value, curvesByAlg, algOrder);
    end

    for i = 1:numel(curvesByAlg)
        if ~isempty(curvesByAlg(i).curves)
            foundAnything = true;
            break;
        end
    end

    if ~foundAnything
        curvesByAlg = [];
    end
end

%% ========================================================================
function curvesByAlg = localScanAny(value, curvesByAlg, algOrder)

    % struct
    if isstruct(value)
        if numel(value) > 1
            for k = 1:numel(value)
                curvesByAlg = localScanAny(value(k), curvesByAlg, algOrder);
            end
            return;
        end

        % 当前 struct 本身是否像一条 run/result
        algName = localDetectAlgorithmName(value, algOrder);
        curve = localExtractConvergenceCurve(value);
        if ~isempty(algName) && ~isempty(curve)
            idx = find(strcmpi({curvesByAlg.algName}, algName), 1);
            if ~isempty(idx)
                curvesByAlg(idx).curves{end+1} = curve(:);
            end
        end

        % 递归扫子字段
        fns = fieldnames(value);
        for i = 1:numel(fns)
            try
                curvesByAlg = localScanAny(value.(fns{i}), curvesByAlg, algOrder);
            catch
            end
        end
        return;
    end

    % cell
    if iscell(value)
        for i = 1:numel(value)
            try
                curvesByAlg = localScanAny(value{i}, curvesByAlg, algOrder);
            catch
            end
        end
        return;
    end

    % table
    if istable(value)
        % 如果表里本身有 algorithm + curve/history 字段，也尝试提取
        vn = lower(string(value.Properties.VariableNames));
        algIdx = find(ismember(vn, ["algorithm","alg","algname","method","methodname"]), 1);
        curveIdx = find(ismember(vn, ["curve","convergence","history","bestfithistory","bestfitnesshistory","bestcosthistory"]), 1);

        if ~isempty(algIdx) && ~isempty(curveIdx)
            algCol = value.Properties.VariableNames{algIdx};
            curveCol = value.Properties.VariableNames{curveIdx};

            for r = 1:height(value)
                algName = localNormalizeAlgName(value.(algCol)(r), algOrder);
                curve = value.(curveCol)(r);
                if iscell(curve), curve = curve{1}; end
                if ~isempty(algName) && isnumeric(curve) && ~isempty(curve)
                    idx = find(strcmpi({curvesByAlg.algName}, algName), 1);
                    if ~isempty(idx)
                        curvesByAlg(idx).curves{end+1} = curve(:);
                    end
                end
            end
        end
        return;
    end
end

%% ========================================================================
function curvesByAlg = localExtractCurvesFromRunRecords(runDir, algOrder)

    curvesByAlg = struct('algName', {}, 'curves', {});
    for i = 1:numel(algOrder)
        curvesByAlg(i).algName = algOrder{i}; %#ok<AGROW>
        curvesByAlg(i).curves = {};
    end

    for a = 1:numel(algOrder)
        algName = algOrder{a};
        pattern1 = fullfile(runDir, sprintf('*_%s_*run*.mat', upper(algName)));
        files = dir(pattern1);

        if isempty(files)
            allFiles = dir(fullfile(runDir, '*.mat'));
            names = upper(string({allFiles.name}));
            mask = contains(names, upper(string(algName)));
            files = allFiles(mask);
        end

        for k = 1:numel(files)
            fp = fullfile(files(k).folder, files(k).name);
            try
                S = load(fp);
                rr = localExtractResultStruct(S);
                curve = localExtractConvergenceCurve(rr);
                if ~isempty(curve)
                    curvesByAlg(a).curves{end+1} = curve(:);
                end
            catch
            end
        end
    end

    hasAny = false;
    for i = 1:numel(curvesByAlg)
        if ~isempty(curvesByAlg(i).curves)
            hasAny = true;
            break;
        end
    end
    if ~hasAny
        curvesByAlg = [];
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
function algName = localDetectAlgorithmName(rr, algOrder)
    algName = '';

    candidateFields = {'algorithm','alg','algName','algorithmName','method','methodName','optimizer','name'};
    for i = 1:numel(candidateFields)
        fn = candidateFields{i};
        if isfield(rr, fn)
            algName = localNormalizeAlgName(rr.(fn), algOrder);
            if ~isempty(algName)
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
                    algName = localNormalizeAlgName(sub.(fn), algOrder);
                    if ~isempty(algName)
                        return;
                    end
                end
            end
        end
    end
end

%% ========================================================================
function algName = localNormalizeAlgName(v, algOrder)
    algName = '';

    if iscell(v) && numel(v) == 1
        v = v{1};
    end

    if isstring(v) || ischar(v)
        s = upper(strtrim(char(string(v))));
        for i = 1:numel(algOrder)
            if strcmpi(s, algOrder{i})
                algName = algOrder{i};
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
function style = localAlgStyle(algName, algOrder)
    algColors = lines(numel(algOrder));
    idx = find(strcmpi(algOrder, algName), 1);
    if isempty(idx)
        idx = 1;
    end

    style.Color = algColors(idx,:);
    style.LineWidth = 2.0;
    if strcmpi(algName, 'FAEAE')
        style.LineWidth = 2.4;
    end
end