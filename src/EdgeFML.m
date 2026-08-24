classdef EdgeFML
    % EdgeFML - 边缘联邦膜学习主框架
    % 实现算法2：Edge-FML主框架（第3.5节）
    %
    % 主要功能：
    % 1. 三层联邦膜结构：区域层、集群层、联邦层
    % 2. 自适应阈值Shamir秘密共享隐私保护机制
    % 3. 分层通信拓扑与自适应压缩
    % 4. 区域异质性感知的解兼容机制
    %
    % 算法流程：
    % - 阶段1：本地膜进化（Local Membrane Evolution）
    % - 阶段2：集群级知识交换（Cluster-Level Knowledge Exchange）
    % - 阶段3：联邦知识聚合（Federated Knowledge Aggregation）
    % - 阶段4：本地知识集成（Local Knowledge Integration）
    %
    % 作者: 拓守恒 (Shouheng Tuo)
    % GitHub: github.com/shouhengtuo/
    % 邮箱: tuo_sh@xupt.edu.cn
    % 日期: 2025-12-03
    % 参考: FML.MD - 边缘联邦膜学习算法描述

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

        % Adapter statistics
        adapterAcceptedTotal  % Total number of adapted solutions accepted in last integration
        adapterAttemptsTotal  % Total adaptation attempts in last integration
    end

    methods
        function obj = EdgeFML(regions, taskSets, R_max, M_local, optimizerClass)
            % 构造函数：初始化Edge-FML系统
            %
            % 输入参数:
            %   regions - RegionConfig对象数组，表示各个边缘区域
            %   taskSets - 任务集合的cell数组，每个cell对应一个区域
            %   R_max - 最大联邦训练轮数
            %   M_local - 本地进化预算（代数）
            %   optimizerClass - 本地优化器类名（可选，默认为 'MTDMS_CMOEA_Local'）
            %
            % 输出:
            %   obj - EdgeFML对象实例

            % 增强输入验证
            if nargin < 4
                error('EdgeFML:InsufficientInput', '需要至少4个输入参数：regions, taskSets, R_max, M_local');
            end
            if nargin < 5 || isempty(optimizerClass)
                optimizerClass = 'MTDMS_CMOEA_Local';
            end

            % 验证regions参数
            if ~isa(regions, 'RegionConfig') || isempty(regions)
                error('EdgeFML:InvalidRegions', 'regions必须是非空的RegionConfig对象数组');
            end

            % 验证taskSets参数
            if ~iscell(taskSets) || length(taskSets) ~= length(regions)
                error('EdgeFML:InvalidTaskSets', 'taskSets必须是与regions长度相同的cell数组');
            end

            % 验证数值参数
            if R_max <= 0 || M_local <= 0
                error('EdgeFML:InvalidParameters', 'R_max和M_local必须为正数');
            end

            % 初始化基本属性
            obj.regions = regions;
            obj.taskSets = taskSets;
            obj.N = length(regions);
            obj.R_max = R_max;
            obj.M_local = M_local;
            obj.M_elite = 10;  % 共享的精英解数量 (从30降低以防早熟收敛)

            % 初始化核心组件
            try
                obj.clusterManager = ClusterManager(regions);
                obj.sss = ShamirSecretSharing();
                obj.metrics = PerformanceMetrics([1000, 1000, 1000]);
            catch ME
                error('EdgeFML:ComponentInitializationFailed', ...
                    '组件初始化失败: %s', ME.message);
            end

            % 为每个区域初始化本地优化器和适配器
            obj.localOptimizers = cell(1, obj.N);
            obj.adapters = cell(1, obj.N);

            for r = 1:obj.N
                try
                    obj.localOptimizers{r} = feval(optimizerClass, ...
                        regions(r), taskSets{r}, M_local);
                    obj.adapters{r} = SolutionAdapter(regions(r), taskSets{r});
                catch ME
                    error('EdgeFML:LocalOptimizerInitFailed', ...
                        '区域%d的本地优化器初始化失败: %s', r, ME.message);
                end
            end

            % 初始化全局状态
            obj.globalElites = [];
            obj.roundHistory = struct('round', {}, 'HV', {}, 'feasibilityRate', {});
            obj.totalCommBytes = 0;

            % 输出初始化信息
            fprintf('Edge-FML系统初始化完成:\n');
            fprintf('  - 区域数量: %d\n', obj.N);
            fprintf('  - 集群数量: %d\n', obj.clusterManager.M);
            fprintf('  - 最大轮数: %d\n', obj.R_max);
            fprintf('  - 本地进化代数: %d\n', obj.M_local);
            fprintf('  - 精英解数量: %d\n', obj.M_elite);

            obj.clusterManager.printClusterInfo();
        end

        function obj = run(obj)
            % 主联邦训练循环（算法2）
            % 执行完整的Edge-FML训练过程，包括四个主要阶段
            %
            % 算法阶段:
            % 1. 本地膜进化：每个区域独立运行MTDMS-CMOEA-Local
            % 2. 集群级知识交换：集群内区域交换精英解
            % 3. 联邦知识聚合：集群间通过加密聚合知识
            % 4. 本地知识集成：将全局知识集成到本地种群

            fprintf('\n========== 开始Edge-FML联邦训练 ==========\n');
            fprintf('训练轮数: %d, 本地进化代数: %d\n', obj.R_max, obj.M_local);

            % 记录训练开始时间
            trainingStartTime = tic;

            for round = 1:obj.R_max
                fprintf('\n--- 第 %d/%d 轮训练 ---\n', round, obj.R_max);
                roundStartTime = tic;

                try
                    % 阶段1：本地膜进化（算法2第9-13行）
                    fprintf('阶段1: 本地膜进化...\n');
                    obj = obj.localEvolution();

                    % 阶段2：集群级知识交换（算法2第15-25行）
                    fprintf('阶段2: 集群级知识交换...\n');
                    obj = obj.clusterLevelExchange();

                    % 阶段3：联邦知识聚合（算法2第27-31行）
                    fprintf('阶段3: 联邦知识聚合...\n');
                    obj = obj.federatedAggregation(round);

                    % 阶段4：本地知识集成（算法2第33-53行）
                    fprintf('阶段4: 本地知识集成...\n');
                    obj = obj.localIntegration();

                    % 评估并记录性能
                    obj = obj.evaluateRound(round);

                    roundTime = toc(roundStartTime);
                    fprintf('第 %d 轮训练完成，耗时: %.2f 秒\n', round, roundTime);

                catch ME
                    % 错误处理和恢复
                    warning('EdgeFML:RoundError', '第 %d 轮训练发生错误: %s', round, ME.message);
                    obj = obj.handleRoundError(round, ME);
                end
            end

            % 构建最终全局前沿（算法2第55-60行）
            fprintf('\n构建最终全局Pareto前沿...\n');
            obj = obj.buildGlobalFront();

            totalTrainingTime = toc(trainingStartTime);
            fprintf('\n========== Edge-FML训练完成 ==========\n');
            fprintf('总训练时间: %.2f 秒\n', totalTrainingTime);
            fprintf('平均每轮时间: %.2f 秒\n', totalTrainingTime / obj.R_max);

            obj.printFinalStatistics();
        end

        function obj = localEvolution(obj)
            % Stage 1: Local membrane evolution for each region
            fprintf('Stage 1: Local Evolution...\n');

            for r = 1:obj.N
                obj.localOptimizers{r} = obj.localOptimizers{r}.evolve();
            end
        end

        function obj = clusterLevelExchange(obj)
            % Stage 2: Cluster-level knowledge exchange
            fprintf('Stage 2: Cluster-Level Exchange...\n');

            M = obj.clusterManager.M;
            clusterElites = cell(1, M);
            clusterViolations = cell(1, M);

            % Intra-cluster exchange (Lines 16-18)
            for m = 1:M
                members = obj.clusterManager.getClusterMembers(m);

                % FIXED: Pre-allocate memory to avoid incremental growth
                numMembers = length(members);
                allElites = Solution.empty(numMembers * obj.M_elite, 0);
                allViolations = zeros(numMembers, 4);
                eliteCount = 0;

                for idx = 1:numMembers
                    r = members(idx);
                    elites = obj.localOptimizers{r}.getEliteSolutions(obj.M_elite);

                    % FIXED: Direct indexing instead of array concatenation
                    numElites = length(elites);
                    allElites(eliteCount+1:eliteCount+numElites) = elites(:);

                    % Compute average constraint violations
                    avgViolation = zeros(1, 4);
                    for i = 1:numElites
                        avgViolation = avgViolation + elites(i).violations;
                    end
                    allViolations(idx, :) = avgViolation / max(numElites, 1);
                    eliteCount = eliteCount + numElites;
                end

                % Trim to actual size
                allElites = allElites(1:eliteCount);

                % Broadcast within cluster (no encryption needed)
                for r = members
                    % Each region receives all cluster elites
                    % Communication cost: intra-cluster
                    obj.totalCommBytes = obj.totalCommBytes + ...
                        eliteCount * obj.estimateSolutionSize();
                end

                % Aggregate at representative (Lines 19-21)
                rep = obj.clusterManager.getRepresentative(m);
                % Filter low-violation elites before merging (for improved representativeness)
                % original: clusterElites{m} = obj.mergeAndFilter(allElites, 0.6);
                if ~isempty(allElites)
                    CVs = [allElites.constraintViolation];
                    thresh = 0.05;
                    mask = CVs <= thresh;
                    filteredElites = allElites(mask);
                    if isempty(filteredElites)
                        filteredElites = allElites;
                    end
                    % Diversity preselection before merge (uniform-like sampling)
                    % original: directly mergeAndFilter(filteredElites, 0.6)
                    preSize = min(50, length(filteredElites));
                    try
                        diversePre = DiversityEnhancer.diversityBasedSelection(filteredElites, preSize, 'hybrid');
                    catch
                        diversePre = filteredElites;
                    end
                    clusterElites{m} = obj.mergeAndFilter(diversePre, 0.6);
                else
                    clusterElites{m} = allElites;
                end
                clusterViolations{m} = mean(allViolations, 1);
            end

            % FIXED: Only store current round data (clear previous)
            obj.clusterElites = clusterElites;
            obj.clusterViolations = clusterViolations;
        end

        function obj = federatedAggregation(obj, round)
            % Stage 3: Federated knowledge aggregation (encrypted)
            fprintf('Stage 3: Federated Aggregation...\n');

            M = obj.clusterManager.M;

            % Collect encrypted knowledge from cluster representatives
            % (Lines 27-29)
            globalViolation = zeros(1, 4);

            % FIXED: Pre-allocate to avoid incremental array growth
            totalElites = 0;
            for m = 1:M
                totalElites = totalElites + length(obj.clusterElites{m});
            end
            allClusterElites = Solution.empty(totalElites, 0);
            eliteIdx = 0;

            for m = 1:M
                % Aggregate violations with adaptive threshold (round-based decay)
                v = obj.clusterViolations{m};
                % original: theta_agg = 0.1
                % baseThreshold = 0.1; % original decayRate = 0.95
                baseThreshold = 0.05;
                decayRate = 0.99;    % adjusted to extend mid-to-late exploration
                theta_agg = baseThreshold * (decayRate ^ (round - 1));

                % Only broadcast significant violations (Line 23)
                v_agg = v;
                v_agg(abs(v) <= theta_agg) = 0;

                globalViolation = globalViolation + v_agg;

                % FIXED: Direct indexing instead of concatenation
                clusterElites_m = obj.clusterElites{m}(:);
                numElites = length(clusterElites_m);
                allClusterElites(eliteIdx+1:eliteIdx+numElites) = clusterElites_m;
                eliteIdx = eliteIdx + numElites;

                % Communication cost: inter-cluster (encrypted with AT-SSS)
                % Encryption overhead factor: ~2x
                obj.totalCommBytes = obj.totalCommBytes + ...
                    numElites * obj.estimateSolutionSize() * 2;
            end

            % Aggregate constraint patterns (Line 29)
            globalViolation = globalViolation / M;

            % Select global elites by HV contribution (Line 30)
            % FIXED: Limit to prevent memory explosion
            maxGlobalElites = min(obj.M_elite, 20);
            obj.globalElites = obj.mergeAndFilter(allClusterElites, 0.8);
            obj.globalElites = obj.selectTopByHV(obj.globalElites, maxGlobalElites);

            fprintf('  Global elites: %d solutions\n', length(obj.globalElites));
        end

        function obj = localIntegration(obj)
            % Stage 4: Local knowledge integration with compatibility enhancement
            fprintf('Stage 4: Local Integration...\n');

            totalAdapted = 0;
            totalRejected = 0;

            % FIXED: Pre-check to avoid unnecessary processing
            if isempty(obj.globalElites)
                fprintf('  No global elites to integrate\n');
                return;
            end

            % FIXED: Limit global elites to reasonable size
            maxElitesToIntegrate = min(length(obj.globalElites), 20);
            numElitesToProcess = maxElitesToIntegrate;

            for r = 1:obj.N
                % Receive global knowledge from cluster representative
                clusterID = obj.clusterManager.getClusterID(r);

                % FIXED: Pre-allocate adapted elites array
                adaptedElites = Solution.empty(numElitesToProcess, 0);
                adaptedCount = 0;

                % FIXED: Process limited number of elites
                for i = 1:numElitesToProcess
                    externalSol = obj.globalElites(i);

                    % Determine source region (simplified: use first region)
                    sourceRegionID = 1;
                    sourceRegion = obj.regions(sourceRegionID);

                    % Compute importance score (simplified)
                    importance = 1.0;

                    % Adapt solution (Lines 40-42)
                    adaptedSol = obj.adapters{r}.adaptSolution(...
                        externalSol, sourceRegion, importance);

                    if ~isempty(adaptedSol)
                        % Re-evaluate adapted solution
                        evaluator = obj.localOptimizers{r}.evaluator;
                        [adaptedSol.objectives, adaptedSol.violations, ...
                         adaptedSol.constraintViolation] = evaluator.evaluate(adaptedSol);

                        % FIXED: Direct indexing instead of concatenation
                        adaptedCount = adaptedCount + 1;
                        adaptedElites(adaptedCount) = adaptedSol;
                        totalAdapted = totalAdapted + 1;
                    else
                        totalRejected = totalRejected + 1;
                    end
                end

                % Trim and merge with local population (Lines 49)
                if adaptedCount > 0
                    adaptedElites = adaptedElites(1:adaptedCount);
                    currentPop = obj.localOptimizers{r}.population;
                    popSize = length(currentPop);

                    % FIXED: Pre-allocate combined array with exact sizes
                    combined = Solution.empty(popSize + adaptedCount, 0);

                    % Ensure column vectors for proper assignment
                    currentPop = currentPop(:);
                    adaptedElites = adaptedElites(:);

                    combined(1:popSize) = currentPop;
                    combined(popSize+1:popSize+adaptedCount) = adaptedElites;

                    obj.localOptimizers{r}.population = ...
                        obj.localOptimizers{r}.environmentalSelection(combined);
                end
            end

            adaptRate = 100 * totalAdapted / max(totalAdapted + totalRejected, 1);
            fprintf('  Adaptation rate: %.2f%% (%d/%d)\n', ...
                adaptRate, totalAdapted, totalAdapted + totalRejected);

            % Record adapter statistics for reporting
            obj.adapterAcceptedTotal = totalAdapted;
            obj.adapterAttemptsTotal = totalAdapted + totalRejected;
        end

        function obj = evaluateRound(obj, round)
            % Evaluate performance for current round

            % FIXED: Pre-allocate to avoid incremental growth
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

            % Record history
            obj.roundHistory(round).round = round;
            obj.roundHistory(round).HV = HV;
            obj.roundHistory(round).feasibilityRate = feasRate;
            % Persist adapter stats captured in local integration stage
            if ~isempty(obj.adapterAcceptedTotal)
                obj.roundHistory(round).adapterAccepted = obj.adapterAcceptedTotal;
                obj.roundHistory(round).adapterAttempts = obj.adapterAttemptsTotal;
            end

            fprintf('  Hypervolume: %.4f, Feasibility: %.2f%%\n', HV, feasRate);
        end

        function obj = buildGlobalFront(obj)
            % Build final global Pareto front
            % REVERTED: Removed diversity selection to avoid quality loss
            fprintf('\nBuilding global Pareto front...\n');

            % FIXED: Pre-allocate memory
            archiveSize = length(obj.localOptimizers{1}.eliteArchive);
            allSolutions = Solution.empty(obj.N * archiveSize, 0);
            idx = 0;

            for r = 1:obj.N
                elites = obj.localOptimizers{r}.eliteArchive;
                numElites = length(elites);
                allSolutions(idx+1:idx+numElites) = elites(:);
                idx = idx + numElites;
            end
            allSolutions = allSolutions(1:idx);

            % Extract non-dominated feasible solutions
            % FIXED: Pre-allocate feasible array
            feasible = Solution.empty(idx, 0);
            feasCount = 0;
            for i = 1:idx
                if allSolutions(i).constraintViolation <= 1e-6
                    feasCount = feasCount + 1;
                    feasible(feasCount) = allSolutions(i);
                end
            end

            if feasCount > 0
                feasible = feasible(1:feasCount);
                obj.globalElites = obj.extractParetoFront(feasible);
            else
                obj.globalElites = allSolutions;
            end

            fprintf('Global Pareto front size: %d solutions\n', length(obj.globalElites));
        end

        function printFinalStatistics(obj)
            % Print final performance statistics
            fprintf('\n========== Final Statistics ==========\n');

            % Global performance
            obj.metrics.printMetrics(obj.globalElites, 'Edge-FML Global');

            % Communication overhead
            fprintf('Total Communication: %.2f MB\n', obj.totalCommBytes / 1e6);
            fprintf('Avg Communication per Round: %.2f MB\n', ...
                obj.totalCommBytes / 1e6 / obj.R_max);

            % Convergence curve
            if ~isempty(obj.roundHistory)
                fprintf('\nConvergence Summary:\n');
                fprintf('Initial HV: %.4f\n', obj.roundHistory(1).HV);
                fprintf('Final HV: %.4f\n', obj.roundHistory(end).HV);
                fprintf('Improvement: %.2f%%\n', ...
                    100 * (obj.roundHistory(end).HV - obj.roundHistory(1).HV) / ...
                    max(obj.roundHistory(1).HV, eps));
            end

            fprintf('======================================\n\n');
        end

        % Helper methods
        function merged = mergeAndFilter(obj, solutions, compatThreshold)
            % Merge solutions with diversity-preserving filtering
            if isempty(solutions)
                merged = [];
                return;
            end

            % Step 1: Extract Pareto front
            paretoFront = obj.extractParetoFront(solutions);

            % Step 2: Filter by feasibility
            % FIXED: Pre-allocate feasible array
            feasible = Solution.empty(length(paretoFront), 0);
            feasCount = 0;

            for i = 1:length(paretoFront)
                if paretoFront(i).constraintViolation <= 1e-6
                    feasCount = feasCount + 1;
                    feasible(feasCount) = paretoFront(i);
                end
            end

            if feasCount > 0
                feasible = feasible(1:feasCount);
                % Step 3: Apply diversity-based selection if too many solutions
                maxSize = 50;  % Maximum merged size
                if length(feasible) > maxSize
                    merged = DiversityEnhancer.diversityBasedSelection(...
                        feasible, maxSize, 'hybrid');
                else
                    merged = feasible;
                end
            else
                merged = paretoFront;  % Keep infeasible if no feasible
            end
        end

        function selected = selectTopByHV(obj, solutions, M)
            % Select top M solutions by HV contribution (prioritize convergence)
            if isempty(solutions) || length(solutions) <= M
                selected = solutions;
                return;
            end

            % REVERTED: Focus on convergence (HV) over diversity
            % Heterogeneous environments need strong local optimization
            % Compute HV contribution for each solution
            contributions = zeros(length(solutions), 1);
            for i = 1:length(solutions)
                remaining = solutions;
                remaining(i) = [];
                HV_without = obj.metrics.computeHypervolume(remaining);
                HV_with = obj.metrics.computeHypervolume(solutions);
                contributions(i) = HV_with - HV_without;
            end

            % Select top M by HV contribution
            [~, sortIdx] = sort(contributions, 'descend');
            selected = solutions(sortIdx(1:M));
        end

        function paretoFront = extractParetoFront(~, population)
            % Extract non-dominated solutions
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
            % 估算解的字节大小
            % 用于计算通信开销
            %
            % 计算方式:
            % - x_offload: K个布尔值，每个1字节
            % - y_cache: T个布尔值，每个1字节
            % - f_resource: T个双精度浮点数，每个8字节
            % - z_security: K个整数，每个1字节

            if isempty(obj.regions) || isempty(obj.taskSets)
                bytes = 0;
                return;
            end

            K = obj.regions(1).numDevices;
            T = length(obj.taskSets{1});

            % 计算总字节数
            bytes = K + T + T*8 + K;  % x + y + f + z
        end

        function obj = handleRoundError(obj, round, ME)
            % 处理训练轮次中的错误
            % 实现错误恢复机制，确保训练能够继续进行
            %
            % 输入:
            %   round - 发生错误的轮次
            %   ME - 错误信息对象

            fprintf('错误详情:\n');
            fprintf('  错误标识符: %s\n', ME.identifier);
            fprintf('  错误消息: %s\n', ME.message);

            % 根据错误类型采取不同的恢复策略
            switch ME.identifier
                case 'EdgeFML:ComponentInitializationFailed'
                    % 组件初始化失败：严重错误，终止训练
                    error('EdgeFML:CriticalError', '关键组件初始化失败，无法继续训练');

                case 'EdgeFML:LocalOptimizerInitFailed'
                    % 本地优化器初始化失败：跳过该区域
                    fprintf('跳过区域 %d 的训练\n', round);

                case {'MTDMS_CMOEA:EvolutionFailed', 'ClusterManager:ClusteringFailed'}
                    % 进化或聚类失败：使用备用策略
                    fprintf('使用备用策略继续训练\n');
                    obj = obj.fallbackStrategy(round);

                otherwise
                    % 其他错误：记录并继续
                    fprintf('未知错误类型，记录并继续训练\n');
            end

            % 记录错误到历史
            if length(obj.roundHistory) >= round
                obj.roundHistory(round).error = ME.message;
                obj.roundHistory(round).errorTime = datetime('now');
            end
        end

        function obj = fallbackStrategy(obj, round)
            % 备用策略：当主要算法失败时使用的简化策略
            %
            % 策略包括:
            % 1. 简化的本地进化
            % 2. 减少的知识交换
            % 3. 保守的聚合方式

            fprintf('执行备用策略，简化算法复杂度\n');

            try
                % 简化的本地进化：减少进化代数
                for r = 1:obj.N
                    if ~isempty(obj.localOptimizers{r})
                        % 使用较少的代数进行快速进化
                        simplifiedGen = max(10, floor(obj.M_local / 4));
                        obj.localOptimizers{r}.maxGen = simplifiedGen;
                        obj.localOptimizers{r} = obj.localOptimizers{r}.evolve();
                    end
                end

                % 简化的知识交换：只交换最优解
                obj = obj.simplifiedKnowledgeExchange();

            catch fallbackError
                warning('EdgeFML:FallbackFailed', '备用策略也失败了: %s', fallbackError.message);
            end
        end

        function obj = simplifiedKnowledgeExchange(obj)
            % 简化的知识交换策略
            % 只交换每个区域的最优解，减少通信开销

            for r = 1:obj.N
                if ~isempty(obj.localOptimizers{r}) && ~isempty(obj.localOptimizers{r}.eliteArchive)
                    % 只取最优解
                    bestSol = obj.localOptimizers{r}.eliteArchive(1);

                    % 简单广播给其他区域
                    for other_r = 1:obj.N
                        if other_r ~= r && ~isempty(obj.localOptimizers{other_r})
                            % 直接添加到其他区域的种群
                            currentPop = obj.localOptimizers{other_r}.population;
                            if length(currentPop) < obj.localOptimizers{other_r}.popSize
                                obj.localOptimizers{other_r}.population(end+1) = bestSol;
                            end
                        end
                    end
                end
            end
        end

        function validateSystemState(obj)
            % 验证系统状态的一致性
            % 用于调试和确保系统正常运行

            try
                % 检查基本属性
                assert(obj.N > 0, '区域数量必须大于0');
                assert(obj.R_max > 0, '最大轮数必须大于0');
                assert(obj.M_local > 0, '本地进化代数必须大于0');

                % 检查组件初始化
                assert(~isempty(obj.clusterManager), '集群管理器未初始化');
                assert(~isempty(obj.sss), '秘密共享组件未初始化');
                assert(~isempty(obj.metrics), '性能指标组件未初始化');

                % 检查本地优化器
                assert(length(obj.localOptimizers) == obj.N, '本地优化器数量不匹配');
                assert(length(obj.adapters) == obj.N, '适配器数量不匹配');

                % 检查区域配置
                assert(length(obj.regions) == obj.N, '区域配置数量不匹配');
                assert(length(obj.taskSets) == obj.N, '任务集数量不匹配');

                fprintf('系统状态验证通过\n');

            catch validationError
                error('EdgeFML:InvalidSystemState', '系统状态验证失败: %s', validationError.message);
            end
        end

        function saveCheckpoint(obj, filename)
            % 保存训练检查点
            % 用于训练中断后的恢复
            %
            % 输入:
            %   filename - 检查点文件名

            try
                checkpoint = struct();
                checkpoint.roundHistory = obj.roundHistory;
                checkpoint.globalElites = obj.globalElites;
                checkpoint.totalCommBytes = obj.totalCommBytes;
                checkpoint.timestamp = datetime('now');

                % 保存本地优化器状态（简化版本）
                checkpoint.localStates = cell(1, obj.N);
                for r = 1:obj.N
                    if ~isempty(obj.localOptimizers{r})
                        checkpoint.localStates{r} = struct();
                        checkpoint.localStates{r}.population = obj.localOptimizers{r}.population;
                        checkpoint.localStates{r}.eliteArchive = obj.localOptimizers{r}.eliteArchive;
                    end
                end

                % 保存到文件
                save(filename, 'checkpoint', '-v7.3');
                fprintf('检查点已保存到: %s\n', filename);

            catch ME
                warning('EdgeFML:CheckpointFailed', '保存检查点失败: %s', ME.message);
            end
        end

        function obj = loadCheckpoint(obj, filename)
            % 从检查点恢复训练状态
            %
            % 输入:
            %   filename - 检查点文件名

            try
                if ~exist(filename, 'file')
                    warning('EdgeFML:CheckpointNotFound', '检查点文件不存在: %s', filename);
                    return;
                end

                % 加载检查点
                checkpointData = load(filename);
                checkpoint = checkpointData.checkpoint;

                % 恢复状态
                obj.roundHistory = checkpoint.roundHistory;
                obj.globalElites = checkpoint.globalElites;
                obj.totalCommBytes = checkpoint.totalCommBytes;

                % 恢复本地优化器状态
                if isfield(checkpoint, 'localStates')
                    for r = 1:min(length(checkpoint.localStates), obj.N)
                        if ~isempty(checkpoint.localStates{r})
                            obj.localOptimizers{r}.population = checkpoint.localStates{r}.population;
                            obj.localOptimizers{r}.eliteArchive = checkpoint.localStates{r}.eliteArchive;
                        end
                    end
                end

                fprintf('从检查点恢复成功: %s (时间: %s)\n', ...
                    filename, char(checkpoint.timestamp));

            catch ME
                warning('EdgeFML:LoadCheckpointFailed', '加载检查点失败: %s', ME.message);
            end
        end
    end
end
