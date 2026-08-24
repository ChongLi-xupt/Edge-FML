classdef EdgeFML_Enhanced
    % EdgeFML_Enhanced - Enhanced version with optimized memory allocation and error handling
    % Based on EdgeFML with performance improvements and robust validation
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Edge Federated Membrane Learning Algorithm Description

    properties
        % System configuration
        regions           % Array of RegionConfig objects
        taskSets          % Cell array of task sets for each region
        N                 % Number of regions

        % Algorithm parameters
        R_max             % Maximum federated rounds
        M_local           % Local evolution budget (generations)
        M_elite           % Number of elite solutions to exchange

        % Components
        clusterManager    % ClusterManager object
        localOptimizers   % Array of MTDMS_CMOEA_Local objects
        adapters          % Array of SolutionAdapter objects
        sss               % ShamirSecretSharing object
        metrics           % PerformanceMetrics object

        % Global state
        globalElites      % Global elite solutions
        roundHistory      % History of performance metrics
        clusterElites     % Cluster elite solutions (temporary storage)
        clusterViolations % Cluster violation patterns (temporary storage)

        % Communication tracking
        totalCommBytes    % Total communication in bytes

        % Enhanced features
        memoryMonitor     % Memory usage monitoring
        errorLog          % Error logging
        performanceStats   % Detailed performance statistics
        validationEnabled  % Enable input validation
    end

    methods
        function obj = EdgeFML_Enhanced(regions, taskSets, R_max, M_local, varargin)
            % Enhanced constructor with validation and error handling
            % Optional: EdgeFML_Enhanced(..., 'Validation', true, 'MemoryMonitor', true)

            % Input validation
            if nargin < 4
                error('EdgeFML_Enhanced: Requires at least 4 input arguments');
            end

            if ~iscell(regions) && ~isa(regions, 'RegionConfig')
                error('EdgeFML_Enhanced: regions must be a cell array or RegionConfig array');
            end
            if ~iscell(taskSets)
                error('EdgeFML_Enhanced: taskSets must be a cell array');
            end

            % Convert RegionConfig array to cell array if needed (to match expected format)
            if ~iscell(regions)
                 % If it's a struct or object array, we can use it directly if the code supports it,
                 % OR convert to cell.
                 % However, looking at line 12: properties regions % Array of RegionConfig objects
                 % And EdgeFML.m usually takes an array of RegionConfig objects.
                 % So the validation here is actually too strict compared to EdgeFML.m

                 % Let's RELAX the validation to allow RegionConfig array.
            end

            if length(regions) ~= length(taskSets)
                error('EdgeFML_Enhanced: regions and taskSets must have same length');
            end

            if R_max <= 0 || M_local <= 0
                error('EdgeFML_Enhanced: R_max and M_local must be positive');
            end

            % Parse optional arguments
            p = inputParser;
            addParameter(p, 'Validation', true, @islogical);
            addParameter(p, 'MemoryMonitor', false, @islogical);
            addParameter(p, 'DebugMode', false, @islogical);
            parse(p, varargin{:});

            obj.validationEnabled = p.Results.Validation;
            obj.memoryMonitor = p.Results.MemoryMonitor;

            % Initialize with error handling
            try
                obj.regions = regions;
                obj.taskSets = taskSets;
                obj.N = length(regions);
                obj.R_max = R_max;
                obj.M_local = M_local;
                obj.M_elite = min(10, max(5, floor(50 / obj.N)));  % Adaptive elite count

                % Initialize components
                obj.clusterManager = ClusterManager(regions);
                obj.sss = ShamirSecretSharing();
                obj.metrics = PerformanceMetrics([1000, 1000, 1000]);

                % Initialize local optimizers with memory pre-allocation
                obj.localOptimizers = cell(1, obj.N);
                obj.adapters = cell(1, obj.N);

                for r = 1:obj.N
                    obj.localOptimizers{r} = MTDMS_CMOEA_Local(...
                        regions(r), taskSets{r}, M_local);
                    obj.adapters{r} = SolutionAdapter(regions(r), taskSets{r});
                end

                % Initialize enhanced monitoring
                obj.globalElites = [];
                obj.roundHistory = struct('round', {}, 'HV', {}, 'feasibilityRate', {}, ...
                    'memoryUsage', {}, 'communicationOverhead', {});
                obj.clusterElites = [];
                obj.clusterViolations = [];
                obj.totalCommBytes = 0;
                obj.errorLog = {};
                obj.performanceStats = struct();

                if obj.memoryMonitor
                    obj.initializeMemoryMonitor();
                end

                fprintf('Edge-FML Enhanced initialized with %d regions in %d clusters\n', ...
                    obj.N, obj.clusterManager.M);
                obj.clusterManager.printClusterInfo();

            catch ME
                obj.logError('Constructor', ME.message, ME.stack);
                rethrow(ME);
            end
        end

        function obj = run(obj)
            % Enhanced main federated training loop with error handling and monitoring

            fprintf('\n========== Starting Edge-FML Enhanced Training ==========\n');

            try
                totalStartTime = tic;

                % Pre-allocate performance tracking arrays
                stageTimes = zeros(4, obj.R_max);  % 4 stages x R_max rounds
                memoryUsage = zeros(1, obj.R_max);
                commOverhead = zeros(1, obj.R_max);

                for round = 1:obj.R_max
                    fprintf('\n--- Round %d/%d ---\n', round, obj.R_max);
                    roundStartTime = tic;

                    % Memory monitoring
                    if obj.memoryMonitor
                        memoryUsage(round) = obj.getCurrentMemoryUsage();
                    end

                    % Stage 1: Local Membrane Evolution
                    stage1Start = tic;
                    obj = obj.localEvolution();
                    stageTimes(1, round) = toc(stage1Start);

                    % Stage 2: Cluster-Level Knowledge Exchange
                    stage2Start = tic;
                    obj = obj.clusterLevelExchange();
                    stageTimes(2, round) = toc(stage2Start);

                    % Stage 3: Federated Knowledge Aggregation
                    stage3Start = tic;
                    obj = obj.federatedAggregation(round);
                    stageTimes(3, round) = toc(stage3Start);

                    % Stage 4: Local Knowledge Integration
                    stage4Start = tic;
                    obj = obj.localIntegration();
                    stageTimes(4, round) = toc(stage4Start);

                    % Evaluate and record performance
                    evalStart = tic;
                    obj = obj.evaluateRound(round);
                    evalTime = toc(evalStart);

                    % Communication tracking
                    commOverhead(round) = obj.estimateCommunicationOverhead();

                    roundTime = toc(roundStartTime);
                    fprintf('Round %d completed in %.2f seconds (eval: %.3fs)\n', ...
                        round, roundTime, evalTime);

                    % Memory cleanup every 2 rounds
                    if mod(round, 2) == 0
                        obj.performMemoryCleanup();
                    end
                end

                % Store performance statistics
                obj.performanceStats.stageTimes = stageTimes;
                obj.performanceStats.memoryUsage = memoryUsage;
                obj.performanceStats.communicationOverhead = commOverhead;
                obj.performanceStats.totalTime = toc(totalStartTime);

                % Final global front
                obj = obj.buildGlobalFront();

                totalTime = toc(totalStartTime);
                fprintf('\n========== Edge-FML Enhanced Training Completed ==========\n');
                fprintf('Total execution time: %.2f seconds\n', totalTime);
                obj.printFinalStatistics();
                obj.printPerformanceAnalysis();

            catch ME
                obj.logError('Run', ME.message, ME.stack);

                % Attempt graceful shutdown
                fprintf('Error occurred: %s\n', ME.message);
                obj.printErrorSummary();
                rethrow(ME);
            end
        end

        function obj = localEvolution(obj)
            % Enhanced local evolution with error handling
            fprintf('Stage 1: Enhanced Local Evolution...\n');

            try
                % Pre-allocate for parallel execution
                if obj.memoryMonitor
                    obj.logMemoryUsage('Before local evolution');
                end
                % Parallel local evolution if possible
                if obj.N > 3 && license('test', 'Distrib_Computing_Toolbox')
                    % Parallel execution: compute new optimizers in parallel and collect errors
                    localNew = cell(1, obj.N);
                    errors = cell(1, obj.N);
                    parfor r = 1:obj.N
                        try
                            localNew{r} = obj.localOptimizers{r}.evolve();
                        catch ME
                            % Keep previous optimizer on error
                            localNew{r} = obj.localOptimizers{r};
                            errors{r} = ME; %#ok<PFOUS>
                        end
                    end

                    % Merge results and log any errors (outside parfor)
                    for r = 1:obj.N
                        if ~isempty(errors{r})
                            obj.logError(sprintf('LocalEvolution_R%d', r), errors{r}.message, errors{r}.stack);
                        end
                        obj.localOptimizers{r} = localNew{r};
                    end
                else
                    % Sequential execution
                    for r = 1:obj.N
                        try
                            obj.localOptimizers{r} = obj.localOptimizers{r}.evolve();
                        catch ME
                            obj.logError(sprintf('LocalEvolution_R%d', r), ME.message, ME.stack);
                            % Continue with previous state
                        end
                    end
                end

                if obj.memoryMonitor
                    obj.logMemoryUsage('After local evolution');
                end

            catch ME
                obj.logError('LocalEvolution', ME.message, ME.stack);
                rethrow(ME);
            end
        end

        function obj = clusterLevelExchange(obj)
            % Enhanced cluster-level exchange with memory optimization
            fprintf('Stage 2: Enhanced Cluster-Level Exchange...\n');

            try
                M = obj.clusterManager.M;

                % Pre-allocate cluster data structures
                clusterElites = cell(1, M);
                clusterViolations = zeros(M, 4);

                % Process clusters sequentially to avoid unsafe writes from parfor
                for m = 1:M
                    clusterElites{m} = obj.processCluster(m);
                    clusterViolations(m, :) = obj.computeClusterViolations(m);
                end

                % Store results
                obj.clusterElites = clusterElites;
                obj.clusterViolations = clusterViolations;

            catch ME
                obj.logError('ClusterLevelExchange', ME.message, ME.stack);
                rethrow(ME);
            end
        end

        function elites = processCluster(obj, clusterID)
            % Process individual cluster with error handling
            try
                members = obj.clusterManager.getClusterMembers(clusterID);
                numMembers = length(members);

                % Pre-allocate with exact size
                allElites = Solution.empty(numMembers * obj.M_elite, 0);
                eliteCount = 0;

                for idx = 1:numMembers
                    r = members(idx);
                    try
                        elites = obj.localOptimizers{r}.getEliteSolutions(obj.M_elite);

                        % Direct indexing for memory efficiency
                        numElites = length(elites);
                        allElites(eliteCount+1:eliteCount+numElites) = elites(:);
                        eliteCount = eliteCount + numElites;

                    catch ME
                        obj.logError(sprintf('ProcessCluster_R%d', r), ME.message, ME.stack);
                        % Continue with empty elites
                    end
                end

                % Trim to actual size
                allElites = allElites(1:eliteCount);

                % Enhanced merging and filtering
                elites = obj.enhancedMergeAndFilter(allElites, 0.6);

                % Communication tracking
                obj.totalCommBytes = obj.totalCommBytes + ...
                    eliteCount * obj.estimateSolutionSize();

            catch ME
                obj.logError(sprintf('ProcessCluster_C%d', clusterID), ME.message, ME.stack);
                elites = Solution.empty(0, 0);
            end
        end

        function violations = computeClusterViolations(obj, clusterID)
            % Compute average constraint violations for cluster
            try
                members = obj.clusterManager.getClusterMembers(clusterID);
                numMembers = length(members);

                if numMembers == 0
                    violations = zeros(1, 4);
                    return;
                end

                allViolations = zeros(numMembers, 4);
                validCount = 0;

                for idx = 1:numMembers
                    r = members(idx);
                    try
                        elites = obj.localOptimizers{r}.getEliteSolutions(obj.M_elite);
                        if ~isempty(elites)
                            avgViolation = zeros(1, 4);
                            for i = 1:length(elites)
                                avgViolation = avgViolation + elites(i).violations;
                            end
                            avgViolation = avgViolation / length(elites);
                            allViolations(idx, :) = avgViolation;
                            validCount = validCount + 1;
                        end
                    catch ME
                        obj.logError(sprintf('ComputeViolations_R%d', r), ME.message, ME.stack);
                    end
                end

                if validCount > 0
                    violations = mean(allViolations(1:validCount, :), 1);
                else
                    violations = zeros(1, 4);
                end

            catch ME
                obj.logError(sprintf('ComputeClusterViolations_C%d', clusterID), ME.message, ME.stack);
                violations = zeros(1, 4);
            end
        end

        function obj = federatedAggregation(obj, round)
            % Enhanced federated aggregation with validation
            fprintf('Stage 3: Enhanced Federated Aggregation...\n');

            try
                M = obj.clusterManager.M;

                % Enhanced aggregation with error handling
                globalViolation = zeros(1, 4);
                totalElites = 0;

                % Pre-allocate for efficiency
                for m = 1:M
                    totalElites = totalElites + length(obj.clusterElites{m});
                end

                allClusterElites = Solution.empty(totalElites, 0);
                eliteIdx = 0;

                for m = 1:M
                    if ~isempty(obj.clusterElites{m})
                        clusterElites_m = obj.clusterElites{m}(:);
                        numElites = length(clusterElites_m);
                        allClusterElites(eliteIdx+1:eliteIdx+numElites) = clusterElites_m;
                        eliteIdx = eliteIdx + numElites;

                        % Aggregate violations with adaptive threshold
                        v = obj.clusterViolations(m, :);
                        theta_agg = obj.adaptiveThreshold(round);
                        v_agg = v;
                        v_agg(abs(v) <= theta_agg) = 0;

                        globalViolation = globalViolation + v_agg;
                    end
                end

                allClusterElites = allClusterElites(1:eliteIdx);

                % Enhanced global elite selection
                maxGlobalElites = min(obj.M_elite, 20);
                obj.globalElites = obj.enhancedSelectGlobalElites(allClusterElites, maxGlobalElites);

                % Enhanced communication tracking
                obj.totalCommBytes = obj.totalCommBytes + ...
                    totalElites * obj.estimateSolutionSize() * 2;  % Encrypted communication

            catch ME
                obj.logError('FederatedAggregation', ME.message, ME.stack);
                rethrow(ME);
            end
        end

        function threshold = adaptiveThreshold(obj, round)
            % Adaptive threshold for communication
            % Decreases over time to reduce communication overhead
            baseThreshold = 0.1;
            decayRate = 0.95;
            threshold = baseThreshold * (decayRate ^ (round - 1));
            threshold = max(threshold, 0.01);  % Minimum threshold
        end

        function elites = enhancedSelectGlobalElites(obj, allElites, M)
            % Enhanced global elite selection with diversity and convergence
            try
                if isempty(allElites) || length(allElites) <= M
                    elites = allElites;
                    return;
                end

                % Multi-criteria selection: convergence + diversity
                % Step 1: Extract Pareto front
                paretoFront = obj.extractParetoFront(allElites);

                if length(paretoFront) <= M
                    elites = paretoFront;
                    return;
                end

                % Step 2: Compute convergence scores
                convergenceScores = zeros(length(paretoFront), 1);
                for i = 1:length(paretoFront)
                    % HV contribution
                    remaining = paretoFront;
                    remaining(i) = [];
                    HV_without = obj.metrics.computeHypervolume(remaining);
                    HV_with = obj.metrics.computeHypervolume(paretoFront);
                    convergenceScores(i) = HV_with - HV_without;
                end

                % Step 3: Compute diversity scores
                diversityScores = obj.computeDiversityScores(paretoFront);

                % Step 4: Combined selection
                combinedScores = 0.6 * convergenceScores + 0.4 * diversityScores;
                [~, sortIdx] = sort(combinedScores, 'descend');

                elites = paretoFront(sortIdx(1:min(M, length(sortIdx))));

            catch ME
                obj.logError('EnhancedSelectGlobalElites', ME.message, ME.stack);
                elites = allElites(1:min(M, length(allElites)));  % Fallback
            end
        end

        function diversityScores = computeDiversityScores(obj, population)
            % Compute diversity scores for selection
            n = length(population);
            diversityScores = zeros(n, 1);

            for i = 1:n
                % Distance to k nearest neighbors
                distances = zeros(n, 1);
                for j = 1:n
                    if i ~= j
                        distances(j) = norm(population(i).objectives - population(j).objectives);
                    else
                        distances(j) = inf;
                    end
                end

                k = min(5, n-1);
                sortedDist = sort(distances);
                diversityScores(i) = mean(sortedDist(1:k));
            end
        end

        function obj = localIntegration(obj)
            % Enhanced local integration with validation
            fprintf('Stage 4: Enhanced Local Integration...\n');

            try
                if isempty(obj.globalElites)
                    fprintf('  No global elites to integrate\n');
                    return;
                end

                totalAdapted = 0;
                totalRejected = 0;

                % Limit global elites for performance
                maxElitesToIntegrate = min(length(obj.globalElites), 20);

                % Sequential integration to avoid unsafe concurrent writes
                for r = 1:obj.N
                    [adapted, rejected] = obj.processRegionIntegration(r, obj.globalElites(1:maxElitesToIntegrate));
                    totalAdapted = totalAdapted + adapted;
                    totalRejected = totalRejected + rejected;
                end

                adaptRate = 100 * totalAdapted / max(totalAdapted + totalRejected, 1);
                fprintf('  Enhanced adaptation rate: %.2f%% (%d/%d)\n', ...
                    adaptRate, totalAdapted, totalAdapted + totalRejected);

            catch ME
                obj.logError('LocalIntegration', ME.message, ME.stack);
                rethrow(ME);
            end
        end

        function [adapted, rejected] = processRegionIntegration(obj, regionID, globalElites)
            % Process integration for individual region
            try
                adapted = 0;
                rejected = 0;

                clusterID = obj.clusterManager.getClusterID(regionID);

                % Pre-allocate adapted elites
                adaptedElites = Solution.empty(length(globalElites), 0);
                adaptedCount = 0;

                for i = 1:length(globalElites)
                    externalSol = globalElites(i);

                    try
                        sourceRegionID = obj.clusterManager.getRepresentative(clusterID);
                        sourceRegion = obj.regions(sourceRegionID);
                        importance = obj.computeSolutionImportance(externalSol);

                        % Enhanced adaptation with validation
                        adaptedSol = obj.adapters{regionID}.adaptSolution(...
                            externalSol, sourceRegion, importance);

                        if ~isempty(adaptedSol)
                            % Re-evaluate adapted solution
                            evaluator = obj.localOptimizers{regionID}.evaluator;
                            [adaptedSol.objectives, adaptedSol.violations, ...
                             adaptedSol.constraintViolation] = evaluator.evaluate(adaptedSol);

                            adaptedCount = adaptedCount + 1;
                            adaptedElites(adaptedCount) = adaptedSol;
                            adapted = adapted + 1;
                        else
                            rejected = rejected + 1;
                        end

                    catch ME
                        obj.logError(sprintf('ProcessIntegration_R%d_S%d', regionID, i), ME.message, ME.stack);
                        rejected = rejected + 1;
                    end
                end

                % Enhanced population update
                if adaptedCount > 0
                    adaptedElites = adaptedElites(1:adaptedCount);
                    currentPop = obj.localOptimizers{regionID}.population;
                    popSize = length(currentPop);

                    % Pre-allocate combined array
                    combined = Solution.empty(popSize + adaptedCount, 0);
                    combined(1:popSize) = currentPop(:);
                    combined(popSize+1:popSize+adaptedCount) = adaptedElites(:);

                    obj.localOptimizers{regionID}.population = ...
                        obj.localOptimizers{regionID}.environmentalSelection(combined);
                end

            catch ME
                obj.logError(sprintf('ProcessRegionIntegration_R%d', regionID), ME.message, ME.stack);
                adapted = 0;
                rejected = length(globalElites);  % All rejected
            end
        end

        function importance = computeSolutionImportance(obj, solution)
            % Compute solution importance for selection
            try
                % Multi-criteria importance: convergence + diversity
                hvContribution = obj.computeHVContribution(solution);
                diversityScore = obj.computeSolutionDiversity(solution);

                % Weighted combination
                importance = 0.7 * hvContribution + 0.3 * diversityScore;

            catch ME
                obj.logError('ComputeSolutionImportance', ME.message, ME.stack);
                importance = 1.0;  % Default importance
            end
        end

        function hvContribution = computeHVContribution(obj, solution)
            % Compute hypervolume contribution
            try
                % Simplified HV contribution based on objective values
                objectives = solution.objectives;
                % Lower objectives are better (minimization)
                hvContribution = 1.0 / (1.0 + sum(objectives));
            catch ME
                obj.logError('ComputeHVContribution', ME.message, ME.stack);
                hvContribution = 0.5;  % Default contribution
            end
        end

        function diversityScore = computeSolutionDiversity(obj, solution)
            % Compute solution diversity score
            try
                % Distance to nearest neighbors in global elite set
                if isempty(obj.globalElites)
                    diversityScore = 1.0;
                    return;
                end

                minDist = inf;
                for i = 1:length(obj.globalElites)
                    if ~isequal(obj.globalElites(i), solution)
                        dist = norm(solution.objectives - obj.globalElites(i).objectives);
                        minDist = min(minDist, dist);
                    end
                end

                diversityScore = min(minDist, 1.0);

            catch ME
                obj.logError('ComputeSolutionDiversity', ME.message, ME.stack);
                diversityScore = 0.5;  % Default diversity
            end
        end

        % Enhanced helper methods
        function merged = enhancedMergeAndFilter(obj, solutions, compatThreshold)
            % Enhanced merging with better memory management
            try
                if isempty(solutions)
                    merged = [];
                    return;
                end

                % Step 1: Extract Pareto front
                paretoFront = obj.extractParetoFront(solutions);

                % Step 2: Filter by feasibility
                feasible = obj.extractFeasible(paretoFront);

                % Step 3: Apply diversity-based selection
                maxSize = 50;
                if length(feasible) > maxSize
                    merged = DiversityEnhancer.diversityBasedSelection(feasible, maxSize, 'hybrid');
                else
                    merged = feasible;
                end

            catch ME
                obj.logError('EnhancedMergeAndFilter', ME.message, ME.stack);
                merged = solutions;  % Fallback
            end
        end

        function feasible = extractFeasible(obj, population)
            % Extract feasible solutions with pre-allocation
            n = length(population);
            feasible = Solution.empty(n, 0);
            feasCount = 0;

            for i = 1:n
                if population(i).constraintViolation <= 1e-6
                    feasCount = feasCount + 1;
                    feasible(feasCount) = population(i);
                end
            end

            % Trim to actual size
            feasible = feasible(1:feasCount);
        end

        function obj = evaluateRound(obj, round)
            % Enhanced round evaluation with memory monitoring
            try
                % Pre-allocate for efficiency
                popSize = length(obj.localOptimizers{1}.population);
                allPop = Solution.empty(obj.N * popSize, 0);
                idx = 0;

                for r = 1:obj.N
                    pop = obj.localOptimizers{r}.population;
                    numPop = length(pop);
                    allPop(idx+1:idx+numPop) = pop(:);
                    idx = idx + numPop;
                end

                allPop = allPop(1:idx);

                HV = obj.metrics.computeHypervolume(allPop);
                feasRate = obj.metrics.computeFeasibilityRate(allPop);

                % Enhanced memory tracking
                currentMemory = 0;
                if obj.memoryMonitor
                    currentMemory = obj.getCurrentMemoryUsage();
                end

                % Record enhanced history
                obj.roundHistory(round).round = round;
                obj.roundHistory(round).HV = HV;
                obj.roundHistory(round).feasibilityRate = feasRate;
                obj.roundHistory(round).memoryUsage = currentMemory;
                obj.roundHistory(round).communicationOverhead = obj.totalCommBytes;

                fprintf('  Enhanced Hypervolume: %.4f, Feasibility: %.2f%%, Memory: %.1fMB\n', ...
                    HV, feasRate, currentMemory / 1e6);

            catch ME
                obj.logError(sprintf('EvaluateRound_R%d', round), ME.message, ME.stack);
                rethrow(ME);
            end
        end

        function obj = buildGlobalFront(obj)
            % Enhanced global front construction
            fprintf('\nBuilding Enhanced Global Pareto Front...\n');

            try
                % Pre-allocate with exact sizing
                totalElites = 0;
                for r = 1:obj.N
                    totalElites = totalElites + length(obj.localOptimizers{r}.eliteArchive);
                end

                allSolutions = Solution.empty(totalElites, 0);
                idx = 0;

                for r = 1:obj.N
                    elites = obj.localOptimizers{r}.eliteArchive;
                    numElites = length(elites);
                    allSolutions(idx+1:idx+numElites) = elites(:);
                    idx = idx + numElites;
                end

                allSolutions = allSolutions(1:idx);

                % Enhanced Pareto front extraction
                feasible = obj.extractFeasible(allSolutions);
                if ~isempty(feasible)
                    obj.globalElites = obj.extractParetoFront(feasible);
                else
                    obj.globalElites = allSolutions(1:min(20, length(allSolutions)));
                end

                fprintf('Enhanced Global Pareto Front Size: %d solutions\n', length(obj.globalElites));

            catch ME
                obj.logError('BuildGlobalFront', ME.message, ME.stack);
                obj.globalElites = Solution.empty(0, 0);  % Fallback
            end
        end

        % Enhanced monitoring and error handling methods
        function initializeMemoryMonitor(obj)
            % Initialize memory monitoring
            obj.memoryMonitor = true;
            fprintf('Memory monitoring enabled\n');
        end

        function memoryMB = getCurrentMemoryUsage(obj)
            % Get current memory usage in MB
            try
                if ispc
                    [~, memInfo] = memory;
                    % Return bytes for consistent unit handling across the class
                    memoryMB = memInfo.MemUsedMATLAB; % bytes
                else
                    % Unix/Linux systems
                    memInfo = feature('memstats');
                    if ~isempty(memInfo)
                        memoryMB = memInfo.PhysicalMemory.Available; % bytes (best-effort)
                    else
                        memoryMB = 0;  % Fallback
                    end
                end
            catch
                memoryMB = 0;  % Fallback
            end
        end

        function logMemoryUsage(obj, phase)
            % Log memory usage
            if obj.memoryMonitor
                memoryBytes = obj.getCurrentMemoryUsage();
                memoryMB = memoryBytes / 1e6;
                fprintf('Memory [%s]: %.1f MB\n', phase, memoryMB);
            end
        end

        function logError(obj, component, message, stack)
            % Enhanced error logging
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            errorEntry = struct('timestamp', timestamp, 'component', component, ...
                'message', message, 'stack', stack);

            obj.errorLog{end+1} = errorEntry;

            % Limit error log size
            if length(obj.errorLog) > 100
                obj.errorLog = obj.errorLog(end-49:end);  % Keep last 50 errors
            end

            fprintf('Error [%s]: %s\n', component, message);
        end

        function performMemoryCleanup(obj)
            % Enhanced memory cleanup
            try
                % Safer memory cleanup: yield to event loop and hint GC
                drawnow;
                pause(0.01);
                if usejava('jvm')
                    java.lang.System.gc();
                end
                fprintf('Memory cleanup (GC hint) performed\n');
            catch ME
                obj.logError('MemoryCleanup', ME.message, ME.stack);
            end
        end

        function commBytes = estimateCommunicationOverhead(obj)
            % Enhanced communication overhead estimation
            try
                % Base overhead + encryption overhead
                baseBytes = obj.totalCommBytes;
                encryptionOverhead = baseBytes * 0.1;  % 10% encryption overhead

                commBytes = baseBytes + encryptionOverhead;
            catch
                commBytes = obj.totalCommBytes;  % Fallback
            end
        end

        function printPerformanceAnalysis(obj)
            % Print detailed performance analysis
            fprintf('\n========== Enhanced Performance Analysis ==========\n');

            if isempty(obj.performanceStats)
                fprintf('No performance statistics available\n');
                return;
            end

            % Stage timing analysis
            if isfield(obj.performanceStats, 'stageTimes')
                stageTimes = obj.performanceStats.stageTimes;
                fprintf('\nStage Timing Analysis:\n');
                fprintf('  Local Evolution: %.2f ± %.2f seconds\n', ...
                    mean(stageTimes(1, :)), std(stageTimes(1, :)));
                fprintf('  Cluster Exchange: %.2f ± %.2f seconds\n', ...
                    mean(stageTimes(2, :)), std(stageTimes(2, :)));
                fprintf('  Federated Aggregation: %.2f ± %.2f seconds\n', ...
                    mean(stageTimes(3, :)), std(stageTimes(3, :)));
                fprintf('  Local Integration: %.2f ± %.2f seconds\n', ...
                    mean(stageTimes(4, :)), std(stageTimes(4, :)));

                totalStageTime = sum(mean(stageTimes, 1), 2);
                fprintf('  Total Stage Time: %.2f seconds\n', totalStageTime);
            end

            % Memory usage analysis
            if isfield(obj.performanceStats, 'memoryUsage') && obj.memoryMonitor
                memoryUsage = obj.performanceStats.memoryUsage;
                fprintf('\nMemory Usage Analysis:\n');
                fprintf('  Initial: %.1f MB\n', memoryUsage(1) / 1e6);
                fprintf('  Final: %.1f MB\n', memoryUsage(end) / 1e6);
                fprintf('  Peak: %.1f MB\n', max(memoryUsage) / 1e6);
                fprintf('  Average: %.1f MB\n', mean(memoryUsage) / 1e6);
            end

            % Communication analysis
            if isfield(obj.performanceStats, 'communicationOverhead')
                commOverhead = obj.performanceStats.communicationOverhead;
                fprintf('\nCommunication Analysis:\n');
                fprintf('  Total: %.2f MB\n', sum(commOverhead) / 1e6);
                fprintf('  Average per Round: %.2f MB\n', mean(commOverhead) / 1e6);
                fprintf('  Peak per Round: %.2f MB\n', max(commOverhead) / 1e6);
            end

            fprintf('==========================================\n\n');
        end

        function printErrorSummary(obj)
            % Print error summary
            fprintf('\n========== Error Summary ==========\n');
            fprintf('Total Errors: %d\n', length(obj.errorLog));

            if ~isempty(obj.errorLog)
                % Count errors by component
                components = {};
                for i = 1:length(obj.errorLog)
                    components{end+1} = obj.errorLog(i).component;
                end

                [uniqueComponents, ~, idx] = unique(components);
                counts = histcounts(idx, 1:length(uniqueComponents));

                fprintf('\nErrors by Component:\n');
                for i = 1:length(uniqueComponents)
                    fprintf('  %s: %d\n', uniqueComponents{i}, counts(i));
                end
            end

            fprintf('================================\n\n');
        end

        % Inherited methods (enhanced versions)
        function paretoFront = extractParetoFront(~, population)
            % Enhanced Pareto front extraction
            n = length(population);
            dominated = false(n, 1);

            for i = 1:n
                for j = 1:n
                    if i ~= j && population(j).dominates(population(i))
                        dominated(i) = true;
                        break;
                    end
                end
            end

            paretoFront = population(~dominated);
        end

        function bytes = estimateSolutionSize(obj)
            % Enhanced solution size estimation: prefer serialization of a sample
            try
                sample = [];
                for r = 1:obj.N
                    if ~isempty(obj.localOptimizers{r}.eliteArchive)
                        sample = obj.localOptimizers{r}.eliteArchive(1);
                        break;
                    elseif ~isempty(obj.localOptimizers{r}.population)
                        sample = obj.localOptimizers{r}.population(1);
                        break;
                    end
                end

                if isempty(sample)
                    if obj.N > 0
                        K = obj.regions(1).numDevices;
                        T = length(obj.taskSets{1});
                        bytes = K + T + T*8 + K + 100;
                    else
                        bytes = 1000;
                    end
                    return;
                end

                bs = getByteStreamFromArray(sample);
                bytes = numel(bs);
            catch
                bytes = 1000;  % Fallback
            end
        end

        function printFinalStatistics(obj)
            % Enhanced final statistics
            fprintf('\n========== Enhanced Final Statistics ==========\n');

            % Global performance
            obj.metrics.printMetrics(obj.globalElites, 'Edge-FML Enhanced');

            % Communication overhead
            fprintf('Total Communication: %.2f MB\n', obj.totalCommBytes / 1e6);
            fprintf('Avg Communication per Round: %.2f MB\n', ...
                obj.totalCommBytes / 1e6 / max(obj.R_max, 1));

            % Enhanced convergence analysis
            if ~isempty(obj.roundHistory)
                fprintf('\nEnhanced Convergence Summary:\n');
                fprintf('Initial HV: %.4f\n', obj.roundHistory(1).HV);
                fprintf('Final HV: %.4f\n', obj.roundHistory(end).HV);
                improvement = 100 * (obj.roundHistory(end).HV - obj.roundHistory(1).HV) / ...
                    max(obj.roundHistory(1).HV, eps);
                fprintf('Improvement: %.2f%%\n', improvement);

                % Memory efficiency
                if obj.memoryMonitor && isfield(obj.roundHistory, 'memoryUsage')
                    initialMemory = obj.roundHistory(1).memoryUsage;
                    finalMemory = obj.roundHistory(end).memoryUsage;
                    memoryEfficiency = 100 * (finalMemory - initialMemory) / max(initialMemory, eps);
                    fprintf('Memory Efficiency: %.2f%%\n', memoryEfficiency);
                end
            end

            % Error analysis
            if ~isempty(obj.errorLog)
                fprintf('Total Errors Encountered: %d\n', length(obj.errorLog));
            end

            fprintf('==========================================\n\n');
        end
    end
end