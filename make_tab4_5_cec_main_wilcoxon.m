function make_tab4_5_cec_main_wilcoxon(resultDir, outDir)
%MAKE_TAB4_5_CEC_MAIN_WILCOXON
% 基于已有 CEC 主对比 summary_long 文件，生成 FAEAE 与其他算法的 Wilcoxon 检验表。
%
% 不重新跑实验。
%
% 统计逻辑：
% - 以 function 为样本
% - 比较 FAEAE 与 AE/PSO/GWO/HHO/WOA 的每函数 mean 值
% - 默认采用 signrank（Wilcoxon signed-rank test）
% - 显著性水平 alpha = 0.05
%
% 输出：
%   - tab4_5_cec_main_wilcoxon.csv
%   - tab4_5_cec_main_wilcoxon.xlsx
%
% 用法：
%   make_tab4_5_cec_main_wilcoxon
%   make_tab4_5_cec_main_wilcoxon('results_cec2017_formal')
%   make_tab4_5_cec_main_wilcoxon('results_cec2017_formal', 'paper_final_tables')

    if nargin < 1 || isempty(resultDir)
        resultDir = 'results_cec2017_formal_high_woa';
    end
    if nargin < 2 || isempty(outDir)
        outDir = 'paper_final_tables';
    end

    if ~exist(resultDir, 'dir')
        error('结果目录不存在：%s', resultDir);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    summaryFile = localFindSummaryFile(resultDir);
    if isempty(summaryFile)
        error('未找到 CEC 主对比 summary_long 文件。');
    end

    T = readtable(summaryFile);

    fprintf('\n=== Make Tab 4-5 CEC Main Wilcoxon ===\n');
    fprintf('Summary file  : %s\n', summaryFile);
    fprintf('Output folder : %s\n\n', outDir);

    algRef = 'FAEAE';
    algOthers = {'AE', 'PSO', 'GWO', 'HHO', 'WOA'};
    alpha = 0.05;

    [funcCol, algCol, meanCol] = localDetectSummaryColumns(T);

    funcVals = localUniqueFunctions(T.(funcCol));
    funcVals = sort(funcVals(:).');

    comparisons = strings(numel(algOthers),1);
    pValues = nan(numel(algOthers),1);
    results = strings(numel(algOthers),1);
    nPairs = zeros(numel(algOthers),1);

    for i = 1:numel(algOthers)
        alg = algOthers{i};

        xRef = nan(numel(funcVals),1);
        xCmp = nan(numel(funcVals),1);

        for k = 1:numel(funcVals)
            fid = funcVals(k);

            maskRef = localMatchFunction(T.(funcCol), fid) & localMatchAlg(T.(algCol), algRef);
            maskCmp = localMatchFunction(T.(funcCol), fid) & localMatchAlg(T.(algCol), alg);

            rowRef = T(maskRef,:);
            rowCmp = T(maskCmp,:);

            if ~isempty(rowRef)
                xRef(k) = localToScalar(rowRef.(meanCol)(1));
            end
            if ~isempty(rowCmp)
                xCmp(k) = localToScalar(rowCmp.(meanCol)(1));
            end
        end

        valid = isfinite(xRef) & isfinite(xCmp);
        x1 = xRef(valid);
        x2 = xCmp(valid);

        comparisons(i) = string(sprintf('%s vs %s', algRef, alg));
        nPairs(i) = numel(x1);

        if numel(x1) < 2
            pValues(i) = NaN;
            results(i) = "";
            continue;
        end

        try
            p = signrank(x1, x2);
        catch
            p = NaN;
        end

        pValues(i) = p;

        meanDiff = mean(x1 - x2, 'omitnan');
        % 这里默认最小化问题：值更小更优
        if isnan(p)
            results(i) = "";
        elseif p >= alpha
            results(i) = "≈";
        else
            if meanDiff < 0
                results(i) = "+";
            elseif meanDiff > 0
                results(i) = "-";
            else
                results(i) = "≈";
            end
        end
    end

    Tout = table(comparisons, nPairs, pValues, results, ...
        'VariableNames', {'Comparison','NumFunctions','PValue','Result'});

    csvFile = fullfile(outDir, 'tab4_5_cec_main_wilcoxon.csv');
    xlsxFile = fullfile(outDir, 'tab4_5_cec_main_wilcoxon.xlsx');

    writetable(Tout, csvFile);
    writetable(Tout, xlsxFile);

    fprintf('Saved: %s\n', csvFile);
    fprintf('Saved: %s\n', xlsxFile);
end

%% ========================================================================
function summaryFile = localFindSummaryFile(resultDir)
    summaryFile = '';

    candidates = { ...
        'cec_main_summary_long.csv', ...
        'cec_summary_long.csv', ...
        'cec2017_summary_long.csv'};

    for i = 1:numel(candidates)
        fp = fullfile(resultDir, candidates{i});
        if exist(fp, 'file')
            summaryFile = fp;
            return;
        end
    end

    files = dir(fullfile(resultDir, '*summary*long*.csv'));
    if ~isempty(files)
        summaryFile = fullfile(files(1).folder, files(1).name);
    end
end

%% ========================================================================
function [funcCol, algCol, meanCol] = localDetectSummaryColumns(T)
    varNames = T.Properties.VariableNames;
    vnLower = lower(string(varNames));

    funcCol = '';
    algCol = '';
    meanCol = '';

    idx = find(ismember(vnLower, ["function","func","funcid","func_id","fid","f"]), 1);
    if ~isempty(idx), funcCol = varNames{idx}; else, error('未识别到 function 列。'); end

    idx = find(ismember(vnLower, ["algorithm","alg","algname","method","methodname"]), 1);
    if ~isempty(idx), algCol = varNames{idx}; else, error('未识别到 algorithm 列。'); end

    idx = find(ismember(vnLower, ["mean","avg","average"]), 1);
    if ~isempty(idx), meanCol = varNames{idx}; else, error('未识别到 mean 列。'); end
end

%% ========================================================================
function funcs = localUniqueFunctions(funcSeries)
    if isnumeric(funcSeries)
        funcs = unique(double(funcSeries));
        return;
    end

    s = string(funcSeries);
    funcs = nan(numel(s),1);
    for i = 1:numel(s)
        x = strtrim(s(i));
        tok = regexp(char(x), '(?:F|f)?(\d+)', 'tokens', 'once');
        if ~isempty(tok)
            funcs(i) = str2double(tok{1});
        else
            funcs(i) = str2double(x);
        end
    end
    funcs = unique(funcs(isfinite(funcs)));
end

%% ========================================================================
function tf = localMatchFunction(funcSeries, fid)
    if isnumeric(funcSeries)
        tf = double(funcSeries) == fid;
        return;
    end

    s = string(funcSeries);
    tf = false(size(s));
    for i = 1:numel(s)
        x = strtrim(s(i));
        tok = regexp(char(x), '(?:F|f)?(\d+)', 'tokens', 'once');
        if ~isempty(tok)
            tf(i) = (str2double(tok{1}) == fid);
        else
            num = str2double(x);
            if ~isnan(num)
                tf(i) = (num == fid);
            end
        end
    end
end

%% ========================================================================
function tf = localMatchAlg(algSeries, algName)
    s = upper(string(algSeries));
    tf = s == upper(string(algName));
end

%% ========================================================================
function x = localToScalar(v)
    if isnumeric(v)
        x = double(v(1));
    elseif isstring(v) || ischar(v)
        x = str2double(string(v));
    else
        x = NaN;
    end
end