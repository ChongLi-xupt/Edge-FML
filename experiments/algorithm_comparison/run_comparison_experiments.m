% Algorithm Comparison Experiments for Edge-FML
% Compares Edge-FML with baseline algorithms: Centralized-MTDMS, Independent-MTDMS, FedAvg-MOEAs, Original-FML

if ~exist('preserveWorkspace', 'var') || ~preserveWorkspace
    clear;
end
clc; close all;

% Add source directory to path
addpath('../../src');
addpath('../');

if ~exist('commonConfig', 'var') || ~exist('comparisonConfig', 'var')
    run('../config.m');
end

% Create results directory if it doesn't exist
if ~exist(commonConfig.results_dir, 'dir')
    mkdir(commonConfig.results_dir);
end

% Create figures directory if it doesn't exist
if ~exist(commonConfig.figures_dir, 'dir')
    mkdir(commonConfig.figures_dir);
end

% Initialize results structure
results = struct();
results.timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
results.commonConfig = commonConfig;
results.comparisonConfig = comparisonConfig;
results.runs = struct();

% Experiment counter
runCount = 0;
totalRuns = length(comparisonConfig.algorithms) * ...
            length(comparisonConfig.datasets) * ...
            length(comparisonConfig.scenario_types) * ...
            commonConfig.repeat_runs;

fprintf('========================================\n');
fprintf('Starting Algorithm Comparison Experiments\n');
fprintf('========================================\n');
fprintf('Total runs: %d\n\n', totalRuns);

% Main experiment loop
for algoIdx = 1:length(comparisonConfig.algorithms)
    algorithm = comparisonConfig.algorithms{algoIdx};

    for dataIdx = 1:length(comparisonConfig.datasets)
        dataset = comparisonConfig.datasets{dataIdx};

        for scenarioIdx = 1:length(comparisonConfig.scenario_types)
            scenarioType = comparisonConfig.scenario_types{scenarioIdx};

            for repeatIdx = 1:commonConfig.repeat_runs
                runCount = runCount + 1;

                fprintf('Run %d/%d: Algorithm=%s, Dataset=%s, Scenario=%s, Repeat=%d\n', ...
                    runCount, totalRuns, algorithm, dataset, scenarioType, repeatIdx);

                if exist('numRegionsOverride', 'var')
                    numRegions = numRegionsOverride;
                else
                    numRegions = 30;
                end
                [regions, taskSets] = SimulationDataGenerator.generateScenario(numRegions, scenarioType);

                % Run the specified algorithm
                switch algorithm
                    case 'MTDMS'
                        fprintf('  Running Centralized-MTDMS (ideal baseline)\n');
                        [resultsRun, elapsedTime] = runCentralizedBaseline(regions, taskSets, commonConfig, 'MTDMS_CMOEA_Local');

                    case 'IMTCMO'
                        fprintf('  Running Centralized-IMTCMO\n');
                        [resultsRun, elapsedTime] = runCentralizedBaseline(regions, taskSets, commonConfig, 'IMTCMO_Local');

                    case 'IMTCMO-BS'
                        fprintf('  Running Centralized-IMTCMO-BS\n');
                        [resultsRun, elapsedTime] = runCentralizedBaseline(regions, taskSets, commonConfig, 'IMTCMO_BS_Local');

                    case 'ICMA'
                        fprintf('  Running Centralized-ICMA\n');
                        [resultsRun, elapsedTime] = runCentralizedBaseline(regions, taskSets, commonConfig, 'ICMA_Local');

                    case 'DRLOS-EMCMO'
                        fprintf('  Running Centralized-DRLOS-EMCMO\n');
                        [resultsRun, elapsedTime] = runCentralizedBaseline(regions, taskSets, commonConfig, 'DRLOS_EMCMO_Local');

                    case 'Edge-FML'
                        % Proposed Edge-FML algorithm (defaults to MTDMS)
                        fprintf('  Running Edge-FML (proposed)\n');
                        [resultsRun, elapsedTime] = runEdgeFML(regions, taskSets, commonConfig, 'MTDMS_CMOEA_Local');

                    otherwise
                        error('Unknown algorithm: %s', algorithm);
                end

                % Record results (use sanitized struct field name)
                runKey = sprintf('%s_%s_%s_%d', algorithm, dataset, scenarioType, repeatIdx);
                safeRunKey = matlab.lang.makeValidName(runKey);

                results.runs.(safeRunKey) = struct();
                results.runs.(safeRunKey).algorithm = algorithm;
                results.runs.(safeRunKey).dataset = dataset;
                results.runs.(safeRunKey).scenarioType = scenarioType;
                results.runs.(safeRunKey).repeatIdx = repeatIdx;
                results.runs.(safeRunKey).elapsedTime = elapsedTime;
                results.runs.(safeRunKey).hypervolume = resultsRun.hv;
                results.runs.(safeRunKey).feasibilityRate = resultsRun.feasRate;
                results.runs.(safeRunKey).diversity = resultsRun.diversity;
                results.runs.(safeRunKey).totalCommBytes = resultsRun.commBytes;
                results.runs.(safeRunKey).globalFront = resultsRun.globalFront;
                results.runs.(safeRunKey).globalFrontObjectives = resultsRun.globalFrontObjectives;

                fprintf('  Completed in %.2f seconds\n', elapsedTime);
                fprintf('  Hypervolume: %.4e, Feasibility: %.2f%%, Diversity: %.4f\n', ...
                    resultsRun.hv, resultsRun.feasRate, resultsRun.diversity);
                fprintf('  Communication: %.2f MB\n\n', resultsRun.commBytes / 1e6);

                % Save intermediate results to avoid data loss
                save(sprintf('%s/comparison_results_%s.mat', commonConfig.results_dir, results.timestamp), 'results');
            end
        end
    end
