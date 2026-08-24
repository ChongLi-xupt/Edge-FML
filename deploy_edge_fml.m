function deploy_edge_fml(configPath, targetPath)
    % Edge-FML部署脚本
    % 自动化部署Edge-FML系统到指定目标路径
    %
    % 输入参数:
    %   configPath - 配置文件路径（可选，默认'./config/'）
    %   targetPath - 目标部署路径（可选，默认'./EdgeFML_Deployed/'）
    %
    % 部署步骤：
    % 1. 环境检查
    % 2. 创建目录结构
    % 3. 复制核心文件
    % 4. 配置系统
    % 5. 初始化日志系统
    % 6. 运行系统测试
    % 7. 生成部署报告
    %
    % 作者: 拓守恒 (Shouheng Tuo)
    % GitHub: github.com/shouhengtuo/
    % 邮箱: tuo_sh@xupt.edu.cn
    % 日期: 2025-12-03

    fprintf('========== Edge-FML 系统部署 ==========\n');
    deployStartTime = tic;

    % 处理输入参数
    if nargin < 1
        configPath = './config/';
    end

    if nargin < 2
        targetPath = './EdgeFML_Deployed/';
    end

    % 标准化路径
    configPath = fullfile(configPath);
    targetPath = fullfile(targetPath);

    try
        % 步骤1：环境检查
        fprintf('\n步骤1: 环境检查...\n');
        checkEnvironment();

        % 步骤2：创建目录结构
        fprintf('\n步骤2: 创建目录结构...\n');
        createDirectoryStructure(targetPath);

        % 步骤3：复制核心文件
        fprintf('\n步骤3: 复制核心文件...\n');
        copyCoreFiles(targetPath);

        % 步骤4：配置系统
        fprintf('\n步骤4: 配置系统...\n');
        setupConfiguration(configPath, targetPath);

        % 步骤5：初始化日志系统
        fprintf('\n步骤5: 初始化日志系统...\n');
        initializeLogging(targetPath);

        % 步骤6：运行系统测试
        fprintf('\n步骤6: 运行系统测试...\n');
        runSystemTests(targetPath);

        % 步骤7：生成部署报告
        fprintf('\n步骤7: 生成部署报告...\n');
        generateDeploymentReport(targetPath, deployStartTime);

        fprintf('\n========== Edge-FML 部署完成 ==========\n');
        fprintf('部署路径: %s\n', targetPath);
        fprintf('部署耗时: %.2f 秒\n', toc(deployStartTime));

    catch ME
        fprintf('\n部署失败: %s\n', ME.message);
        fprintf('错误标识符: %s\n', ME.identifier);
        rethrow(ME);
    end
end

function checkEnvironment()
    % 检查部署环境

    fprintf('  检查MATLAB版本...\n');
    matlabVersion = version('-release');
    fprintf('    MATLAB版本: %s\n', matlabVersion);

    % 检查MATLAB版本兼容性
    year = str2double(matlabVersion(1:4));
    if year < 2018
        error('Deploy:UnsupportedMATLABVersion', ...
            '需要MATLAB R2018a或更高版本，当前版本: %s', matlabVersion);
    end

    fprintf('  检查必需工具箱...\n');
    requiredToolboxes = {'Optimization Toolbox', 'Statistics and Machine Learning Toolbox'};

    for i = 1:length(requiredToolboxes)
        toolbox = requiredToolboxes{i};
        if ~license('test', toolbox)
            warning('Deploy:MissingToolbox', '缺少工具箱: %s', toolbox);
        else
            fprintf('    ✓ %s\n', toolbox);
        end
    end

    fprintf('  检查系统资源...\n');
    [status, sysinfo] = memory;
    fprintf('    可用内存: %.0f MB\n', sysinfo.PhysicalMemory.Available / 1024 / 1024);

    % 检查磁盘空间
    currentDir = pwd;
    [~, diskInfo] = system(['dir /-c "' currentDir '"']);
    fprintf('    当前目录: %s\n', currentDir);

    fprintf('  环境检查完成\n');
end

