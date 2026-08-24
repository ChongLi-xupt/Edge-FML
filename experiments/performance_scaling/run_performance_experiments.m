% Performance Scaling Experiments for Edge-FML
% Tests algorithm performance across different dataset sizes, region counts, and scenario types

clear; clc; close all;

% Add source directory to path
addpath('../../src');
addpath('../');

% Get current script directory
scriptDir = fileparts(mfilename('fullpath'));
rootDir = fullfile(scriptDir, '../../');

% Load configuration
run(fullfile(scriptDir, '../config.m'));

% Create results directory if it doesn't exist
resultsDir = fullfile(rootDir, commonConfig.results_dir);
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
    fprintf('Created results directory: %s\n', resultsDir);
end
commonConfig.results_dir = resultsDir;

% Create figures directory if it doesn't exist
figuresDir = fullfile(rootDir, commonConfig.figures_dir);
if ~exist(figuresDir, 'dir')
    mkdir(figuresDir);
    fprintf('Created figures directory: %s\n', figuresDir);
end
commonConfig.figures_dir = figuresDir;

% Initialize results structure
results = struct();
results.timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
results.commonConfig = commonConfig;
results.performanceConfig = performanceConfig;
results.runs = struct();

% Experiment counter
runCount = 0;
totalRuns = length(performanceConfig.datasets) * ...
            length(performanceConfig.region_counts) * ...
            length(performanceConfig.scenario_types) * ...
            commonConfig.repeat_runs;

fprintf('========================================\n');
fprintf('Starting Performance Scaling Experiments\n');
fprintf('========================================\n');
fprintf('Total runs: %d\n\n', totalRuns);

% Open log file for detailed logging
logFileName = sprintf('%s/performance_experiment_log_%s.txt', commonConfig.results_dir, results.timestamp);
logFile = fopen(logFileName, 'w');
fprintf(logFile, 'Performance Scaling Experiment Log\n');
fprintf(logFile, 'Timestamp: %s\n', results.timestamp);
fprintf(logFile, 'Total runs: %d\n\n', totalRuns);
fclose(logFile);

