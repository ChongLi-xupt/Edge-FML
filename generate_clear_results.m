% Generate clear experiment results with visualizations
clear; clc; close all;

% Add source directory to path
addpath('src');

% Configuration
config = struct();
config.N = 5;              % Number of regions
config.R_max = 3;          % Federated rounds
config.M_local = 10;       % Local generations
config.scenarioType = 'homogeneous';
config.timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
config.results_dir = fullfile(pwd, 'experiments', 'results');
config.figures_dir = fullfile(pwd, 'experiments', 'figures');

% Create directories if they don't exist
if ~exist(config.results_dir, 'dir')
    mkdir(config.results_dir);
end
if ~exist(config.figures_dir, 'dir')
    mkdir(config.figures_dir);
end

fprintf('=== Edge-FML Experiment: Generating Results ===\n');
fprintf('Configuration:\n');
fprintf('  Regions: %d\n', config.N);
fprintf('  Federated rounds: %d\n', config.R_max);
fprintf('  Local generations: %d\n', config.M_local);
fprintf('  Scenario: %s\n', config.scenarioType);
fprintf('  Timestamp: %s\n', config.timestamp);
fprintf('=================================================\n\n');

% Step 1: Generate scenario
fprintf('1. Generating scenario...\n');
[regions, taskSets] = SimulationDataGenerator.generateScenario(config.N, config.scenarioType);
fprintf('   ✓ Scenario generated with %d regions\n\n', config.N);

% Step 2: Initialize Edge-FML
fprintf('2. Initializing Edge-FML...\n');
edgeFML = EdgeFML(regions, taskSets, config.R_max, config.M_local);
fprintf('   ✓ Edge-FML initialized with %d clusters\n\n', edgeFML.clusterManager.M);

% Step 3: Run federated optimization
fprintf('3. Running federated optimization...\n');
edgeFML = edgeFML.run();
fprintf('   ✓ Federated optimization completed\n\n');

% Step 4: Evaluate results
fprintf('4. Evaluating results...\n');
metrics = PerformanceMetrics([1000, 1000, 1000]);

% Compute metrics for global front
globalFront = edgeFML.globalElites;
HV = metrics.computeHypervolume(globalFront);
feasRate = metrics.computeFeasibilityRate(globalFront);
diversity = metrics.computeDiversity(globalFront);

fprintf('   Global Performance Metrics:\n');
fprintf('   Hypervolume: %.4f\n', HV);
fprintf('   Feasibility Rate: %.2f%%\n', feasRate);
fprintf('   Diversity: %.4f\n', diversity);
fprintf('   Total Communication: %.2f MB\n', edgeFML.totalCommBytes / 1e6);
fprintf('   Avg Communication per Round: %.2f MB\n', edgeFML.totalCommBytes / 1e6 / config.R_max);
fprintf('   Global Front Size: %d solutions\n\n', length(globalFront));

% Step 5: Generate visualization figures
fprintf('5. Generating visualization figures...\n');

% Figure 1: Convergence curve
if ~isempty(edgeFML.roundHistory)
    figure('Name', 'Convergence Curve', 'Position', [100, 100, 800, 600]);
    rounds = [edgeFML.roundHistory.round];
    HV_values = [edgeFML.roundHistory.HV];
    feas_values = [edgeFML.roundHistory.feasibilityRate];

    subplot(2, 1, 1);
    plot(rounds, HV_values, '-o', 'LineWidth', 2, 'MarkerSize', 6);
    xlabel('Federated Round');
    ylabel('Hypervolume');
    title('Convergence Curve - Hypervolume');
    grid on;

    subplot(2, 1, 2);
    plot(rounds, feas_values, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'r');
    xlabel('Federated Round');
    ylabel('Feasibility Rate (%)');
    title('Convergence Curve - Feasibility Rate');
    grid on;

    % Save figure
    fig_file = sprintf('%s/convergence_curve_%s', config.figures_dir, config.timestamp);
    saveas(gcf, [fig_file, '.fig']);
    saveas(gcf, [fig_file, '.png']);
    fprintf('   ✓ Convergence curve saved to %s\n', fig_file);
end

% Figure 2: 3D Pareto front
if length(globalFront) >= 2
    figure('Name', '3D Pareto Front', 'Position', [100, 100, 800, 600]);

    % Extract objectives
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    scatter3(objs(:, 1), objs(:, 2), objs(:, 3), 50, 'filled', 'MarkerFaceAlpha', 0.7);
    xlabel('Objective 1 (Cost)');
    ylabel('Objective 2 (Latency)');
    zlabel('Objective 3 (Energy)');
    title('3D Pareto Front - Edge-FML Global Solutions');
    grid on;

    % Save figure
    fig_file = sprintf('%s/pareto_front_3d_%s', config.figures_dir, config.timestamp);
    saveas(gcf, [fig_file, '.fig']);
    saveas(gcf, [fig_file, '.png']);
    fprintf('   ✓ 3D Pareto front saved to %s\n', fig_file);
end

