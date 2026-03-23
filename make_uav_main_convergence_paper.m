function make_uav_main_convergence_paper(resultDir, outDir)
%MAKE_UAV_MAIN_CONVERGENCE_PAPER
% 只基于已有 run_records 结果，生成 UAV 主实验 3 张收敛曲线图：
%   - Scene 1
%   - Scene 2
%   - Scene 4
%
% 不会重新跑实验。
%
% 颜色映射与 plot_uav_representative_corridor_paths_all 保持一致：
%   algColors = lines(6)
%   顺序固定为：
%   AE / PSO / GWO / HHO / WOA / FAEAE
%
% 用法：
%   make_uav_main_convergence_paper
%   make_uav_main_convergence_paper('results_uav_6alg_formal_safe')
%   make_uav_main_convergence_paper('results_uav_6alg_formal_safe', 'paper_final_figures')
%
% 输出：
%   fig4_4_scene1_convergence_main.png/.fig
%   fig4_5_scene2_convergence_main.png/.fig
%   fig4_6_scene4_convergence_main.png/.fig

    if nargin < 1 || isempty(resultDir)
        resultDir = 'results_uav_6alg_formal_safe';
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

    runDir = fullfile(resultDir, 'run_records');
    if ~exist(runDir, 'dir')
        error('未找到 run_records 目录：%s', runDir);
    end

    sceneIds = [1, 2, 4];
    algOrder = {'AE', 'PSO', 'GWO', 'HHO', 'WOA', 'FAEAE'};

    fprintf('\n=== Make UAV Main Convergence Figures ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Run folder   : %s\n', runDir);
    fprintf('Output folder: %s\n\n', outDir);

    for s = 1:numel(sceneIds)
        sceneId = sceneIds(s);

        fig = figure('Color', 'w', 'Position', [80 80 1100 780]);
        hold on;
        grid on;
        box on;

        legendHandles = [];
        legendNames = {};

        fprintf('Scene %d:\n', sceneId);

        for a = 1:numel(algOrder)
            algName = algOrder{a};
            files = localFindRunFiles(runDir, sceneId, algName);

            if isempty(files)
                fprintf('  %-6s | no run files found.\n', algName);
                continue;
            end

            curves = {};
            for k = 1:numel(files)
                fp = fullfile(files(k).folder, files(k).name);
                try
                    S = load(fp);
                    rr = localExtractResultStruct(S);
                    curve = localExtractConvergenceCurve(rr);
                    if ~isempty(curve)
                        curves{end+1} = curve(:); %#ok<AGROW>
                    end
                catch
                    % ignore broken file
                end
            end

            if isempty(curves)
                fprintf('  %-6s | no valid convergence curve found.\n', algName);
                continue;
            end

            meanCurve = localMeanCurve(curves);

            style = localAlgStyle(algName, algOrder);
            h = plot(1:numel(meanCurve), meanCurve, ...
                'LineWidth', style.LineWidth, ...
                'Color', style.Color);

            legendHandles(end+1) = h; %#ok<AGROW>
            legendNames{end+1} = algName; %#ok<AGROW>

            fprintf('  %-6s | valid runs used = %d | curve length = %d\n', ...
                algName, numel(curves), numel(meanCurve));
        end

        xlabel('Iteration', 'FontName', 'Times New Roman', 'FontSize', 13);
        ylabel('Best-so-far cost', 'FontName', 'Times New Roman', 'FontSize', 13);
        title(sprintf('Scene %d Convergence Curves', sceneId), ...
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

        [pngName, figName] = localSceneConvFilenames(sceneId);
        savefig(fig, fullfile(outDir, figName));
        exportgraphics(fig, fullfile(outDir, pngName), 'Resolution', 300);
        close(fig);

        fprintf('  Saved: %s\n', fullfile(outDir, pngName));
        fprintf('  Saved: %s\n\n', fullfile(outDir, figName));
    end

    fprintf('Done.\n');
end

%% ========================================================================
function files = localFindRunFiles(runDir, sceneId, algName)
    pattern1 = fullfile(runDir, sprintf('scene%d_%s_run*.mat', sceneId, upper(algName)));
    files = dir(pattern1);

    if ~isempty(files)
        return;
    end

    allSceneFiles = dir(fullfile(runDir, sprintf('scene%d_*run*.mat', sceneId)));
    if isempty(allSceneFiles)
        files = [];
        return;
    end

    names = upper(string({allSceneFiles.name}));
    mask = contains(names, upper(string(algName)));
    files = allSceneFiles(mask);
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
% 与 representative 轨迹图保持一致：
% algColors = lines(numel(algorithms))

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

%% ========================================================================
function [pngName, figName] = localSceneConvFilenames(sceneId)
    switch sceneId
        case 1
            stem = 'fig4_4_scene1_convergence_main';
        case 2
            stem = 'fig4_5_scene2_convergence_main';
        case 4
            stem = 'fig4_6_scene4_convergence_main';
        otherwise
            stem = sprintf('scene%d_convergence_main', sceneId);
    end

    pngName = [stem, '.png'];
    figName = [stem, '.fig'];
end