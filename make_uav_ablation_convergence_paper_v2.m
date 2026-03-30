function make_uav_ablation_convergence_paper_v2(resultDir, outFigDir)
%MAKE_UAV_ABLATION_CONVERGENCE_PAPER_V2
% 仅用于 UAV 消融实验收敛曲线图。
% 精确匹配 run_records 中的安全文件名：
%   BASE_AE
%   AE_INIT
%   AE_INIT_AOS
%   AE_INIT_AOS_REPAIR
%   FAEAE

    if nargin < 1 || isempty(resultDir)
        error('Please provide resultDir.');
    end
    if nargin < 2 || isempty(outFigDir)
        outFigDir = resultDir;
    end
    if ~exist(outFigDir, 'dir')
        mkdir(outFigDir);
    end

    runDir = fullfile(resultDir, 'run_records');
    if ~exist(runDir, 'dir')
        error('Cannot find run_records folder: %s', runDir);
    end

    algMap = { ...
        'Base-AE', 'BASE_AE'; ...
        'AE+Init', 'AE_INIT'; ...
        'AE+Init+AOS', 'AE_INIT_AOS'; ...
        'AE+Init+AOS+Repair', 'AE_INIT_AOS_REPAIR'; ...
        'FAEAE', 'FAEAE'};

    sceneList = [1 2 4];

    fprintf('\n=== Make UAV Ablation Convergence Figures ===\n');
    fprintf('Result folder: %s\n', resultDir);
    fprintf('Run folder   : %s\n', runDir);
    fprintf('Output folder: %s\n\n', outFigDir);

    for s = 1:numel(sceneList)
        sid = sceneList(s);

        fig = figure('Color', 'w', 'Position', [100 100 1000 700]);
        hold on;

        legendNames = {};
        hasAny = false;

        for a = 1:size(algMap,1)
            showName = algMap{a,1};
            safeName = algMap{a,2};

            files = dir(fullfile(runDir, sprintf('scene%d_%s_run*.mat', sid, safeName)));
            if isempty(files)
                fprintf('Scene %d: %s | no run files found.\n', sid, showName);
                continue;
            end

            curves = {};
            maxLen = 0;

            for k = 1:numel(files)
                S = load(fullfile(files(k).folder, files(k).name));
                rr = localExtractResultStruct(S);

                conv = [];
                if isfield(rr, 'convergence') && ~isempty(rr.convergence)
                    conv = rr.convergence(:);
                elseif isfield(rr, 'bestHist') && ~isempty(rr.bestHist)
                    conv = rr.bestHist(:);
                end

                if isempty(conv)
                    continue;
                end

                curves{end+1} = conv; %#ok<AGROW>
                maxLen = max(maxLen, numel(conv));
            end

            if isempty(curves)
                fprintf('Scene %d: %s | no valid convergence data.\n', sid, showName);
                continue;
            end

            M = nan(numel(curves), maxLen);
            for k = 1:numel(curves)
                c = curves{k};
                M(k,1:numel(c)) = c(:)';
                if numel(c) < maxLen
                    M(k,numel(c)+1:end) = c(end);
                end
            end

            meanCurve = mean(M, 1, 'omitnan');
            plot(meanCurve, 'LineWidth', 2.0);

            legendNames{end+1} = showName; %#ok<AGROW>
            hasAny = true;

            fprintf('Scene %d: %s | valid runs used = %d | curve length = %d\n', ...
                sid, showName, size(M,1), size(M,2));
        end

        if ~hasAny
            close(fig);
            continue;
        end

        grid on;
        xlabel('Iteration');
        ylabel('Mean best cost');
        title(sprintf('Scene %d Ablation Convergence', sid));

        legend(legendNames, 'Location', 'northeastoutside');

        if sid == 1
            baseName = 'fig_scene1_ablation_convergence';
        elseif sid == 2
            baseName = 'fig_scene2_ablation_convergence';
        else
            baseName = 'fig_scene4_ablation_convergence';
        end

        saveas(fig, fullfile(outFigDir, [baseName '.png']));
        savefig(fig, fullfile(outFigDir, [baseName '.fig']));
        close(fig);
    end
end

function rr = localExtractResultStruct(S)
    if isfield(S, 'result') && isstruct(S.result)
        rr = S.result;
        return;
    end

    fns = fieldnames(S);
    for i = 1:numel(fns)
        if isstruct(S.(fns{i}))
            rr = S.(fns{i});
            return;
        end
    end

    error('Cannot find result struct in mat file.');
end