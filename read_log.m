% Read and display the full matlab.log file
clear; clc;

fprintf('=== Reading Full MATLAB Log ===\n');
fprintf('==============================\n\n');

% Read the log file
log_file = 'matlab.log';
if exist(log_file, 'file')
    lines = readlines(log_file);
    fprintf('Total lines: %d\n\n', length(lines));

    % Display the last 100 lines
    start_line = max(1, length(lines) - 100);
    fprintf('Last %d lines:\n', length(lines) - start_line + 1);
    fprintf('--------------------------------\n');

    for i = start_line:length(lines)
        fprintf('%s\n', char(lines(i)));
    end

else
    fprintf('Log file not found: %s\n', log_file);
end
