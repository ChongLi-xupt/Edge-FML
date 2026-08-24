% Ablation Studies for Edge-FML
% Tests the effectiveness of individual components by disabling them one by one

clear; clc; close all;

% Add source directory to path
currentDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(currentDir)); % Go up two levels to project root

addpath(fullfile(projectRoot, 'src'));
addpath(fullfile(projectRoot, 'experiments'));

% Load configuration
configPath = fullfile(projectRoot, 'experiments', 'config.m');
run(configPath);

% Resolve absolute paths for results and figures
resultsDir = fullfile(currentDir, 'experiments', 'results');
figuresDir = fullfile(currentDir, 'experiments', 'figures');

% Create results directory if it doesn't exist
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

% Create figures directory if it doesn't exist
if ~exist(figuresDir, 'dir')
    mkdir(figuresDir);
end

% Initialize results structure
results = struct();
results.timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
results.commonConfig = commonConfig;
results.ablationConfig = ablationConfig;
results.runs = struct();

% Experiment counter
runCount = 0;
totalRuns = length(ablationConfig.variants) * commonConfig.repeat_runs;

fprintf('========================================\n');
fprintf('Starting Ablation Studies\n');
fprintf('========================================\n');
fprintf('Total runs: %d\n\n', totalRuns);

% Main experiment loop
for variantIdx = 1:length(ablationConfig.variants)
    variant = ablationConfig.variants{variantIdx};

    for repeatIdx = 1:commonConfig.repeat_runs
        runCount = runCount + 1;

        fprintf('Run %d/%d: Variant=%s, Repeat=%d\n', ...
            runCount, totalRuns, variant, repeatIdx);

        % Generate scenario
        [regions, taskSets] = SimulationDataGenerator.generateScenario(...
            ablationConfig.num_regions, ablationConfig.scenario_type);

        % Initialize Edge-FML framework with ablation variant
        edgeFML = EdgeFML(regions, taskSets, commonConfig.R_max, commonConfig.M_local);

        % Apply ablation modifications based on variant
        switch variant
            case 'no_clustering'
                % Disable clustering by setting all regions to a single cluster
                fprintf('  Applying ablation: No clustering (flat structure)\n');
                edgeFML.clusterManager = ClusterManager(regions, 'flat');

            case 'no_atsss'
                % Disable adaptive threshold SSS by using fixed threshold
                fprintf('  Applying ablation: No adaptive threshold SSS\n');
                % Modify SSS to use fixed threshold
                edgeFML.sss = ShamirSecretSharing('fixed');

            case 'no_compat'
                % Disable solution compatibility mechanism
                fprintf('  Applying ablation: No solution compatibility\n');
                % Modify adapters to bypass compatibility checks
                for r = 1:edgeFML.N
                    edgeFML.adapters{r} = SolutionAdapter(regions(r), taskSets{r}, 'no_compat');
                end

            case 'no_local_enhance'
                % Disable local optimizer enhancements
                fprintf('  Applying ablation: No local optimizer enhancements\n');
                % Create standard MTDMS-CMOEA without enhancements
                for r = 1:edgeFML.N
                    edgeFML.localOptimizers{r} = MTDMS_CMOEA_Local(...
                        regions(r), taskSets{r}, commonConfig.M_local, 'standard');
                end

            case 'no_comm_compress'
                % Disable communication compression
                fprintf('  Applying ablation: No communication compression\n');
                % Set compression factor to 1 (no compression)
                edgeFML.clusterManager.compressFactor = 1.0;

            case 'full'
                fprintf('  Running full Edge-FML implementation\n');
                % No modifications needed for full implementation

            otherwise
                % Support theta_keep sweep variants: 'theta_keep_0.40', 'theta_keep_0.45', ...
                if startsWith(variant, 'theta_keep_')
                    fprintf('  Applying ablation: ThetaKeep sweep (%s)\n', variant);
                    tkStr = erase(variant, 'theta_keep_');
                    tkVal = str2double(tkStr);
                    if isnan(tkVal)
                        warning('Invalid ThetaKeep value in variant: %s', variant);
                    end
                    for r = 1:edgeFML.N
                        % original: adapters without explicit ThetaKeep
                        edgeFML.adapters{r} = SolutionAdapter(regions(r), taskSets{r}, 'default', 'ThetaKeep', tkVal);
                    end
                else
                    warning('Unknown ablation variant: %s', variant);
                end
        end

        % Run federated optimization
        tic;
        edgeFML = edgeFML.run();
        elapsedTime = toc;

        % Evaluate results
        metrics = PerformanceMetrics(commonConfig.metrics_ref);
        globalFront = edgeFML.globalElites;

        HV = metrics.computeHypervolume(globalFront);
        feasRate = metrics.computeFeasibilityRate(globalFront);
        diversity = metrics.computeDiversity(globalFront);

        % Compute constraint violation breakdown on final global front
        violCounts = zeros(1, 4);
        violMeans = zeros(1, 4);
        if ~isempty(globalFront)
            V = zeros(length(globalFront), 4);
            for i = 1:length(globalFront)
                if ~isempty(globalFront(i).violations)
                    V(i, :) = globalFront(i).violations;
                end
            end
            violMeans = mean(V, 1);
            violCounts = sum(V > 0, 1);
        end

        % Adapter hit rate from EdgeFML integration statistics
        adapterAttempts = 0;
        adapterAccepted = 0;
        adapterRate = NaN;
        if isprop(edgeFML, 'adapterAttemptsTotal') && ~isempty(edgeFML.adapterAttemptsTotal)
            adapterAttempts = edgeFML.adapterAttemptsTotal;
            adapterAccepted = edgeFML.adapterAcceptedTotal;
            adapterRate = 100 * adapterAccepted / max(adapterAttempts, 1);
        end

        % Record results
        runKey = sprintf('%s_%d', variant, repeatIdx);

        results.runs.(runKey) = struct();
        results.runs.(runKey).variant = variant;
        results.runs.(runKey).repeatIdx = repeatIdx;
        results.runs.(runKey).elapsedTime = elapsedTime;
        results.runs.(runKey).hypervolume = HV;
        results.runs.(runKey).feasibilityRate = feasRate;
        results.runs.(runKey).diversity = diversity;
        results.runs.(runKey).totalCommBytes = edgeFML.totalCommBytes;
        results.runs.(runKey).clusterCount = edgeFML.clusterManager.M;
        results.runs.(runKey).globalFrontSize = length(globalFront);
        results.runs.(runKey).violationsBreakdown = struct('counts', violCounts, 'means', violMeans);
        results.runs.(runKey).adapterStats = struct('attempts', adapterAttempts, 'accepted', adapterAccepted, 'rate', adapterRate);

        % Save convergence history
        results.runs.(runKey).convergenceHistory = edgeFML.roundHistory;

        % Save global front objectives for visualization
        if length(globalFront) > 0
            objs = zeros(length(globalFront), 3);
            for i = 1:length(globalFront)
                objs(i, :) = globalFront(i).objectives;
            end
            results.runs.(runKey).globalFrontObjectives = objs;
        end

        fprintf('  Completed in %.2f seconds\n', elapsedTime);
        fprintf('  Hypervolume: %.4e, Feasibility: %.2f%%, Diversity: %.4f\n', ...
            HV, feasRate, diversity);
        fprintf('  Communication: %.2f MB\n\n', edgeFML.totalCommBytes / 1e6);

        % Save intermediate results to avoid data loss
        save(fullfile(resultsDir, sprintf('ablation_results_%s.mat', results.timestamp)), 'results');
    end
end

% Save final results
resultsFileName = fullfile(resultsDir, sprintf('ablation_results_%s.mat', results.timestamp));
save(resultsFileName, 'results');

fprintf('========================================\n');
fprintf('Ablation Studies Completed\n');
fprintf('Results saved to: %s\n', resultsFileName);
fprintf('========================================\n');

% Generate summary report and visualizations
reportScript = fullfile(fileparts(mfilename('fullpath')), 'generate_ablation_report.m');
run(reportScript);
