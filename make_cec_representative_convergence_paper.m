function figs = make_cec_representative_convergence_paper(resultDir, outDir, targetFuncs)
%MAKE_CEC_REPRESENTATIVE_CONVERGENCE_PAPER
% Generate separate convergence figures for representative CEC2017 functions.
%
% Recommended representative functions:
%   F9, F16, F21, F27
%
% Usage:
%   make_cec_representative_convergence_paper
%   make_cec_representative_convergence_paper('results_cec2017_formal_high_woa')
%   make_cec_representative_convergence_paper('results_cec2017_formal_high_woa', 'paper_final_figures')
%   make_cec_representative_convergence_paper('results_cec2017_formal_high_woa', 'paper_final_figures', [9 16 21 27])
%
% Output files:
%   fig_cec_convergence_F9.pdf/png/fig
%   fig_cec_convergence_F16.pdf/png/fig
%   fig_cec_convergence_F21.pdf/png/fig
%   fig_cec_convergence_F27.pdf/png/fig
%
% Notes:
%   1. No title is placed inside each figure.
%   2. The function IDs should be described in the LaTeX caption.
%   3. All figures use the same canvas size and axes position to ensure aligned
%      layout when arranged as subfigures in LaTeX.
%   4. Legends are enclosed in boxes.

    if nargin < 1 || isempty(resultDir)
        resultDir = 'results_cec2017_formal_high_woa';
    end
    if nargin < 2 || isempty(outDir)
        outDir = 'paper_final_figures';
    end
    if nargin < 3 || isempty(targetFuncs)
        targetFuncs = [9 16 21 27];
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

    fprintf('\n=== Make CEC Representative Convergence Figures ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Output folder: %s\n', outDir);
    fprintf('Target funcs : %s\n\n', mat2str(targetFuncs));

    curvesByFunc = [];

    % 1) Try export workspace.
    if exist(exportWsFile, 'file')
        fprintf('Trying export workspace: %s\n', exportWsFile);
        try
            S = load(exportWsFile);
            curvesByFunc = localExtractCurvesByFuncFromWorkspace(S, algOrder, targetFuncs);
            if ~isempty(curvesByFunc)
                fprintf('Successfully extracted convergence data from export workspace.\n');
            end
        catch ME
            warning('CEC:LoadFailed', '读取 export workspace 失败：%s', ME.message);
        end
    end

    % 2) Try batch results.
    if isempty(curvesByFunc) && exist(batchMatFile, 'file')
        fprintf('Trying batch results: %s\n', batchMatFile);
        try
            S = load(batchMatFile);
            curvesByFunc = localExtractCurvesByFuncFromWorkspace(S, algOrder, targetFuncs);
            if ~isempty(curvesByFunc)
                fprintf('Successfully extracted convergence data from batch results.\n');
            end
        catch ME
            warning('CEC:LoadFailed', '读取 batch results 失败：%s', ME.message);
        end
    end

    % 3) Fallback to run_records.
    if isempty(curvesByFunc) && exist(runDir, 'dir')
        fprintf('Trying fallback run_records: %s\n', runDir);
        curvesByFunc = localExtractCurvesByFuncFromRunRecords(runDir, algOrder, targetFuncs);
        if ~isempty(curvesByFunc)
            fprintf('Successfully extracted convergence data from run_records.\n');
        end
    end

    if isempty(curvesByFunc)
        error('未能提取到代表函数收敛曲线，请检查 workspace 或 run_records 的字段/文件名。');
    end

    % ---------------------------------------------------------------------
    % Fixed figure geometry for consistent LaTeX alignment.
    % ---------------------------------------------------------------------
    figW = 15.0;
    figH = 10.2;
    axPos = [0.14, 0.15, 0.82, 0.78];

    figs = gobjects(numel(targetFuncs), 1);

    for k = 1:numel(targetFuncs)

        fid = targetFuncs(k);

        fig = figure( ...
            'Color', 'w', ...
            'Units', 'centimeters', ...
            'Position', [3, 3, figW, figH], ...
            'PaperUnits', 'centimeters', ...
            'PaperSize', [figW, figH], ...
            'PaperPosition', [0, 0, figW, figH]);

        figs(k) = fig;

        ax = axes(fig);
        set(ax, 'Units', 'normalized', 'Position', axPos);

        hold(ax, 'on');
        grid(ax, 'on');
        box(ax, 'on');

        hasAny = false;
        allY = [];

        meanCurves = cell(1, numel(algOrder));
        commonLen = 0;

        % ---------- Collect mean curves for the current function ----------
        for a = 1:numel(algOrder)
            algName = algOrder{a};

            idx = localFindFuncAlg(curvesByFunc, fid, algName);
            if isempty(idx)
                fprintf('F%-2d | %-6s | no curve extracted.\n', fid, algName);
                continue;
            end

            curveCell = curvesByFunc(idx).curves;
            if isempty(curveCell)
                fprintf('F%-2d | %-6s | empty curve set.\n', fid, algName);
                continue;
            end

            meanCurve = localMeanCurve(curveCell);
            meanCurves{a} = meanCurve(:);
            commonLen = max(commonLen, numel(meanCurve));

            fprintf('F%-2d | %-6s | curves used = %d | final length = %d\n', ...
                fid, algName, numel(curveCell), numel(meanCurve));
        end

        % ---------- Plot after padding to the same length ----------
        for a = 1:numel(algOrder)
            algName = algOrder{a};
            meanCurve = meanCurves{a};

            if isempty(meanCurve)
                continue;
            end

            meanCurve = localPadCurveToLength(meanCurve, commonLen);

            style = localAlgStyle(algName, algOrder);

            if all(meanCurve > 0)
                semilogy(ax, 1:numel(meanCurve), meanCurve, ...
                    'LineWidth', style.LineWidth, ...
                    'Color', style.Color, ...
                    'DisplayName', algName);
            else
                plot(ax, 1:numel(meanCurve), meanCurve, ...
                    'LineWidth', style.LineWidth, ...
                    'Color', style.Color, ...
                    'DisplayName', algName);
            end

            hasAny = true;
            allY = [allY; meanCurve(:)]; %#ok<AGROW>
        end

        xlabel(ax, 'Iteration', ...
            'FontName', 'Times New Roman', ...
            'FontSize', 12);

        ylabel(ax, 'Best-so-far value', ...
            'FontName', 'Times New Roman', ...
            'FontSize', 12);

        % No title is used here. The function ID is specified in the file
        % name and in the LaTeX caption, e.g., (a) F9, (b) F16, etc.

        set(ax, ...
            'FontName', 'Times New Roman', ...
            'FontSize', 11, ...
            'LineWidth', 1.0, ...
            'GridAlpha', 0.18, ...
            'MinorGridAlpha', 0.10);

        if hasAny
            xlim(ax, [1, commonLen]);

            yy = allY(isfinite(allY));

            if ~isempty(yy)
                ymin = min(yy);
                ymax = max(yy);

                if ymax > ymin
                    if all(yy > 0)
                        ymin = max(ymin, realmin);
                        logPad = 0.05 * (log10(ymax) - log10(ymin));
                        yLow = 10^(log10(ymin) - logPad);
                        yHigh = 10^(log10(ymax) + logPad);
                        ylim(ax, [yLow, yHigh]);
                    else
                        pad = 0.05 * (ymax - ymin);
                        ylim(ax, [ymin - pad, ymax + pad]);
                    end
                end
            end

            % Optional manual adjustment for specific functions.
            % For semilogy, do not use zero as the lower bound.
            switch fid
                case 9
                    if all(yy > 0)
                        yLow = max(min(yy), realmin);
                        ylim(ax, [yLow, 20000]);
                    else
                        ylim(ax, [0, 20000]);
                    end
                case 16
                    % ylim(ax, [2400, 6000]);
                case 21
                    % ylim(ax, [2350, 2750]);
                case 27
                    % ylim(ax, [3200, 4200]);
            end
        end

        % Boxed legend.
        lgd = legend(ax, ...
            'Location', 'best', ...
            'Interpreter', 'none', ...
            'Box', 'on');

        lgd.EdgeColor = [0, 0, 0];
        lgd.LineWidth = 0.8;
        lgd.Color = [1, 1, 1];
        lgd.FontName = 'Times New Roman';
        lgd.FontSize = 8;

        hold(ax, 'off');

        % -----------------------------------------------------------------
        % Export with fixed PDF page size.
        % -----------------------------------------------------------------
        outBase = fullfile(outDir, sprintf('fig_cec_convergence_F%d', fid));
        outFig = [outBase, '.fig'];
        outPdf = [outBase, '.pdf'];
        outPng = [outBase, '.png'];

        savefig(fig, outFig);

        set(fig, 'PaperUnits', 'centimeters');
        set(fig, 'PaperSize', [figW, figH]);
        set(fig, 'PaperPosition', [0, 0, figW, figH]);

        print(fig, outPdf, '-dpdf', '-vector');
        exportgraphics(fig, outPng, 'Resolution', 300);

        fprintf('\nSaved: %s\n', outFig);
        fprintf('Saved: %s\n', outPdf);
        fprintf('Saved: %s\n', outPng);

        close(fig);
    end