end

function [resultsRun, elapsedTime] = runFederatedBaseline(regions, taskSets, config, localOptimizerClassName)
    % Generic federated wrapper for baseline algorithms (FedAvg style)
    tic;

    numRegions = length(regions);
    R_max = config.R_max;
    M_local = config.M_local;

    fprintf('\n========== 开始 %s 联邦训练 ==========\n', localOptimizerClassName);
    fprintf('训练轮数: %d, 本地进化代数: %d\n', R_max, M_local);

    % Initialize local optimizers
    optimizers = cell(numRegions, 1);
    for r = 1:numRegions
        % Dynamically instantiate the optimizer class
        optimizers{r} = feval(localOptimizerClassName, regions(r), taskSets{r}, M_local);
    end

    % Federated training loop
    for round = 1:R_max
        fprintf('\n--- 第 %d/%d 轮训练 ---\n', round, R_max);

        % 1. Local evolution
        fprintf('阶段1: 本地进化 (代数: %d)...\n', M_local);
        for r = 1:numRegions
            optimizers{r} = optimizers{r}.evolve();
        end

        % 2. Global knowledge exchange (FedAvg style)
        if round < R_max
            fprintf('阶段2: 全局知识交换 (FedAvg)...\n');
            % Collect non-dominated elites from all regions
            allNonDominated = [];
            for r = 1:numRegions
                currentElites = optimizers{r}.eliteArchive;
                if ~isempty(currentElites)
                    allNonDominated = [allNonDominated; currentElites(:)];
                end
            end

            % Extract global Pareto front from collected elites
            globalPareto = extractParetoFront(allNonDominated);

            % Select top M solutions for distribution
            M_dist = min(20, length(globalPareto));
            if M_dist > 0
                % Simple selection: sort by first objective
                objMat = vertcat(globalPareto.objectives);
                [~, idx] = sort(objMat(:,1));
                globalElites = globalPareto(idx(1:M_dist));
            else
                globalElites = globalPareto;
            end

            % 3. Distribute global elites back to all regions
            if ~isempty(globalElites)
                for r = 1:numRegions
                    currentPop = optimizers{r}.population;
                    if isempty(currentPop)
                        continue;
                    end

                    % Map global elites to target region dimensions
                    popSize = length(currentPop);
                    replaceCount = min(length(globalElites), floor(popSize * 0.2)); % Replace max 20%

                    % Find worst solutions to replace (highest constraint violation or first objective)
                    objMatPop = vertcat(currentPop.objectives);
                    violMatPop = [currentPop.constraintViolation]';
                    [~, worstIdx] = sortrows([violMatPop, objMatPop(:,1)], 'descend');

                    for i = 1:replaceCount
                        eliteCopy = globalElites(i);
                        % Dimension mapping (K_src, T_src) -> (K_tgt, T_tgt)
                        K_tgt = regions(r).numDevices;
                        T_tgt = length(taskSets{r});
                        K_src = length(eliteCopy.x_offload);
                        T_src = length(eliteCopy.y_cache);

                        mapped = Solution(K_tgt, T_tgt);
                        % Mapping logic: mod-based replication
                        for k2 = 1:K_tgt
                            k_src = mod(k2 - 1, K_src) + 1;
                            mapped.x_offload(k2) = eliteCopy.x_offload(k_src);
                            mapped.z_security(k2) = eliteCopy.z_security(k_src);
                        end
                        for t2 = 1:T_tgt
                            t_src = mod(t2 - 1, T_src) + 1;
                            mapped.y_cache(t2) = eliteCopy.y_cache(t_src);
                            mapped.f_resource(t2) = eliteCopy.f_resource(t_src);
                        end

                        % Re-evaluate in target region
                        try
                            [mapped.objectives, mapped.violations, mapped.constraintViolation] = ...
                                optimizers{r}.evaluator.evaluate(mapped);
                            currentPop(worstIdx(i)) = mapped;
                        catch
                            % Keep original if evaluation fails
                        end
                    end
                    optimizers{r}.population = currentPop;
                end
            end
        end
    end

    % Collect final global front from all regions
    finalElites = [];
    for r = 1:numRegions
        if ~isempty(optimizers{r}.eliteArchive)
            finalElites = [finalElites; optimizers{r}.eliteArchive(:)];
        end
    end
    globalFront = extractParetoFront(finalElites);

    % Evaluate final performance
    metrics = PerformanceMetrics(config.metrics_ref);
    hv = metrics.computeHypervolume(globalFront);
    feasRate = metrics.computeFeasibilityRate(globalFront);
    diversity = metrics.computeDiversity(globalFront);

    % Communication cost estimation (FedAvg style)
    % N regions * R rounds * M solutions * avgSize
    commBytes = numRegions * R_max * 20 * 1000;

    % Extract objectives for visualization
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    elapsedTime = toc;
    resultsRun = struct();
    resultsRun.hv = hv;
    resultsRun.feasRate = feasRate;
    resultsRun.diversity = diversity;
    resultsRun.commBytes = commBytes;
    resultsRun.globalFront = globalFront;
    resultsRun.globalFrontObjectives = objs;
