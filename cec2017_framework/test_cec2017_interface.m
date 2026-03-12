function test_cec2017_interface()
%TEST_CEC2017_INTERFACE Minimal test for CEC2017 MEX interface.

clc;

rootDir = fileparts(mfilename('fullpath'));
cecDir = fullfile(rootDir, 'third_party', 'cec2017');

if ~exist(cecDir, 'dir')
    error('CEC2017 folder not found: %s', cecDir);
end

addpath(genpath(cecDir));
fprintf('CEC folder added:\n%s\n\n', cecDir);

if exist('cec17_func', 'file') ~= 3 && exist('cec17_func', 'file') ~= 2
    error('cec17_func was not found on MATLAB path.');
end

fprintf('cec17_func detected successfully.\n');

D = 30;
funcId = 1;
x_row = zeros(1, D);
x_col = zeros(D, 1);

oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir));
cd(cecDir);

fprintf('\nChanged working directory to:\n%s\n', cecDir);

fprintf('\nTrying row-vector input: size = [%d %d]\n', size(x_row,1), size(x_row,2));
row_ok = false;
try
    f_row = cec17_func(x_row, funcId);
    fprintf('Row-vector call succeeded. f = %.12g\n', f_row);
    row_ok = true;
catch ME
    fprintf('Row-vector call failed:\n%s\n', ME.message);
end

fprintf('\nTrying column-vector input: size = [%d %d]\n', size(x_col,1), size(x_col,2));
col_ok = false;
try
    f_col = cec17_func(x_col, funcId);
    fprintf('Column-vector call succeeded. f = %.12g\n', f_col);
    col_ok = isfinite(f_col);
catch ME
    fprintf('Column-vector call failed:\n%s\n', ME.message);
end

fprintf('\n==============================\n');
fprintf('CEC2017 Interface Test Summary\n');
fprintf('==============================\n');
fprintf('Function detected: YES\n');
fprintf('Row input works   : %d\n', row_ok);
fprintf('Column input works: %d\n', col_ok);

if ~row_ok && ~col_ok
    error('CEC2017 MEX detected, but valid evaluation still failed. Please send me the full output.');
end

if row_ok && ~col_ok
    fprintf('Recommended wrapper input format: ROW VECTOR\n');
elseif ~row_ok && col_ok
    fprintf('Recommended wrapper input format: COLUMN VECTOR\n');
else
    fprintf('Both formats work. We will still standardize one format in wrapper.\n');
end

fprintf('==============================\n');
end