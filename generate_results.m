% Simple script to generate experiment results and figures
% This version uses absolute paths and simple plotting
clear; clc;

% Set up paths
root_dir = pwd;
src_dir = fullfile(root_dir, 'src');
results_dir = fullfile(root_dir, 'experiments', 'results');
figures_dir = fullfile(root_dir, 'experiments', 'figures');

% Create directories if needed
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end
if ~exist(figures_dir, 'dir')
    mkdir(figures_dir);
end

% Add source to path
addpath(src_dir);

% Configuration
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
N = 5;
R_max = 3;
M_local = 10;
scenarioType = 'homogeneous';

fprintf('=== Edge-FML Simple Experiment ===\n');
fprintf('Timestamp: %s\n', timestamp);
fprintf('=================================\n\n');

% Step 1: Generate scenario
fprintf('1. Generating scenario...\n');
[regions, taskSets] = SimulationDataGenerator.generateScenario(N, scenarioType);
fprintf('   ✓ Scenario generated with %d regions\n\n', N);

% Step 2: Initialize and run Edge-FML
fprintf('2. Running Edge-FML...\n');
edgeFML = EdgeFML(regions, taskSets, R_max, M_local);
edgeFML = edgeFML.run();
fprintf('   ✓ Edge-FML completed\n\n');

% Step 3: Compute metrics
fprintf('3. Computing metrics...\n');
metrics = PerformanceMetrics([1000, 1000, 1000]);
HV = metrics.computeHypervolume(edgeFML.globalElites);
feasRate = metrics.computeFeasibilityRate(edgeFML.globalElites);
diversity = metrics.computeDiversity(edgeFML.globalElites);

fprintf('   Hypervolume: %.4f\n', HV);
fprintf('   Feasibility Rate: %.2f%%\n', feasRate);
fprintf('   Diversity: %.4f\n', diversity);
fprintf('   Communication: %.2f MB\n', edgeFML.totalCommBytes / 1e6);
fprintf('   Global Front: %d solutions\n\n', length(edgeFML.globalElites));

% Step 4: Save results
fprintf('4. Saving results...\n');
results = struct();
results.timestamp = timestamp;
results.config = struct('N', N, 'R_max', R_max, 'M_local', M_local, 'scenarioType', scenarioType);
results.metrics = struct('HV', HV, 'feasRate', feasRate, 'diversity', diversity, 'commMB', edgeFML.totalCommBytes / 1e6);
results.globalFrontSize = length(edgeFML.globalElites);

% Save objectives if available
if length(edgeFML.globalElites) > 0
    results.globalFrontObjectives = zeros(length(edgeFML.globalElites), 3);
    for i = 1:length(edgeFML.globalElites)
        results.globalFrontObjectives(i, :) = edgeFML.globalElites(i).objectives;
    end
end

% Save convergence history
if ~isempty(edgeFML.roundHistory)
    results.convergenceHistory = edgeFML.roundHistory;
end

% Save to file
results_file = fullfile(results_dir, ['simple_results_', timestamp, '.mat']);
save(results_file, 'results');
fprintf('   ✓ Results saved to: %s\n\n', results_file);

% Step 5: Generate simple figure
fprintf('5. Generating figure...\n');

% Create a simple convergence plot
if ~isempty(edgeFML.roundHistory)
    figure('Visible', 'off');  % Don't show figure in batch mode

    rounds = [edgeFML.roundHistory.round];
    HV_values = [edgeFML.roundHistory.HV];

    plot(rounds, HV_values, '-o', 'LineWidth', 2, 'MarkerSize', 6);
    xlabel('Federated Round');
    ylabel('Hypervolume');
    title('Edge-FML Convergence Curve');
    grid on;

    % Save figure
    fig_file = fullfile(figures_dir, ['convergence_', timestamp]);
    saveas(gcf, [fig_file, '.fig']);
    saveas(gcf, [fig_file, '.png']);
    fprintf('   ✓ Figure saved to: %s\n\n', fig_file);

    close(gcf);
end

fprintf('=== Experiment Completed ===\n');
fprintf('Results and figure generated successfully!\n');
