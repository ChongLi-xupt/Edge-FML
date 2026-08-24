% PAR_MTDMS_CMOEA 类 - 实现了用于边缘计算环境的并行多目标优化算法
% 该算法结合了约束处理技术和膜计算思想，用于解决延迟、能耗和安全风险的多目标优化问题
classdef PAR_MTDMS_CMOEA < handle
    properties
        region              % 区域信息 - 存储边缘计算区域的属性
        tasks               % 任务列表 - 存储待分配的任务信息
        evaluator           % 目标评估器 - 用于评估解的目标函数值

        popSize             % 种群大小 - 遗传算法中种群的个体数量
        maxGen              % 最大代数 - 遗传算法的最大迭代次数
        useParallel         % 是否并行 - 控制是否使用并行计算
        finalRelaxRate      % 最终松弛率 - 约束处理中的最终松弛参数

        CR                  % 交叉概率 - 差分进化算法中的交叉概率参数
        F                   % 缩放因子 - 差分进化算法中的缩放因子参数
        pbestRate           % 最优比例 - 用于选择最优个体的比例参数
        varMax              % 最大方差 - 限制安全级别方差的最大值

        eliteArchive        % 精英档案 - 存储帕累托前沿的精英解
        stage2Pool          % 第二阶段池 - 存储第二阶段的解
        fes                 % 函数评估次数 - 统计目标函数评估次数
        runtime             % 运行时间 - 记录算法总运行时间
    end

    methods
        % 构造函数 - 初始化PAR_MTDMS_CMOEA实例
        function obj = PAR_MTDMS_CMOEA(region, tasks, popSize, maxGen, useParallel, finalRelaxRate)
            % 检查输入参数数量，至少需要region, tasks, popSize, maxGen
            if nargin < 4
                error('PAR_MTDMS_CMOEA:InsufficientInput', 'Need at least region, tasks, popSize, maxGen');
            end
            % 如果未提供useParallel参数，默认设置为false
            if nargin < 5
                useParallel = false;
            end
            % 如果未提供finalRelaxRate参数，默认设置为0.05
            if nargin < 6
                finalRelaxRate = 0.05;
            end

            % 初始化对象属性
            obj.region = region;                          % 设置区域信息
            obj.tasks = tasks;                            % 设置任务列表
            obj.evaluator = ObjectiveEvaluator(region, tasks);  % 创建目标评估器

            obj.popSize = max(20, popSize);               % 设置种群大小，最小为20
            obj.maxGen = max(1, maxGen);                  % 设置最大代数，最小为1
            obj.useParallel = useParallel;                % 设置并行计算标志
            obj.finalRelaxRate = finalRelaxRate;          % 设置最终松弛率

            obj.CR = 0.35;                                % 设置交叉概率为0.35
            obj.F = 0.5;                                  % 设置缩放因子为0.5
            obj.pbestRate = 0.2;                          % 设置最优比例为0.2
            obj.varMax = 1.0;                             % 设置最大方差为1.0

            obj.eliteArchive = Solution.empty(0, 1);      % 初始化空的精英档案
            obj.stage2Pool = Solution.empty(0, 1);        % 初始化空的第二阶段池
            obj.fes = 0;                                  % 初始化函数评估次数为0
            obj.runtime = 0;                              % 初始化运行时间为0
        end

        % 运行函数 - 执行完整的优化过程
        function obj = run(obj)
            % 开始计时
            tic;

            % 将最大代数分为三个阶段：第一阶段占25%，第二阶段占55%，第三阶段占剩余
            stage1Gen = max(1, round(obj.maxGen * 0.25));     % 第一阶段代数
            stage2Gen = max(1, round(obj.maxGen * 0.55));     % 第二阶段代数
            stage3Gen = max(1, obj.maxGen - stage1Gen - stage2Gen);  % 第三阶段代数

            % 初始化四个膜（种群）
            membranes = cell(4, 1);
            for m = 1:4
                membranes{m} = obj.initializePopulation(obj.popSize);  % 为每个膜初始化种群
            end

            % 第一阶段：独立演化
            for gen = 1:stage1Gen
                for m = 1:4
                    offspring = obj.generateOffspring(membranes{m}, m);      % 产生子代
                    combined = [membranes{m}(:); offspring(:)];              % 合并父代和子代
                    membranes{m} = obj.environmentalSelectionStage1(combined, obj.popSize, m);  % 环境选择
                end
            end

            % 合并所有膜的个体到一个池中
            pool = [membranes{1}(:); membranes{2}(:); membranes{3}(:); membranes{4}(:)];
            % 获取约束违反度
            poolCV = [pool.constraintViolation]';
            % 计算第70百分位数作为初始约束容忍度
            theta0 = obj.safePercentile(poolCV, 70);
            theta0 = max(theta0, 1e-3);  % 确保theta0不小于1e-3

            % 计算最终约束容忍度
            thetaFinal = max(theta0 * obj.finalRelaxRate, 1e-6);

            % 选择主种群和辅助种群
            mainPop = obj.environmentalSelectionConstrained(pool, obj.popSize, 1e-6, 2);  % 严格可行解种群
            auxPop = obj.environmentalSelectionConstrained(pool, obj.popSize, theta0, 2);  % 松弛约束解种群

            % 第二阶段：约束处理演化
            for gen = 1:stage2Gen
                t = gen / max(stage2Gen, 1);  % 当前代数比例
                % 计算衰减系数
                decay = 1 - log(gen + 1) / log(stage2Gen + 1);
                % 根据衰减计算当前辅助种群的约束容忍度
                thetaAux = thetaFinal + (theta0 - thetaFinal) * decay * (1 - 0.5 * t);
                thetaAux = max(thetaFinal, thetaAux);  % 确保不低于最终容忍度

                % 为主种群和辅助种群生成子代
                offMain = obj.generateOffspringStage2(mainPop);
                offAux = obj.generateOffspringStage2(auxPop);

                % 对合并后的种群进行环境选择
                mainPop = obj.environmentalSelectionConstrained([mainPop(:); offMain(:)], obj.popSize, 1e-6, 2);
                auxPop = obj.environmentalSelectionConstrained([auxPop(:); offAux(:)], obj.popSize, thetaAux, 2);
            end

            % 将第二阶段的种群保存到stage2Pool属性
            obj.stage2Pool = [mainPop(:); auxPop(:)];

            % 从主种群中选择代表解
            reps = obj.selectRepresentatives(mainPop, min(20, length(mainPop)));
            stage3Candidates = Solution.empty(0, 1);
            totalCandidates = 0;

            % 第三阶段：安全优化
            for i = 1:length(reps)
                % 针对每个代表解进行安全优化
                cand = obj.optimizeSecurity(reps(i), stage3Gen, max(20, round(obj.popSize * 0.6)));
                if isempty(cand)
                    continue;
                end
                % 将候选解添加到stage3Candidates中
                startIdx = totalCandidates + 1;
                totalCandidates = totalCandidates + length(cand);
                stage3Candidates(startIdx:totalCandidates, 1) = cand(:);
            end

            % 如果没有生成任何候选解，则使用主种群
            if isempty(stage3Candidates)
                stage3Candidates = mainPop(:);
            end

            % 提取可行解
            feasible = stage3Candidates([stage3Candidates.constraintViolation]' <= 1e-6);
            if isempty(feasible)
                feasible = stage3Candidates;
            end

            % 提取帕累托前沿解作为精英档案
            obj.eliteArchive = obj.extractParetoFront(feasible, 3);
            % 计算总运行时间
            obj.runtime = toc;
        end
    end

    methods (Access = private)
        % 初始化种群 - 随机生成N个解
        function pop = initializePopulation(obj, N)
            K = obj.region.numDevices;  % 设备数量
            T = length(obj.tasks);      % 任务数量

            % 创建N个空解
            pop = Solution.empty(N, 0);
            for i = 1:N
                sol = Solution(K, T);                           % 创建新解
                sol.x_offload = (rand(K, 1) > 0.7);             % 卸载决策：70%设备不卸载
                sol.y_cache = (rand(T, 1) > 0.9);               % 缓存决策：90%任务不缓存
                sol.f_resource = 0.1 + 0.4 * rand(T, 1);        % 资源分配：0.1~0.5之间
                sol.z_security = randi([1, 4], K, 1);           % 安全等级：1~4之间
                sol = obj.repairSolution(sol);                  % 修复解使其满足约束
                sol = obj.evalAndCount(sol);                    % 评估解并计数
                pop(i) = sol;                                   % 将解加入种群
            end
        end

        % 评估解并增加函数评估计数
        function sol = evalAndCount(obj, sol)
            % 评估解的目标函数值和约束违反度
            [sol.objectives, sol.violations, sol.constraintViolation] = obj.evaluator.evaluate(sol);
            obj.fes = obj.fes + 1;  % 增加函数评估次数
        end

        % 修复解 - 确保解满足约束条件
        function sol = repairSolution(obj, sol)
            K = length(sol.x_offload);  % 设备数量
            T = length(sol.y_cache);    % 任务数量

            % 确保安全等级不低于最低要求
            for k = 1:K
                if sol.x_offload(k) == 1  % 如果设备进行了任务卸载
                    taskType = mod(k-1, T) + 1;  % 确定设备对应的任务类型
                    minSec = obj.tasks(taskType).securityLevel;  % 获取最低安全等级
                    sol.z_security(k) = max(sol.z_security(k), minSec);  % 修复安全等级
                end
            end
            % 限制安全等级在1~4范围内
            sol.z_security = max(1, min(4, round(sol.z_security)));

            % 限制资源分配在0.1~1.0范围内
            sol.f_resource = max(0.1, min(1.0, sol.f_resource));

            % 检查并修复资源总量超限
            totalAlloc = sum(sol.f_resource);
            if totalAlloc > T  % 如果资源分配超过上限
                sol.f_resource = sol.f_resource * (T * 0.95 / totalAlloc);  % 按比例缩小
            end

            % 处理缓存容量约束
            cacheUsed = 0;              % 已使用的缓存
            cacheIndices = zeros(T, 1); % 缓存索引
            cacheCount = 0;             % 缓存计数
            for t = 1:T
                if sol.y_cache(t) == 1  % 如果任务t被缓存
                    cacheUsed = cacheUsed + obj.tasks(t).dataSize;  % 累加缓存使用量
                    cacheCount = cacheCount + 1;
                    cacheIndices(cacheCount) = t;
                end
            end

            % 如果缓存使用量超过容量限制，移除一些缓存
            if cacheUsed > obj.region.cacheCapacity && cacheCount > 0
                cacheIndices = cacheIndices(1:cacheCount);  % 获取有效索引
                dataSizes = zeros(cacheCount, 1);           % 任务数据大小
                for idx = 1:cacheCount
                    dataSizes(idx) = obj.tasks(cacheIndices(idx)).dataSize;  % 获取数据大小
                end
                [~, sortOrder] = sort(dataSizes, 'descend');  % 按数据大小降序排序

                % 从最大的开始移除缓存直到满足容量限制
                for idx = 1:cacheCount
                    taskIdx = cacheIndices(sortOrder(idx));
                    if sol.y_cache(taskIdx) == 1  % 如果该任务当前被缓存
                        sol.y_cache(taskIdx) = 0;  % 取消缓存
                        cacheUsed = cacheUsed - obj.tasks(taskIdx).dataSize;  % 更新使用量
                        if cacheUsed <= obj.region.cacheCapacity  % 如果满足容量限制
                            break;
                        end
                    end
                end
            end
        end

        % 生成子代 - 基于差分进化变异操作
        function offspring = generateOffspring(obj, pop, membraneType)
            N = length(pop);  % 种群大小
            K = obj.region.numDevices;  % 设备数量
            T = length(obj.tasks);      % 任务数量

            % 创建N个空解作为子代
            offspring = Solution.empty(N, 0);
            for i = 1:N
                % 根据膜类型选择不同的变异策略
                if membraneType == 1
                    mode = 'pbest';     % 选择最优个体作为基础
                elseif membraneType == 2
                    mode = 'rand';      % 随机选择个体
                elseif membraneType == 3
                    mode = 'latency';   % 优先考虑延迟
                else
                    mode = 'energy';    % 优先考虑能耗
                end

                trial = obj.deMutation(pop, i, mode, K, T);  % 差分进化变异
                trial = obj.repairSolution(trial);           % 修复解
                trial = obj.evalAndCount(trial);             % 评估解
                offspring(i) = trial;                        % 将子代加入种群
            end
        end

        % 差分进化变异操作
        function trial = deMutation(obj, pop, i, mode, K, T)
            N = length(pop);
            trial = Solution(K, T);  % 创建新的解

            % 根据模式选择变异策略
            if strcmp(mode, 'pbest')  % 如果是选择最优个体模式
                p = max(2, round(obj.pbestRate * N));  % 计算最优个体数量
                ranked = obj.nonDominatedSorting(pop, 2);  % 非支配排序
                pbest = ranked(randi([1, p]));  % 随机选择一个最优个体
                idx = randperm(N, 2);  % 随机选择两个个体
                r1 = pop(idx(1));
                r2 = pop(idx(2));
                base = pbest;  % 以最优个体为基础
            else
                idx = randperm(N, 3);  % 随机选择三个个体
                base = pop(idx(1));
                r1 = pop(idx(2));
                r2 = pop(idx(3));
            end

            % 对资源分配变量进行变异
            for t = 1:T
                if rand < obj.CR  % 如果随机数小于交叉概率
                    trial.f_resource(t) = base.f_resource(t) + obj.F * (r1.f_resource(t) - r2.f_resource(t));  % DE变异
                else
                    trial.f_resource(t) = pop(i).f_resource(t);  % 保持原值
                end
            end

            % 对卸载决策和安全等级进行变异
            for k = 1:K
                if rand < obj.CR  % 如果随机数小于交叉概率
                    trial.x_offload(k) = base.x_offload(k);  % 采用基础个体的值
                else
                    trial.x_offload(k) = pop(i).x_offload(k);  % 保持原值
                end
                if rand < obj.CR  % 如果随机数小于交叉概率
                    trial.z_security(k) = r1.z_security(k);  % 采用r1个体的值
                else
                    trial.z_security(k) = pop(i).z_security(k);  % 保持原值
                end
            end

            % 对缓存决策进行变异
            for t = 1:T
                if rand < obj.CR  % 如果随机数小于交叉概率
                    trial.y_cache(t) = r2.y_cache(t);  % 采用r2个体的值
                else
                    trial.y_cache(t) = pop(i).y_cache(t);  % 保持原值
                end
            end

            % 特殊处理：延迟模式下更倾向于卸载，能量模式下更倾向于缓存
            if strcmp(mode, 'latency')  % 如果是延迟模式
                trial.x_offload = (rand(K, 1) > 0.75);  % 更多设备进行卸载
            elseif strcmp(mode, 'energy')  % 如果是能量模式
                trial.y_cache = (rand(T, 1) > 0.95);    % 更少任务被缓存
            end
        end

        % 第二阶段生成子代
        function offspring = generateOffspringStage2(obj, pop)
            N = length(pop);  % 种群大小
            K = obj.region.numDevices;  % 设备数量
            T = length(obj.tasks);      % 任务数量

            % 创建N个空解作为子代
            offspring = Solution.empty(N, 0);
            ranked = obj.nonDominatedSorting(pop, 2);  % 非支配排序
            p = max(2, round(obj.pbestRate * N));      % 计算最优个体数量
            for i = 1:N
                % 随机选择变异模式
                if rand < 0.5
                    mode = 'rand';      % 随机模式
                else
                    mode = 'pbest';     % 最优模式
                end

                % 根据模式选择变异策略
                if strcmp(mode, 'pbest')
                    pbest = ranked(randi([1, p]));  % 随机选择一个最优个体
                    idx = randperm(N, 2);  % 随机选择两个个体
                    r1 = pop(idx(1));
                    r2 = pop(idx(2));
                    base = pbest;  % 以最优个体为基础
                else
                    idx = randperm(N, 3);  % 随机选择三个个体
                    base = pop(idx(1));
                    r1 = pop(idx(2));
                    r2 = pop(idx(3));
                end

                trial = Solution(K, T);  % 创建新的解
                % 对资源分配变量进行变异
                for t = 1:T
                    if rand < obj.CR  % 如果随机数小于交叉概率
                        trial.f_resource(t) = base.f_resource(t) + obj.F * (r1.f_resource(t) - r2.f_resource(t));  % DE变异
                    else
                        trial.f_resource(t) = pop(i).f_resource(t);  % 保持原值
                    end
                end
                % 对卸载决策和安全等级进行变异
                for k = 1:K
                    if rand < obj.CR  % 如果随机数小于交叉概率
                        trial.x_offload(k) = base.x_offload(k);  % 采用基础个体的值
                    else
                        trial.x_offload(k) = pop(i).x_offload(k);  % 保持原值
                    end
                    if rand < obj.CR  % 如果随机数小于交叉概率
                        trial.z_security(k) = r1.z_security(k);  % 采用r1个体的值
                    else
                        trial.z_security(k) = pop(i).z_security(k);  % 保持原值
                    end
                end
                % 对缓存决策进行变异
                for t = 1:T
                    if rand < obj.CR  % 如果随机数小于交叉概率
                        trial.y_cache(t) = r2.y_cache(t);  % 采用r2个体的值
                    else
                        trial.y_cache(t) = pop(i).y_cache(t);  % 保持原值
                    end
                end

                trial = obj.repairSolution(trial);     % 修复解
                trial = obj.evalAndCount(trial);       % 评估解
                offspring(i) = trial;                  % 将子代加入种群
            end
        end

        % 第一阶段环境选择
        function selected = environmentalSelectionStage1(obj, combined, N, membraneType)
            % 根据膜类型选择不同的选择策略
            if membraneType == 2  % 无约束选择
                selected = obj.environmentalSelectionUnconstrained(combined, N, 2);
                return;
            end

            if membraneType == 3  % 标量选择，优先考虑第一个目标
                selected = obj.scalarSelection(combined, N, 1);
                return;
            end

            if membraneType == 4  % 标量选择，优先考虑第二个目标
                selected = obj.scalarSelection(combined, N, 2);
                return;
            end

            % 默认使用约束环境选择
            selected = obj.environmentalSelectionConstrained(combined, N, max(1e-3, obj.safePercentile([combined.constraintViolation]', 80)), 2);
        end

        % 标量选择 - 基于单个目标的选择
        function selected = scalarSelection(obj, combined, N, primaryObjIdx)
            objMat = vertcat(combined.objectives);  % 获取目标值矩阵
            cv = [combined.constraintViolation]';   % 获取约束违反度向量
            penalty = 1e3 * cv;                   % 计算惩罚项
            fit = objMat(:, primaryObjIdx) + penalty;  % 计算适应度（目标值+惩罚）
            [~, idx] = sort(fit, 'ascend');       % 按适应度升序排序
            selected = combined(idx(1:min(N, length(idx))));  % 选择前N个个体
        end

        % 无约束环境选择 - 使用非支配排序
        function selected = environmentalSelectionUnconstrained(obj, combined, N, objDim)
            ranked = obj.nonDominatedSorting(combined, objDim);  % 非支配排序
            selected = ranked(1:min(N, length(ranked)));         % 选择前N个个体
        end

        % 约束环境选择 - 考虑约束违反度的选择
        function selected = environmentalSelectionConstrained(obj, combined, N, theta, objDim)
            popSize = length(combined);           % 合并种群大小
            feasibleIdx = zeros(popSize, 1);      % 可行解索引数组
            infeasibleIdx = zeros(popSize, 1);    % 不可行解索引数组
            feasCount = 0;                        % 可行解计数
            infeasCount = 0;                      % 不可行解计数

            % 分离可行解和不可行解
            for i = 1:popSize
                if combined(i).constraintViolation <= theta  % 如果约束违反度小于等于阈值
                    feasCount = feasCount + 1;
                    feasibleIdx(feasCount) = i;
                else
                    infeasCount = infeasCount + 1;
                    infeasibleIdx(infeasCount) = i;
                end
            end

            feasibleIdx = feasibleIdx(1:feasCount);      % 截取有效的可行解索引
            infeasibleIdx = infeasibleIdx(1:infeasCount);  % 截取有效的不可行解索引

            selected = Solution.empty(0, 1);  % 初始化选择结果为空
            if feasCount > 0  % 如果存在可行解
                rankedFeasible = obj.nonDominatedSorting(combined(feasibleIdx), objDim);  % 对可行解进行非支配排序
                if length(rankedFeasible) >= N  % 如果可行解数量足够
                    selected = rankedFeasible(1:N);  % 直接选择前N个
                    return;
                end
                selected = rankedFeasible(:);  % 否则选择所有可行解
            end

            % 如果选择的解数量不足N，补充不可行解
            if length(selected) < N && infeasCount > 0
                infeasiblePop = combined(infeasibleIdx);  % 获取不可行解
                [~, sortIdx] = sort([infeasiblePop.constraintViolation]);  % 按约束违反度排序
                remaining = N - length(selected);  % 需要补充的数量
                toAdd = infeasiblePop(sortIdx(1:min(remaining, infeasCount)));  % 选择违反度最小的解

                totalSelected = length(selected) + length(toAdd);  % 总共选择的解数
                out = Solution.empty(totalSelected, 0);  % 创建输出数组
                if ~isempty(selected)
                    out(1:length(selected)) = selected(:);  % 添加已选择的解
                end
                out(length(selected)+1:totalSelected) = toAdd(:);  % 添加补充的解
                selected = out;  % 更新选择结果
            end
        end

        % 非支配排序 - 用于多目标优化的选择
        function ranked = nonDominatedSorting(obj, population, objDim)
            popSize = length(population);           % 种群大小
            dominationCount = zeros(popSize, 1);    % 每个个体被支配计数
            dominatedSet = cell(popSize, 1);        % 每个个体支配的集合
            rank = inf(popSize, 1);                 % 每个个体的等级

            % 计算支配关系
            for i = 1:popSize
                for j = (i+1):popSize
                    if obj.dominatesObj(population(i), population(j), objDim)  % 如果i支配j
                        dominatedSet{i} = [dominatedSet{i}, j];  % i支配j
                        dominationCount(j) = dominationCount(j) + 1;  % j被支配数+1
                    elseif obj.dominatesObj(population(j), population(i), objDim)  % 如果j支配i
                        dominatedSet{j} = [dominatedSet{j}, i];  % j支配i
                        dominationCount(i) = dominationCount(i) + 1;  % i被支配数+1
                    end
                end
            end

            fronts = {};              % 帕累托前沿
            currentFront = find(dominationCount == 0)';  % 找到支配数为0的个体（非支配解）
            rank(currentFront) = 1;   % 将其等级设为1
            frontIdx = 1;             % 前沿索引
            while ~isempty(currentFront)  % 当前前沿非空时继续
                fronts{frontIdx} = currentFront;  % 将当前前沿加入前沿集合
                nextFront = [];  % 下一前沿
                for i = currentFront
                    ds = dominatedSet{i};  % 获取i支配的个体
                    for j = ds
                        dominationCount(j) = dominationCount(j) - 1;  % 减少被支配数
                        if dominationCount(j) == 0  % 如果j不再被支配
                            rank(j) = frontIdx + 1;  % 设置等级
                            nextFront = [nextFront, j];  % 加入下一前沿
                        end
                    end
                end
                currentFront = nextFront;  % 更新当前前沿
                frontIdx = frontIdx + 1;   % 增加前沿索引
            end

            crowd = zeros(popSize, 1);  % 拥挤距离
            for f = 1:length(fronts)  % 计算每个前沿的拥挤距离
                front = fronts{f};
                if length(front) <= 2  % 如果前沿个体数<=2
                    crowd(front) = inf;  % 拥挤距离设为无穷大
                else
                    crowd(front) = obj.computeCrowding(population(front), objDim);  % 计算拥挤距离
                end
            end

            % 排序矩阵：等级优先，然后是拥挤距离
            sortMat = [rank, -crowd];
            [~, sortIdx] = sortrows(sortMat);  % 按等级和拥挤距离排序
            ranked = population(sortIdx);  % 返回排序后的种群
        end

        % 计算拥挤距离
        function cd = computeCrowding(obj, frontPop, objDim)
            n = length(frontPop);  % 前沿个体数
            cd = zeros(n, 1);      % 拥挤距离数组
            objMat = vertcat(frontPop.objectives);  % 目标值矩阵
            objMat = objMat(:, 1:objDim);  % 取前objDim个目标

            for m = 1:objDim  % 对每个目标维度计算
                [sortedVals, order] = sort(objMat(:, m));  % 按此目标值排序
                cd(order(1)) = inf;    % 边界点拥挤距离为无穷大
                cd(order(end)) = inf;  % 边界点拥挤距离为无穷大
                fmin = sortedVals(1);  % 最小值
                fmax = sortedVals(end);  % 最大值
                if fmax > fmin  % 如果最大值大于最小值
                    for i = 2:(n-1)  % 对中间个体计算拥挤距离
                        if isinf(cd(order(i)))  % 如果已经是无穷大
                            continue;
                        end
                        cd(order(i)) = cd(order(i)) + (sortedVals(i+1) - sortedVals(i-1)) / (fmax - fmin);  % 累加距离
                    end
                end
            end
        end

        % 判断支配关系 - 解A是否支配解B
        function tf = dominatesObj(obj, solA, solB, objDim)
            a = solA.objectives(1:objDim);  % A的目标值
            b = solB.objectives(1:objDim);  % B的目标值
            tf = all(a <= b) && any(a < b);  % A的所有目标都不比B差，且至少有一个目标比B好
        end

        % 提取帕累托前沿 - 从种群中提取非支配解
        function pf = extractParetoFront(obj, population, objDim)
            n = length(population);  % 种群大小
            dominated = false(n, 1);  % 被支配标记数组
            for i = 1:n
                for j = 1:n
                    if i ~= j && obj.dominatesObj(population(j), population(i), objDim)  % 如果j支配i
                        dominated(i) = true;  % 标记i为被支配
                        break;
                    end
                end
            end
            pf = population(~dominated);  % 返回非被支配的个体
        end

        % 选择代表解 - 从种群中选择M个代表性解
        function reps = selectRepresentatives(obj, population, M)
            if isempty(population)  % 如果种群为空
                reps = Solution.empty(0, 1);  % 返回空解
                return;
            end
            ranked = obj.nonDominatedSorting(population, 2);  % 非支配排序
            M = min(M, length(ranked));  % 确保M不超过种群大小
            reps = ranked(1:M);  % 选择前M个解
        end

        % 优化安全等级 - 针对基础解优化安全等级
        function out = optimizeSecurity(obj, baseSol, gens, N)
            K = obj.region.numDevices;  % 设备数量
            T = length(obj.tasks);      % 任务数量

            pop = Solution.empty(N, 0);  % 初始化种群
            for i = 1:N
                sol = Solution(K, T);
                sol.x_offload = baseSol.x_offload;  % 复制基础解的卸载决策
                sol.y_cache = baseSol.y_cache;      % 复制基础解的缓存决策
                sol.f_resource = baseSol.f_resource;  % 复制基础解的资源分配
                sol.z_security = baseSol.z_security;  % 复制基础解的安全等级

                % 随机变异安全等级
                flipMask = rand(K, 1) < 0.3;  % 30%的设备安全等级会变化
                sol.z_security(flipMask) = randi([1, 4], sum(flipMask), 1);  % 随机生成新安全等级
                sol = obj.repairSolution(sol);  % 修复解
                sol = obj.evalAndCount(sol);    % 评估解
                sol.constraintViolation = sol.constraintViolation + obj.securityVarianceViolation(sol);  % 添加安全方差约束违反
                pop(i) = sol;  % 加入种群
            end

            % 进行gens代演化
            for gen = 1:gens
                offspring = Solution.empty(N, 0);  % 初始化子代种群
                for i = 1:N
                    idx = randperm(N, 3);  % 随机选择三个个体
                    x1 = pop(idx(1));
                    x2 = pop(idx(2));
                    x3 = pop(idx(3));

                    trial = Solution(K, T);
                    trial.x_offload = baseSol.x_offload;  % 保持基础解的卸载决策
                    trial.y_cache = baseSol.y_cache;      % 保持基础解的缓存决策
                    trial.f_resource = baseSol.f_resource;  % 保持基础解的资源分配
                    trial.z_security = pop(i).z_security;  % 初始化安全等级

                    % 差分进化变异
                    v = x1.z_security + obj.F * (x2.z_security - x3.z_security);
                    v = round(v);  % 四舍五入为整数
                    v = max(1, min(4, v));  % 限制在1-4范围内

                    % 应用变异
                    for k = 1:K
                        if rand < obj.CR  % 如果随机数小于交叉概率
                            trial.z_security(k) = v(k);  % 应用变异值
                        end
                    end

                    trial = obj.repairSolution(trial);  % 修复解
                    trial = obj.evalAndCount(trial);    % 评估解
                    trial.constraintViolation = trial.constraintViolation + obj.securityVarianceViolation(trial);  % 添加安全方差约束违反
                    offspring(i) = trial;  % 加入子代种群
                end

                % 环境选择
                combined = [pop(:); offspring(:)];  % 合并父代和子代
                pop = obj.environmentalSelectionConstrained(combined, N, max(1e-6, obj.safePercentile([combined.constraintViolation]', 60)), 3);  % 选择下一代
            end

            out = pop(:);  % 返回最终种群
        end

        % 计算安全等级方差约束违反度
        function v = securityVarianceViolation(obj, sol)
            z = sol.z_security(sol.x_offload == 1);  % 获取参与卸载的设备的安全等级
            if isempty(z)  % 如果没有设备参与卸载
                v = 0;  % 没有方差违反
                return;
            end
            v = max(0, var(double(z)) - obj.varMax);  % 计算超出最大允许方差的部分
        end

        % 安全的百分位数计算
        function p = safePercentile(obj, x, q)
            if isempty(x)  % 如果数组为空
                p = 0;  % 返回0
                return;
            end
            x = x(~isnan(x));  % 移除NaN值
            if isempty(x)  % 如果移除NaN后数组为空
                p = 0;  % 返回0
                return;
            end
            xs = sort(x);  % 排序
            idx = max(1, min(length(xs), round(q / 100 * length(xs))));  % 计算百分位位置
            p = xs(idx);  % 返回百分位数值
        end
    end
end