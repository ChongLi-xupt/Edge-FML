classdef SimulationDataGenerator
    % SimulationDataGenerator - Generate simulation data for Edge-FML
    % Creates heterogeneous edge regions and task sets
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Simulation Data Generation for Edge Computing

    methods(Static)
        function [regions, taskSets] = generateScenario(N, scenarioType, dataset)
            % Generate edge computing scenario
            % N: number of regions
            % scenarioType: 'homogeneous', 'moderate', 'heterogeneous'
            % dataset: optional dataset name to influence task characteristics

            if nargin < 2
                scenarioType = 'moderate';
            end
            if nargin < 3
                dataset = '';
            end

            fprintf('Generating %s scenario with %d regions...\n', scenarioType, N);

            % Set heterogeneity parameters based on scenario type
            switch scenarioType
                case 'homogeneous' %区域参数分布集中，便于算法基线对照
                    F_range = [2.0, 2.5];      % GHz
                    C_range = [50, 80];        % MB
                    K_range = [40, 50];        % devices
                    B_range = [80, 100];       % Mbps
                    delta_range = [15, 25];    % ms
                    R_range = [0.2, 0.4];      % risk level

                case 'moderate'
                    F_range = [1.5, 3.0];
                    C_range = [40, 100];
                    K_range = [30, 60];
                    B_range = [50, 120];
                    delta_range = [10, 40];
                    R_range = [0.1, 0.6];

                case 'heterogeneous' %区域在算力/缓存/带宽/时延等差异较大，用于检验算法的异构适应能力
                    F_range = [1.0, 4.0];
                    C_range = [20, 150];
                    K_range = [20, 100];
                    B_range = [20, 150];
                    delta_range = [10, 100];
                    R_range = [0.1, 0.9];

                otherwise
                    error('Unknown scenario type: %s', scenarioType);
            end

            % Generate regions
            regions = RegionConfig.empty(N, 0);
            for r = 1:N
                F = F_range(1) + (F_range(2) - F_range(1)) * rand;
                C = C_range(1) + (C_range(2) - C_range(1)) * rand;
                K = randi(K_range);
                B = B_range(1) + (B_range(2) - B_range(1)) * rand;
                delta = delta_range(1) + (delta_range(2) - delta_range(1)) * rand;
                R = R_range(1) + (R_range(2) - R_range(1)) * rand;

                regions(r) = RegionConfig(r, F, C, K, B, delta, R);
            end

            % Generate task sets (common across regions)
            % Dataset profile controls task count and magnitude
            dname = lower(dataset);
            if contains(dname, 'small')
                T = 10;
                dataMax = 12;      % MB
                workMin = 0.3e9;   % GigaCycles
                workMax = 3.0e9;
                dlMin = 2.0;       % seconds
                dlMax = 6.0;
            elseif contains(dname, 'large')
                T = 40;
                dataMax = 30;      % MB (keep caching feasible)
                workMin = 0.8e9;
                workMax = 8.0e9;
                dlMin = 1.0;
                dlMax = 8.0;
            elseif contains(dname, 'heterogeneous')
                T = 25;
                dataMax = 22;
                workMin = 0.5e9;
                workMax = 5.5e9;
                dlMin = 1.5;
                dlMax = 9.0;
            else
                T = 20;
                dataMax = 20;
                workMin = 0.5e9;
                workMax = 5.0e9;
                dlMin = 1.5;
                dlMax = 9.0;
            end
            taskSets = cell(1, N);

            for r = 1:N
                tasks = TaskData.empty(T, 0);

                for t = 1:T
                    % FIXED: More realistic task characteristics
                    % Reduced data size to make caching more feasible
                    dataSize = 1 + (dataMax - 1) * rand;  % 1-dataMax MB

                    % Reduced workload to meet deadline constraints
                    workload = workMin + (workMax - workMin) * rand;

                    % FIXED: More relaxed deadlines (dataset-informed)
                    deadline = dlMin + (dlMax - dlMin) * rand;

                    % Security level 1-4
                    secLevel = randi([1, 4]);

                    % Priority 1-5
                    priority = randi([1, 5]);

                    % Access frequency
                    accessFreq = 1 + 99 * rand;

                    tasks(t) = TaskData(t, dataSize, workload, deadline, ...
                        secLevel, priority, accessFreq);
                end

                taskSets{r} = tasks;
            end

            fprintf('Scenario generation completed.\n');
            SimulationDataGenerator.printScenarioStats(regions);
        end

        function printScenarioStats(regions)
            % Print statistics of generated scenario
            N = length(regions);

            F_vals = [regions.computeCapacity];
            C_vals = [regions.cacheCapacity];
            K_vals = [regions.numDevices];
            B_vals = [regions.bandwidth];

            fprintf('\n--- Scenario Statistics ---\n');
            fprintf('Compute Capacity (GHz): %.2f ± %.2f [%.2f, %.2f]\n', ...
                mean(F_vals), std(F_vals), min(F_vals), max(F_vals));
            fprintf('Cache Capacity (MB): %.2f ± %.2f [%.2f, %.2f]\n', ...
                mean(C_vals), std(C_vals), min(C_vals), max(C_vals));
            fprintf('Devices per Region: %.1f ± %.1f [%d, %d]\n', ...
                mean(K_vals), std(K_vals), min(K_vals), max(K_vals));
            fprintf('Bandwidth (Mbps): %.2f ± %.2f [%.2f, %.2f]\n', ...
                mean(B_vals), std(B_vals), min(B_vals), max(B_vals));

            % Compute average heterogeneity
            totalRD = 0;
            count = 0;
            for i = 1:N
                for j = (i+1):N
                    totalRD = totalRD + regions(i).computeDissimilarity(regions(j));
                    count = count + 1;
                end
            end
            avgRD = totalRD / max(count, 1);
            fprintf('Average Region Dissimilarity: %.4f\n', avgRD);
            fprintf('---------------------------\n\n');
        end

        function testSSS()
            % Test Shamir Secret Sharing implementation
            fprintf('\n=== Testing Shamir Secret Sharing ===\n');

            sss = ShamirSecretSharing();

            % Test 1: Simple vector sharing
            fprintf('Test 1: Vector sharing and reconstruction\n');
            secret = [1.5, 2.7, 3.9, 4.1, 5.3];
            n = 5;  % 5 shares
            t = 3;  % threshold 3

            shares = sss.split(secret, n, t);

            % Reconstruct with exactly t shares
            indices = [1, 3, 5];
            reconstructed = sss.reconstruct(shares(indices, :), indices);

            error = max(abs(secret - reconstructed));
            fprintf('  Original: '); fprintf('%.4f ', secret); fprintf('\n');
            fprintf('  Reconstructed: '); fprintf('%.4f ', reconstructed); fprintf('\n');
            fprintf('  Max error: %.6f\n', error);

            if error < 1e-3
                fprintf('  ✓ Test 1 PASSED\n');
            else
                fprintf('  ✗ Test 1 FAILED\n');
            end

            % Test 2: Solution encryption/decryption
            fprintf('\nTest 2: Solution encryption and decryption\n');
            K = 10; T = 5;
            sol = Solution(K, T);
            sol.x_offload = randi([0, 1], K, 1);
            sol.y_cache = randi([0, 1], T, 1);
            sol.f_resource = rand(T, 1);
            sol.z_security = randi([1, 4], K, 1);

            % Encrypt
            encShares = sss.encryptSolution(sol, n, t);

            % Decrypt
            decSol = sss.decryptSolution(encShares, indices, K, T);

            % Compare
            errorX = sum(abs(sol.x_offload - decSol.x_offload));
            errorY = sum(abs(sol.y_cache - decSol.y_cache));
            errorF = max(abs(sol.f_resource - decSol.f_resource));
            errorZ = sum(abs(sol.z_security - decSol.z_security));

            fprintf('  Errors - x: %d, y: %d, f: %.4f, z: %d\n', ...
                errorX, errorY, errorF, errorZ);

            if errorX == 0 && errorY == 0 && errorF < 1e-3 && errorZ == 0
                fprintf('  ✓ Test 2 PASSED\n');
            else
                fprintf('  ✗ Test 2 FAILED\n');
            end

            fprintf('=====================================\n\n');
        end

        function testLocalOptimizer()
            % Test local optimizer
            fprintf('\n=== Testing Local Optimizer ===\n');

            % Generate small scenario
            region = RegionConfig(1, 2.0, 60, 30, 80, 20, 0.3);

            tasks = TaskData.empty(10, 0);
            for t = 1:10
                tasks(t) = TaskData(t, 5+10*rand, 2e9*rand, 1+2*rand, ...
                    randi([1,3]), randi([1,5]), 10*rand);
            end

            % Create optimizer
            optimizer = MTDMS_CMOEA_Local(region, tasks, 50);

            fprintf('Initial population size: %d\n', length(optimizer.population));
            fprintf('Initial elite archive size: %d\n', length(optimizer.eliteArchive));

            % Run evolution
            fprintf('Running evolution for 50 generations...\n');
            tic;
            optimizer = optimizer.evolve();
            elapsedTime = toc;

            fprintf('Evolution completed in %.2f seconds\n', elapsedTime);
            fprintf('Final elite archive size: %d\n', length(optimizer.eliteArchive));

            % Evaluate performance
            metrics = PerformanceMetrics([500, 500, 500]);
            metrics.printMetrics(optimizer.eliteArchive, 'Local Optimizer');

            fprintf('===============================\n\n');
        end

        function testClustering()
            % Test clustering algorithm
            fprintf('\n=== Testing Clustering Algorithm ===\n');

            % Generate heterogeneous regions
            [regions, ~] = SimulationDataGenerator.generateScenario(15, 'heterogeneous');

            % Create cluster manager
            clusterMgr = ClusterManager(regions);

            % Print results
            clusterMgr.printClusterInfo();

            fprintf('====================================\n\n');
        end

        function testSolutionAdapter()
            % Test solution adaptation
            fprintf('\n=== Testing Solution Adapter ===\n');

            % Create two different regions
            sourceRegion = RegionConfig(1, 2.0, 60, 40, 80, 20, 0.3);
            targetRegion = RegionConfig(2, 3.5, 100, 50, 120, 15, 0.2);

            % Create task sets
            T = 10;
            sourceTasks = TaskData.empty(T, 0);
            targetTasks = TaskData.empty(T, 0);

            for t = 1:T
                sourceTasks(t) = TaskData(t, 5+10*rand, 2e9*rand, 1+2*rand, ...
                    randi([1,3]), randi([1,5]), 10*rand);
                targetTasks(t) = TaskData(t, 5+10*rand, 2e9*rand, 1+2*rand, ...
                    randi([1,3]), randi([1,5]), 10*rand);
            end

            % Create a solution in source region
            K_source = sourceRegion.numDevices;
            sourceSol = Solution(K_source, T);
            sourceSol.x_offload = (rand(K_source, 1) > 0.5);
            sourceSol.y_cache = (rand(T, 1) > 0.7);
            sourceSol.f_resource = 0.3 + 0.5 * rand(T, 1);
            sourceSol.z_security = randi([1, 4], K_source, 1);

            % Evaluate in source region
            sourceEval = ObjectiveEvaluator(sourceRegion, sourceTasks);
            [sourceSol.objectives, sourceSol.violations, sourceSol.constraintViolation] = ...
                sourceEval.evaluate(sourceSol);

            fprintf('Source solution CV: %.4f\n', sourceSol.constraintViolation);

            % Adapt to target region
            adapter = SolutionAdapter(targetRegion, targetTasks);
            adaptedSol = adapter.adaptSolution(sourceSol, sourceRegion, 1.0);

            if ~isempty(adaptedSol)
                fprintf('Adaptation successful!\n');
                fprintf('Adapted solution CV: %.4f\n', adaptedSol.constraintViolation);
                fprintf('Compatibility score: %.4f\n', ...
                    adapter.computeCompatibility(adaptedSol, ...
                    sourceRegion.computeDissimilarity(targetRegion), 1.0));
            else
                fprintf('Adaptation rejected (low compatibility)\n');
            end

            fprintf('================================\n\n');
        end
    end
end