end

% =======================================
% Helper Functions for Different Algorithms
% =======================================

function [resultsRun, elapsedTime] = runCentralizedBaseline(regions, taskSets, config, optimizerClass)
    % Centralized Baseline: Ideal centralized optimization
    % Combines all regions into a single centralized problem

    tic;

    numRegions = length(regions);
    R_max = config.R_max;
    M_local = config.M_local;
    totalGen = R_max * M_local;

    fprintf('\n========== 开始 %s 训练 ==========\n', ['Centralized-', strrep(optimizerClass, '_Local', '')]);
    fprintf('总进化代数: %d (对应联邦训练 %d 轮 * %d 本地代数)\n', totalGen, R_max, M_local);

    % For simplicity, use the first region's configuration but scale up
    region = regions(1);
    region.numDevices = sum([regions.numDevices]);
    region.computeCapacity = sum([regions.computeCapacity]);
    region.cacheCapacity = sum([regions.cacheCapacity]);

    % Combine all task sets
    combinedTasks = [];
    for tIdx = 1:length(taskSets)
        combinedTasks = [combinedTasks; taskSets{tIdx}];
    end

    % Run centralized optimization
    optimizer = feval(optimizerClass, region, combinedTasks, totalGen);
    optimizer = optimizer.evolve();

    globalFront = optimizer.eliteArchive;
    if ~isempty(globalFront)
        for i = 1:length(globalFront)
            globalFront(i).objectives = globalFront(i).objectives / max(numRegions, 1);
        end
    end

    % Evaluate results
    metrics = PerformanceMetrics(config.metrics_ref);

    hv = metrics.computeHypervolume(globalFront);
    feasRate = metrics.computeFeasibilityRate(globalFront);
    diversity = metrics.computeDiversity(globalFront);

    % Extract objectives for visualization
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    elapsedTime = toc;

    resultsRun = struct();
    resultsRun.hv = hv;
    resultsRun.feasRate = feasRate;
    resultsRun.diversity = diversity;
    resultsRun.commBytes = 0; % No communication in centralized
    resultsRun.globalFront = globalFront;
    resultsRun.globalFrontObjectives = objs;
end