% Figure 3: 2D Pareto front projections
if length(globalFront) >= 2
    figure('Name', '2D Pareto Front Projections', 'Position', [100, 100, 1200, 400]);

    % Extract objectives
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    % Projection 1: Obj1 vs Obj2
    subplot(1, 3, 1);
    scatter(objs(:, 1), objs(:, 2), 50, 'filled', 'MarkerFaceAlpha', 0.7);
    xlabel('Objective 1 (Cost)');
    ylabel('Objective 2 (Latency)');
    title('Pareto Front: Cost vs Latency');
    grid on;

    % Projection 2: Obj1 vs Obj3
    subplot(1, 3, 2);
    scatter(objs(:, 1), objs(:, 3), 50, 'filled', 'MarkerFaceAlpha', 0.7, 'Color', 'r');
    xlabel('Objective 1 (Cost)');
    ylabel('Objective 3 (Energy)');
    title('Pareto Front: Cost vs Energy');
    grid on;

    % Projection 3: Obj2 vs Obj3
    subplot(1, 3, 3);
    scatter(objs(:, 2), objs(:, 3), 50, 'filled', 'MarkerFaceAlpha', 0.7, 'Color', 'g');
    xlabel('Objective 2 (Latency)');
    ylabel('Objective 3 (Energy)');
    title('Pareto Front: Latency vs Energy');
    grid on;

    % Save figure
    fig_file = sprintf('%s/pareto_front_2d_%s', config.figures_dir, config.timestamp);
    saveas(gcf, [fig_file, '.fig']);
    saveas(gcf, [fig_file, '.png']);
    fprintf('   ✓ 2D Pareto front projections saved to %s\n', fig_file);
end

% Step 6: Save results to file
fprintf('6. Saving results to file...\n');

% Create results structure
results = struct();
results.config = config;
results.edgeFML = edgeFML;
results.metrics = struct();
results.metrics.hypervolume = HV;
results.metrics.feasibilityRate = feasRate;
results.metrics.diversity = diversity;
results.metrics.totalCommBytes = edgeFML.totalCommBytes;

% Save objectives for analysis
if length(globalFront) > 0
    results.globalFrontObjectives = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        results.globalFrontObjectives(i, :) = globalFront(i).objectives;
    end
end

% Save convergence history
results.convergenceHistory = edgeFML.roundHistory;

% Save to MAT file
results_file = sprintf('%s/edge_fml_experiment_results_%s.mat', config.results_dir, config.timestamp);
save(results_file, 'results');
fprintf('   ✓ Results saved to %s\n\n', results_file);

% Step 7: Generate text report
fprintf('7. Generating text report...\n');

report_file = sprintf('%s/edge_fml_experiment_report_%s.txt', config.results_dir, config.timestamp);
fid = fopen(report_file, 'w');

fprintf(fid, '========================================\n');
fprintf(fid, 'Edge-FML Experiment Report\n');
fprintf(fid, '========================================\n\n');
fprintf(fid, 'Experiment Timestamp: %s\n\n', config.timestamp);

fprintf(fid, '=== Configuration ===\n');
fprintf(fid, 'Number of Regions: %d\n', config.N);
fprintf(fid, 'Federated Rounds: %d\n', config.R_max);
fprintf(fid, 'Local Generations: %d\n', config.M_local);
fprintf(fid, 'Scenario Type: %s\n\n', config.scenarioType);

fprintf(fid, '=== Performance Metrics ===\n');
fprintf(fid, 'Hypervolume: %.4f\n', HV);
fprintf(fid, 'Feasibility Rate: %.2f%%\n', feasRate);
fprintf(fid, 'Diversity: %.4f\n', diversity);
fprintf(fid, 'Total Communication: %.2f MB\n', edgeFML.totalCommBytes / 1e6);
fprintf(fid, 'Avg Communication per Round: %.2f MB\n', edgeFML.totalCommBytes / 1e6 / config.R_max);
fprintf(fid, 'Global Front Size: %d solutions\n\n', length(globalFront));

fprintf(fid, '=== Convergence History ===\n');
if ~isempty(edgeFML.roundHistory)
    for i = 1:length(edgeFML.roundHistory)
        fprintf(fid, 'Round %d: HV=%.4f, Feasibility=%.2f%%\n', ...
            edgeFML.roundHistory(i).round, ...
            edgeFML.roundHistory(i).HV, ...
            edgeFML.roundHistory(i).feasibilityRate);
    end
end
fprintf(fid, '\n');

fprintf(fid, '=== Generated Files ===\n');
fprintf(fid, 'Results File: %s\n', results_file);
fprintf(fid, 'Convergence Curve: %s/convergence_curve_%s.*\n', config.figures_dir, config.timestamp);
fprintf(fid, '3D Pareto Front: %s/pareto_front_3d_%s.*\n', config.figures_dir, config.timestamp);
fprintf(fid, '2D Pareto Front Projections: %s/pareto_front_2d_%s.*\n', config.figures_dir, config.timestamp);
fprintf(fid, 'Report File: %s\n\n', report_file);

fprintf(fid, '========================================\n');
fprintf(fid, 'End of Report\n');
fprintf(fid, '========================================\n');

fclose(fid);
fprintf('   ✓ Report saved to %s\n\n', report_file);

% Final summary
fprintf('=== Experiment Completed Successfully ===\n');
fprintf('✓ Scenario generated\n');
fprintf('✓ Edge-FML initialized\n');
fprintf('✓ Federated optimization completed\n');
fprintf('✓ Performance metrics computed\n');
fprintf('✓ Visualization figures generated\n');
fprintf('✓ Results saved to MAT file\n');
fprintf('✓ Text report generated\n\n');
fprintf('All experiment results have been successfully generated!\n');
