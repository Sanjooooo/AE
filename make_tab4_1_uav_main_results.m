function make_tab4_1_uav_main_results(resultDir, outDir)
%MAKE_TAB4_1_UAV_MAIN_RESULTS
% 基于已有 summary 文件，生成 UAV 主实验结果表：
%   mean ± std + rank
%
% 不重新跑实验。
%
% 优先读取：
%   - uav_comparison_summary_long.csv
%   - uav_comparison_average_rank.csv
%
% 输出：
%   - tab4_1_uav_main_results.csv
%   - tab4_1_uav_main_results.xlsx
%
% 用法：
%   make_tab4_1_uav_main_results
%   make_tab4_1_uav_main_results('results_uav_6alg_formal_safe')
%   make_tab4_1_uav_main_results('results_uav_6alg_formal_safe', 'paper_final_tables')

    if nargin < 1 || isempty(resultDir)
        resultDir = 'results_uav_6alg_formal_safe';
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

    summaryLongFile = fullfile(resultDir, 'uav_comparison_summary_long.csv');
    avgRankFile     = fullfile(resultDir, 'uav_comparison_average_rank.csv');

    if ~exist(summaryLongFile, 'file')
        error('未找到：%s', summaryLongFile);
    end

    T = readtable(summaryLongFile);

    if exist(avgRankFile, 'file')
        Tavg = readtable(avgRankFile);
    else
        Tavg = table();
        warning('未找到 average rank 文件：%s，后续将尝试从 summary_long 中推断。', avgRankFile);
    end

    fprintf('\n=== Make Tab 4-1 UAV Main Results ===\n');
    fprintf('Summary file  : %s\n', summaryLongFile);
    if ~isempty(Tavg)
        fprintf('Average rank  : %s\n', avgRankFile);
    end
    fprintf('Output folder : %s\n\n', outDir);

    sceneOrder = [1, 2, 4];
    algOrder = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};

    [sceneCol, algCol, meanCol, stdCol, rankCol] = localDetectSummaryColumns(T);

    % 输出表：每个 scene 两行（Mean ± Std / Rank）+ 最后一行 Average Rank
    rowNames = {};
    rowData = strings(0, numel(algOrder) + 2); 
    % 列结构：Scene | Statistic | AE | PSO | GWO | HHO | WOA | FAEAE

    for i = 1:numel(sceneOrder)
        sid = sceneOrder(i);

        meanStdRow = strings(1, numel(algOrder) + 2);
        rankRow    = strings(1, numel(algOrder) + 2);

        meanStdRow(1) = "Scene " + sid;
        meanStdRow(2) = "Mean ± Std";

        rankRow(1) = "Scene " + sid;
        rankRow(2) = "Rank";

        for j = 1:numel(algOrder)
            alg = algOrder{j};
            mask = localMatchScene(T.(sceneCol), sid) & localMatchAlg(T.(algCol), alg);
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

            meanStdRow(j+2) = sprintf('%.4f ± %.4f', meanVal, stdVal);

            if isnan(rankVal)
                rankRow(j+2) = "";
            else
                rankRow(j+2) = sprintf('%.4f', rankVal);
            end
        end

        rowData = [rowData; meanStdRow; rankRow]; %#ok<AGROW>
    end

    % Average Rank 行
    avgRankRow = strings(1, numel(algOrder) + 2);
    avgRankRow(1) = "Average";
    avgRankRow(2) = "Rank";

    avgRanks = localGetAverageRanks(Tavg, T, algOrder);
    for j = 1:numel(algOrder)
        if isnan(avgRanks(j))
            avgRankRow(j+2) = "";
        else
            avgRankRow(j+2) = sprintf('%.4f', avgRanks(j));
        end
    end

    rowData = [rowData; avgRankRow];

    Tout = array2table(rowData, 'VariableNames', ...
        [{'Scene','Statistic'}, algOrder]);

    csvFile = fullfile(outDir, 'tab4_1_uav_main_results.csv');
    xlsxFile = fullfile(outDir, 'tab4_1_uav_main_results.xlsx');

    writetable(Tout, csvFile);
    writetable(Tout, xlsxFile);

    fprintf('Saved: %s\n', csvFile);
    fprintf('Saved: %s\n', xlsxFile);
end

%% ========================================================================
function [sceneCol, algCol, meanCol, stdCol, rankCol] = localDetectSummaryColumns(T)
    varNames = T.Properties.VariableNames;
    vnLower = lower(string(varNames));

    sceneCol = '';
    algCol = '';
    meanCol = '';
    stdCol = '';
    rankCol = '';

    idx = find(ismember(vnLower, ["scene","sceneid","scene_id","mapid","scenarioid"]), 1);
    if ~isempty(idx), sceneCol = varNames{idx}; else, error('未识别到 scene 列。'); end

    idx = find(ismember(vnLower, ["algorithm","alg","algname","method","methodname"]), 1);
    if ~isempty(idx), algCol = varNames{idx}; else, error('未识别到 algorithm 列。'); end

    idx = find(ismember(vnLower, ["mean","avg","meancost","average"]), 1);
    if ~isempty(idx), meanCol = varNames{idx}; else, error('未识别到 mean 列。'); end

    idx = find(ismember(vnLower, ["std","stdev","stddev","sigma"]), 1);
    if ~isempty(idx), stdCol = varNames{idx}; else, error('未识别到 std 列。'); end

    idx = find(ismember(vnLower, ["rank","averagerank","avg_rank","ranking"]), 1);
    if ~isempty(idx), rankCol = varNames{idx}; else, rankCol = ''; end
end

%% ========================================================================
function avgRanks = localGetAverageRanks(Tavg, Tsummary, algOrder)
    avgRanks = nan(1, numel(algOrder));

    % 先尝试从 average_rank.csv 读
    if ~isempty(Tavg) && height(Tavg) > 0
        vnLower = lower(string(Tavg.Properties.VariableNames));

        algIdx = find(ismember(vnLower, ["algorithm","alg","algname","method","methodname"]), 1);
        rankIdx = find(ismember(vnLower, ["rank","averagerank","avg_rank","average_rank"]), 1);

        if ~isempty(algIdx) && ~isempty(rankIdx)
            algCol = Tavg.Properties.VariableNames{algIdx};
            rankCol = Tavg.Properties.VariableNames{rankIdx};

            for j = 1:numel(algOrder)
                mask = localMatchAlg(Tavg.(algCol), algOrder{j});
                rows = Tavg(mask,:);
                if ~isempty(rows)
                    avgRanks(j) = localToScalar(rows.(rankCol)(1));
                end
            end
            return;
        end
    end

    % 否则尝试从 summary_long 中按 scene rank 平均
    [~, algCol, ~, ~, rankCol] = localDetectSummaryColumns(Tsummary);
    if isempty(rankCol)
        return;
    end

    for j = 1:numel(algOrder)
        mask = localMatchAlg(Tsummary.(algCol), algOrder{j});
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
function tf = localMatchScene(sceneSeries, sceneId)
    if isnumeric(sceneSeries)
        tf = double(sceneSeries) == sceneId;
        return;
    end

    s = string(sceneSeries);
    tf = false(size(s));

    for i = 1:numel(s)
        x = strtrim(s(i));
        num = sscanf(char(x), 'Scene %d');
        if ~isempty(num)
            tf(i) = (num == sceneId);
        else
            num2 = str2double(x);
            if ~isnan(num2)
                tf(i) = (num2 == sceneId);
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