function [resultsRun, elapsedTime] = runIndependentMTDMS(regions, taskSets, config)
    % Independent-MTDMS: No collaboration (each region runs independently)

    tic;

    numRegions = length(regions);
    R_max = config.R_max;
    M_local = config.M_local;
    totalGen = R_max * M_local;

    fprintf('\n========== 开始 Independent-MTDMS 训练 ==========\n');
    fprintf('每个区域独立进化总代数: %d (对应联邦训练 %d 轮 * %d 本地代数)\n', totalGen, R_max, M_local);

    % Collect elites from each region into a single Solution array
    allElites = Solution.empty(0,1);

    % Run MTDMS-CMOEA independently for each region
    for r = 1:numRegions
        optimizer = MTDMS_CMOEA_Local(regions(r), taskSets{r}, totalGen);
        optimizer = optimizer.evolve();
        elites = optimizer.eliteArchive;
        if isempty(elites)
            continue;
        end
        elites = elites(:); % ensure column vector
        % Append preserving Solution typed array
        startIdx = length(allElites) + 1;
        allElites(startIdx:startIdx+length(elites)-1) = elites;
    end

    % Evaluate results
    metrics = PerformanceMetrics(config.metrics_ref);
    globalFront = extractParetoFront(allElites);

    hv = metrics.computeHypervolume(globalFront);
    feasRate = metrics.computeFeasibilityRate(globalFront);
    diversity = metrics.computeDiversity(globalFront);

    % Extract objectives for visualization
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    elapsedTime = toc;

    resultsRun = struct();
    resultsRun.hv = hv;
    resultsRun.feasRate = feasRate;
    resultsRun.diversity = diversity;
    resultsRun.commBytes = 0; % No communication in independent mode
    resultsRun.globalFront = globalFront;
    resultsRun.globalFrontObjectives = objs;
end

function [resultsRun, elapsedTime] = runPARMTDMSCMOEA(regions, taskSets, config)
    tic;

    numRegions = length(regions);
    R_max = config.R_max;
    M_local = config.M_local;
    totalGen = R_max * M_local;

    fprintf('\n========== 开始 PAR-MTDMS-CMOEA 训练 ==========\n');
    fprintf('每个区域独立进化总代数: %d (对应联邦训练 %d 轮 * %d 本地代数)\n', totalGen, R_max, M_local);

    allElites = Solution.empty(0, 1);

    for r = 1:numRegions
        solver = PAR_MTDMS_CMOEA(regions(r), taskSets{r}, config.population_size, totalGen, false, 0.05);
        solver = solver.run();

        elites = solver.eliteArchive;
        if isempty(elites)
            continue;
        end
        elites = elites(:);
        startIdx = length(allElites) + 1;
        allElites(startIdx:startIdx+length(elites)-1) = elites;
    end

    metrics = PerformanceMetrics(config.metrics_ref);
    globalFront = extractParetoFront(allElites);

    hv = metrics.computeHypervolume(globalFront);
    feasRate = metrics.computeFeasibilityRate(globalFront);
    diversity = metrics.computeDiversity(globalFront);

    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    elapsedTime = toc;

    resultsRun = struct();
    resultsRun.hv = hv;
    resultsRun.feasRate = feasRate;
    resultsRun.diversity = diversity;
    resultsRun.commBytes = 0;
    resultsRun.globalFront = globalFront;
    resultsRun.globalFrontObjectives = objs;
end

function [resultsRun, elapsedTime] = runOriginalFML(regions, taskSets, config)
    % Original-FML: Original federated membrane learning
    % Simulate original FML by disabling Edge-FML enhancements

    tic;

    % Initialize Edge-FML but disable enhancements
    edgeFML = EdgeFML(regions, taskSets, config.R_max, config.M_local);

    % Disable clustering (flat structure)
    edgeFML.clusterManager = ClusterManager(regions, 'flat');

    % Disable adaptive threshold SSS (use fixed threshold)
    edgeFML.sss = ShamirSecretSharing('fixed');

    % Disable solution compatibility mechanism
    for r = 1:edgeFML.N
        edgeFML.adapters{r} = SolutionAdapter(regions(r), taskSets{r}, 'no_compat');
    end

    % Disable local optimizer enhancements
    for r = 1:edgeFML.N
        edgeFML.localOptimizers{r} = MTDMS_CMOEA_Local(regions(r), taskSets{r}, config.M_local, 'standard');
    end

    % Disable communication compression
    edgeFML.clusterManager.compressFactor = 1.0;

    % Run federated optimization
    edgeFML = edgeFML.run();

    % Evaluate results
    metrics = PerformanceMetrics(config.metrics_ref);
    globalFront = edgeFML.globalElites;

    hv = metrics.computeHypervolume(globalFront);
    feasRate = metrics.computeFeasibilityRate(globalFront);
    diversity = metrics.computeDiversity(globalFront);

    % Extract objectives for visualization
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    elapsedTime = toc;

    resultsRun = struct();
    resultsRun.hv = hv;
    resultsRun.feasRate = feasRate;
    resultsRun.diversity = diversity;
    resultsRun.commBytes = edgeFML.totalCommBytes;
    resultsRun.globalFront = globalFront;
    resultsRun.globalFrontObjectives = objs;
