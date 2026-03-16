function merge_scene4_into_uav_formal_results(oldFormalDir, newScene4Dir)
%MERGE_SCENE4_INTO_UAV_FORMAL_RESULTS
% Merge rerun Scene 4 formal results into the original full formal folder.
%
% Usage:
%   merge_scene4_into_uav_formal_results(oldFormalDir, newScene4Dir)
%
% Example:
%   merge_scene4_into_uav_formal_results( ...
%       fullfile(pwd,'results_uav_6alg_formal_safe'), ...
%       fullfile(pwd,'results_uav_scene4_formal_rerun'));
%
% What it does:
%   1) Load original full formal master MAT
%   2) Load new Scene-4-only master MAT
%   3) Replace Scene 4 result blocks in old allResults/runStatus
%   4) Replace Scene 4 run_records files
%   5) Save merged master MAT atomically
%   6) Rebuild summary + paper tables
%
% Assumptions:
%   - oldFormalDir uses cfg.sceneIds = [1 2 4]
%   - newScene4Dir uses cfg.sceneIds = [4]
%   - algorithm lists are identical and ordered the same

    if nargin < 2
        error('Usage: merge_scene4_into_uav_formal_results(oldFormalDir, newScene4Dir)');
    end

    oldMasterFile = fullfile(oldFormalDir, 'uav_comparison_results.mat');
    newMasterFile = fullfile(newScene4Dir, 'uav_comparison_results.mat');

    oldRunDir = fullfile(oldFormalDir, 'run_records');
    newRunDir = fullfile(newScene4Dir, 'run_records');

    if ~exist(oldMasterFile, 'file')
        error('Cannot find old master file: %s', oldMasterFile);
    end
    if ~exist(newMasterFile, 'file')
        error('Cannot find new Scene-4 master file: %s', newMasterFile);
    end
    if ~exist(oldRunDir, 'dir')
        error('Cannot find old run_records: %s', oldRunDir);
    end
    if ~exist(newRunDir, 'dir')
        error('Cannot find new run_records: %s', newRunDir);
    end

    fprintf('\n=== Merge Scene 4 Into UAV Formal Results ===\n');
    fprintf('Old formal dir : %s\n', oldFormalDir);
    fprintf('New Scene4 dir : %s\n\n', newScene4Dir);

    % ------------------------------------------------------------
    % Load both master files
    % ------------------------------------------------------------
    Sold = load(oldMasterFile);
    Snew = load(newMasterFile);

    oldCfg = Sold.cfg;
    newCfg = Snew.cfg;

    oldScenes = oldCfg.sceneIds;
    newScenes = newCfg.sceneIds;

    if ~isequal(newScenes, 4)
        error('newScene4Dir must contain only Scene 4. Current new cfg.sceneIds = %s', mat2str(newScenes));
    end

    if ~isequal(oldCfg.algorithms, newCfg.algorithms)
        error('Algorithm lists are not identical between old and new result folders.');
    end

    oldSceneIdx = find(oldScenes == 4, 1);
    if isempty(oldSceneIdx)
        error('Scene 4 not found in old formal cfg.sceneIds.');
    end

    newSceneIdx = 1; % because newScenes = [4]

    oldAllResults = Sold.allResults;
    newAllResults = Snew.allResults;

    oldRunStatus = Sold.runStatus;
    newRunStatus = Snew.runStatus;

    oldErrorLog = [];
    if isfield(Sold, 'errorLog')
        oldErrorLog = Sold.errorLog;
    end

    % ------------------------------------------------------------
    % Backup old master MAT before modification
    % ------------------------------------------------------------
    backupMaster = fullfile(oldFormalDir, ...
        ['uav_comparison_results_backup_before_scene4_merge_' datestr(now,'yyyymmdd_HHMMSS') '.mat']);
    copyfile(oldMasterFile, backupMaster);
    fprintf('Backup created: %s\n', backupMaster);

    % ------------------------------------------------------------
    % Replace Scene 4 blocks in allResults and runStatus
    % ------------------------------------------------------------
    nAlgs = numel(oldCfg.algorithms);

    for a = 1:nAlgs
        oldAllResults{oldSceneIdx, a} = newAllResults{newSceneIdx, a};

        for r = 1:oldCfg.nRuns
            oldRunStatus{oldSceneIdx, a, r} = newRunStatus{newSceneIdx, a, r};
        end
    end

    % ------------------------------------------------------------
    % Replace Scene 4 run_records files
    % ------------------------------------------------------------
    newScene4Files = dir(fullfile(newRunDir, 'scene4_*.mat'));

    % Backup old Scene 4 run files
    backupRunDir = fullfile(oldFormalDir, ...
        ['run_records_backup_scene4_before_merge_' datestr(now,'yyyymmdd_HHMMSS')]);
    mkdir(backupRunDir);

    oldScene4Files = dir(fullfile(oldRunDir, 'scene4_*.mat'));
    for k = 1:numel(oldScene4Files)
        src = fullfile(oldScene4Files(k).folder, oldScene4Files(k).name);
        copyfile(src, fullfile(backupRunDir, oldScene4Files(k).name));
    end
    fprintf('Scene 4 run_records backup created: %s\n', backupRunDir);

    % Delete old Scene 4 run files from old formal dir
    for k = 1:numel(oldScene4Files)
        delete(fullfile(oldScene4Files(k).folder, oldScene4Files(k).name));
    end

    % Copy new Scene 4 run files into old formal dir
    for k = 1:numel(newScene4Files)
        src = fullfile(newScene4Files(k).folder, newScene4Files(k).name);
        dst = fullfile(oldRunDir, newScene4Files(k).name);
        copyfile(src, dst);
    end
    fprintf('Scene 4 run_records replaced: %d files copied.\n', numel(newScene4Files));

    % ------------------------------------------------------------
    % Save merged master MAT atomically
    % ------------------------------------------------------------
    atomicSaveMaster(oldMasterFile, oldAllResults, oldRunStatus, oldErrorLog, oldCfg);
    fprintf('Merged master MAT saved.\n');

    % ------------------------------------------------------------
    % Rebuild summary and paper tables
    % ------------------------------------------------------------
    fprintf('\nRebuilding summary...\n');
    summarize_uav_comparison_results(oldFormalDir);

    fprintf('\nRebuilding paper tables...\n');
    export_uav_comparison_paper_tables(oldFormalDir);

    fprintf('\nMerge finished successfully.\n');
    fprintf('Updated folder:\n%s\n', oldFormalDir);
end


% ========================================================================
function atomicSaveMaster(dataFile, allResults, runStatus, errorLog, cfg)
    tmpFile = [dataFile '.tmp'];
    save(tmpFile, 'allResults', 'runStatus', 'errorLog', 'cfg', '-v7.3');

    if exist(dataFile, 'file')
        delete(dataFile);
    end
    movefile(tmpFile, dataFile);
end