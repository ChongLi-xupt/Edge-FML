% Comprehensive Edge-FML Experiment Runner
% Runs performance testing, algorithm comparison, and ablation studies
% Uses enhanced Edge-FML framework with robust error handling
%
% Author: 拓守恒 (Shouheng Tuo)
% Email: shouheng.tuo@example.com
% Date: 2025-12-01

clear; clc; close all;

% Add source directory to path
addpath('src');
addpath('experiments');

fprintf('========================================\n');
fprintf('Edge-FML Comprehensive Experiment Runner\n');
fprintf('========================================\n');

% Initialize comprehensive testing framework
framework = ComprehensiveTestingFramework('experiments/config.m');

% Set test mode based on user preference
testMode = 'all';  % Can be changed to 'performance', 'comparison', 'ablation', 'debug', 'stress'

fprintf('Test Mode: %s\n', testMode);

% Run experiments based on mode
switch testMode
    case 'all'
        framework.runAllTests();
    case 'performance'
        framework.runPerformanceTests();
    case 'comparison'
        framework.runComparisonTests();
    case 'ablation'
        framework.runAblationTests();
    case 'debug'
        framework.runDebugTests();
    case 'stress'
        framework.runStressTests();
    otherwise
        error('Unknown test mode: %s', testMode);
end

fprintf('\n========================================\n');
fprintf('Experiment execution completed\n');
fprintf('Results saved to: %s\n', framework.resultsDir);
fprintf('========================================\n');

% Display completion message
if ispc
    msgbox('Edge-FML comprehensive experiments completed successfully!', 'Success', 'help');
else
    fprintf('Edge-FML comprehensive experiments completed successfully!\n');
end