end

%% ========================================================================
function curvesByFunc = localExtractCurvesByFuncFromWorkspace(S, algOrder, targetFuncs)

    curvesByFunc = struct('funcId', {}, 'algName', {}, 'curves', {});
    ptr = 0;

    for f = 1:numel(targetFuncs)
        for a = 1:numel(algOrder)
            ptr = ptr + 1;
            curvesByFunc(ptr).funcId = targetFuncs(f);
            curvesByFunc(ptr).algName = algOrder{a};
            curvesByFunc(ptr).curves = {};
        end
    end

    foundAnything = false;

    fns = fieldnames(S);
    for i = 1:numel(fns)
        value = S.(fns{i});
        curvesByFunc = localScanAnyByFunc(value, curvesByFunc, algOrder, targetFuncs);
    end

    for i = 1:numel(curvesByFunc)
        if ~isempty(curvesByFunc(i).curves)
            foundAnything = true;
            break;
        end
    end

    if ~foundAnything
        curvesByFunc = [];
    end
end

%% ========================================================================
function curvesByFunc = localScanAnyByFunc(value, curvesByFunc, algOrder, targetFuncs)

    if isstruct(value)
        if numel(value) > 1
            for k = 1:numel(value)
                curvesByFunc = localScanAnyByFunc(value(k), curvesByFunc, algOrder, targetFuncs);
            end
            return;
        end

        algName = localDetectAlgorithmName(value, algOrder);
        funcId = localDetectFunctionId(value, targetFuncs);
        curve = localExtractConvergenceCurve(value);

        if ~isempty(algName) && ~isempty(funcId) && ~isempty(curve)
            idx = localFindFuncAlg(curvesByFunc, funcId, algName);
            if ~isempty(idx)
                curvesByFunc(idx).curves{end+1} = curve(:);
            end
        end

        fns = fieldnames(value);
        for i = 1:numel(fns)
            try
                curvesByFunc = localScanAnyByFunc(value.(fns{i}), curvesByFunc, algOrder, targetFuncs);
            catch
            end
        end
        return;
    end

    if iscell(value)
        for i = 1:numel(value)
            try
                curvesByFunc = localScanAnyByFunc(value{i}, curvesByFunc, algOrder, targetFuncs);
            catch
            end
        end
        return;
    end

    if istable(value)
        vn = lower(string(value.Properties.VariableNames));

        algIdx = find(ismember(vn, ["algorithm","alg","algname","method","methodname"]), 1);
        curveIdx = find(ismember(vn, ["curve","convergence","history","bestfithistory","bestfitnesshistory","bestcosthistory"]), 1);
        funcIdx = find(ismember(vn, ["funcid","functionid","fid","function","problem","problemid","testfunction"]), 1);

        if ~isempty(algIdx) && ~isempty(curveIdx) && ~isempty(funcIdx)
            algCol = value.Properties.VariableNames{algIdx};
            curveCol = value.Properties.VariableNames{curveIdx};
            funcCol = value.Properties.VariableNames{funcIdx};

            for r = 1:height(value)
                algName = localNormalizeAlgName(value.(algCol)(r), algOrder);
                funcId = localNormalizeFunctionId(value.(funcCol)(r), targetFuncs);

                curve = value.(curveCol)(r);
                if iscell(curve)
                    curve = curve{1};
                end

                if ~isempty(algName) && ~isempty(funcId) && isnumeric(curve) && ~isempty(curve)
                    idx = localFindFuncAlg(curvesByFunc, funcId, algName);
                    if ~isempty(idx)
                        curvesByFunc(idx).curves{end+1} = curve(:);
                    end
                end
            end
        end
        return;
    end
