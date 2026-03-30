function build_merged_uav_master_v2(oldDir, newDir, mergedDir)
%BUILD_MERGED_UAV_MASTER_V2
% 用旧完整结果目录作为骨架，只替换 FAEAE 为新 v2 的 run_records，
% 生成兼容原脚本的：
%   - uav_comparison_results.mat
%   - run_records/
%
% oldDir: 旧完整 fair_init 结果目录（含 uav_comparison_results.mat 和 run_records）
% newDir: 新 v2 仅 FAEAE 结果目录（至少含 run_records）
% mergedDir: 已经放好合并 csv 的目录；本函数会在其中补齐 .mat 和 run_records

    if nargin < 3
        error('Usage: build_merged_uav_master_v2(oldDir, newDir, mergedDir)');
    end

    oldMat = fullfile(oldDir, 'uav_comparison_results.mat');
    oldRunDir = fullfile(oldDir, 'run_records');
    newRunDir = fullfile(newDir, 'run_records');
    mergedMat = fullfile(mergedDir, 'uav_comparison_results.mat');
    mergedRunDir = fullfile(mergedDir, 'run_records');

    if ~exist(oldMat, 'file')
        error('旧目录缺少 uav_comparison_results.mat: %s', oldMat);
    end
    if ~exist(oldRunDir, 'dir')
        error('旧目录缺少 run_records: %s', oldRunDir);
    end
    if ~exist(newRunDir, 'dir')
        error('新目录缺少 run_records: %s', newRunDir);
    end
    if ~exist(mergedDir, 'dir')
        mkdir(mergedDir);
    end
    if ~exist(mergedRunDir, 'dir')
        mkdir(mergedRunDir);
    end

    fprintf('\n============================================================\n');
    fprintf('Build merged UAV master (v2)\n');
    fprintf('OldDir    : %s\n', oldDir);
    fprintf('NewDir    : %s\n', newDir);
    fprintf('MergedDir : %s\n', mergedDir);
    fprintf('============================================================\n\n');

    %% 1) 复制并合并 run_records
    fprintf('[1/3] Merging run_records ...\n');

    % 先复制旧目录全部 run_records
    copyfile(fullfile(oldRunDir, '*'), mergedRunDir);

    % 删除 merged 中旧的 FAEAE 文件
    oldFaeae = dir(fullfile(mergedRunDir, '*FAEAE*.mat'));
    for k = 1:numel(oldFaeae)
        delete(fullfile(oldFaeae(k).folder, oldFaeae(k).name));
    end

    % 拷贝新 FAEAE 文件
    newFaeae = dir(fullfile(newRunDir, '*FAEAE*.mat'));
    if isempty(newFaeae)
        error('新 run_records 中没有找到 FAEAE 的 .mat 文件。');
    end
    for k = 1:numel(newFaeae)
        copyfile(fullfile(newFaeae(k).folder, newFaeae(k).name), mergedRunDir);
    end
    fprintf('  Copied %d new FAEAE run files.\n', numel(newFaeae));

    %% 2) 用旧 master mat 作为骨架，只替换 allResults 中 FAEAE
    fprintf('[2/3] Rebuilding uav_comparison_results.mat ...\n');

    S = load(oldMat);
    if ~isfield(S, 'allResults') || ~isfield(S, 'cfg')
        error('旧 uav_comparison_results.mat 中缺少 allResults 或 cfg。');
    end

    cfg = S.cfg;
    allResults = S.allResults;

    faeIdx = find(strcmpi(cfg.algorithms, 'FAEAE'), 1);
    if isempty(faeIdx)
        error('旧 cfg.algorithms 中没有找到 FAEAE。');
    end

    for s = 1:numel(cfg.sceneIds)
        sid = cfg.sceneIds(s);

        files = dir(fullfile(newRunDir, sprintf('scene%d_FAEAE_run*.mat', sid)));
        if isempty(files)
            % 保险：宽松匹配
            files = dir(fullfile(newRunDir, sprintf('scene%d_*FAEAE*run*.mat', sid)));
        end
        if isempty(files)
            warning('Scene %d 在新 run_records 中没有找到 FAEAE 文件，保留旧结果。', sid);
            continue;
        end

        % 按 run 编号排序
        runNums = nan(numel(files),1);
        for k = 1:numel(files)
            tok = regexp(files(k).name, 'run(\d+)', 'tokens', 'once');
            if ~isempty(tok)
                runNums(k) = str2double(tok{1});
            else
                runNums(k) = k;
            end
        end
        [~, ord] = sort(runNums, 'ascend');
        files = files(ord);

        runs = struct([]);

        for k = 1:numel(files)
            fp = fullfile(files(k).folder, files(k).name);
            T = load(fp);
            rr = localExtractResultStruct(T);
        
            % 补几个常用兼容字段
            rr = localNormalizeResultStruct(rr, sid);
        
            % ===== 关键：先对齐字段，再追加 =====
            if isempty(runs)
                runs = rr;
            else
                [runs, rr] = localAlignStructArrayAndScalar(runs, rr);
                runs(end+1) = rr;
            end
        end

        allResults{s, faeIdx} = runs;
        fprintf('  Scene %d | replaced FAEAE with %d runs.\n', sid, numel(runs));
    end

    S.allResults = allResults;
    save(mergedMat, '-struct', 'S', '-v7.3');

    %% 3) 可选：如果 mergedDir 里已有合并好的 csv，就不动；否则可以后续再 summarize
    fprintf('[3/3] Done.\n');
    fprintf('  Saved: %s\n', mergedMat);
    fprintf('  Folder: %s\n', mergedRunDir);
