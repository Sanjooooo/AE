function batch_export_named_figs_for_journal(figDir, outDir)
%BATCH_EXPORT_NAMED_FIGS_FOR_JOURNAL
% Batch export named MATLAB .fig files to journal-preferred artwork formats.
%
% Expected input files:
%   Fig1a.fig, Fig1b.fig
%   Fig2a.fig, Fig2b.fig, Fig2c.fig, Fig2d.fig
%   Fig3a.fig ... Fig3i.fig
%   Fig4a.fig ... Fig4i.fig
%   Fig5a.fig ... Fig5d.fig
%
% Default export plan:
%   - Export EPS for all figures.
%   - Export TIFF at 600 dpi for complex 3D figures:
%       Fig1a, Fig3a--Fig3c, Fig4a--Fig4c
%
% Usage:
%   batch_export_named_figs_for_journal
%
% or:
%   batch_export_named_figs_for_journal('F:\MATLAB_Project\FAEAE_matlab\figure_no_init\fig', ...
%                                       'F:\MATLAB_Project\FAEAE_matlab\figure_no_init\journal_export')
%
% Notes:
%   - EPS is preferred for vector graphics.
%   - TIFF is used as a robust backup for complex 3D / filled / transparent figures.
%   - Put exported files in the same directory as sn-article.tex before submission.

    clc;
    fprintf('=== Batch Export Named .fig Files for Journal Artwork ===\n');

    %% ------------------------------------------------------------
    % 1. Folder settings
    % -------------------------------------------------------------
    if nargin < 1 || isempty(figDir)
        figDir = pwd;
    end

    if nargin < 2 || isempty(outDir)
        outDir = fullfile(figDir, 'journal_artwork_export');
    end

    if ~exist(figDir, 'dir')
        error('Input folder does not exist: %s', figDir);
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    fprintf('Input folder : %s\n', figDir);
    fprintf('Output folder: %s\n\n', outDir);

    %% ------------------------------------------------------------
    % 2. Export settings
    % -------------------------------------------------------------
    exportEPSForAll  = true;

    % If true, every .fig will also be exported as TIFF.
    % If false, only figures listed in extraTIFFNames will be exported as TIFF.
    exportTIFFForAll = false;

    % Optional PDF output for local LaTeX compilation.
    % Keep false unless you also want PDF copies.
    exportPDFForAll  = false;

    % TIFF resolution for combination artwork / complex 3D graphics.
    tiffResolution = 600;

    % Font normalization.
    % Set true only if you want to force all figures to use the same font.
    normalizeFonts = false;
    defaultFontName = 'Times New Roman';
    defaultFontSize = 10;

    % White background.
    forceWhiteBackground = true;

    %% ------------------------------------------------------------
    % 3. Define figure names
    % -------------------------------------------------------------
    figNames = {};

    figNames = [figNames, make_panel_names(1, 'ab')];
    figNames = [figNames, make_panel_names(2, 'abcd')];
    figNames = [figNames, make_panel_names(3, 'abcdefghi')];
    figNames = [figNames, make_panel_names(4, 'abcdefghi')];
    figNames = [figNames, make_panel_names(5, 'abcd')];

    % Figures that should have TIFF backup by default.
    % These correspond to 3D or potentially complex transparent/filled graphics.
    extraTIFFNames = { ...
        'Fig1a', ...
        'Fig3a', 'Fig3b', 'Fig3c', ...
        'Fig4a', 'Fig4b', 'Fig4c' ...
    };

    %% ------------------------------------------------------------
    % 4. Batch export
    % -------------------------------------------------------------
    nTotal = numel(figNames);
    nSuccess = 0;
    nMissing = 0;
    nFailed = 0;

    for k = 1:nTotal
        baseName = figNames{k};
        figFile = fullfile(figDir, [baseName, '.fig']);

        fprintf('----------------------------------------\n');
        fprintf('Processing %s.fig\n', baseName);

        if ~exist(figFile, 'file')
            warning('Missing file: %s', figFile);
            nMissing = nMissing + 1;
            continue;
        end

        exportTIFF = exportTIFFForAll || ismember(baseName, extraTIFFNames);

        try
            export_one_fig_file( ...
                figFile, outDir, baseName, ...
                exportEPSForAll, exportTIFF, exportPDFForAll, ...
                tiffResolution, forceWhiteBackground, ...
                normalizeFonts, defaultFontName, defaultFontSize);

            nSuccess = nSuccess + 1;

        catch ME
            warning('Failed to export %s.fig. Reason: %s', baseName, ME.message);
            nFailed = nFailed + 1;
        end
    end

    %% ------------------------------------------------------------
    % 5. Summary
    % -------------------------------------------------------------
    fprintf('\n========================================\n');
    fprintf('Batch export finished.\n');
    fprintf('Total expected : %d\n', nTotal);
    fprintf('Exported       : %d\n', nSuccess);
    fprintf('Missing        : %d\n', nMissing);
    fprintf('Failed         : %d\n', nFailed);
    fprintf('Output folder  : %s\n', outDir);
    fprintf('========================================\n');

    fprintf('\nDefault TIFF backup generated for:\n');
    for i = 1:numel(extraTIFFNames)
        fprintf('  %s.tif\n', extraTIFFNames{i});
    end

    fprintf('\nPlease visually check EPS files first. If EPS for 3D panels is abnormal, use the corresponding TIFF file.\n');