% Main experiment loop
for dataIdx = 1:length(performanceConfig.datasets)
    dataset = performanceConfig.datasets{dataIdx};

    for regionIdx = 1:length(performanceConfig.region_counts)
        numRegions = performanceConfig.region_counts(regionIdx);

        for scenarioIdx = 1:length(performanceConfig.scenario_types)
            scenarioType = performanceConfig.scenario_types{scenarioIdx};

            for repeatIdx = 1:commonConfig.repeat_runs
                runCount = runCount + 1;

                fprintf('Run %d/%d: Dataset=%s, Regions=%d, Scenario=%s, Repeat=%d\n', ...
                    runCount, totalRuns, dataset, numRegions, scenarioType, repeatIdx);

                % Update log file
                logFile = fopen(logFileName, 'a');
                fprintf(logFile, '\n=== Run %d/%d ===\n', runCount, totalRuns);
                fprintf(logFile, 'Dataset: %s\n', dataset);
                fprintf(logFile, 'Regions: %d\n', numRegions);
                fprintf(logFile, 'Scenario: %s\n', scenarioType);
                fprintf(logFile, 'Repeat: %d\n', repeatIdx);
                fclose(logFile);

                try
                    % Generate scenario
                    fprintf('  Generating scenario...\n');
                    [regions, taskSets] = SimulationDataGenerator.generateScenario(numRegions, scenarioType);
                    fprintf('  Scenario generated with %d regions\n', numRegions);

                    % Update log file
                    logFile = fopen(logFileName, 'a');
                    fprintf(logFile, 'Scenario generated with %d regions\n', numRegions);
                    fclose(logFile);

                    % Initialize Edge-FML framework
                    fprintf('  Initializing Edge-FML...\n');
                    edgeFML = EdgeFML(regions, taskSets, commonConfig.R_max, commonConfig.M_local);
                    fprintf('  Edge-FML initialized with %d clusters\n', edgeFML.clusterManager.M);

                    % Update log file
                    logFile = fopen(logFileName, 'a');
                    fprintf(logFile, 'Edge-FML initialized with %d clusters\n', edgeFML.clusterManager.M);
                    fclose(logFile);

                    % Run federated optimization
                    fprintf('  Running federated optimization...\n');
                    tic;
                    edgeFML = edgeFML.run();
                    elapsedTime = toc;
                    fprintf('  Federated optimization completed in %.2f seconds\n', elapsedTime);

                    % Update log file
                    logFile = fopen(logFileName, 'a');
                    fprintf(logFile, 'Federated optimization completed in %.2f seconds\n', elapsedTime);
                    fclose(logFile);

                    % Evaluate results
                    fprintf('  Evaluating results...\n');
                    metrics = PerformanceMetrics(commonConfig.metrics_ref);
                    globalFront = edgeFML.globalElites;

                    HV = metrics.computeHypervolume(globalFront);
                    feasRate = metrics.computeFeasibilityRate(globalFront);
                    diversity = metrics.computeDiversity(globalFront);

                    fprintf('  Hypervolume: %.4e\n', HV);
                    fprintf('  Feasibility Rate: %.2f%%\n', feasRate);
                    fprintf('  Diversity: %.4f\n', diversity);
                    fprintf('  Communication: %.2f MB\n', edgeFML.totalCommBytes / 1e6);

                    % Update log file
                    logFile = fopen(logFileName, 'a');
                    fprintf(logFile, 'Hypervolume: %.4e\n', HV);
                    fprintf(logFile, 'Feasibility Rate: %.2f%%\n', feasRate);
                    fprintf(logFile, 'Diversity: %.4f\n', diversity);
                    fprintf(logFile, 'Communication: %.2f MB\n', edgeFML.totalCommBytes / 1e6);
                    fclose(logFile);

                    % Record results (use a valid struct field name)
                    runKey = sprintf('%s_%d_%s_%d', dataset, numRegions, scenarioType, repeatIdx);
                    safeRunKey = matlab.lang.makeValidName(runKey);

                    results.runs.(safeRunKey) = struct();
                    results.runs.(safeRunKey).dataset = dataset;
                    results.runs.(safeRunKey).numRegions = numRegions;
                    results.runs.(safeRunKey).scenarioType = scenarioType;
                    results.runs.(safeRunKey).repeatIdx = repeatIdx;
                    results.runs.(safeRunKey).elapsedTime = elapsedTime;
                    results.runs.(safeRunKey).hypervolume = HV;
                    results.runs.(safeRunKey).feasibilityRate = feasRate;
                    results.runs.(safeRunKey).diversity = diversity;
                    results.runs.(safeRunKey).totalCommBytes = edgeFML.totalCommBytes;
                    results.runs.(safeRunKey).clusterCount = edgeFML.clusterManager.M;
                    results.runs.(safeRunKey).globalFrontSize = length(globalFront);

                    % Save convergence history
                    results.runs.(safeRunKey).convergenceHistory = edgeFML.roundHistory;

                    % Save global front objectives for visualization
                    if length(globalFront) > 0
                        objs = zeros(length(globalFront), 3);
                        for i = 1:length(globalFront)
                            objs(i, :) = globalFront(i).objectives;
                        end
                        results.runs.(safeRunKey).globalFrontObjectives = objs;
                    end

                    % Save intermediate results to avoid data loss
                    intermediateResultsFile = sprintf('%s/performance_results_%s.mat', commonConfig.results_dir, results.timestamp);
                    save(intermediateResultsFile, 'results');
                    fprintf('  Intermediate results saved to: %s\n\n', intermediateResultsFile);

                    % Update log file
                    logFile = fopen(logFileName, 'a');
                    fprintf(logFile, 'Intermediate results saved to: %s\n', intermediateResultsFile);
                    fclose(logFile);

                catch ME
                    % Handle any errors that occur during the experiment
                    fprintf('  ERROR: %s\n', ME.message);
                    fprintf('  Error ID: %s\n', ME.identifier);
                    fprintf('  Error line: %d\n', ME.stack(1).line);
                    fprintf('  Error file: %s\n\n', ME.stack(1).file);

                    % Update log file with error information
                    logFile = fopen(logFileName, 'a');
                    fprintf(logFile, 'ERROR: %s\n', ME.message);
                    fprintf(logFile, 'Error ID: %s\n', ME.identifier);
                    fprintf(logFile, 'Error line: %d\n', ME.stack(1).line);
                    fprintf(logFile, 'Error file: %s\n', ME.stack(1).file);
                    fclose(logFile);

                    % Save intermediate results even if there was an error
                    intermediateResultsFile = sprintf('%s/performance_results_%s.mat', commonConfig.results_dir, results.timestamp);
                    save(intermediateResultsFile, 'results');
                    fprintf('  Intermediate results saved to: %s\n\n', intermediateResultsFile);
                end
            end
        end
    end
end

% Save final results
resultsFileName = sprintf('%s/performance_results_%s.mat', commonConfig.results_dir, results.timestamp);
save(resultsFileName, 'results');

fprintf('========================================\n');
fprintf('Performance Scaling Experiments Completed\n');
fprintf('========================================\n');
fprintf('Results saved to: %s\n', resultsFileName);
fprintf('========================================\n');

% Generate summary report and visualizations
reportScript = fullfile(scriptDir, 'generate_performance_report.m');
run(reportScript);
