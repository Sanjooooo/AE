function make_tab4_6_cec_ablation_results(resultDir, outDir)
%MAKE_TAB4_6_CEC_ABLATION_RESULTS
% 基于已有 CEC 消融 summary 文件，生成结果表：
%   mean ± std + rank
%
% 不重新跑实验。
%
% 优先读取：
%   - cec_ablation_summary_long.csv
%   - cec2017_ablation_summary_long.csv
%   - resultDir 下任意包含 ablation + summary_long 的 csv
%
% 输出：
%   - tab4_6_cec_ablation_results.csv
%   - tab4_6_cec_ablation_results.xlsx
%
% 用法：
%   make_tab4_6_cec_ablation_results
%   make_tab4_6_cec_ablation_results('results_cec2017_ablation')
%   make_tab4_6_cec_ablation_results('results_cec2017_ablation', 'paper_final_tables')

    if nargin < 1 || isempty(resultDir)
        resultDir = 'results_cec2017_ablation';
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

    [summaryFile, avgRankFile] = localFindSummaryFiles(resultDir);

    if isempty(summaryFile)
        error('未找到 CEC 消融 summary_long 文件。');
    end

    T = readtable(summaryFile);
    if ~isempty(avgRankFile) && exist(avgRankFile, 'file')
        Tavg = readtable(avgRankFile);
    else
        Tavg = table();
    end

    fprintf('\n=== Make Tab 4-6 CEC Ablation Results ===\n');
    fprintf('Summary file  : %s\n', summaryFile);
    if ~isempty(Tavg)
        fprintf('Average rank  : %s\n', avgRankFile);
    end
    fprintf('Output folder : %s\n\n', outDir);

    methodOrder = {'Base-AE', 'AE+Init', 'AE+Init+AOS', 'AE+Init+AOS+Repair', 'FAE-AE'};

    [funcCol, methodCol, meanCol, stdCol, rankCol] = localDetectSummaryColumns(T);

    funcVals = localUniqueFunctions(T.(funcCol));
    funcVals = sort(funcVals(:).');

    rowData = strings(0, numel(methodOrder) + 2);

    for i = 1:numel(funcVals)
        fid = funcVals(i);

        meanStdRow = strings(1, numel(methodOrder) + 2);
        rankRow    = strings(1, numel(methodOrder) + 2);

        meanStdRow(1) = "F" + fid;
        meanStdRow(2) = "Mean ± Std";

        rankRow(1) = "F" + fid;
        rankRow(2) = "Rank";

        for j = 1:numel(methodOrder)
            method = methodOrder{j};

            mask = localMatchFunction(T.(funcCol), fid) & localMatchMethod(T.(methodCol), method);
            rows = T(mask,:);

            if isempty(rows)
                meanStdRow(j+2) = "";
                rankRow(j+2) = "";
                continue;
            end

            meanVal = localToScalar(rows.(meanCol)(1));
            stdVal  = localToScalar(rows.(stdCol)(1));

            if ~isempty(rankCol)
                rankVal = localToScalar(rows.(rankCol)(1));
            else
                rankVal = NaN;
            end

            meanStdRow(j+2) = sprintf('%.4e ± %.4e', meanVal, stdVal);

            if isnan(rankVal)
                rankRow(j+2) = "";
            else
                rankRow(j+2) = sprintf('%.4f', rankVal);
            end
        end

        rowData = [rowData; meanStdRow; rankRow]; %#ok<AGROW>
    end

    avgRankRow = strings(1, numel(methodOrder) + 2);
    avgRankRow(1) = "Average";
    avgRankRow(2) = "Rank";

    avgRanks = localGetAverageRanks(Tavg, T, methodOrder);
    for j = 1:numel(methodOrder)
        if isnan(avgRanks(j))
            avgRankRow(j+2) = "";
        else
            avgRankRow(j+2) = sprintf('%.4f', avgRanks(j));
        end
    end

    rowData = [rowData; avgRankRow];

    Tout = array2table(rowData, 'VariableNames', ...
        [{'Function','Statistic'}, methodOrder]);

    csvFile = fullfile(outDir, 'tab4_6_cec_ablation_results.csv');
    xlsxFile = fullfile(outDir, 'tab4_6_cec_ablation_results.xlsx');

    writetable(Tout, csvFile);
    writetable(Tout, xlsxFile);

    fprintf('Saved: %s\n', csvFile);
    fprintf('Saved: %s\n', xlsxFile);
end

%% ========================================================================
function [summaryFile, avgRankFile] = localFindSummaryFiles(resultDir)
    summaryFile = '';
    avgRankFile = '';

    candidatesSummary = { ...
        'cec_ablation_summary_long.csv', ...
        'cec2017_ablation_summary_long.csv'};

    for i = 1:numel(candidatesSummary)
        fp = fullfile(resultDir, candidatesSummary{i});
        if exist(fp, 'file')
            summaryFile = fp;
            break;
        end
    end

    if isempty(summaryFile)
        files = dir(fullfile(resultDir, '*ablation*summary*long*.csv'));
        if ~isempty(files)
            summaryFile = fullfile(files(1).folder, files(1).name);
        end
    end

    candidatesRank = { ...
        'cec_ablation_average_rank.csv', ...
        'cec2017_ablation_average_rank.csv'};

    for i = 1:numel(candidatesRank)
        fp = fullfile(resultDir, candidatesRank{i});
        if exist(fp, 'file')
            avgRankFile = fp;
            break;
        end
    end

    if isempty(avgRankFile)
        files = dir(fullfile(resultDir, '*ablation*average*rank*.csv'));
        if ~isempty(files)
            avgRankFile = fullfile(files(1).folder, files(1).name);
        end
    end
end

%% ========================================================================
function [funcCol, methodCol, meanCol, stdCol, rankCol] = localDetectSummaryColumns(T)
    varNames = T.Properties.VariableNames;
    vnLower = lower(string(varNames));

    funcCol = '';
    methodCol = '';
    meanCol = '';
    stdCol = '';
    rankCol = '';

    idx = find(ismember(vnLower, ["function","func","funcid","func_id","fid","f"]), 1);
    if ~isempty(idx), funcCol = varNames{idx}; else, error('未识别到 function 列。'); end

    idx = find(ismember(vnLower, ["algorithm","alg","algname","method","methodname"]), 1);
    if ~isempty(idx), methodCol = varNames{idx}; else, error('未识别到 method 列。'); end

    idx = find(ismember(vnLower, ["mean","avg","average"]), 1);
    if ~isempty(idx), meanCol = varNames{idx}; else, error('未识别到 mean 列。'); end

    idx = find(ismember(vnLower, ["std","stdev","stddev","sigma"]), 1);
    if ~isempty(idx), stdCol = varNames{idx}; else, error('未识别到 std 列。'); end

    idx = find(ismember(vnLower, ["rank","averagerank","avg_rank","ranking"]), 1);
    if ~isempty(idx), rankCol = varNames{idx}; else, rankCol = ''; end
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
function avgRanks = localGetAverageRanks(Tavg, Tsummary, methodOrder)
    avgRanks = nan(1, numel(methodOrder));

    if ~isempty(Tavg) && height(Tavg) > 0
        vnLower = lower(string(Tavg.Properties.VariableNames));

        methodIdx = find(ismember(vnLower, ["algorithm","alg","algname","method","methodname"]), 1);
        rankIdx = find(ismember(vnLower, ["rank","averagerank","avg_rank","average_rank"]), 1);

        if ~isempty(methodIdx) && ~isempty(rankIdx)
            methodCol = Tavg.Properties.VariableNames{methodIdx};
            rankCol = Tavg.Properties.VariableNames{rankIdx};

            for j = 1:numel(methodOrder)
                mask = localMatchMethod(Tavg.(methodCol), methodOrder{j});
                rows = Tavg(mask,:);
                if ~isempty(rows)
                    avgRanks(j) = localToScalar(rows.(rankCol)(1));
                end
            end
            return;
        end
    end

    [~, methodCol, ~, ~, rankCol] = localDetectSummaryColumns(Tsummary);
    if isempty(rankCol)
        return;
    end

    for j = 1:numel(methodOrder)
        mask = localMatchMethod(Tsummary.(methodCol), methodOrder{j});
        rows = Tsummary(mask,:);
        if ~isempty(rows)
            vals = localToNumericVector(rows.(rankCol));
            vals = vals(isfinite(vals));
            if ~isempty(vals)
                avgRanks(j) = mean(vals);
            end
        end
    end
end

%% ========================================================================
function tf = localMatchMethod(methodSeries, methodName)
    s = upper(string(methodSeries));
    tf = s == upper(string(methodName));
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

%% ========================================================================
function x = localToNumericVector(v)
    if isnumeric(v)
        x = double(v(:));
    elseif isstring(v) || ischar(v)
        x = str2double(string(v(:)));
    else
        x = nan(numel(v),1);
    end
end