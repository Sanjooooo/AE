function make_uav_wilcoxon_table(resultDir, outDir, testType, prefix)
%MAKE_UAV_WILCOXON_TABLE
% 基于 uav_comparison_results.mat 中的逐次运行结果，
% 对 FAEAE 与各 baseline 在每个场景上做非参数显著性检验。
%
% 默认使用 ranksum（更稳健，不要求严格配对）。
% 如果你确认不同算法共享同一组 run seed，也可改用 signrank。
%
% 输出：
%   - [prefix '_tab_wilcoxon.csv']
%   - [prefix '_tab_wilcoxon.xlsx']
%
% 表结构：
%   Scene | ComparedMethod | FAEAE_Mean | Baseline_Mean | pValue | Result | Test
%
% 其中：
%   Result = '+': FAEAE 显著更优
%   Result = '-': FAEAE 显著更差
%   Result = '≈': 差异不显著
%
% 用法：
%   make_uav_wilcoxon_table
%   make_uav_wilcoxon_table(resultDir)
%   make_uav_wilcoxon_table(resultDir, outDir)
%   make_uav_wilcoxon_table(resultDir, outDir, 'ranksum')
%   make_uav_wilcoxon_table(resultDir, outDir, 'ranksum', 'main')
%   make_uav_wilcoxon_table(resultDir, outDir, 'ranksum', 'fair_init')

    if nargin < 1 || isempty(resultDir)
        resultDir = uigetdir(pwd, 'Select UAV result folder');
        if isequal(resultDir, 0)
            error('No folder selected.');
        end
    end
    if nargin < 2 || isempty(outDir)
        outDir = 'paper_final_tables';
    end
    if nargin < 3 || isempty(testType)
        testType = 'ranksum';
    end
    if nargin < 4 || isempty(prefix)
        prefix = 'main';
    end

    if ~exist(resultDir, 'dir')
        error('结果目录不存在：%s', resultDir);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    dataFile = fullfile(resultDir, 'uav_comparison_results.mat');
    if ~exist(dataFile, 'file')
        error('未找到：%s', dataFile);
    end

    S = load(dataFile);
    if ~isfield(S, 'allResults') || ~isfield(S, 'cfg')
        error('结果文件中缺少 allResults 或 cfg。');
    end

    allResults = S.allResults;
    cfg = S.cfg;

    sceneOrder = [1, 2, 4];
    algOrder = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};
    faeName = 'FAEAE';
    alpha = 0.05;

    sceneIds = cfg.sceneIds;
    algorithms = cfg.algorithms;

    faeIdx = find(strcmpi(algorithms, faeName), 1);
    if isempty(faeIdx)
        error('未在 cfg.algorithms 中找到 FAEAE。');
    end

    fprintf('\n=== Make UAV Wilcoxon Table ===\n');
    fprintf('Data file     : %s\n', dataFile);
    fprintf('Output folder : %s\n', outDir);
    fprintf('Test type     : %s\n', testType);
    fprintf('Prefix        : %s\n\n', prefix);

    Scene = strings(0,1);
    ComparedMethod = strings(0,1);
    FAEAE_Mean = zeros(0,1);
    Baseline_Mean = zeros(0,1);
    pValue = zeros(0,1);
    Result = strings(0,1);
    Test = strings(0,1);

    for s = 1:numel(sceneOrder)
        sid = sceneOrder(s);

        sIdx = find(sceneIds == sid, 1);
        if isempty(sIdx)
            warning('cfg.sceneIds 中未找到 Scene %d，跳过。', sid);
            continue;
        end

        faeVals = localExtractBestVals(allResults{sIdx, faeIdx});

        for a = 1:numel(algOrder)
            alg = algOrder{a};
            if strcmpi(alg, faeName)
                continue;
            end

            aIdx = find(strcmpi(algorithms, alg), 1);
            if isempty(aIdx)
                warning('cfg.algorithms 中未找到算法 %s，跳过。', alg);
                continue;
            end

            baseVals = localExtractBestVals(allResults{sIdx, aIdx});

            [p, flag] = localDoTest(faeVals, baseVals, testType, alpha);

            Scene(end+1,1) = "Scene " + sid; %#ok<AGROW>
            ComparedMethod(end+1,1) = string(alg); %#ok<AGROW>
            FAEAE_Mean(end+1,1) = mean(faeVals, 'omitnan'); %#ok<AGROW>
            Baseline_Mean(end+1,1) = mean(baseVals, 'omitnan'); %#ok<AGROW>
            pValue(end+1,1) = p; %#ok<AGROW>
            Result(end+1,1) = flag; %#ok<AGROW>
            Test(end+1,1) = string(lower(testType)); %#ok<AGROW>

            fprintf('  Scene %d | vs %-5s | p = %.6g | result = %s\n', sid, alg, p, flag);
        end
    end

    Tout = table(Scene, ComparedMethod, FAEAE_Mean, Baseline_Mean, pValue, Result, Test);

    csvFile  = fullfile(outDir, sprintf('%s_tab_wilcoxon.csv', prefix));
    xlsxFile = fullfile(outDir, sprintf('%s_tab_wilcoxon.xlsx', prefix));

    writetable(Tout, csvFile);
    writetable(Tout, xlsxFile);

    fprintf('\nSaved: %s\n', csvFile);
    fprintf('Saved: %s\n', xlsxFile);
end

%% ========================================================================
function vals = localExtractBestVals(runs)
    if isempty(runs)
        vals = nan(0,1);
        return;
    end

    n = numel(runs);
    vals = nan(n,1);

    for i = 1:n
        rr = runs(i);
        vals(i) = localGetField(rr, {'bestFit','bestFitness','bestCost'}, NaN);
    end

    vals = vals(isfinite(vals));
end

%% ========================================================================
function [p, flag] = localDoTest(faeVals, baseVals, testType, alpha)
    p = NaN;
    flag = "≈";

    faeVals = faeVals(isfinite(faeVals));
    baseVals = baseVals(isfinite(baseVals));

    if isempty(faeVals) || isempty(baseVals)
        return;
    end

    switch lower(testType)
        case 'signrank'
            n = min(numel(faeVals), numel(baseVals));
            if n == 0
                return;
            end
            x = faeVals(1:n);
            y = baseVals(1:n);
            try
                p = signrank(x, y);
            catch
                p = NaN;
            end

        case 'ranksum'
            try
                p = ranksum(faeVals, baseVals);
            catch
                p = NaN;
            end

        otherwise
            error('Unsupported testType: %s. Use "ranksum" or "signrank".', testType);
    end

    mF = mean(faeVals, 'omitnan');
    mB = mean(baseVals, 'omitnan');

    if isnan(p)
        flag = "≈";
        return;
    end

    if p < alpha
        if mF < mB
            flag = "+";
        elseif mF > mB
            flag = "-";
        else
            flag = "≈";
        end
    else
        flag = "≈";
    end
end

%% ========================================================================
function val = localGetField(s, names, defaultVal)
    val = defaultVal;
    for k = 1:numel(names)
        if isfield(s, names{k})
            val = s.(names{k});
            return;
        end
    end
end