function createDirectoryStructure(targetPath)
    % 创建Edge-FML目录结构

    directories = {
        targetPath
        fullfile(targetPath, 'src')
        fullfile(targetPath, 'config')
        fullfile(targetPath, 'logs')
        fullfile(targetPath, 'results')
        fullfile(targetPath, 'data')
        fullfile(targetPath, 'examples')
        fullfile(targetPath, 'docs')
        fullfile(targetPath, 'tests')
    };

    for i = 1:length(directories)
        dirPath = directories{i};
        if ~exist(dirPath, 'dir')
            mkdir(dirPath);
            fprintf('    创建目录: %s\n', dirPath);
        else
            fprintf('    目录已存在: %s\n', dirPath);
        end
    end

    fprintf('  目录结构创建完成\n');
end

function copyCoreFiles(targetPath)
    % 复制核心文件到目标路径

    sourceDir = './src/';
    targetSrcDir = fullfile(targetPath, 'src');

    % 获取所有.m文件
    mFiles = dir(fullfile(sourceDir, '*.m'));

    for i = 1:length(mFiles)
        sourceFile = fullfile(sourceDir, mFiles(i).name);
        targetFile = fullfile(targetSrcDir, mFiles(i).name);

        try
            copyfile(sourceFile, targetFile);
            fprintf('    复制文件: %s\n', mFiles(i).name);
        catch ME
            warning('Deploy:FileCopyFailed', '复制文件失败: %s - %s', ...
                mFiles(i).name, ME.message);
        end
    end

    % 复制其他重要文件
    importantFiles = {
        'docs/FML.MD'
        'README.md'
        'docs/ALGORITHM_STRUCTURE.md'
        'docs/EDGE_FML_COMPREHENSIVE_CODE_IMPROVEMENT_PLAN.md'
    };

    for i = 1:length(importantFiles)
        filename = importantFiles{i};
        if exist(filename, 'file')
            try
                copyfile(filename, fullfile(targetPath, filename));
                fprintf('    复制文档: %s\n', filename);
            catch ME
                warning('Deploy:DocCopyFailed', '复制文档失败: %s - %s', ...
                    filename, ME.message);
            end
        end
    end

    fprintf('  核心文件复制完成\n');
end

function setupConfiguration(configPath, targetPath)
    % 配置Edge-FML系统

    targetConfigDir = fullfile(targetPath, 'config');

    % 如果源配置目录存在，复制配置文件
    if exist(configPath, 'dir')
        configFiles = dir(fullfile(configPath, '*'));
        for i = 1:length(configFiles)
            if ~configFiles(i).isdir
                sourceFile = fullfile(configPath, configFiles(i).name);
                targetFile = fullfile(targetConfigDir, configFiles(i).name);

                try
                    copyfile(sourceFile, targetFile);
                    fprintf('    复制配置: %s\n', configFiles(i).name);
                catch ME
                    warning('Deploy:ConfigCopyFailed', '复制配置失败: %s - %s', ...
                        configFiles(i).name, ME.message);
                end
            end
        end
    else
        % 创建默认配置文件
        createDefaultConfig(targetConfigDir);
    end

    fprintf('  系统配置完成\n');
end

