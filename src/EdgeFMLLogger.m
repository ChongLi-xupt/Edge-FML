classdef EdgeFMLLogger < handle
    % EdgeFMLLogger - 统一的日志和错误处理系统
    % 为Edge-FML系统提供全面的日志记录、错误处理和调试功能
    %
    % 主要功能：
    % 1. 多级别日志记录（DEBUG, INFO, WARNING, ERROR）
    % 2. 性能监控和时间统计
    % 3. 错误追踪和恢复建议
    % 4. 检查点保存和恢复
    % 5. 调试信息收集
    %
    % 作者: 拓守恒 (Shouheng Tuo)
    % GitHub: github.com/shouhengtuo/
    % 邮箱: tuo_sh@xupt.edu.cn
    % 日期: 2025-12-03

    properties (Access = private)
        logFile           % 日志文件句柄
        logLevel          % 当前日志级别
        maxFileSize       % 最大文件大小（字节）
        logDirectory      % 日志目录
        enableConsole     % 是否启用控制台输出
        enableFile        % 是否启用文件输出
        performanceData   % 性能数据存储
        errorHistory     % 错误历史记录
        debugMode        % 调试模式标志
    end

    properties (Constant)
        % 日志级别常量
        DEBUG = 1;
        INFO = 2;
        WARNING = 3;
        ERROR = 4;

        % 日志级别名称
        LEVEL_NAMES = containers.Map(...
            {1, 2, 3, 4}, ...
            {'DEBUG', 'INFO', 'WARNING', 'ERROR'});
    end

    methods (Static)
        function logger = getInstance(logDirectory, logLevel)
            % 单例模式获取日志器实例
            persistent instance;

            if isempty(instance) || nargin > 0
                if nargin < 1
                    logDirectory = './logs/';
                end
                if nargin < 2
                    logLevel = EdgeFMLLogger.INFO;
                end

                instance = EdgeFMLLogger(logDirectory, logLevel);
            end

            logger = instance;
        end

        function log(level, message, varargin)
            % 静态便捷日志方法
            logger = EdgeFMLLogger.getInstance();
            logger.logMessage(level, message, varargin{:});
        end

        function debug(message, varargin)
            EdgeFMLLogger.log(EdgeFMLLogger.DEBUG, message, varargin{:});
        end

        function info(message, varargin)
            EdgeFMLLogger.log(EdgeFMLLogger.INFO, message, varargin{:});
        end

        function warning(message, varargin)
            EdgeFMLLogger.log(EdgeFMLLogger.WARNING, message, varargin{:});
        end

        function error(message, varargin)
            EdgeFMLLogger.log(EdgeFMLLogger.ERROR, message, varargin{:});
        end
    end

    methods
        function obj = EdgeFMLLogger(logDirectory, logLevel)
            % 构造函数：初始化日志系统
            %
            % 输入:
            %   logDirectory - 日志目录路径
            %   logLevel - 日志级别

            if nargin < 1
                logDirectory = './logs/';
            end
            if nargin < 2
                logLevel = EdgeFMLLogger.INFO;
            end

            % 创建日志目录
            if ~exist(logDirectory, 'dir')
                mkdir(logDirectory);
            end

            % 初始化属性
            obj.logDirectory = logDirectory;
            obj.logLevel = logLevel;
            obj.maxFileSize = 50 * 1024 * 1024;  % 50MB
            obj.enableConsole = true;
            obj.enableFile = true;
            obj.debugMode = (logLevel <= EdgeFMLLogger.DEBUG);

            % 初始化数据结构
            obj.performanceData = struct();
            obj.errorHistory = [];

            % 打开日志文件
            obj = obj.openLogFile();

            % 记录初始化信息
            obj.logMessage(EdgeFMLLogger.INFO, 'EdgeFML日志系统初始化完成');
            obj.logMessage(EdgeFMLLogger.INFO, '日志目录: %s', logDirectory);
            obj.logMessage(EdgeFMLLogger.INFO, '日志级别: %s', ...
                char(EdgeFMLLogger.LEVEL_NAMES(logLevel)));
        end

        function delete(obj)
            % 析构函数：清理资源
            if ~isempty(obj.logFile) && obj.enableFile
                fprintf(obj.logFile, '\n========== 日志系统关闭 ==========\n');
                fclose(obj.logFile);
            end
        end

        function logMessage(obj, level, message, varargin)
            % 记录日志消息
            %
            % 输入:
            %   level - 日志级别
            %   message - 消息格式字符串
            %   varargin - 格式化参数

            % 检查日志级别
            if level < obj.logLevel
                return;
            end

            % 格式化消息
            if ~isempty(varargin)
                formattedMessage = message;
            else
                try
                    formattedMessage = sprintf(message, varargin{:});
                catch
                    formattedMessage = sprintf('[格式化错误] %s', message);
                end
            end

            % 添加时间戳和级别信息
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            levelName = char(EdgeFMLLogger.LEVEL_NAMES(level));
            logEntry = sprintf('[%s] [%s] %s\n', timestamp, levelName, formattedMessage);

            % 控制台输出
            if obj.enableConsole
                fprintf(logEntry);
            end

            % 文件输出
            if obj.enableFile && ~isempty(obj.logFile)
                try
                    fprintf(obj.logFile, logEntry);

                    % 检查文件大小并轮转
                    fileInfo = dir(obj.logFile.name);
                    if ~isempty(fileInfo) && fileInfo.bytes > obj.maxFileSize
                        obj = obj.rotateLogFile();
                    end

                catch fileError
                    % 文件写入失败，尝试重新打开
                    warning('EdgeFMLLogger:FileWriteFailed', ...
                        '日志文件写入失败: %s', fileError.message);
                    obj = obj.openLogFile();
                end
            end
        end

        function startTimer(obj, timerName)
            % 开始计时
            %
            % 输入:
            %   timerName - 计时器名称

            if ~isfield(obj.performanceData, 'timers')
                obj.performanceData.timers = struct();
            end

            obj.performanceData.timers.(timerName) = tic;
            obj.logMessage(EdgeFMLLogger.DEBUG, '开始计时: %s', timerName);
        end

        function elapsed = stopTimer(obj, timerName)
            % 停止计时并返回耗时
            %
            % 输入:
            %   timerName - 计时器名称
            %
            % 输出:
            %   elapsed - 耗时（秒）

            if ~isfield(obj.performanceData, 'timers') || ...
               ~isfield(obj.performanceData.timers, timerName)
                elapsed = NaN;
                obj.logMessage(EdgeFMLLogger.WARNING, '计时器 %s 未找到', timerName);
                return;
            end

            elapsed = toc(obj.performanceData.timers.(timerName));
            obj.performanceData.timers = rmfield(obj.performanceData.timers, timerName);

            obj.logMessage(EdgeFMLLogger.DEBUG, '停止计时: %s, 耗时: %.4f秒', ...
                timerName, elapsed);

            % 记录到性能统计
            if ~isfield(obj.performanceData, 'statistics')
                obj.performanceData.statistics = struct();
            end

            if ~isfield(obj.performanceData.statistics, timerName)
                obj.performanceData.statistics.(timerName) = struct();
                obj.performanceData.statistics.(timerName).count = 0;
                obj.performanceData.statistics.(timerName).total = 0;
                obj.performanceData.statistics.(timerName).min = inf;
                obj.performanceData.statistics.(timerName).max = 0;
            end

            stats = obj.performanceData.statistics.(timerName);
            stats.count = stats.count + 1;
            stats.total = stats.total + elapsed;
            stats.min = min(stats.min, elapsed);
            stats.max = max(stats.max, elapsed);
            obj.performanceData.statistics.(timerName) = stats;
        end

        function logError(obj, identifier, message, stack)
            % 记录错误信息
            %
            % 输入:
            %   identifier - 错误标识符
            %   message - 错误消息
            %   stack - 错误堆栈

            errorRecord = struct();
            errorRecord.timestamp = datetime('now');
            errorRecord.identifier = identifier;
            errorRecord.message = message;
            errorRecord.stack = stack;

            % 添加到错误历史
            obj.errorHistory(end+1) = errorRecord;

            % 记录日志
            obj.logMessage(EdgeFMLLogger.ERROR, '错误: %s - %s', identifier, message);

            % 提供恢复建议
            recoverySuggestion = obj.getRecoverySuggestion(identifier);
            if ~isempty(recoverySuggestion)
                obj.logMessage(EdgeFMLLogger.INFO, '恢复建议: %s', recoverySuggestion);
            end
        end

        function logPerformance(obj)
            % 记录性能统计信息
            if ~isfield(obj.performanceData, 'statistics')
                obj.logMessage(EdgeFMLLogger.WARNING, '没有性能统计数据');
                return;
            end

            obj.logMessage(EdgeFMLLogger.INFO, '========== 性能统计报告 ==========');

            timerNames = fieldnames(obj.performanceData.statistics);
            for i = 1:length(timerNames)
                name = timerNames{i};
                stats = obj.performanceData.statistics.(name);

                obj.logMessage(EdgeFMLLogger.INFO, ...
                    '%s: 调用次数=%d, 平均=%.4fs, 最小=%.4fs, 最大=%.4fs, 总计=%.4fs', ...
                    name, stats.count, stats.total/stats.count, stats.min, stats.max, stats.total);
            end

            obj.logMessage(EdgeFMLLogger.INFO, '=====================================');
        end

        function saveCheckpoint(obj, checkpointData, filename)
            % 保存检查点数据
            %
            % 输入:
            %   checkpointData - 检查点数据
            %   filename - 文件名

            try
                checkpointFile = fullfile(obj.logDirectory, filename);
                checkpointData.logTimestamp = datetime('now');
                save(checkpointFile, 'checkpointData', '-v7.3');

                obj.logMessage(EdgeFMLLogger.INFO, '检查点已保存: %s', checkpointFile);

            catch ME
                obj.logMessage(EdgeFMLLogger.ERROR, '保存检查点失败: %s', ME.message);
            end
        end

        function checkpointData = loadCheckpoint(obj, filename)
            % 加载检查点数据
            %
            % 输入:
            %   filename - 文件名
            %
            % 输出:
            %   checkpointData - 检查点数据

            checkpointFile = fullfile(obj.logDirectory, filename);

            try
                if exist(checkpointFile, 'file')
                    loadedData = load(checkpointFile);
                    checkpointData = loadedData.checkpointData;

                    obj.logMessage(EdgeFMLLogger.INFO, '检查点已加载: %s', checkpointFile);
                    obj.logMessage(EdgeFMLLogger.INFO, '检查点时间: %s', ...
                        char(checkpointData.logTimestamp));
                else
                    obj.logMessage(EdgeFMLLogger.WARNING, '检查点文件不存在: %s', checkpointFile);
                    checkpointData = [];
                end

            catch ME
                obj.logMessage(EdgeFMLLogger.ERROR, '加载检查点失败: %s', ME.message);
                checkpointData = [];
            end
        end

        function setLogLevel(obj, level)
            % 设置日志级别
            obj.logLevel = level;
            obj.logMessage(EdgeFMLLogger.INFO, '日志级别已更改为: %s', ...
                char(EdgeFMLLogger.LEVEL_NAMES(level)));
        end

        function enableDebugMode(obj, enable)
            % 启用/禁用调试模式
            obj.debugMode = enable;
            if enable
                obj.setLogLevel(EdgeFMLLogger.DEBUG);
                obj.logMessage(EdgeFMLLogger.INFO, '调试模式已启用');
            else
                obj.setLogLevel(EdgeFMLLogger.INFO);
                obj.logMessage(EdgeFMLLogger.INFO, '调试模式已禁用');
            end
        end
    end

    methods (Access = private)
        function obj = openLogFile(obj)
            % 打开日志文件
            if ~obj.enableFile
                return;
            end

            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            filename = sprintf('edge_fml_%s.log', timestamp);
            filepath = fullfile(obj.logDirectory, filename);

            try
                obj.logFile = fopen(filepath, 'w');
                if obj.logFile == -1
                    obj.logFile = [];
                    obj.enableFile = false;
                    obj.logMessage(EdgeFMLLogger.WARNING, '无法创建日志文件: %s', filepath);
                else
                    fprintf(obj.logFile, '========== Edge-FML 日志文件 ==========\n');
                    fprintf(obj.logFile, '创建时间: %s\n', datestr(now));
                    fprintf(obj.logFile, 'MATLAB版本: %s\n', version);
                end
            catch ME
                obj.logFile = [];
                obj.enableFile = false;
                obj.logMessage(EdgeFMLLogger.ERROR, '打开日志文件失败: %s', ME.message);
            end
        end

        function obj = rotateLogFile(obj)
            % 轮转日志文件
            if ~isempty(obj.logFile)
                return;
            end

            fprintf(obj.logFile, '\n========== 日志文件轮转 ==========\n');
            fclose(obj.logFile);

            % 重命名当前文件
            oldFile = obj.logFile.name;
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            newFile = sprintf('%s.rotated_%s', oldFile, timestamp);
            movefile(oldFile, newFile);

            % 打开新文件
            obj = obj.openLogFile();
        end

        function suggestion = getRecoverySuggestion(obj, identifier)
            % 根据错误标识符提供恢复建议
            %
            % 输入:
            %   identifier - 错误标识符
            %
            % 输出:
            %   suggestion - 恢复建议

            switch identifier
                case 'EdgeFML:InsufficientInput'
                    suggestion = '请检查所有必需的输入参数是否已提供';

                case 'EdgeFML:InvalidRegions'
                    suggestion = '请确保regions参数是有效的RegionConfig对象数组';

                case 'EdgeFML:ComponentInitializationFailed'
                    suggestion = '请检查系统依赖项和配置文件';

                case 'MTDMS_CMOEA:EvolutionFailed'
                    suggestion = '尝试减少种群大小或增加进化代数';

                case 'ClusterManager:ClusteringFailed'
                    suggestion = '尝试使用更简单的聚类算法或减少区域数量';

                case 'ObjectiveEvaluator:EvaluationFailed'
                    suggestion = '检查任务数据和区域配置的有效性';

                otherwise
                    suggestion = '';
            end
        end
    end
end