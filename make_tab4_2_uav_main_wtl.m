function make_tab4_2_uav_main_wtl(resultDir, outDir)
%MAKE_TAB4_2_UAV_MAIN_WTL
% 基于已有 uav_comparison_faeae_wtl.csv，生成 UAV 主实验 W/T/L 表。
%
% 不重新跑实验。
%
% 输出：
%   - tab4_2_uav_main_wtl.csv
%   - tab4_2_uav_main_wtl.xlsx
%
% 用法：
%   make_tab4_2_uav_main_wtl
%   make_tab4_2_uav_main_wtl('results_uav_6alg_formal_safe')
%   make_tab4_2_uav_main_wtl('results_uav_6alg_formal_safe', 'paper_final_tables')

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

    wtlFile = fullfile(resultDir, 'uav_comparison_faeae_wtl.csv');
    if ~exist(wtlFile, 'file')
        error('未找到：%s', wtlFile);
    end

    T = readtable(wtlFile);

    fprintf('\n=== Make Tab 4-2 UAV Main W/T/L ===\n');
    fprintf('WTL file      : %s\n', wtlFile);
    fprintf('Output folder : %s\n\n', outDir);

    [compCol, winCol, tieCol, lossCol] = localDetectWTLColumns(T);

    algOrder = {'AE', 'PSO', 'GWO', 'HHO', 'WOA'};

    comparedMethod = strings(0,1);
    winVals  = zeros(0,1);
    tieVals  = zeros(0,1);
    lossVals = zeros(0,1);

    for i = 1:numel(algOrder)
        alg = algOrder{i};
        mask = localMatchAlg(T.(compCol), alg);
        rows = T(mask,:);

        if isempty(rows)
            comparedMethod(end+1,1) = string(alg); %#ok<AGROW>
            winVals(end+1,1)  = NaN; %#ok<AGROW>
            tieVals(end+1,1)  = NaN; %#ok<AGROW>
            lossVals(end+1,1) = NaN; %#ok<AGROW>
        else
            comparedMethod(end+1,1) = string(alg); %#ok<AGROW>
            winVals(end+1,1)  = localToScalar(rows.(winCol)(1));  %#ok<AGROW>
            tieVals(end+1,1)  = localToScalar(rows.(tieCol)(1));  %#ok<AGROW>
            lossVals(end+1,1) = localToScalar(rows.(lossCol)(1)); %#ok<AGROW>
        end
    end

    Tout = table(comparedMethod, winVals, tieVals, lossVals, ...
        'VariableNames', {'ComparedMethod','Win','Tie','Loss'});

    csvFile  = fullfile(outDir, 'tab4_2_uav_main_wtl.csv');
    xlsxFile = fullfile(outDir, 'tab4_2_uav_main_wtl.xlsx');

    writetable(Tout, csvFile);
    writetable(Tout, xlsxFile);

    fprintf('Saved: %s\n', csvFile);
    fprintf('Saved: %s\n', xlsxFile);
end

%% ========================================================================
function [compCol, winCol, tieCol, lossCol] = localDetectWTLColumns(T)
    varNames = T.Properties.VariableNames;
    vnLower = lower(string(varNames));

    compCol = '';
    winCol = '';
    tieCol = '';
    lossCol = '';

    idx = find(ismember(vnLower, ["algorithm","alg","algname","method","methodname","comparedmethod","compared_method","baseline"]), 1);
    if ~isempty(idx), compCol = varNames{idx}; else, error('未识别到 compared method 列。'); end

    idx = find(ismember(vnLower, ["win","wins","w"]), 1);
    if ~isempty(idx), winCol = varNames{idx}; else, error('未识别到 win 列。'); end

    idx = find(ismember(vnLower, ["tie","ties","t"]), 1);
    if ~isempty(idx), tieCol = varNames{idx}; else, error('未识别到 tie 列。'); end

    idx = find(ismember(vnLower, ["loss","losses","l"]), 1);
    if ~isempty(idx), lossCol = varNames{idx}; else, error('未识别到 loss 列。'); end
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