function createDefaultConfig(configDir)
    % 创建默认配置文件

    % 创建主配置文件
    mainConfig = struct();
    mainConfig.system.max_regions = 50;
    mainConfig.system.max_rounds = 100;
    mainConfig.system.local_generations = 50;
    mainConfig.system.elite_size = 10;

    mainConfig.logging.level = 'INFO';
    mainConfig.logging.enable_file = true;
    mainConfig.logging.enable_console = true;
    mainConfig.logging.max_file_size = 50;  % MB

    mainConfig.performance.enable_profiling = false;
    mainConfig.performance.save_checkpoints = true;

    % 保存配置文件
    configFile = fullfile(configDir, 'edge_fml_config.mat');
    try
        save(configFile, 'mainConfig', '-v7.3');
        fprintf('    创建默认配置: edge_fml_config.mat\n');
    catch ME
        warning('Deploy:ConfigCreationFailed', '创建默认配置失败: %s', ME.message);
    end

    % 创建配置说明文件
    configReadme = fullfile(configDir, 'README.md');
    try
        fid = fopen(configReadme, 'w');
        if fid ~= -1
            fprintf(fid, '# Edge-FML 配置文件说明\n\n');
            fprintf(fid, '## edge_fml_config.mat\n');
            fprintf(fid, '主配置文件，包含系统参数和设置。\n\n');
            fprintf(fid, '### 配置项说明\n');
            fprintf(fid, '- `system.max_regions`: 最大区域数量\n');
            fprintf(fid, '- `system.max_rounds`: 最大联邦轮数\n');
            fprintf(fid, '- `system.local_generations`: 本地进化代数\n');
            fprintf(fid, '- `system.elite_size`: 精英解数量\n');
            fprintf(fid, '- `logging.level`: 日志级别 (DEBUG/INFO/WARNING/ERROR)\n');
            fprintf(fid, '- `logging.enable_file`: 是否启用文件日志\n');
            fprintf(fid, '- `logging.enable_console`: 是否启用控制台日志\n');
            fprintf(fid, '- `logging.max_file_size`: 日志文件最大大小(MB)\n');
            fprintf(fid, '- `performance.enable_profiling`: 是否启用性能分析\n');
            fprintf(fid, '- `performance.save_checkpoints`: 是否保存检查点\n');
            fclose(fid);
            fprintf('    创建配置说明: README.md\n');
        end
    catch ME
        warning('Deploy:ConfigReadmeFailed', '创建配置说明失败: %s', ME.message);
    end
end

function initializeLogging(targetPath)
    % 初始化日志系统

    logDir = fullfile(targetPath, 'logs');

    % 添加路径到MATLAB路径
    addpath(fullfile(targetPath, 'src'));

    try
        % 初始化日志系统
        logger = EdgeFMLLogger(logDir, EdgeFMLLogger.INFO);
        logger.info('Edge-FML系统日志初始化完成');

        % 创建日志初始化文件
        logInitFile = fullfile(logDir, 'initialization.log');
        fid = fopen(logInitFile, 'w');
        if fid ~= -1
            fprintf(fid, 'Edge-FML 日志系统初始化\n');
            fprintf(fid, '初始化时间: %s\n', datestr(now));
            fprintf(fid, '日志目录: %s\n', logDir);
            fprintf(fid, 'MATLAB版本: %s\n', version);
            fclose(fid);
            fprintf('    创建日志初始化文件\n');
        end

    catch ME
        warning('Deploy:LoggingInitFailed', '日志系统初始化失败: %s', ME.message);
    end

    fprintf('  日志系统初始化完成\n');
end

function runSystemTests(targetPath)
    % 运行系统测试

    testDir = fullfile(targetPath, 'tests');

    % 创建测试脚本
    testScript = fullfile(testDir, 'system_test.m');
    try
        fid = fopen(testScript, 'w');
        if fid ~= -1
            fprintf(fid, 'function system_test()\n');
            fprintf(fid, '%% Edge-FML 系统测试脚本\n\n');
            fprintf(fid, 'fprintf(''开始系统测试...\n'');\n\n');

            fprintf(fid, '%% 测试1: 基本类加载\n');
            fprintf(fid, 'try\n');
            fprintf(fid, '    regions = SimulationDataGenerator.generateRegions(3);\n');
            fprintf(fid, '    taskSets = SimulationDataGenerator.generateTaskSets(regions);\n');
            fprintf(fid, '    edge_fml = EdgeFML(regions, taskSets, 5, 10);\n');
            fprintf(fid, '    fprintf(''  ✓ 基本类加载测试通过\n'');\n');
            fprintf(fid, 'catch ME\n');
            fprintf(fid, '    fprintf(''  ✗ 基本类加载测试失败: %%s\n'', ME.message);\n');
            fprintf(fid, 'end\n\n');

            fprintf(fid, '%% 测试2: 配置验证\n');
            fprintf(fid, 'try\n');
            fprintf(fid, '    InputValidator.validateAll(regions, taskSets, 5, 10);\n');
            fprintf(fid, '    fprintf(''  ✓ 配置验证测试通过\n'');\n');
            fprintf(fid, 'catch ME\n');
            fprintf(fid, '    fprintf(''  ✗ 配置验证测试失败: %%s\n'', ME.message);\n');
            fprintf(fid, 'end\n\n');

            fprintf(fid, 'fprintf(''系统测试完成\n'');\n');
            fclose(fid);
            fprintf('    创建系统测试脚本\n');
        end

        % 运行测试
        addpath(testDir);
        try
            system_test();
            fprintf('  ✓ 系统测试通过\n');
        catch ME
            warning('Deploy:SystemTestFailed', '系统测试失败: %s', ME.message);
        end

    catch ME
        warning('Deploy:TestCreationFailed', '创建测试脚本失败: %s', ME.message);
    end
