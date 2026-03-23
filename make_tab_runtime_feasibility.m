function make_tab_runtime_feasibility(resultDir, outDir, prefix)
%MAKE_TAB_RUNTIME_FEASIBILITY
% 基于已有 summary 文件，生成 UAV 实验的
% Feasibility ratio + Avg runtime 表。
%
% 优先读取：
%   - uav_comparison_summary_long.csv
%   - uav_comparison_summary_workspace.mat
%
% 输出：
%   - [prefix '_tab_runtime_feasibility.csv']
%   - [prefix '_tab_runtime_feasibility.xlsx']
%
% 表结构：
%   每个 scene 两行：
%     Feasibility ratio
%     Avg runtime (s)
%
% 用法：
%   make_tab_runtime_feasibility
%   make_tab_runtime_feasibility(resultDir)
%   make_tab_runtime_feasibility(resultDir, outDir)
%   make_tab_runtime_feasibility(resultDir, outDir, 'main')
%   make_tab_runtime_feasibility(resultDir, outDir, 'fair_init')

    if nargin < 1 || isempty(resultDir)
        resultDir = uigetdir(pwd, 'Select UAV result folder');
        if isequal(resultDir, 0)
            error('No folder selected.');
        end
    end
    if nargin < 2 || isempty(outDir)
        outDir = 'paper_final_tables';
    end
    if nargin < 3 || isempty(prefix)
        prefix = 'main';
    end

    if ~exist(resultDir, 'dir')
        error('结果目录不存在：%s', resultDir);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    summaryLongFile = fullfile(resultDir, 'uav_comparison_summary_long.csv');
    summaryMatFile  = fullfile(resultDir, 'uav_comparison_summary_workspace.mat');

    if exist(summaryLongFile, 'file')
        T = readtable(summaryLongFile);
        sourceUsed = summaryLongFile;
    elseif exist(summaryMatFile, 'file')
        S = load(summaryMatFile);
        if isfield(S, 'summary') && isfield(S.summary, 'longTable')
            T = S.summary.longTable;
        else
            error('summary workspace 中未找到 summary.longTable。');
        end
        sourceUsed = summaryMatFile;
    else
        error('未找到 summary_long.csv 或 summary_workspace.mat。');
    end

    fprintf('\n=== Make Runtime + Feasibility Table ===\n');
    fprintf('Source used   : %s\n', sourceUsed);
    fprintf('Output folder : %s\n', outDir);
    fprintf('Prefix        : %s\n\n', prefix);

    sceneOrder = [1, 2, 4];
    algOrder = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};

    [sceneCol, algCol, feasCol, runtimeCol] = localDetectColumns(T);

    rowData = strings(0, numel(algOrder) + 2);

    for i = 1:numel(sceneOrder)
        sid = sceneOrder(i);

        feasRow = strings(1, numel(algOrder) + 2);
        timeRow = strings(1, numel(algOrder) + 2);

        feasRow(1) = "Scene " + sid;
        feasRow(2) = "Feasibility ratio";

        timeRow(1) = "Scene " + sid;
        timeRow(2) = "Avg runtime (s)";

        for j = 1:numel(algOrder)
            alg = algOrder{j};

            mask = localMatchScene(T.(sceneCol), sid) & localMatchAlg(T.(algCol), alg);
            rows = T(mask,:);

            if isempty(rows)
                feasRow(j+2) = "";
                timeRow(j+2) = "";
                continue;
            end

            feasVal = localToScalar(rows.(feasCol)(1));
            timeVal = localToScalar(rows.(runtimeCol)(1));

            if isnan(feasVal)
                feasRow(j+2) = "";
            else
                feasRow(j+2) = sprintf('%.4f', feasVal);
            end

            if isnan(timeVal)
                timeRow(j+2) = "";
            else
                timeRow(j+2) = sprintf('%.4f', timeVal);
            end
        end

        rowData = [rowData; feasRow; timeRow]; %#ok<AGROW>
    end

    Tout = array2table(rowData, 'VariableNames', ...
        [{'Scene','Statistic'}, algOrder]);

    csvFile  = fullfile(outDir, sprintf('%s_tab_runtime_feasibility.csv', prefix));
    xlsxFile = fullfile(outDir, sprintf('%s_tab_runtime_feasibility.xlsx', prefix));

    writetable(Tout, csvFile);
    writetable(Tout, xlsxFile);

    fprintf('Saved: %s\n', csvFile);
    fprintf('Saved: %s\n', xlsxFile);
end

%% ========================================================================
function [sceneCol, algCol, feasCol, runtimeCol] = localDetectColumns(T)
    varNames = T.Properties.VariableNames;
    vnLower = lower(string(varNames));

    sceneCol = '';
    algCol = '';
    feasCol = '';
    runtimeCol = '';

    idx = find(ismember(vnLower, ["scene","sceneid","scene_id","mapid","scenarioid"]), 1);
    if ~isempty(idx)
        sceneCol = varNames{idx};
    else
        error('未识别到 scene 列。');
    end

    idx = find(ismember(vnLower, ["algorithm","alg","algname","method","methodname"]), 1);
    if ~isempty(idx)
        algCol = varNames{idx};
    else
        error('未识别到 algorithm 列。');
    end

    idx = find(ismember(vnLower, ["feasratio","feasible_ratio","feasibility","feasibilityratio","feasible"]), 1);
    if ~isempty(idx)
        feasCol = varNames{idx};
    else
        error('未识别到 feasibility ratio 列。');
    end

    idx = find(ismember(vnLower, ["avgruntime","avgtime","runtime","time","avg_runtime"]), 1);
    if ~isempty(idx)
        runtimeCol = varNames{idx};
    else
        error('未识别到 avg runtime 列。');
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