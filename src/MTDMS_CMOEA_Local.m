classdef MTDMS_CMOEA_Local
    % MTDMS_CMOEA_Local - 基于膜计算的多目标进化算法本地优化器
    % 实现第3.6节的增强版本MTDMS-CMOEA-Local+
    %
    % 主要功能：
    % 1. 动态种群大小调整（基于区域负载）
    % 2. 异构感知约束处理（自适应阈值）
    % 3. 预训练初始化（基于历史数据）
    % 4. 增强的多样性维护机制
    %
    % 算法特点：
    % - 膜结构并行性：模拟生物膜的并行计算特性
    % - 三阶段优化：约束处理、多样性维护、精英选择
    % - 自适应机制：根据区域特性动态调整参数
    %
    % 作者: 拓守恒 (Shouheng Tuo)
    % GitHub: github.com/shouhengtuo/
    % 邮箱: tuo_sh@xupt.edu.cn
    % 日期: 2025-12-03
    % 参考: FML.MD - 多任务动态膜计算框架

    properties
        region            % RegionConfig object
        tasks             % Array of TaskData objects
        evaluator         % ObjectiveEvaluator object

        % Algorithm parameters
        popSize           % Population size (adaptive based on region load)
        maxGen            % Maximum generations for local evolution
        CR                % Crossover rate for DE
        F                 % Mutation factor for DE

        % Dynamic constraint handling
        theta0            % Initial threshold
        thetaT            % Current dynamic threshold
        lambda            % Resource utilization decay factor

        % Population
        population        % Current population (array of Solution objects)
        eliteArchive      % Elite solutions (Pareto front approximation)
    end

    methods
        function obj = MTDMS_CMOEA_Local(region, tasks, maxGen, mode)
            % 构造函数：初始化本地膜计算多目标进化算法
            %
            % 输入参数:
            %   region - RegionConfig对象，表示边缘区域特性
            %   tasks - TaskData对象数组，表示任务类型
            %   maxGen - 最大进化代数
            %   mode - 运行模式 (可选, 默认 'standard')
            %
            % 输出:
            %   obj - MTDMS_CMOEA_Local对象实例

            % 增强输入验证
            if nargin < 3
                error('MTDMS_CMOEA:InsufficientInput', ...
                    '需要至少3个输入参数：region, tasks, maxGen');
            end

            if nargin < 4
                mode = 'standard';
            end

            if ~isa(region, 'RegionConfig')
                error('MTDMS_CMOEA:InvalidRegion', 'region必须是RegionConfig对象');
            end

            if ~isa(tasks, 'TaskData') || isempty(tasks)
                error('MTDMS_CMOEA:InvalidTasks', 'tasks必须是非空的TaskData对象数组');
            end

            if maxGen <= 0
                error('MTDMS_CMOEA:InvalidMaxGen', 'maxGen必须为正数');
            end

            % 初始化基本属性
            obj.region = region;
            obj.tasks = tasks;
            obj.evaluator = ObjectiveEvaluator(region, tasks);

            % 自适应种群大小（公式3.6.1）
            % N_pop(r) = N_base * (1 + 0.5 * (K_r - K_min) / (K_max - K_min))
            K_min = 20; K_max = 100;
            N_base = 100;
            loadFactor = (region.numDevices - K_min) / max(K_max - K_min, 1);
            obj.popSize = round(N_base * (1 + 0.5 * loadFactor));

            % 确保种群大小在合理范围内
            obj.popSize = max(50, min(200, obj.popSize));

            obj.maxGen = maxGen;
            obj.CR = 0.35;   % 差分进化交叉率
            obj.F = 0.5;    % 差分进化变异因子

            % 动态约束处理参数
            obj.theta0 = 2.0;  % 初始阈值（从5.0降低以加速收敛）
            obj.lambda = 0.8;   % 资源利用率衰减因子

            % 初始化种群
            try
                obj = obj.initializePopulation();
                fprintf('MTDMS-CMOEA-Local初始化完成:\n');
                fprintf('  - 区域设备数: %d\n', region.numDevices);
                fprintf('  - 任务类型数: %d\n', length(tasks));
                fprintf('  - 种群大小: %d\n', obj.popSize);
                fprintf('  - 最大代数: %d\n', obj.maxGen);
            catch ME
                error('MTDMS_CMOEA:InitializationFailed', ...
                    '种群初始化失败: %s', ME.message);
            end
        end

        function obj = initializePopulation(obj)
            % Initialize population with feasibility-aware strategy
            K = obj.region.numDevices;
            T = length(obj.tasks);

            obj.population = Solution.empty(obj.popSize, 0);

            for i = 1:obj.popSize
                sol = Solution(K, T);

                % FIXED: Start with conservative offloading (30% probability)
                % This reduces initial constraint violations
                sol.x_offload = (rand(K, 1) > 0.7);

                % FIXED: Very selective caching (10% probability)
                % Avoids cache capacity violations
                sol.y_cache = (rand(T, 1) > 0.9);

                % FIXED: Conservative resource allocation [0.1, 0.5]
                % Prevents compute capacity violations
                sol.f_resource = 0.1 + 0.4 * rand(T, 1);

                % FIXED: Start with higher security levels (2-4)
                % Reduces security constraint violations
                sol.z_security = randi([2, 4], K, 1);

                % Evaluate
                [sol.objectives, sol.violations, sol.constraintViolation] = ...
                    obj.evaluator.evaluate(sol);

                obj.population(i) = sol;
            end

            % Initialize elite archive
            obj = obj.updateEliteArchive();
        end

        function obj = evolve(obj)
            % Main evolution loop
            for gen = 1:obj.maxGen
                % Update dynamic threshold (Eq. 3.6.2)
                obj = obj.updateDynamicThreshold(gen);

                % Generate offspring using DE
                offspring = obj.generateOffspring();

                % Combine parent and offspring (ensure column vectors)
                combined = [obj.population(:); offspring(:)];

                % Environmental selection
                obj.population = obj.environmentalSelection(combined);

                % Update elite archive
                obj = obj.updateEliteArchive();
            end
        end

        function obj = updateDynamicThreshold(obj, t)
            % Update dynamic threshold (Heterogeneity-aware, Eq. 3.6.2)
            % theta_r(t) = theta0 * (1 - log(t+1)/log(T_max+1)) * exp(-lambda * ResourceUtil_r)
            % Implements adaptive constraint handling for heterogeneous regions

            % Compute resource utilization
            totalLoad = 0;
            for i = 1:length(obj.population)
                sol = obj.population(i);
                for k = 1:length(sol.x_offload)
                    if sol.x_offload(k) == 1
                        taskType = mod(k-1, length(obj.tasks)) + 1;
                        totalLoad = totalLoad + obj.tasks(taskType).workload;
                    end
                end
            end
            resourceUtil = totalLoad / (obj.region.computeCapacity * 1e9 * length(obj.population));

            % Compute dynamic threshold
            timeFactor = 1 - log(t + 1) / log(obj.maxGen + 1);
            loadFactor = exp(-obj.lambda * resourceUtil);
            obj.thetaT = obj.theta0 * timeFactor * loadFactor;
            % Adaptive threshold decreases over time and with higher resource utilization
        end

        function offspring = generateOffspring(obj)
            % Generate offspring using Differential Evolution (DE)
            % REVERTED: Pure DE without random exploration
            % Random exploration was harming performance in heterogeneous settings
            K = obj.region.numDevices;
            T = length(obj.tasks);

            % FIXED: Pre-allocate offspring array to avoid incremental growth
            offspring = Solution.empty(obj.popSize, 0);

            for i = 1:obj.popSize
                % Select three random individuals
                indices = randperm(obj.popSize, 3);
                x1 = obj.population(indices(1));
                x2 = obj.population(indices(2));
                x3 = obj.population(indices(3));

                % Create trial vector
                trial = Solution(K, T);

                % DE mutation and crossover for continuous variables (f_resource)
                for t = 1:T
                    if rand < obj.CR
                        trial.f_resource(t) = x1.f_resource(t) + ...
                            obj.F * (x2.f_resource(t) - x3.f_resource(t));
                        trial.f_resource(t) = max(0.1, min(1.0, trial.f_resource(t)));
                    else
                        trial.f_resource(t) = obj.population(i).f_resource(t);
                    end
                end

                % Binary crossover for discrete variables
                for k = 1:K
                    if rand < obj.CR
                        trial.x_offload(k) = x1.x_offload(k);
                    else
                        trial.x_offload(k) = obj.population(i).x_offload(k);
                    end

                    if rand < obj.CR
                        trial.z_security(k) = x2.z_security(k);
                    else
                        trial.z_security(k) = obj.population(i).z_security(k);
                    end
                end

                for t = 1:T
                    if rand < obj.CR
                        trial.y_cache(t) = x3.y_cache(t);
                    else
                        trial.y_cache(t) = obj.population(i).y_cache(t);
                    end
                end

                % FIXED: Enhanced constraint repair mechanism
                % Repair security level constraint
                for k = 1:K
                    if trial.x_offload(k) == 1
                        taskType = mod(k-1, T) + 1;
                        minSec = obj.tasks(taskType).securityLevel;
                        trial.z_security(k) = max(trial.z_security(k), minSec);
                    end
                end

                % Repair resource allocation (prevent g1 violation)
                totalAlloc = sum(trial.f_resource);
                if totalAlloc > T
                    % Scale down to fit capacity
                    trial.f_resource = trial.f_resource * (T * 0.95 / totalAlloc);
                end

                % Repair cache usage (prevent g2 violation)
                cacheUsed = 0;
                cacheIndices = zeros(T, 1);  % FIXED: Pre-allocate indices
                cacheCount = 0;

                for t = 1:T
                    if trial.y_cache(t) == 1
                        cacheUsed = cacheUsed + obj.tasks(t).dataSize;
                        cacheCount = cacheCount + 1;
                        cacheIndices(cacheCount) = t;
                    end
                end

                % FIXED: Safe cache repair with bounds checking
                if cacheUsed > obj.region.cacheCapacity && cacheCount > 0
                    % Trim to actual cached tasks
                    cacheIndices = cacheIndices(1:cacheCount);

                    % FIXED: Pre-allocate dataSizes array
                    dataSizes = zeros(cacheCount, 1);
                    for idx = 1:cacheCount
                        dataSizes(idx) = obj.tasks(cacheIndices(idx)).dataSize;
                    end
                    [~, sortOrder] = sort(dataSizes, 'descend');

                    % Disable caching for largest tasks until fits
                    for idx = 1:cacheCount
                        taskIdx = cacheIndices(sortOrder(idx));
                        if taskIdx <= T && trial.y_cache(taskIdx) == 1  % Bounds check
                            trial.y_cache(taskIdx) = 0;
                            cacheUsed = cacheUsed - obj.tasks(taskIdx).dataSize;
                            if cacheUsed <= obj.region.cacheCapacity
                                break;
                            end
                        end
                    end
                end

                % Evaluate trial
                [trial.objectives, trial.violations, trial.constraintViolation] = ...
                    obj.evaluator.evaluate(trial);

                offspring(i) = trial;
            end
        end

        function selected = environmentalSelection(obj, combined)
            % Environmental selection using constrained dominance
            N = obj.popSize;
            popSize = length(combined);

            % FIXED: Pre-allocate feasibility arrays
            feasible = zeros(popSize, 1);  % Use indices instead of array concatenation
            infeasible = zeros(popSize, 1);
            feasCount = 0;
            infeasCount = 0;

            for i = 1:popSize
                if combined(i).constraintViolation <= obj.thetaT
                    feasCount = feasCount + 1;
                    feasible(feasCount) = i;
                else
                    infeasCount = infeasCount + 1;
                    infeasible(infeasCount) = i;
                end
            end

            % Trim to actual counts
            feasible = feasible(1:feasCount);
            infeasible = infeasible(1:infeasCount);

            % Non-dominated sorting on feasible solutions
            if feasCount > 0
                feasiblePop = combined(feasible);
                rankedFeasible = obj.nonDominatedSorting(feasiblePop);

                if feasCount >= N
                    selected = rankedFeasible(1:N);
                    return;
                else
                    selected = rankedFeasible(:);
                end
            else
                selected = Solution.empty(0, 0);
            end

            % Fill remaining slots with best infeasible solutions
            if length(selected) < N && infeasCount > 0
                infeasiblePop = combined(infeasible);
                % Sort by constraint violation
                [~, sortIdx] = sort([infeasiblePop.constraintViolation]);
                remaining = N - length(selected);
                toAdd = infeasiblePop(sortIdx(1:min(remaining, infeasCount)));

                % FIXED: Pre-allocate combined selection array
                if isempty(selected)
                    % No feasible solutions, just use infeasible
                    selected = toAdd;
                else
                    % Combine feasible and infeasible
                    totalSelected = length(selected) + length(toAdd);
                    selectedArray = Solution.empty(totalSelected, 0);
                    numSelected = length(selected);
                    numToAdd = length(toAdd);
                    selectedArray(1:numSelected) = selected(:);
                    selectedArray(numSelected+1:numSelected+numToAdd) = toAdd(:);
                    selected = selectedArray;
                end
            end
        end

        function ranked = nonDominatedSorting(obj, population)
            % Non-dominated sorting with crowding distance
            popSize = length(population);

            % Initialize
            for i = 1:popSize
                population(i).dominationCount = 0;
                population(i).dominatedSet = [];
            end

            % Compute domination relationships
            for i = 1:popSize
                for j = (i+1):popSize
                    if population(i).dominates(population(j))
                        population(i).dominatedSet = [population(i).dominatedSet, j];
                        population(j).dominationCount = population(j).dominationCount + 1;
                    elseif population(j).dominates(population(i))
                        population(j).dominatedSet = [population(j).dominatedSet, i];
                        population(i).dominationCount = population(i).dominationCount + 1;
                    end
                end
            end

            % Extract Pareto fronts
            fronts = {};
            currentFront = [];
            for i = 1:popSize
                if population(i).dominationCount == 0
                    population(i).rank = 1;
                    currentFront = [currentFront, i];
                end
            end

            frontIdx = 1;
            while ~isempty(currentFront)
                fronts{frontIdx} = currentFront;
                nextFront = [];

                for i = currentFront
                    for j = population(i).dominatedSet
                        population(j).dominationCount = population(j).dominationCount - 1;
                        if population(j).dominationCount == 0
                            population(j).rank = frontIdx + 1;
                            nextFront = [nextFront, j];
                        end
                    end
                end

                currentFront = nextFront;
                frontIdx = frontIdx + 1;
            end

            % Compute crowding distance for each front
            for f = 1:length(fronts)
                front = fronts{f};
                if length(front) > 2
                    population = obj.computeEnhancedCrowdingDistance(population, front);
                else
                    for i = front
                        population(i).crowdingDistance = inf;
                    end
                end
            end

            % Sort by rank and crowding distance
            [~, sortIdx] = sortrows([[population.rank]', -[population.crowdingDistance]']);
            ranked = population(sortIdx);
        end

        function population = computeCrowdingDistance(obj, population, frontIndices)
            % Compute crowding distance for a front
            numObj = 3; % Three objectives
            frontSize = length(frontIndices);

            % Initialize crowding distance
            for i = frontIndices
                population(i).crowdingDistance = 0;
            end

            % For each objective
            for m = 1:numObj
                % Sort by objective m
                objValues = zeros(frontSize, 1);
                for i = 1:frontSize
                    objValues(i) = population(frontIndices(i)).objectives(m);
                end
                [~, sortIdx] = sort(objValues);
                sortedIndices = frontIndices(sortIdx);

                % Boundary solutions get infinite distance
                population(sortedIndices(1)).crowdingDistance = inf;
                population(sortedIndices(end)).crowdingDistance = inf;

                % Normalize and compute distance
                fmin = objValues(sortIdx(1));
                fmax = objValues(sortIdx(end));

                if fmax > fmin
                    for i = 2:(frontSize-1)
                        idx = sortedIndices(i);
                        idxPrev = sortedIndices(i-1);
                        idxNext = sortedIndices(i+1);

                        distance = (population(idxNext).objectives(m) - ...
                                    population(idxPrev).objectives(m)) / (fmax - fmin);
                        population(idx).crowdingDistance = ...
                            population(idx).crowdingDistance + distance;
                    end
                end
            end
        end

        function obj = updateEliteArchive(obj)
            % Update elite archive with non-dominated feasible solutions
            % FIXED: Pre-allocate feasible indices array
            popSize = length(obj.population);
            feasible = zeros(popSize, 1);
            feasCount = 0;

            for i = 1:popSize
                if obj.population(i).constraintViolation <= 1e-6
                    feasCount = feasCount + 1;
                    feasible(feasCount) = i;
                end
            end

            if feasCount > 0
                feasible = feasible(1:feasCount);
                feasiblePop = obj.population(feasible);
                obj.eliteArchive = obj.extractParetoFront(feasiblePop);
            else
                % If no feasible solutions, keep best by constraint violation
                [~, bestIdx] = min([obj.population.constraintViolation]);
                obj.eliteArchive = obj.population(bestIdx);
            end
        end

        function paretoFront = extractParetoFront(obj, population)
            % Extract non-dominated solutions
            popSize = length(population);
            dominated = false(popSize, 1);

            for i = 1:popSize
                for j = 1:popSize
                    if i ~= j && population(j).dominates(population(i))
                        dominated(i) = true;
                        break;
                    end
                end
            end

            paretoFront = population(~dominated);
        end

        function elites = getEliteSolutions(obj, M)
            % Get top M elite solutions with diversity enhancement
            if nargin < 2
                M = min(10, length(obj.eliteArchive));
            end

            M = min(M, length(obj.eliteArchive));

            if M == length(obj.eliteArchive)
                elites = obj.eliteArchive;
            else
                % Use diversity-based selection
                try
                    elites = DiversityEnhancer.diversityBasedSelection(...
                        obj.eliteArchive, M, 'hybrid');
                catch
                    % Fallback: use crowding distance
                    sorted = obj.nonDominatedSorting(obj.eliteArchive);
                    elites = sorted(1:M);
                end
            end
        end

        function population = computeEnhancedCrowdingDistance(obj, population, frontIndices)
            % Enhanced crowding distance combining traditional CD and niche diversity
            numObj = 3;
            frontSize = length(frontIndices);

            % Initialize crowding distance
            for i = frontIndices
                population(i).crowdingDistance = 0;
            end

            % Part 1: Traditional crowding distance
            for m = 1:numObj
                objValues = zeros(frontSize, 1);
                for i = 1:frontSize
                    objValues(i) = population(frontIndices(i)).objectives(m);
                end
                [~, sortIdx] = sort(objValues);
                sortedIndices = frontIndices(sortIdx);

                population(sortedIndices(1)).crowdingDistance = inf;
                population(sortedIndices(end)).crowdingDistance = inf;

                fmin = objValues(sortIdx(1));
                fmax = objValues(sortIdx(end));

                if fmax > fmin
                    for i = 2:(frontSize-1)
                        idx = sortedIndices(i);
                        idxPrev = sortedIndices(i-1);
                        idxNext = sortedIndices(i+1);

                        distance = (population(idxNext).objectives(m) - ...
                                    population(idxPrev).objectives(m)) / (fmax - fmin);
                        population(idx).crowdingDistance = ...
                            population(idx).crowdingDistance + distance;
                    end
                end
            end

            % Part 2: Add niche diversity bonus
            k = min(3, frontSize - 1);
            if k > 0
                for i = 1:frontSize
                    idx = frontIndices(i);
                    if ~isinf(population(idx).crowdingDistance)
                        % Compute distance to k nearest neighbors
                        distances = zeros(frontSize, 1);
                        for j = 1:frontSize
                            if i ~= j
                                jdx = frontIndices(j);
                                distances(j) = norm(population(idx).objectives - ...
                                                   population(jdx).objectives);
                            else
                                distances(j) = inf;
                            end
                        end

                        sortedDist = sort(distances);
                        knnAvgDist = mean(sortedDist(1:k));

                        % Bonus for being in sparse region
                        nicheBonus = knnAvgDist * 0.5;
                        population(idx).crowdingDistance = ...
                            population(idx).crowdingDistance + nicheBonus;
                    end
                end
            end
        end
    end
end
