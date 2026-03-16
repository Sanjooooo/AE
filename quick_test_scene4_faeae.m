function quick_test_scene4_faeae(mode)
%QUICK_TEST_SCENE4_FAEAE Quick validation for Scene 4 after low-altitude override.
%
% Usage:
%   quick_test_scene4_faeae
%   quick_test_scene4_faeae('smoke')
%   quick_test_scene4_faeae('mid')
%
% Modes:
%   'smoke' : 3 runs
%   'mid'   : 5 runs
%
% Output:
%   A dedicated result folder for Scene 4 FAEAE only.

    if nargin < 1 || isempty(mode)
        mode = 'smoke';
    end
    mode = lower(mode);

    switch mode
        case 'smoke'
            nRuns = 3;
            tag = 'smoke';
        case 'mid'
            nRuns = 5;
            tag = 'mid';
        otherwise
            error('Unknown mode: %s. Use ''smoke'' or ''mid''.', mode);
    end

    cfg = getUAVComparisonConfig('smoke');

    % Only Scene 4 + FAEAE
    cfg.sceneIds = [4];
    cfg.algorithms = {'FAEAE'};
    cfg.nRuns = nRuns;
    cfg.resultDir = fullfile(pwd, sprintf('results_scene4_faeae_quick_%s', tag));

    fprintf('\n=== Quick Test: Scene 4 | FAEAE ===\n');
    fprintf('Runs      : %d\n', cfg.nRuns);
    fprintf('ResultDir : %s\n\n', cfg.resultDir);

    run_uav_comparison_batch(cfg);

    % Summarize
    summary = summarize_uav_comparison_results(cfg.resultDir); %#ok<NASGU>

    % Plot representative path for quick visual check
    try
        plot_uav_representative_corridor_paths_all(cfg.resultDir);
    catch ME
        warning('Representative path plotting failed: %s', ME.message);
    end

    fprintf('\nQuick Scene-4 FAEAE test finished.\n');
    fprintf('Please check:\n');
    fprintf('  1) uav_comparison_summary_long.csv\n');
    fprintf('  2) representative_corridor_figures/\n');
    fprintf('to see whether the path now goes through building corridors.\n');
end