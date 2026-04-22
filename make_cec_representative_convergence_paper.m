function make_cec_representative_convergence_paper(resultDir, outDir, targetFuncs)
%MAKE_CEC_REPRESENTATIVE_CONVERGENCE_PAPER
% 生成 4 个代表 CEC 函数的 2x2 收敛图
%
% 推荐代表函数：
%   F9, F16, F21, F27
%
% 用法：
%   make_cec_representative_convergence_paper
%   make_cec_representative_convergence_paper('results_cec2017_formal_high_woa')
%   make_cec_representative_convergence_paper('results_cec2017_formal_high_woa', 'paper_final_figures')
%   make_cec_representative_convergence_paper('results_cec2017_formal_high_woa', 'paper_final_figures', [9 16 21 27])

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

    fprintf('\n=== Make CEC Representative Convergence Figure ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Output folder: %s\n', outDir);
    fprintf('Target funcs : %s\n\n', mat2str(targetFuncs));

    curvesByFunc = [];

    % 1) export workspace
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

    % 2) batch results
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

    % 3) run_records fallback
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

    fig = figure('Color', 'w', 'Position', [60 60 1200 850]);
    t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    legendHandles = [];
    legendNames = {};

    for k = 1:numel(targetFuncs)
        fid = targetFuncs(k);
        ax = nexttile;
        hold(ax, 'on');
        grid(ax, 'on');
        box(ax, 'on');

        hasAny = false;
        allY = [];

        % ---------- 先收集这个函数下所有算法的平均曲线 ----------
        meanCurves = cell(1, numel(algOrder));
        commonLen = 0;

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

        % ---------- 再统一补齐后绘图 ----------
        for a = 1:numel(algOrder)
            algName = algOrder{a};
            meanCurve = meanCurves{a};

            if isempty(meanCurve)
                continue;
            end

            meanCurve = localPadCurveToLength(meanCurve, commonLen);

            style = localAlgStyle(algName, algOrder);
            if all(meanCurve > 0)
                h = semilogy(ax, 1:numel(meanCurve), meanCurve, ...
                    'LineWidth', style.LineWidth, ...
                    'Color', style.Color);
            else
                h = plot(ax, 1:numel(meanCurve), meanCurve, ...
                    'LineWidth', style.LineWidth, ...
                    'Color', style.Color);
            end

            hasAny = true;
            allY = [allY; meanCurve(:)]; %#ok<AGROW>

            if k == 1
                legendHandles(end+1) = h; %#ok<AGROW>
                legendNames{end+1} = algName; %#ok<AGROW>
            end
        end

        title(ax, sprintf('F%d Convergence', fid), ...
            'FontName', 'Times New Roman', 'FontSize', 13, 'FontWeight', 'bold');
        xlabel(ax, 'Iteration', 'FontName', 'Times New Roman', 'FontSize', 12);
        ylabel(ax, 'Best-so-far value', 'FontName', 'Times New Roman', 'FontSize', 12);

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
                    if ~all(yy > 0)
                        pad = 0.05 * (ymax - ymin);
                        ylim(ax, [ymin - pad, ymax + pad]);
                    end
                end
            end
        
            switch fid
                case 9
                    ylim(ax, [0, 20000]);
                case 16
                    % ylim(ax, [2400, 6000]);
                case 21
                    % ylim(ax, [2350, 2750]);
                case 27
                    % ylim(ax, [3200, 4200]);
            end
        end
    end

    if ~isempty(legendHandles)
        lgd = legend(legendHandles, legendNames, ...
            'Orientation', 'horizontal', ...
            'Interpreter', 'none', ...
            'Box', 'off');
        lgd.Layout.Tile = 'south';
    end

%     title(t, 'CEC2017 Representative Function Convergence Curves', ...
%         'FontName', 'Times New Roman', 'FontSize', 14, 'FontWeight', 'bold');

    outFig = fullfile(outDir, 'fig4_15_cec_representative_convergence.fig');
    outPng = fullfile(outDir, 'fig4_15_cec_representative_convergence.png');

    savefig(fig, outFig);
    exportgraphics(fig, outPng, 'Resolution', 300);
    close(fig);

    fprintf('\nSaved: %s\n', outPng);
    fprintf('Saved: %s\n', outFig);
end

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
            algCol  = value.Properties.VariableNames{algIdx};
            curveCol = value.Properties.VariableNames{curveIdx};
            funcCol  = value.Properties.VariableNames{funcIdx};

            for r = 1:height(value)
                algName = localNormalizeAlgName(value.(algCol)(r), algOrder);
                funcId = localNormalizeFunctionId(value.(funcCol)(r), targetFuncs);

                curve = value.(curveCol)(r);
                if iscell(curve), curve = curve{1}; end

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

function idx = localFindFuncAlg(curvesByFunc, funcId, algName)
    idx = find([curvesByFunc.funcId] == funcId & strcmpi({curvesByFunc.algName}, algName), 1);
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
    style.LineWidth = 1.5;
    if strcmpi(algName, 'FAEAE')
        style.LineWidth = 2.2;
    end
end