end

function [resultsRun, elapsedTime] = runEdgeFML(regions, taskSets, config, optimizerClass)
    % Edge-FML: Proposed algorithm

    tic;

    if nargin < 4 || isempty(optimizerClass)
        optimizerClass = 'MTDMS_CMOEA_Local';
    end

    % Initialize Edge-FML framework
    edgeFML = EdgeFML(regions, taskSets, config.R_max, config.M_local, optimizerClass);

    % Run federated optimization
    edgeFML = edgeFML.run();

    % Evaluate results
    metrics = PerformanceMetrics(config.metrics_ref);
    globalFront = edgeFML.globalElites;

    hv = metrics.computeHypervolume(globalFront);
    feasRate = metrics.computeFeasibilityRate(globalFront);
    diversity = metrics.computeDiversity(globalFront);

    % Extract objectives for visualization
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    elapsedTime = toc;

    resultsRun = struct();
    resultsRun.hv = hv;
    resultsRun.feasRate = feasRate;
    resultsRun.diversity = diversity;
    resultsRun.commBytes = edgeFML.totalCommBytes;
    resultsRun.globalFront = globalFront;
    resultsRun.globalFrontObjectives = objs;
end

function [resultsRun, elapsedTime] = runEdgeFMLEnhanced(regions, taskSets, config)
    % Edge-FML-Enhanced: Enhanced version with robustness features

    tic;

    % Initialize Edge-FML Enhanced framework
    edgeFML = EdgeFML_Enhanced(regions, taskSets, config.R_max, config.M_local);

    % Run federated optimization
    edgeFML = edgeFML.run();

    % Evaluate results
    metrics = PerformanceMetrics(config.metrics_ref);
    globalFront = edgeFML.globalElites;

    hv = metrics.computeHypervolume(globalFront);
    feasRate = metrics.computeFeasibilityRate(globalFront);
    diversity = metrics.computeDiversity(globalFront);

    % Extract objectives for visualization
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    elapsedTime = toc;

    resultsRun = struct();
    resultsRun.hv = hv;
    resultsRun.feasRate = feasRate;
    resultsRun.diversity = diversity;
    resultsRun.commBytes = edgeFML.totalCommBytes;
    resultsRun.globalFront = globalFront;
    resultsRun.globalFrontObjectives = objs;
end

function [resultsRun, elapsedTime] = runEdgeFMLParallel(regions, taskSets, config)
    % Edge-FML-Parallel: Parallel version for performance

    tic;

    % Determine number of workers (default to 4 if not specified)
    if isfield(config, 'num_workers')
        numWorkers = config.num_workers;
    else
        numWorkers = 4;
    end

    % Initialize Edge-FML Parallel framework
    % Fix: Pass 'NumWorkers' as a named parameter
    edgeFML = EdgeFML_Parallel(regions, taskSets, config.R_max, config.M_local, 'NumWorkers', numWorkers);

    % Run federated optimization
    edgeFML = edgeFML.run();

    % Evaluate results
    metrics = PerformanceMetrics(config.metrics_ref);
    globalFront = edgeFML.globalElites;

    hv = metrics.computeHypervolume(globalFront);
    feasRate = metrics.computeFeasibilityRate(globalFront);
    diversity = metrics.computeDiversity(globalFront);

    % Extract objectives for visualization
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end

    elapsedTime = toc;

    resultsRun = struct();
    resultsRun.hv = hv;
    resultsRun.feasRate = feasRate;
    resultsRun.diversity = diversity;
    resultsRun.commBytes = edgeFML.totalCommBytes;
    resultsRun.globalFront = globalFront;
    resultsRun.globalFrontObjectives = objs;
end

function paretoFront = extractParetoFront(population)
    % Extract non-dominated solutions from population
    n = length(population);
    dominated = false(n, 1);

    for i = 1:n
        for j = 1:n
            if i ~= j && dominates(population(j), population(i))
                dominated(i) = true;
                break;
            end
        end
    end

    paretoFront = population(~dominated);
end

function isDominated = dominates(solA, solB)
    % Check if solA dominates solB
    % solA dominates solB if solA is better or equal in all objectives and better in at least one
    objA = solA.objectives;
    objB = solB.objectives;

    % All objectives must be better or equal
    allBetterOrEqual = all(objA <= objB);

    % At least one objective must be better
    atLeastOneBetter = any(objA < objB);

    isDominated = allBetterOrEqual && atLeastOneBetter;
end
