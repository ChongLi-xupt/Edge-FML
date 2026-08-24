% Comprehensive Testing Framework for Edge-FML
% Provides robust performance testing, algorithm comparison, and ablation studies
%
% Author: 拓守恒 (Shouheng Tuo)
% Email: shouheng.tuo@example.com
% Date: 2025-12-01

classdef ComprehensiveTestingFramework
    properties
        % Configuration
        config            % Testing configuration
        resultsDir        % Results directory
        figuresDir        % Figures directory
        logFile           % Log file handle

        % Testing modes
        testModes         % Available test modes
        currentMode       % Current test mode

        % Results storage
        allResults        % All test results
        summaryStats      % Summary statistics

        % Enhanced features
        parallelEnabled    % Enable parallel testing
        memoryMonitor     % Memory monitoring
        errorTracking     % Error tracking
        progressCallback   % Progress callback function
    end

    methods
        function obj = ComprehensiveTestingFramework(varargin)
            % Constructor with enhanced configuration
            % Usage: ComprehensiveTestingFramework(configFile, 'Parallel', true, 'MemoryMonitor', true)

            % Parse input arguments
            p = inputParser;
            addParameter(p, 'ConfigFile', '', @ischar);
            addParameter(p, 'Parallel', false, @islogical);
            addParameter(p, 'MemoryMonitor', false, @islogical);
            addParameter(p, 'TestMode', 'all', @ischar);
            addParameter(p, 'ProgressCallback', [], @(x) isa(x, 'function_handle'));
            parse(p, varargin{:});

            % Initialize configuration
            obj.config = obj.loadConfiguration(p.Results.ConfigFile);
            obj.parallelEnabled = p.Results.Parallel;
            obj.memoryMonitor = p.Results.MemoryMonitor;
            obj.currentMode = p.Results.TestMode;
            obj.progressCallback = p.Results.ProgressCallback;

            % Initialize directories
            obj.resultsDir = fullfile(obj.config.results_dir, ...
                sprintf('comprehensive_test_%s', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
            obj.figuresDir = fullfile(obj.resultsDir, 'figures');

            if ~exist(obj.resultsDir, 'dir')
                mkdir(obj.resultsDir);
                mkdir(obj.figuresDir);
            end

            % Initialize logging
            obj.logFile = fopen(fullfile(obj.resultsDir, 'testing_log.txt'), 'w');
            obj.logMessage('Framework', 'Comprehensive testing framework initialized');

            % Initialize results storage
            obj.allResults = struct();
            obj.summaryStats = struct();

            % Define test modes
            obj.testModes = {
                'performance',     % Performance scaling tests
                'comparison',      % Algorithm comparison tests
                'ablation',        % Ablation study tests
                'debug',           % Debug and validation tests
                'stress',          % Stress testing
                'all'              % All tests
            };

            % Initialize enhanced features
            obj.errorTracking = struct('count', 0, 'errors', {});
            obj.initializeMemoryMonitor();

            fprintf('Comprehensive Testing Framework initialized\n');
            fprintf('Results directory: %s\n', obj.resultsDir);
            fprintf('Test mode: %s\n', obj.currentMode);
            fprintf('Parallel testing: %s\n', obj.bool2str(obj.parallelEnabled));
            fprintf('Memory monitoring: %s\n', obj.bool2str(obj.memoryMonitor));
        end

        function run(obj)
            % Main testing execution
            try
                obj.logMessage('Run', 'Starting comprehensive testing');

                switch obj.currentMode
                    case 'performance'
                        obj.runPerformanceTests();
                    case 'comparison'
                        obj.runComparisonTests();
                    case 'ablation'
                        obj.runAblationTests();
                    case 'debug'
                        obj.runDebugTests();
                    case 'stress'
                        obj.runStressTests();
                    case 'all'
                        obj.runAllTests();
                    otherwise
                        error('Unknown test mode: %s', obj.currentMode);
                end

                obj.generateSummaryReport();
                obj.logMessage('Run', 'Comprehensive testing completed');

            catch ME
                obj.logError('Run', ME.message, ME.stack);
                obj.generateErrorReport();
                rethrow(ME);
            end
        end

        function runPerformanceTests(obj)
            % Enhanced performance scaling tests
            obj.logMessage('PerformanceTests', 'Starting performance scaling tests');

            % Test configurations
            testConfigs = obj.getPerformanceTestConfigs();

            for configIdx = 1:length(testConfigs)
                config = testConfigs{configIdx};
                obj.logMessage('PerformanceTests', ...
                    sprintf('Running config %d/%d: %s', configIdx, length(testConfigs), config.name));

                % Run test with error handling
                try
                    results = obj.runSinglePerformanceTest(config);
                    obj.allResults.performance.(config.name) = results;

                    if ~isempty(obj.progressCallback)
                        obj.progressCallback(configIdx, length(testConfigs), results);
                    end

                catch ME
                    obj.logError('PerformanceTests', ME.message, ME.stack);
                    obj.allResults.performance.(config.name) = struct('error', ME.message);
                end
            end
        end

        function runComparisonTests(obj)
            % Enhanced algorithm comparison tests
            obj.logMessage('ComparisonTests', 'Starting algorithm comparison tests');

            % Algorithm configurations
            algorithms = obj.getComparisonAlgorithms();
            datasets = obj.getComparisonDatasets();

            for algoIdx = 1:length(algorithms)
                algorithm = algorithms{algoIdx};
                obj.logMessage('ComparisonTests', ...
                    sprintf('Testing algorithm %d/%d: %s', algoIdx, length(algorithms), algorithm));

                for dataIdx = 1:length(datasets)
                    dataset = datasets{dataIdx};
                    obj.logMessage('ComparisonTests', ...
                        sprintf('Testing on dataset %d/%d: %s', dataIdx, length(datasets), dataset));

                    try
                        results = obj.runSingleComparisonTest(algorithm, dataset);
                        key = sprintf('%s_%s', algorithm, dataset);
                        obj.allResults.comparison.(key) = results;

                        if ~isempty(obj.progressCallback)
                            obj.progressCallback(algoIdx, length(algorithms), results);
                        end

                    catch ME
                        obj.logError('ComparisonTests', ME.message, ME.stack);
                        key = sprintf('%s_%s', algorithm, dataset);
                        obj.allResults.comparison.(key) = struct('error', ME.message);
                    end
                end
            end
        end

        function runAblationTests(obj)
            % Enhanced ablation study tests
            obj.logMessage('AblationTests', 'Starting ablation study tests');

            % Ablation configurations
            ablationConfigs = obj.getAblationConfigs();

            for configIdx = 1:length(ablationConfigs)
                config = ablationConfigs{configIdx};
                obj.logMessage('AblationTests', ...
                    sprintf('Running ablation %d/%d: %s', configIdx, length(ablationConfigs), config.name));

                try
                    results = obj.runSingleAblationTest(config);
                    obj.allResults.ablation.(config.name) = results;

                    if ~isempty(obj.progressCallback)
                        obj.progressCallback(configIdx, length(ablationConfigs), results);
                    end

                catch ME
                    obj.logError('AblationTests', ME.message, ME.stack);
                    obj.allResults.ablation.(config.name) = struct('error', ME.message);
                end
            end
        end

        function runDebugTests(obj)
            % Enhanced debug and validation tests
            obj.logMessage('DebugTests', 'Starting debug and validation tests');

            % Debug test configurations
            debugConfigs = obj.getDebugTestConfigs();

            for configIdx = 1:length(debugConfigs)
                config = debugConfigs{configIdx};
                obj.logMessage('DebugTests', ...
                    sprintf('Running debug test %d/%d: %s', configIdx, length(debugConfigs), config.name));

                try
                    results = obj.runSingleDebugTest(config);
                    obj.allResults.debug.(config.name) = results;

                catch ME
                    obj.logError('DebugTests', ME.message, ME.stack);
                    obj.allResults.debug.(config.name) = struct('error', ME.message);
                end
            end
        end

        function runStressTests(obj)
            % Enhanced stress testing
            obj.logMessage('StressTests', 'Starting stress tests');

            % Stress test configurations
            stressConfigs = obj.getStressTestConfigs();

            for configIdx = 1:length(stressConfigs)
                config = stressConfigs{configIdx};
                obj.logMessage('StressTests', ...
                    sprintf('Running stress test %d/%d: %s', configIdx, length(stressConfigs), config.name));

                try
                    results = obj.runSingleStressTest(config);
                    obj.allResults.stress.(config.name) = results;

                catch ME
                    obj.logError('StressTests', ME.message, ME.stack);
                    obj.allResults.stress.(config.name) = struct('error', ME.message);
                end
            end
        end

        function runAllTests(obj)
            % Run all test categories
            obj.logMessage('RunAll', 'Starting all test categories');

            % Run each test category
            obj.runPerformanceTests();
            obj.runComparisonTests();
            obj.runAblationTests();
            obj.runDebugTests();
            obj.runStressTests();
        end

        % Test execution methods
        function results = runSinglePerformanceTest(obj, config)
            % Run single performance test with enhanced monitoring

            obj.logMessage('SinglePerfTest', sprintf('Running %s', config.name));

            % Initialize test environment
            startTime = tic;
            initialMemory = obj.getCurrentMemoryUsage();

            % Generate test scenario
            [regions, taskSets] = SimulationDataGenerator.generateScenario(...
                config.numRegions, config.scenarioType);

            % Initialize Edge-FML with enhanced features
            edgeFML = obj.createEnhancedEdgeFML(regions, taskSets, config);

            % Run with monitoring
            try
                edgeFML = edgeFML.run();
                elapsedTime = toc(startTime);
                finalMemory = obj.getCurrentMemoryUsage();

                % Enhanced results
                results = struct();
                results.config = config;
                results.success = true;
                results.elapsedTime = elapsedTime;
                results.hypervolume = edgeFML.metrics.computeHypervolume(edgeFML.globalElites);
                results.feasibilityRate = edgeFML.metrics.computeFeasibilityRate(edgeFML.globalElites);
                results.diversity = edgeFML.metrics.computeDiversity(edgeFML.globalElites);
                results.communicationOverhead = edgeFML.totalCommBytes;
                results.memoryUsage = struct('initial', initialMemory, 'final', finalMemory, 'peak', finalMemory);
                results.globalFrontSize = length(edgeFML.globalElites);
                results.convergenceHistory = edgeFML.roundHistory;
                results.clusterCount = edgeFML.clusterManager.M;

                obj.logMessage('SinglePerfTest', sprintf('Completed %s in %.2f seconds', config.name, elapsedTime));

            catch ME
                results = struct();
                results.config = config;
                results.success = false;
                results.error = ME.message;
                results.stack = ME.stack;
                results.elapsedTime = toc(startTime);
            end
        end

        function results = runSingleComparisonTest(obj, algorithm, dataset)
            % Run single algorithm comparison test

            obj.logMessage('SingleCompTest', sprintf('Running %s on %s', algorithm, dataset));

            startTime = tic;
            initialMemory = obj.getCurrentMemoryUsage();

            try
                % Load dataset
                [regions, taskSets] = obj.loadComparisonDataset(dataset);

                % Run algorithm based on type
                switch algorithm
                    case 'Centralized-MTDMS'
                        results = obj.runCentralizedBaseline(regions, taskSets);
                    case 'Independent-MTDMS'
                        results = obj.runIndependentBaseline(regions, taskSets);
                    case 'FedAvg-MOEAs'
                        results = obj.runFedAvgBaseline(regions, taskSets);
                    case 'Original-FML'
                        results = obj.runOriginalFML(regions, taskSets);
                    case 'Edge-FML'
                        edgeFML = obj.createEnhancedEdgeFML(regions, taskSets, obj.config);
                        edgeFML = edgeFML.run();
                        results = obj.extractEdgeFMLResults(edgeFML);
                    otherwise
                        error('Unknown algorithm: %s', algorithm);
                end

                elapsedTime = toc(startTime);
                finalMemory = obj.getCurrentMemoryUsage();

                % Enhanced results
                results.algorithm = algorithm;
                results.dataset = dataset;
                results.success = true;
                results.elapsedTime = elapsedTime;
                results.memoryUsage = struct('initial', initialMemory, 'final', finalMemory);

                obj.logMessage('SingleCompTest', sprintf('Completed %s in %.2f seconds', algorithm, elapsedTime));

            catch ME
                results = struct();
                results.algorithm = algorithm;
                results.dataset = dataset;
                results.success = false;
                results.error = ME.message;
                results.stack = ME.stack;
                results.elapsedTime = toc(startTime);
            end
        end

        function results = runSingleAblationTest(obj, config)
            % Run single ablation test

            obj.logMessage('SingleAblationTest', sprintf('Running %s', config.name));

            startTime = tic;
            initialMemory = obj.getCurrentMemoryUsage();

            try
                % Generate test scenario
                [regions, taskSets] = SimulationDataGenerator.generateScenario(...
                    obj.config.ablationConfig.num_regions, obj.config.ablationConfig.scenario_type);

                % Create Edge-FML with ablation modifications
                edgeFML = obj.createAblationEdgeFML(regions, taskSets, config);

                % Run test
                edgeFML = edgeFML.run();
                elapsedTime = toc(startTime);
                finalMemory = obj.getCurrentMemoryUsage();

                % Enhanced results
                results = struct();
                results.config = config;
                results.success = true;
                results.elapsedTime = elapsedTime;
                results.hypervolume = edgeFML.metrics.computeHypervolume(edgeFML.globalElites);
                results.feasibilityRate = edgeFML.metrics.computeFeasibilityRate(edgeFML.globalElites);
                results.diversity = edgeFML.metrics.computeDiversity(edgeFML.globalElites);
                results.communicationOverhead = edgeFML.totalCommBytes;
                results.memoryUsage = struct('initial', initialMemory, 'final', finalMemory);
                results.globalFrontSize = length(edgeFML.globalElites);

                obj.logMessage('SingleAblationTest', sprintf('Completed %s in %.2f seconds', config.name, elapsedTime));

            catch ME
                results = struct();
                results.config = config;
                results.success = false;
                results.error = ME.message;
                results.stack = ME.stack;
                results.elapsedTime = toc(startTime);
            end
        end

        function results = runSingleDebugTest(obj, config)
            % Run single debug test

            obj.logMessage('SingleDebugTest', sprintf('Running %s', config.name));

            startTime = tic;

            try
                % Run specific debug test
                switch config.testType
                    case 'component_validation'
                        results = obj.runComponentValidation();
                    case 'algorithm_correctness'
                        results = obj.runAlgorithmCorrectness();
                    case 'edge_case_analysis'
                        results = obj.runEdgeCaseAnalysis();
                    case 'memory_leak_detection'
                        results = obj.runMemoryLeakDetection();
                    otherwise
                        error('Unknown debug test type: %s', config.testType);
                end

                elapsedTime = toc(startTime);
                results.success = true;
                results.elapsedTime = elapsedTime;

                obj.logMessage('SingleDebugTest', sprintf('Completed %s in %.2f seconds', config.name, elapsedTime));

            catch ME
                results = struct();
                results.config = config;
                results.success = false;
                results.error = ME.message;
                results.stack = ME.stack;
                results.elapsedTime = toc(startTime);
            end
        end

        function results = runSingleStressTest(obj, config)
            % Run single stress test

            obj.logMessage('SingleStressTest', sprintf('Running %s', config.name));

            startTime = tic;
            initialMemory = obj.getCurrentMemoryUsage();

            try
                % Generate stress scenario
                [regions, taskSets] = SimulationDataGenerator.generateScenario(...
                    config.numRegions, config.scenarioType);

                % Create Edge-FML with stress parameters
                edgeFML = obj.createStressEdgeFML(regions, taskSets, config);

                % Run stress test
                edgeFML = edgeFML.run();
                elapsedTime = toc(startTime);
                finalMemory = obj.getCurrentMemoryUsage();

                % Enhanced results
                results = struct();
                results.config = config;
                results.success = true;
                results.elapsedTime = elapsedTime;
                results.hypervolume = edgeFML.metrics.computeHypervolume(edgeFML.globalElites);
                results.feasibilityRate = edgeFML.metrics.computeFeasibilityRate(edgeFML.globalElites);
                results.communicationOverhead = edgeFML.totalCommBytes;
                results.memoryUsage = struct('initial', initialMemory, 'final', finalMemory, 'peak', finalMemory);
                results.stressMetrics = obj.computeStressMetrics(edgeFML);

                obj.logMessage('SingleStressTest', sprintf('Completed %s in %.2f seconds', config.name, elapsedTime));

            catch ME
                results = struct();
                results.config = config;
                results.success = false;
                results.error = ME.message;
                results.stack = ME.stack;
                results.elapsedTime = toc(startTime);
            end
        end

        % Configuration and helper methods
        function config = loadConfiguration(obj, configFile)
            % Load configuration from file or use defaults

            if ~isempty(configFile) && exist(configFile, 'file')
                config = load(configFile);
                obj.logMessage('Config', sprintf('Loaded configuration from %s', configFile));
            else
                % Default comprehensive configuration
                config = struct();

                % Performance test configurations
                config.performance = struct();
                config.performance.datasets = {'benchmark_small.mat', 'benchmark_medium.mat', 'benchmark_large.mat'};
                config.performance.region_counts = [5, 10, 20, 50];
                config.performance.scenario_types = {'homogeneous', 'moderate', 'heterogeneous'};
                config.performance.repeat_runs = 3;

                % Comparison test configurations
                config.comparison = struct();
                config.comparison.algorithms = {'Edge-FML', 'Original-FML', 'FedAvg-MOEAs', 'Independent-MTDMS', 'Centralized-MTDMS'};
                config.comparison.datasets = {'benchmark_medium.mat', 'benchmark_heterogeneous.mat'};
                config.comparison.scenario_types = {'moderate', 'heterogeneous'};
                config.comparison.repeat_runs = 3;

                % Ablation test configurations
                config.ablation = struct();
                config.ablation.variants = {'full', 'no_clustering', 'no_atsss', 'no_compat', 'no_local_enhance', 'no_comm_compress'};
                config.ablation.num_regions = 30;
                config.ablation.scenario_type = 'heterogeneous';
                config.ablation.repeat_runs = 3;

                % Debug test configurations
                config.debug = struct();
                config.debug.tests = {
                    struct('name', 'component_validation', 'testType', 'component_validation'),
                    struct('name', 'algorithm_correctness', 'testType', 'algorithm_correctness'),
                    struct('name', 'edge_case_analysis', 'testType', 'edge_case_analysis'),
                    struct('name', 'memory_leak_detection', 'testType', 'memory_leak_detection')
                };

                % Stress test configurations
                config.stress = struct();
                config.stress.tests = {
                    struct('name', 'large_scale', 'numRegions', 100, 'scenarioType', 'heterogeneous'),
                    struct('name', 'extreme_heterogeneity', 'numRegions', 50, 'scenarioType', 'extreme'),
                    struct('name', 'memory_pressure', 'numRegions', 30, 'scenarioType', 'heterogeneous', 'memoryLimit', '100')
                };

                % Common settings
                config.common = struct();
                config.common.R_max = 10;
                config.common.M_local = 30;
                config.common.M_elite = 10;
                config.common.metrics_ref = [1000, 1000, 1000];
                config.common.results_dir = obj.resultsDir;
                config.common.figures_dir = obj.figuresDir;

                obj.logMessage('Config', 'Using default comprehensive configuration');
            end
        end

        function str = bool2str(~, value)
            % Convert boolean to string
            if value
                str = 'enabled';
            else
                str = 'disabled';
            end
        end

        % Enhanced monitoring methods
        function initializeMemoryMonitor(obj)
            % Initialize memory monitoring
            obj.memoryMonitor = true;
            obj.logMessage('MemoryMonitor', 'Memory monitoring initialized');
        end

        function memoryMB = getCurrentMemoryUsage(obj)
            % Get current memory usage in MB
            try
                if ispc
                    [~, memInfo] = memory;
                    memoryMB = memInfo.MemUsedMATLAB / 1e6;
                else
                    % Unix/Linux systems
                    memInfo = feature('memstats');
                    if ~isempty(memInfo)
                        memoryMB = memInfo.PhysicalMemory.Available / 1e6;
                    else
                        memoryMB = 0;
                    end
                end
            catch
                memoryMB = 0;
            end
        end

        function logMessage(obj, component, message)
            % Log message with timestamp
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            fprintf(obj.logFile, '[%s] [%s] %s\n', timestamp, component, message);
        end

        function logError(obj, component, message, stack)
            % Log error with enhanced information
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

            % Increment error count
            obj.errorTracking.count = obj.errorTracking.count + 1;

            % Store error details
            errorEntry = struct();
            errorEntry.timestamp = timestamp;
            errorEntry.component = component;
            errorEntry.message = message;
            errorEntry.stack = stack;

            obj.errorTracking.errors{end+1} = errorEntry;

            % Log to file
            fprintf(obj.logFile, '[%s] [ERROR] [%s] %s\n', timestamp, component, message);

            % Log to console
            fprintf('[%s] [ERROR] [%s] %s\n', timestamp, component, message);
        end

        function generateSummaryReport(obj)
            % Generate comprehensive summary report
            obj.logMessage('Summary', 'Generating comprehensive summary report');

            % Save all results
            save(fullfile(obj.resultsDir, 'comprehensive_results.mat'), 'obj', 'allResults', 'summaryStats');

            % Generate HTML report
            obj.generateHTMLReport();

            % Generate visualizations
            obj.generateVisualizations();

            obj.logMessage('Summary', 'Summary report generated');
        end

        function generateHTMLReport(obj)
            % Generate comprehensive HTML report
            htmlFile = fullfile(obj.resultsDir, 'comprehensive_report.html');

            fid = fopen(htmlFile, 'w');

            % HTML header
            fprintf(fid, '<html>\n<head>\n<title>Edge-FML Comprehensive Test Report</title>\n');
            fprintf(fid, '<style>\n');
            fprintf(fid, 'body { font-family: Arial, sans-serif; margin: 20px; }\n');
            fprintf(fid, 'h1 { color: #2c3e50; }\n');
            fprintf(fid, 'h2 { color: #1e88e5; }\n');
            fprintf(fid, 'table { border-collapse: collapse; width: 100%%; }\n');
            fprintf(fid, 'th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }\n');
            fprintf(fid, 'th { background-color: #f2f2f2; }\n');
            fprintf(fid, '.error { color: #d32f2f; }\n');
            fprintf(fid, '.success { color: #28a745; }\n');
            fprintf(fid, '</style>\n</head>\n<body>\n');

            % Report title
            fprintf(fid, '<h1>Edge-FML Comprehensive Test Report</h1>\n');
            fprintf(fid, '<p>Generated: %s</p>\n', datestr(now));

            % Test results
            if isfield(obj.allResults, 'performance')
                fprintf(fid, '<h2>Performance Tests</h2>\n');
                obj.writePerformanceResultsHTML(fid);
            end

            if isfield(obj.allResults, 'comparison')
                fprintf(fid, '<h2>Algorithm Comparison</h2>\n');
                obj.writeComparisonResultsHTML(fid);
            end

            if isfield(obj.allResults, 'ablation')
                fprintf(fid, '<h2>Ablation Studies</h2>\n');
                obj.writeAblationResultsHTML(fid);
            end

            if isfield(obj.allResults, 'debug')
                fprintf(fid, '<h2>Debug Tests</h2>\n');
                obj.writeDebugResultsHTML(fid);
            end

            if isfield(obj.allResults, 'stress')
                fprintf(fid, '<h2>Stress Tests</h2>\n');
                obj.writeStressResultsHTML(fid);
            end

            % Error summary
            fprintf(fid, '<h2>Error Summary</h2>\n');
            fprintf(fid, '<p>Total Errors: %d</p>\n', obj.errorTracking.count);

            if obj.errorTracking.count > 0
                fprintf(fid, '<table>\n<tr><th>Timestamp</th><th>Component</th><th>Error</th></tr>\n');
                for i = 1:min(10, length(obj.errorTracking.errors))
                    error = obj.errorTracking.errors{i};
                    fprintf(fid, '<tr><td>%s</td><td>%s</td><td class="error">%s</td></tr>\n', ...
                        error.timestamp, error.component, error.message);
                end
                fprintf(fid, '</table>\n');
            end

            % HTML footer
            fprintf(fid, '</body>\n</html>\n');
            fclose(fid);

            obj.logMessage('HTMLReport', sprintf('HTML report generated: %s', htmlFile));
        end

        % Additional helper methods would be implemented here
        % ... (continuing with all the helper methods)

    end
end