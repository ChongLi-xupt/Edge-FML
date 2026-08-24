classdef InputValidator
    % InputValidator - 统一的输入验证系统
    % 为Edge-FML系统提供全面的输入参数验证功能
    %
    % 主要功能：
    % 1. 区域配置验证
    % 2. 任务数据验证
    % 3. 算法参数验证
    % 4. 数值范围检查
    % 5. 数据类型验证
    % 6. 依赖关系检查
    %
    % 作者: 拓守恒 (Shouheng Tuo)
    % GitHub: github.com/shouhengtuo/
    % 邮箱: tuo_sh@xupt.edu.cn
    % 日期: 2025-12-03

    methods (Static)
        function validateRegionConfig(regions)
            % 验证区域配置
            %
            % 输入:
            %   regions - RegionConfig对象数组

            if nargin < 1 || isempty(regions)
                error('InputValidator:EmptyRegions', 'regions参数不能为空');
            end

            if ~isa(regions, 'RegionConfig')
                error('InputValidator:InvalidRegionType', 'regions必须是RegionConfig对象数组');
            end

            if ~isvector(regions) || length(regions) == 0
                error('InputValidator:InvalidRegionFormat', 'regions必须是非空向量');
            end

            % 验证每个区域的配置
            for i = 1:length(regions)
                region = regions(i);

                try
                    % 验证计算容量
                    if ~isnumeric(region.computeCapacity) || region.computeCapacity <= 0
                        error('InputValidator:InvalidComputeCapacity', ...
                            '区域%d的计算容量必须为正数', i);
                    end

                    % 验证缓存容量
                    if ~isnumeric(region.cacheCapacity) || region.cacheCapacity <= 0
                        error('InputValidator:InvalidCacheCapacity', ...
                            '区域%d的缓存容量必须为正数', i);
                    end

                    % 验证设备数量
                    if ~isnumeric(region.numDevices) || region.numDevices <= 0 || ...
                       mod(region.numDevices, 1) ~= 0
                        error('InputValidator:InvalidNumDevices', ...
                            '区域%d的设备数量必须为正整数', i);
                    end

                    % 验证带宽
                    if ~isnumeric(region.bandwidth) || region.bandwidth <= 0
                        error('InputValidator:InvalidBandwidth', ...
                            '区域%d的带宽必须为正数', i);
                    end

                    % 验证延迟
                    if ~isnumeric(region.latency) || region.latency < 0
                        error('InputValidator:InvalidLatency', ...
                            '区域%d的延迟必须为非负数', i);
                    end

                    % 验证合理性范围
                    if region.computeCapacity > 100 || region.computeCapacity < 0.1
                        warning('InputValidator:UnusualComputeCapacity', ...
                            '区域%d的计算容量%.2f GHz可能不合理', i, region.computeCapacity);
                    end

                    if region.cacheCapacity > 10000 || region.cacheCapacity < 1
                        warning('InputValidator:UnusualCacheCapacity', ...
                            '区域%d的缓存容量%.2f MB可能不合理', i, region.cacheCapacity);
                    end

                    if region.numDevices > 1000 || region.numDevices < 1
                        warning('InputValidator:UnusualNumDevices', ...
                            '区域%d的设备数量%d可能不合理', i, region.numDevices);
                    end

                catch ME
                    if startsWith(ME.identifier, 'InputValidator:')
                        rethrow(ME);
                    else
                        error('InputValidator:RegionAccessFailed', ...
                            '访问区域%d配置时出错: %s', i, ME.message);
                    end
                end
            end

            fprintf('区域配置验证通过：%d个区域\n', length(regions));
        end

        function validateTaskData(tasks)
            % 验证任务数据
            %
            % 输入:
            %   tasks - TaskData对象数组

            if nargin < 1 || isempty(tasks)
                error('InputValidator:EmptyTasks', 'tasks参数不能为空');
            end

            if ~isa(tasks, 'TaskData')
                error('InputValidator:InvalidTaskType', 'tasks必须是TaskData对象数组');
            end

            if ~isvector(tasks) || length(tasks) == 0
                error('InputValidator:InvalidTaskFormat', 'tasks必须是非空向量');
            end

            % 验证每个任务的配置
            for i = 1:length(tasks)
                task = tasks(i);

                try
                    % 验证工作负载
                    if ~isnumeric(task.workload) || task.workload <= 0
                        error('InputValidator:InvalidWorkload', ...
                            '任务%d的工作负载必须为正数', i);
                    end

                    % 验证数据大小
                    if ~isnumeric(task.dataSize) || task.dataSize <= 0
                        error('InputValidator:InvalidDataSize', ...
                            '任务%d的数据大小必须为正数', i);
                    end

                    % 验证截止时间
                    if ~isnumeric(task.deadline) || task.deadline <= 0
                        error('InputValidator:InvalidDeadline', ...
                            '任务%d的截止时间必须为正数', i);
                    end

                    % 验证安全级别
                    if ~isnumeric(task.securityLevel) || ...
                       task.securityLevel < 1 || task.securityLevel > 4
                        error('InputValidator:InvalidSecurityLevel', ...
                            '任务%d的安全级别必须在[1,4]范围内', i);
                    end

                    % 验证访问频率
                    if ~isnumeric(task.accessFreq) || task.accessFreq < 0
                        error('InputValidator:InvalidAccessFreq', ...
                            '任务%d的访问频率必须为非负数', i);
                    end

                    % 验证优先级
                    if ~isnumeric(task.priority) || ...
                       task.priority < 1 || task.priority > 10
                        error('InputValidator:InvalidPriority', ...
                            '任务%d的优先级必须在[1,10]范围内', i);
                    end

                    % 验证合理性范围
                    if task.workload > 1e9 || task.workload < 1e3
                        warning('InputValidator:UnusualWorkload', ...
                            '任务%d的工作负载%.2e cycles可能不合理', i, task.workload);
                    end

                    if task.dataSize > 1000 || task.dataSize < 0.1
                        warning('InputValidator:UnusualDataSize', ...
                            '任务%d的数据大小%.2f MB可能不合理', i, task.dataSize);
                    end

                    if task.deadline > 100 || task.deadline < 0.01
                        warning('InputValidator:UnusualDeadline', ...
                            '任务%d的截止时间%.2f秒可能不合理', i, task.deadline);
                    end

                catch ME
                    if startsWith(ME.identifier, 'InputValidator:')
                        rethrow(ME);
                    else
                        error('InputValidator:TaskAccessFailed', ...
                            '访问任务%d数据时出错: %s', i, ME.message);
                    end
                end
            end

            fprintf('任务数据验证通过：%d个任务类型\n', length(tasks));
        end

        function validateAlgorithmParameters(R_max, M_local, popSize, maxGen)
            % 验证算法参数
            %
            % 输入:
            %   R_max - 最大联邦轮数
            %   M_local - 本地进化预算
            %   popSize - 种群大小
            %   maxGen - 最大代数

            % 验证R_max
            if nargin >= 1
                if ~isnumeric(R_max) || R_max <= 0 || mod(R_max, 1) ~= 0
                    error('InputValidator:InvalidRMax', ...
                        'R_max必须为正整数，当前值: %s', mat2str(R_max));
                end

                if R_max > 1000
                    warning('InputValidator:LargeRMax', ...
                        'R_max=%d可能过大，建议值范围[10,100]', R_max);
                end

                if R_max < 5
                    warning('InputValidator:SmallRMax', ...
                        'R_max=%d可能过小，建议值范围[10,100]', R_max);
                end
            end

            % 验证M_local
            if nargin >= 2
                if ~isnumeric(M_local) || M_local <= 0 || mod(M_local, 1) ~= 0
                    error('InputValidator:InvalidMLocal', ...
                        'M_local必须为正整数，当前值: %s', mat2str(M_local));
                end

                if M_local > 1000
                    warning('InputValidator:LargeMLocal', ...
                        'M_local=%d可能过大，建议值范围[50,200]', M_local);
                end

                if M_local < 10
                    warning('InputValidator:SmallMLocal', ...
                        'M_local=%d可能过小，建议值范围[50,200]', M_local);
                end
            end

            % 验证popSize
            if nargin >= 3
                if ~isnumeric(popSize) || popSize <= 0 || mod(popSize, 1) ~= 0
                    error('InputValidator:InvalidPopSize', ...
                        'popSize必须为正整数，当前值: %s', mat2str(popSize));
                end

                if popSize > 500
                    warning('InputValidator:LargePopSize', ...
                        'popSize=%d可能过大，建议值范围[50,200]', popSize);
                end

                if popSize < 20
                    warning('InputValidator:SmallPopSize', ...
                        'popSize=%d可能过小，建议值范围[50,200]', popSize);
                end
            end

            % 验证maxGen
            if nargin >= 4
                if ~isnumeric(maxGen) || maxGen <= 0 || mod(maxGen, 1) ~= 0
                    error('InputValidator:InvalidMaxGen', ...
                        'maxGen必须为正整数，当前值: %s', mat2str(maxGen));
                end

                if maxGen > 1000
                    warning('InputValidator:LargeMaxGen', ...
                        'maxGen=%d可能过大，建议值范围[50,200]', maxGen);
                end

                if maxGen < 10
                    warning('InputValidator:SmallMaxGen', ...
                        'maxGen=%d可能过小，建议值范围[50,200]', maxGen);
                end
            end

            fprintf('算法参数验证通过\n');
        end

        function validateCompatibility(regions, taskSets)
            % 验证区域和任务集的兼容性
            %
            % 输入:
            %   regions - RegionConfig对象数组
            %   taskSets - 任务集的cell数组

            if nargin < 2
                error('InputValidator:InsufficientCompatibilityInput', ...
                    '需要regions和taskSets参数进行兼容性验证');
            end

            % 验证数量匹配
            if length(regions) ~= length(taskSets)
                error('InputValidator:RegionTaskMismatch', ...
                    'regions数量(%d)与taskSets数量(%d)不匹配', ...
                    length(regions), length(taskSets));
            end

            % 验证每个区域的任务集
            for r = 1:length(regions)
                region = regions(r);
                taskSet = taskSets{r};

                % 验证任务集不为空
                if isempty(taskSet)
                    error('InputValidator:EmptyTaskSet', ...
                        '区域%d的任务集不能为空', r);
                end

                % 验证任务数据类型
                if ~isa(taskSet, 'TaskData')
                    error('InputValidator:InvalidTaskSetType', ...
                        '区域%d的任务集必须是TaskData对象数组', r);
                end

                % 验证任务数量合理性
                numTasks = length(taskSet);
                if numTasks > 50
                    warning('InputValidator:ManyTasks', ...
                        '区域%d的任务数量%d可能过多', r, numTasks);
                end

                if numTasks < 1
                    error('InputValidator:NoTasks', ...
                        '区域%d至少需要1个任务', r);
                end

                % 验证任务与设备的比例
                if region.numDevices > 0 && numTasks > region.numDevices * 2
                    warning('InputValidator:HighTaskDeviceRatio', ...
                        '区域%d的任务数量/设备数量比例过高(%.2f)', ...
                        r, numTasks / region.numDevices);
                end
            end

            fprintf('兼容性验证通过：%d个区域-任务集对\n', length(regions));
        end

        function validateSystemRequirements(regions, taskSets, availableMemory, availableCores)
            % 验证系统资源需求
            %
            % 输入:
            %   regions - RegionConfig对象数组
            %   taskSets - 任务集的cell数组
            %   availableMemory - 可用内存（MB）
            %   availableCores - 可用CPU核心数

            if nargin < 3
                availableMemory = 8192;  % 默认8GB
            end

            if nargin < 4
                availableCores = 8;  % 默认8核
            end

            % 估算内存需求
            totalDevices = sum([regions.numDevices]);
            totalTasks = sum(cellfun(@length, taskSets));

            % 基础内存需求（每个设备约10MB，每个任务约5MB）
            estimatedMemory = totalDevices * 10 + totalTasks * 5;

            % 种群内存需求（每个个体约1KB）
            avgPopSize = 100;
            estimatedMemory = estimatedMemory + length(regions) * avgPopSize * 1;

            % 缓冲内存（50%额外）
            estimatedMemory = estimatedMemory * 1.5;

            if estimatedMemory > availableMemory
                warning('InputValidator:InsufficientMemory', ...
                    '估算内存需求%.0fMB超过可用内存%.0fMB', ...
                    estimatedMemory, availableMemory);
            end

            % 估算CPU需求
            estimatedCores = max(1, floor(length(regions) / 2));

            if estimatedCores > availableCores
                warning('InputValidator:InsufficientCores', ...
                    '估算CPU需求%d核超过可用核心%d核', ...
                    estimatedCores, availableCores);
            end

            fprintf('系统资源验证：内存需求%.0fMB/%.0fMB，CPU需求%d/%d核\n', ...
                estimatedMemory, availableMemory, estimatedCores, availableCores);
        end

        function validateFilePaths(configPath, logPath, outputPath)
            % 验证文件路径
            %
            % 输入:
            %   configPath - 配置文件路径
            %   logPath - 日志文件路径
            %   outputPath - 输出文件路径

            % 验证配置文件路径
            if nargin >= 1 && ~isempty(configPath)
                if ~ischar(configPath) && ~isstring(configPath)
                    error('InputValidator:InvalidConfigPath', ...
                        'configPath必须是字符串，当前类型: %s', class(configPath));
                end

                [dir, name, ext] = fileparts(configPath);
                if isempty(dir)
                    dir = '.';
                end

                if ~exist(dir, 'dir')
                    error('InputValidator:ConfigDirNotFound', ...
                        '配置文件目录不存在: %s', dir);
                end

                if isempty(name)
                    error('InputValidator:EmptyConfigName', ...
                        '配置文件名不能为空');
                end
            end

            % 验证日志路径
            if nargin >= 2 && ~isempty(logPath)
                if ~ischar(logPath) && ~isstring(logPath)
                    error('InputValidator:InvalidLogPath', ...
                        'logPath必须是字符串，当前类型: %s', class(logPath));
                end

                if ~exist(logPath, 'dir')
                    try
                        mkdir(logPath);
                        fprintf('创建日志目录: %s\n', logPath);
                    catch ME
                        error('InputValidator:LogDirCreationFailed', ...
                            '无法创建日志目录: %s', ME.message);
                    end
                end
            end

            % 验证输出路径
            if nargin >= 3 && ~isempty(outputPath)
                if ~ischar(outputPath) && ~isstring(outputPath)
                    error('InputValidator:InvalidOutputPath', ...
                        'outputPath必须是字符串，当前类型: %s', class(outputPath));
                end

                if ~exist(outputPath, 'dir')
                    try
                        mkdir(outputPath);
                        fprintf('创建输出目录: %s\n', outputPath);
                    catch ME
                        error('InputValidator:OutputDirCreationFailed', ...
                            '无法创建输出目录: %s', ME.message);
                    end
                end
            end

            fprintf('文件路径验证通过\n');
        end

        function summary = validateAll(regions, taskSets, R_max, M_local, varargin)
            % 执行全面验证
            %
            % 输入:
            %   regions - RegionConfig对象数组
            %   taskSets - 任务集的cell数组
            %   R_max - 最大联邦轮数
            %   M_local - 本地进化预算
            %   varargin - 可选参数（内存、CPU等）
            %
            % 输出:
            %   summary - 验证摘要

            summary = struct();
            summary.startTime = datetime('now');
            summary.errors = {};
            summary.warnings = {};
            summary.passed = true;

            try
                % 验证区域配置
                InputValidator.validateRegionConfig(regions);

                % 验证任务数据
                InputValidator.validateTaskData(taskSets{1});

                % 验证兼容性
                InputValidator.validateCompatibility(regions, taskSets);

                % 验证算法参数
                InputValidator.validateAlgorithmParameters(R_max, M_local);

                % 验证系统资源（可选）
                if length(varargin) >= 1
                    availableMemory = varargin{1};
                else
                    availableMemory = 8192;
                end

                if length(varargin) >= 2
                    availableCores = varargin{2};
                else
                    availableCores = 8;
                end

                InputValidator.validateSystemRequirements(regions, taskSets, ...
                    availableMemory, availableCores);

                % 验证文件路径（可选）
                if length(varargin) >= 3
                    configPath = varargin{3};
                else
                    configPath = './config/';
                end

                if length(varargin) >= 4
                    logPath = varargin{4};
                else
                    logPath = './logs/';
                end

                if length(varargin) >= 5
                    outputPath = varargin{5};
                else
                    outputPath = './results/';
                end

                InputValidator.validateFilePaths(configPath, logPath, outputPath);

            catch ME
                summary.errors{end+1} = ME.message;
                summary.passed = false;
            end

            summary.endTime = datetime('now');
            summary.duration = summary.endTime - summary.startTime;

            % 输出验证摘要
            if summary.passed
                fprintf('\n========== 验证摘要 ==========\n');
                fprintf('验证状态: 通过\n');
                fprintf('验证耗时: %.2f秒\n', seconds(summary.duration));
                fprintf('================================\n');
            else
                fprintf('\n========== 验证摘要 ==========\n');
                fprintf('验证状态: 失败\n');
                fprintf('错误数量: %d\n', length(summary.errors));
                for i = 1:length(summary.errors)
                    fprintf('错误%d: %s\n', i, summary.errors{i});
                end
                fprintf('================================\n');
            end
        end
    end
end