end

%% ========================================================================
function curvesByFunc = localExtractCurvesByFuncFromRunRecords(runDir, algOrder, targetFuncs)

    curvesByFunc = struct('funcId', {}, 'algName', {}, 'curves', {});
    ptr = 0;

    for f = 1:numel(targetFuncs)
        for a = 1:numel(algOrder)
            ptr = ptr + 1;
            curvesByFunc(ptr).funcId = targetFuncs(f);
            curvesByFunc(ptr).algName = algOrder{a};
            curvesByFunc(ptr).curves = {};
        end
    end

    allFiles = dir(fullfile(runDir, '*.mat'));

    for k = 1:numel(allFiles)
        fp = fullfile(allFiles(k).folder, allFiles(k).name);
        fname = allFiles(k).name;

        algName = localNormalizeAlgNameFromFilename(fname, algOrder);
        funcId = localNormalizeFunctionIdFromFilename(fname, targetFuncs);

        if isempty(algName) || isempty(funcId)
            continue;
        end

        try
            S = load(fp);
            rr = localExtractResultStruct(S);
            curve = localExtractConvergenceCurve(rr);

            if ~isempty(curve)
                idx = localFindFuncAlg(curvesByFunc, funcId, algName);
                if ~isempty(idx)
                    curvesByFunc(idx).curves{end+1} = curve(:);
                end
            end
        catch
        end
    end

    hasAny = false;
    for i = 1:numel(curvesByFunc)
        if ~isempty(curvesByFunc(i).curves)
            hasAny = true;
            break;
        end
    end

    if ~hasAny
        curvesByFunc = [];
    end
