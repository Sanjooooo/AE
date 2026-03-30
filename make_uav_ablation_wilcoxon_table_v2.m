function make_uav_ablation_wilcoxon_table_v2(resultDir, outTableDir)
% 专门用于消融实验：
% FAEAE vs {Base-AE, AE+Init, AE+Init+AOS, AE+Init+AOS+Repair}

    if nargin < 1 || isempty(resultDir)
        error('Please provide resultDir.');
    end
    if nargin < 2 || isempty(outTableDir)
        outTableDir = resultDir;
    end
    if ~exist(outTableDir, 'dir')
        mkdir(outTableDir);
    end

    runFile = fullfile(resultDir, 'uav_comparison_runs.csv');
    if ~exist(runFile, 'file')
        error('Cannot find: %s', runFile);
    end

    T = readtable(runFile);

    baselines = {'Base-AE','AE+Init','AE+Init+AOS','AE+Init+AOS+Repair'};
    sceneList = unique(T.Scene);

    rows = table();

    for s = 1:numel(sceneList)
        sid = sceneList(s);

        fMask = T.Scene == sid & strcmpi(T.Algorithm, 'FAEAE');
        fVals = T.BestFitness(fMask);

        for i = 1:numel(baselines)
            alg = baselines{i};
            bMask = T.Scene == sid & strcmpi(T.Algorithm, alg);
            bVals = T.BestFitness(bMask);

            n = min(numel(fVals), numel(bVals));
            if n == 0
                p = NaN;
                mark = "";
            else
                f = fVals(1:n);
                b = bVals(1:n);

                p = ranksum(f, b);

                if p >= 0.05
                    mark = "≈";
                else
                    if median(f,'omitnan') < median(b,'omitnan')
                        mark = "+";
                    else
                        mark = "-";
                    end
                end
            end

            row = table(sid, string(alg), p, string(mark), ...
                'VariableNames', {'Scene','ComparedMethod','pValue','Result'});

            if isempty(rows)
                rows = row;
            else
                rows = [rows; row]; %#ok<AGROW>
            end
        end
    end

    writetable(rows, fullfile(outTableDir, 'ablation_tab_wilcoxon.csv'));
    writetable(rows, fullfile(outTableDir, 'ablation_tab_wilcoxon.xlsx'));

    fprintf('Saved: %s\n', fullfile(outTableDir, 'ablation_tab_wilcoxon.csv'));
    fprintf('Saved: %s\n', fullfile(outTableDir, 'ablation_tab_wilcoxon.xlsx'));
end