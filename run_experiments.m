% Main Experiment Runner for Edge-FML
% This script allows users to run different types of experiments: performance scaling, ablation studies, or algorithm comparison

clear; clc; close all;

fprintf('========================================\n');
fprintf('Edge-FML Experiment Runner\n');
fprintf('========================================\n\n');

% Display menu
fprintf('Please select an experiment type to run:\n');
fprintf('1. Performance Scaling Experiments\n');
fprintf('2. Ablation Studies\n');
fprintf('3. Algorithm Comparison Experiments\n');
fprintf('4. Exit\n\n');

% Get user input
choice = input('Enter your choice (1-4): ');

% Handle user choice
switch choice
    case 1
        % Performance scaling experiments
        fprintf('\n========================================\n');
        fprintf('Starting Performance Scaling Experiments\n');
        fprintf('========================================\n\n');

        % Load configuration
        run('experiments/config.m');

        % Ask user if they want to use default parameters
        useDefault = input('Use default parameters? (y/n): ', 's');

        if strcmpi(useDefault, 'n')
            % Allow user to modify parameters
            fprintf('\nCurrent parameters:\n');
            fprintf('Maximum federated rounds: %d\n', commonConfig.R_max);
            fprintf('Local evolution generations: %d\n', commonConfig.M_local);
            fprintf('Repeated runs: %d\n', commonConfig.repeat_runs);

            commonConfig.R_max = input('Enter new maximum federated rounds: ');
            commonConfig.M_local = input('Enter new local evolution generations: ');
            commonConfig.repeat_runs = input('Enter new number of repeated runs: ');

            % Save updated configuration
            save('experiments/config_struct.mat', 'commonConfig', 'performanceConfig', 'ablationConfig', 'comparisonConfig');
        end

        % Run performance scaling experiments
        run('experiments/performance_scaling/run_performance_experiments.m');

    case 2
        % Ablation studies
        fprintf('\n========================================\n');
        fprintf('Starting Ablation Studies\n');
        fprintf('========================================\n\n');

        % Load configuration
        run('experiments/config.m');

        % Ask user if they want to use default parameters
        useDefault = input('Use default parameters? (y/n): ', 's');

        if strcmpi(useDefault, 'n')
            % Allow user to modify parameters
            fprintf('\nCurrent parameters:\n');
            fprintf('Number of regions: %d\n', ablationConfig.num_regions);
            fprintf('Scenario type: %s\n', ablationConfig.scenario_type);
            fprintf('Maximum federated rounds: %d\n', commonConfig.R_max);
            fprintf('Local evolution generations: %d\n', commonConfig.M_local);
            fprintf('Repeated runs: %d\n', commonConfig.repeat_runs);

            ablationConfig.num_regions = input('Enter new number of regions: ');
            ablationConfig.scenario_type = input('Enter new scenario type (homogeneous/moderate/heterogeneous): ', 's');
            commonConfig.R_max = input('Enter new maximum federated rounds: ');
            commonConfig.M_local = input('Enter new local evolution generations: ');
            commonConfig.repeat_runs = input('Enter new number of repeated runs: ');

            % Save updated configuration
            save('experiments/config_struct.mat', 'commonConfig', 'performanceConfig', 'ablationConfig', 'comparisonConfig');
        end

        % Run ablation studies
        run('experiments/ablation_studies/run_ablation_experiments.m');

    case 3
        % Algorithm comparison experiments
        fprintf('\n========================================\n');
        fprintf('Starting Algorithm Comparison Experiments\n');
        fprintf('========================================\n\n');

        % Load configuration
        run('experiments/config.m');

        % Ask user if they want to use default parameters
        useDefault = input('Use default parameters? (y/n): ', 's');

        if strcmpi(useDefault, 'n')
            % Allow user to modify parameters
            fprintf('\nCurrent parameters:\n');
            fprintf('Maximum federated rounds: %d\n', commonConfig.R_max);
            fprintf('Local evolution generations: %d\n', commonConfig.M_local);
            fprintf('Repeated runs: %d\n', commonConfig.repeat_runs);

            commonConfig.R_max = input('Enter new maximum federated rounds: ');
            commonConfig.M_local = input('Enter new local evolution generations: ');
            commonConfig.repeat_runs = input('Enter new number of repeated runs: ');

            % Save updated configuration
            save('experiments/config_struct.mat', 'commonConfig', 'performanceConfig', 'ablationConfig', 'comparisonConfig');
        end

        % Run algorithm comparison experiments
        run('experiments/algorithm_comparison/run_comparison_experiments.m');

    case 4
        % Exit
        fprintf('\nExiting experiment runner.\n');
        return;

    otherwise
        % Invalid choice
        fprintf('\nInvalid choice. Please enter a number between 1 and 4.\n');
        return;
end

fprintf('\n========================================\n');
fprintf('Experiment completed successfully!\n');
fprintf('Results are saved in the experiments/results directory.\n');
fprintf('Figures are saved in the experiments/figures directory.\n');
fprintf('========================================\n');
