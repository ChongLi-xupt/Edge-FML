% Edge-FML Example: Basic Usage
% This script demonstrates how to use Edge-FML for distributed edge optimization

clear; clc; close all;

fprintf('========================================\n');
fprintf('  Edge-FML Basic Example\n');
fprintf('========================================\n\n');

%% Add path
addpath('src');

%% Step 1: Generate Scenario
fprintf('Step 1: Generating edge scenario...\n');
N = 6;                    % Number of edge regions
scenarioType = 'moderate'; % Heterogeneity level

dataGen = SimulationDataGenerator();
[regions, taskSets] = dataGen.generateScenario(N, scenarioType);
fprintf('  Created %d regions with %s heterogeneity\n\n', N, scenarioType);

%% Step 2: Configure Edge-FML
fprintf('Step 2: Configuring Edge-FML...\n');
R_max = 5;        % Federated rounds
M_local = 20;     % Local evolution generations

fprintf('  Federated rounds: %d\n', R_max);
fprintf('  Local generations: %d\n\n', M_local);

%% Step 3: Initialize Framework
fprintf('Step 3: Initializing Edge-FML framework...\n');
edgeFML = EdgeFML(regions, taskSets, R_max, M_local);
fprintf('  Framework initialized\n');
fprintf('  Clusters formed: %d\n\n', edgeFML.clusterManager.M);

%% Step 4: Run Federated Optimization
fprintf('Step 4: Running federated optimization...\n');
fprintf('========================================\n\n');

tic;
edgeFML = edgeFML.run();
elapsedTime = toc;

fprintf('\n========================================\n');
fprintf('Optimization completed in %.2f seconds\n\n', elapsedTime);

%% Step 5: Evaluate Results
fprintf('Step 5: Evaluating results...\n');

% Extract global Pareto front
globalFront = edgeFML.globalElites;
fprintf('  Global Pareto front size: %d solutions\n', length(globalFront));

% Compute performance metrics
metrics = PerformanceMetrics([1000, 1000, 1000]);
HV = metrics.computeHypervolume(globalFront);
feasRate = metrics.computeFeasibilityRate(globalFront);
diversity = metrics.computeDiversity(globalFront);

fprintf('  Hypervolume: %.4e (%.2f M)\n', HV, HV/1e6);
fprintf('  Feasibility Rate: %.2f%%\n', feasRate);
fprintf('  Diversity: %.4f\n', diversity);

%% Step 6: Visualize Results (Optional)
if length(globalFront) > 0
    fprintf('\nStep 6: Generating visualization...\n');

    % Extract objectives
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    % 3D Pareto front plot
    figure('Position', [100, 100, 800, 600]);
    scatter3(objs(:,1), objs(:,2), objs(:,3), ...
             100, 'filled', 'MarkerFaceAlpha', 0.6);
    grid on;
    xlabel('Latency (ms)', 'FontSize', 12);
    ylabel('Energy (J)', 'FontSize', 12);
    zlabel('Security Risk', 'FontSize', 12);
    title('Edge-FML: Global Pareto Front', 'FontSize', 14, 'FontWeight', 'bold');

    % Convergence plot
    if isfield(edgeFML.roundHistory(1), 'HV')
        figure('Position', [150, 150, 800, 400]);

        subplot(1, 2, 1);
        hvValues = [edgeFML.roundHistory.HV];
        plot(1:R_max, hvValues, '-o', 'LineWidth', 2, 'MarkerSize', 8);
        grid on;
        xlabel('Round', 'FontSize', 12);
        ylabel('Hypervolume', 'FontSize', 12);
        title('HV Convergence', 'FontSize', 13, 'FontWeight', 'bold');

        subplot(1, 2, 2);
        feasValues = [edgeFML.roundHistory.feasibilityRate];
        plot(1:R_max, feasValues, '-s', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.8500 0.3250 0.0980]);
        grid on;
        xlabel('Round', 'FontSize', 12);
        ylabel('Feasibility Rate (%)', 'FontSize', 12);
        title('Feasibility Evolution', 'FontSize', 13, 'FontWeight', 'bold');
        ylim([0, 100]);
    end

    fprintf('  Visualization complete\n');
end

%% Summary
fprintf('\n========================================\n');
fprintf('  Edge-FML Example Completed\n');
fprintf('========================================\n');
fprintf('Total execution time: %.2f seconds\n', elapsedTime);
fprintf('Final hypervolume: %.4e\n', HV);
fprintf('Final feasibility: %.2f%%\n', feasRate);
fprintf('\nFor more advanced usage, see USAGE_GUIDE.md\n');