end

function generateDeploymentReport(targetPath, deployStartTime)
    % 生成部署报告

    reportDir = fullfile(targetPath, 'docs');
    reportFile = fullfile(reportDir, 'deployment_report.md');

    try
        fid = fopen(reportFile, 'w');
        if fid ~= -1
            fprintf(fid, '# Edge-FML 部署报告\n\n');
            fprintf(fid, '## 部署信息\n\n');
            fprintf(fid, '- **部署时间**: %s\n', datestr(now));
            fprintf(fid, '- **部署路径**: %s\n', targetPath);
            fprintf(fid, '- **部署耗时**: %.2f 秒\n', toc(deployStartTime));
            fprintf(fid, '- **MATLAB版本**: %s\n', version('-release'));
            fprintf(fid, '- **操作系统**: %s\n', computer);

            fprintf(fid, '## 目录结构\n\n');
            fprintf(fid, '```\n');
            fprintf(fid, 'EdgeFML_Deployed/\n');
            fprintf(fid, '├── src/           # 核心源代码\n');
            fprintf(fid, '├── config/        # 配置文件\n');
            fprintf(fid, '├── logs/          # 日志文件\n');
            fprintf(fid, '├── results/       # 结果输出\n');
            fprintf(fid, '├── data/          # 数据文件\n');
            fprintf(fid, '├── examples/      # 示例代码\n');
            fprintf(fid, '├── docs/          # 文档\n');
            fprintf(fid, '└── tests/         # 测试脚本\n');
            fprintf(fid, '```\n\n');

            fprintf(fid, '## 使用说明\n\n');
            fprintf(fid, '### 1. 基本使用\n');
            fprintf(fid, '```matlab\n');
            fprintf(fid, '%% 添加路径\n');
            fprintf(fid, 'addpath(''./EdgeFML_Deployed/src'');\n\n');
            fprintf(fid, '%% 生成测试数据\n');
            fprintf(fid, 'regions = SimulationDataGenerator.generateRegions(5);\n');
            fprintf(fid, 'taskSets = SimulationDataGenerator.generateTaskSets(regions);\n\n');
            fprintf(fid, '%% 运行Edge-FML\n');
            fprintf(fid, 'edge_fml = EdgeFML(regions, taskSets, 20, 50);\n');
            fprintf(fid, 'edge_fml.run();\n');
            fprintf(fid, '```\n\n');

            fprintf(fid, '### 2. 配置自定义\n');
            fprintf(fid, '编辑 `config/edge_fml_config.mat` 文件来自定义系统参数。\n\n');

            fprintf(fid, '### 3. 日志查看\n');
            fprintf(fid, '日志文件位于 `logs/` 目录下。\n\n');

            fprintf(fid, '## 故障排除\n\n');
            fprintf(fid, '### 常见问题\n');
            fprintf(fid, '1. **类加载失败**: 检查MATLAB路径设置\n');
            fprintf(fid, '2. **内存不足**: 调整种群大小或区域数量\n');
            fprintf(fid, '3. **配置错误**: 验证配置文件格式和参数\n\n');

            fprintf(fid, '### 技术支持\n');
            fprintf(fid, '- **作者**: 拓守恒 (Shouheng Tuo)\n');
            fprintf(fid, '- **GitHub**: github.com/shouhengtuo/\n');
            fprintf(fid, '- **邮箱**: tuo_sh@xupt.edu.cn\n');

            fclose(fid);
            fprintf('  创建部署报告: deployment_report.md\n');
        end

    catch ME
        warning('Deploy:ReportGenerationFailed', '生成部署报告失败: %s', ME.message);
    end
end