end


%% ========================================================================
% Helper: create names like Fig3a, Fig3b, ...
% ========================================================================
function names = make_panel_names(figNo, letters)
    names = cell(1, numel(letters));
    for i = 1:numel(letters)
        names{i} = sprintf('Fig%d%s', figNo, letters(i));
    end
end


%% ========================================================================
% Helper: export one .fig file
% ========================================================================
function export_one_fig_file(figFile, outDir, baseName, ...
    exportEPS, exportTIFF, exportPDF, ...
    tiffResolution, forceWhiteBackground, ...
    normalizeFonts, defaultFontName, defaultFontSize)

    fig = openfig(figFile, 'invisible');

    if forceWhiteBackground
        set(fig, 'Color', 'w');
        set(fig, 'InvertHardcopy', 'off');
    end

    set(fig, 'PaperPositionMode', 'auto');

    if normalizeFonts
        apply_font_settings(fig, defaultFontName, defaultFontSize);
    end

    drawnow;

    epsFile = fullfile(outDir, [baseName, '.eps']);
    tifFile = fullfile(outDir, [baseName, '.tif']);
    pdfFile = fullfile(outDir, [baseName, '.pdf']);

    %% -----------------------------
    % EPS export
    % ------------------------------
    if exportEPS
        try
            set(fig, 'Renderer', 'painters');
            print(fig, epsFile, '-depsc2', '-painters');
            fprintf('  EPS saved : %s\n', epsFile);
        catch ME
            warning('EPS export failed for %s: %s', baseName, ME.message);
        end
    end

    %% -----------------------------
    % TIFF export
    % ------------------------------
    if exportTIFF
        try
            set(fig, 'Renderer', 'opengl');
            print(fig, tifFile, '-dtiff', ['-r', num2str(tiffResolution)]);
            fprintf('  TIFF saved: %s  (%d dpi)\n', tifFile, tiffResolution);
        catch ME
            warning('TIFF export using print failed for %s: %s', baseName, ME.message);

            try
                exportgraphics(fig, tifFile, ...
                    'Resolution', tiffResolution, ...
                    'BackgroundColor', 'white');
                fprintf('  TIFF saved by exportgraphics: %s  (%d dpi)\n', tifFile, tiffResolution);
            catch ME2
                warning('TIFF exportgraphics also failed for %s: %s', baseName, ME2.message);
            end
        end
    end

    %% -----------------------------
    % Optional PDF export
    % ------------------------------
    if exportPDF
        try
            exportgraphics(fig, pdfFile, ...
                'ContentType', 'vector', ...
                'BackgroundColor', 'white');
            fprintf('  PDF saved : %s\n', pdfFile);
        catch ME
            warning('PDF exportgraphics failed for %s: %s', baseName, ME.message);

            try
                set(fig, 'Renderer', 'painters');
                print(fig, pdfFile, '-dpdf', '-painters');
                fprintf('  PDF saved by print: %s\n', pdfFile);
            catch ME2
                warning('PDF export also failed for %s: %s', baseName, ME2.message);
            end
        end
    end

    close(fig);
end


%% ========================================================================
% Helper: normalize font settings
% ========================================================================
function apply_font_settings(fig, fontName, fontSize)

    ax = findall(fig, 'Type', 'Axes');
    for i = 1:numel(ax)
        try
            set(ax(i), 'FontName', fontName, 'FontSize', fontSize);
        catch
        end
    end

    lgd = findall(fig, 'Type', 'Legend');
    for i = 1:numel(lgd)
        try
            set(lgd(i), 'FontName', fontName, 'FontSize', fontSize);
        catch
        end
    end

    cb = findall(fig, 'Type', 'ColorBar');
    for i = 1:numel(cb)
        try
            set(cb(i), 'FontName', fontName, 'FontSize', fontSize);
        catch
        end
    end

    txt = findall(fig, 'Type', 'Text');
    for i = 1:numel(txt)
        try
            set(txt(i), 'FontName', fontName, 'FontSize', fontSize);
        catch
        end
    end
end