end

%% ========================================================================
function funcId = localDetectFunctionId(rr, targetFuncs)

    funcId = [];

    candidateFields = {'funcId','functionId','fid','function','problem','problemId','testFunction','cecFunc','func'};

    for i = 1:numel(candidateFields)
        fn = candidateFields{i};
        if isfield(rr, fn)
            funcId = localNormalizeFunctionId(rr.(fn), targetFuncs);
            if ~isempty(funcId)
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
                    funcId = localNormalizeFunctionId(sub.(fn), targetFuncs);
                    if ~isempty(funcId)
                        return;
                    end
                end
            end
        end
    end
end

%% ========================================================================
function funcId = localNormalizeFunctionId(v, targetFuncs)

    funcId = [];

    if iscell(v) && numel(v) == 1
        v = v{1};
    end

    if isnumeric(v) && isscalar(v)
        if any(targetFuncs == v)
            funcId = double(v);
        end
        return;
    end

    if isstring(v) || ischar(v)
        s = upper(strtrim(char(string(v))));
        tok = regexp(s, 'F?(\d+)', 'tokens', 'once');

        if ~isempty(tok)
            x = str2double(tok{1});
            if any(targetFuncs == x)
                funcId = x;
            end
        end
    end
end

%% ========================================================================
function algName = localNormalizeAlgNameFromFilename(fname, algOrder)

    algName = '';
    up = upper(fname);

    for i = 1:numel(algOrder)
        if contains(up, upper(algOrder{i}))
            algName = algOrder{i};
            return;
        end
    end
end

%% ========================================================================
function funcId = localNormalizeFunctionIdFromFilename(fname, targetFuncs)

    funcId = [];
    up = upper(fname);
    tok = regexp(up, 'F(\d+)', 'tokens', 'once');

    if ~isempty(tok)
        x = str2double(tok{1});
        if any(targetFuncs == x)
            funcId = x;
        end
    end
end

%% ========================================================================
function idx = localFindFuncAlg(curvesByFunc, funcId, algName)

    idx = find([curvesByFunc.funcId] == funcId & strcmpi({curvesByFunc.algName}, algName), 1);
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
        if size(x, 1) >= size(x, 2)
            v = x(:, 1);
        else
            v = x(1, :).';
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
        M(i, 1:L) = c(:);

        if L < maxLen
            M(i, L+1:end) = c(end);
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

    style.Color = algColors(idx, :);
    style.LineWidth = 1.5;

    if strcmpi(algName, 'FAEAE')
        style.LineWidth = 2.2;
    end
end