end

%% ========================================================================
function rr = localExtractResultStruct(T)
    rr = [];

    if isfield(T, 'result') && isstruct(T.result)
        rr = T.result;
        return;
    end

    fns = fieldnames(T);
    if numel(fns) == 1 && isstruct(T.(fns{1}))
        rr = T.(fns{1});
        return;
    end

    % 兜底：找第一个 struct
    for i = 1:numel(fns)
        if isstruct(T.(fns{i}))
            rr = T.(fns{i});
            return;
        end
    end

    error('无法从 .mat 文件中识别 result struct。');
end

%% ========================================================================
function rr = localNormalizeResultStruct(rr, sceneId)
    % sceneId
    if ~isfield(rr, 'sceneId')
        rr.sceneId = sceneId;
    end

    % bestFitness / bestFit 兼容
    if isfield(rr, 'bestFitness') && ~isfield(rr, 'bestFit')
        rr.bestFit = rr.bestFitness;
    elseif isfield(rr, 'bestFit') && ~isfield(rr, 'bestFitness')
        rr.bestFitness = rr.bestFit;
    end

    % runtime / runTime 兼容
    if isfield(rr, 'runtime') && ~isfield(rr, 'runTime')
        rr.runTime = rr.runtime;
    elseif isfield(rr, 'runTime') && ~isfield(rr, 'runtime')
        rr.runtime = rr.runTime;
    end

    % convergence / bestHist 兼容
    if isfield(rr, 'bestHist') && ~isfield(rr, 'convergence')
        rr.convergence = rr.bestHist;
    elseif isfield(rr, 'convergence') && ~isfield(rr, 'bestHist')
        rr.bestHist = rr.convergence;
    end

    % finalFeasible / bestDetail 兼容
    if ~isfield(rr, 'finalFeasible')
        if isfield(rr, 'bestDetail') && isstruct(rr.bestDetail) && isfield(rr.bestDetail, 'isFeasible')
            rr.finalFeasible = rr.bestDetail.isFeasible;
        elseif isfield(rr, 'isFeasible')
            rr.finalFeasible = rr.isFeasible;
        else
            rr.finalFeasible = NaN;
        end
    end

    % finalViolation 兼容
    if ~isfield(rr, 'finalViolation')
        if isfield(rr, 'bestDetail') && isstruct(rr.bestDetail) && isfield(rr.bestDetail, 'V')
            rr.finalViolation = rr.bestDetail.V;
        else
            rr.finalViolation = NaN;
        end
    end
end

function [A, b] = localAlignStructArrayAndScalar(A, b)
% 让 struct 数组 A 和单个 struct b 拥有相同字段集合

aFields = fieldnames(A);
bFields = fieldnames(b);
allFields = unique([aFields; bFields]);

% 给 A 补字段
for i = 1:numel(allFields)
    fn = allFields{i};
    if ~isfield(A, fn)
        defaultVal = localDefaultValueLike(b.(fn));
        for k = 1:numel(A)
            A(k).(fn) = defaultVal;
        end
    end
end

% 给 b 补字段
for i = 1:numel(allFields)
    fn = allFields{i};
    if ~isfield(b, fn)
        b.(fn) = localDefaultValueLike(A(1).(fn));
    end
end

A = orderfields(A, b);
b = orderfields(b, A(1));
end

function v = localDefaultValueLike(example)
if isnumeric(example)
    if isempty(example)
        v = [];
    else
        v = nan(size(example));
    end
elseif islogical(example)
    v = false;
elseif ischar(example)
    v = '';
elseif isstring(example)
    v = "";
elseif iscell(example)
    v = cell(size(example));
elseif isstruct(example)
    v = struct();
else
    v = [];
end
end