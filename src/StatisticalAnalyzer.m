classdef StatisticalAnalyzer
    % StatisticalAnalyzer - Comprehensive statistical analysis for Edge-FML results
    % Provides significance testing, effect size calculation, and statistical reporting
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Statistical Analysis Framework

    properties
        % Analysis settings
        confidenceLevel   % Confidence level for statistical tests (default: 0.05)
        effectSizeThreshold % Threshold for practical significance
        multipleComparisonMethod % Method for multiple comparison correction

        % Test selection
        normalityTest    % Test for normality ('shapiro-wilk', 'kolmogorov-smirnov', 'anderson-darling')
        varianceTest     % Test for equal variances ('levene', 'bartlett', 'brown-forsythe')

        % Output settings
        verbose          % Enable detailed output
        saveResults      % Save statistical results to file
        outputPath       % Path for saving results

        % Statistical methods
        nonParametricTests % Enable non-parametric tests
        bootstrapSamples  % Number of bootstrap samples for robust statistics
        permutationTests   % Enable permutation tests
    end

    methods
        function obj = StatisticalAnalyzer(varargin)
            % Constructor with customizable settings
            % Usage: StatisticalAnalyzer('ConfidenceLevel', 0.01, 'Verbose', true)

            % Parse input arguments
            p = inputParser;
            addParameter(p, 'ConfidenceLevel', 0.05, @(x) isnumeric(x) && x > 0 && x < 1);
            addParameter(p, 'EffectSizeThreshold', 0.5, @isnumeric);
            addParameter(p, 'MultipleComparisonMethod', 'bonferroni', @ischar);
            addParameter(p, 'NormalityTest', 'shapiro-wilk', @ischar);
            addParameter(p, 'VarianceTest', 'levene', @ischar);
            addParameter(p, 'Verbose', true, @islogical);
            addParameter(p, 'SaveResults', true, @islogical);
            addParameter(p, 'OutputPath', './statistical_results/', @ischar);
            addParameter(p, 'NonParametricTests', true, @islogical);
            addParameter(p, 'BootstrapSamples', 1000, @isnumeric);
            addParameter(p, 'PermutationTests', true, @islogical);
            parse(p, varargin{:});

            % Initialize settings
            obj.confidenceLevel = p.Results.ConfidenceLevel;
            obj.effectSizeThreshold = p.Results.EffectSizeThreshold;
            obj.multipleComparisonMethod = p.Results.MultipleComparisonMethod;
            obj.normalityTest = p.Results.NormalityTest;
            obj.varianceTest = p.Results.VarianceTest;
            obj.verbose = p.Results.Verbose;
            obj.saveResults = p.Results.SaveResults;
            obj.outputPath = p.Results.OutputPath;
            obj.nonParametricTests = p.Results.NonParametricTests;
            obj.bootstrapSamples = p.Results.BootstrapSamples;
            obj.permutationTests = p.Results.PermutationTests;

            % Create output directory if needed
            if obj.saveResults && ~exist(obj.outputPath, 'dir')
                mkdir(obj.outputPath);
            end

            if obj.verbose
                fprintf('Statistical Analyzer initialized\n');
                fprintf('Confidence level: %.3f\n', obj.confidenceLevel);
                fprintf('Effect size threshold: %.3f\n', obj.effectSizeThreshold);
                fprintf('Multiple comparison method: %s\n', obj.multipleComparisonMethod);
            end
        end

        function results = compareAlgorithms(obj, algorithmResults, varargin)
            % Comprehensive algorithm comparison with statistical testing
            % Usage: results = compareAlgorithms(results, 'Metrics', {'HV', 'Feasibility'})

            p = inputParser;
            addParameter(p, 'Metrics', {'HV', 'FeasibilityRate', 'CommunicationOverhead'}, @iscell);
            addParameter(p, 'TestType', 'auto', @ischar); % 'parametric', 'nonparametric', 'auto'
            addParameter(p, 'EffectSize', true, @islogical);
            addParameter(p, 'PowerAnalysis', false, @islogical);
            addParameter(p, 'BootstrapCI', false, @islogical);
            parse(p, varargin{:});

            % Extract algorithm names and data
            algorithms = fieldnames(algorithmResults);
            metrics = p.Results.Metrics;

            % Initialize results structure
            results = struct();
            results.algorithms = algorithms;
            results.metrics = metrics;
            results.summary = struct();
            results.detailedTests = struct();
            results.effectSizes = struct();
            results.powerAnalysis = struct();
            results.recommendations = struct();

            % Perform analysis for each metric
            for i = 1:length(metrics)
                metric = metrics{i};
                if obj.verbose
                    fprintf('\nAnalyzing metric: %s\n', metric);
                end

                % Extract data for current metric
                data = obj.extractMetricData(algorithmResults, algorithms, metric);

                % Check data validity
                if obj.validateData(data, algorithms)
                    % Determine appropriate test
                    testType = obj.determineTestType(data, p.Results.TestType);

                    % Perform statistical tests
                    [testResults, detailedTests] = obj.performStatisticalTests(data, algorithms, testType, metric);

                    % Calculate effect sizes
                    effectSizes = obj.calculateEffectSizes(data, algorithms, metric);

                    % Power analysis (if requested)
                    if p.Results.PowerAnalysis
                        powerResults = obj.performPowerAnalysis(data, algorithms, metric);
                    else
                        powerResults = [];
                    end

                    % Bootstrap confidence intervals (if requested)
                    if p.Results.BootstrapCI
                        bootstrapResults = obj.performBootstrapAnalysis(data, algorithms, metric);
                    else
                        bootstrapResults = [];
                    end

                    % Store results
                    results.summary.(metric) = testResults;
                    results.detailedTests.(metric) = detailedTests;
                    results.effectSizes.(metric) = effectSizes;
                    if ~isempty(powerResults)
                        results.powerAnalysis.(metric) = powerResults;
                    end
                    if ~isempty(bootstrapResults)
                        results.bootstrapCI.(metric) = bootstrapResults;
                    end

                    % Generate recommendations
                    results.recommendations.(metric) = obj.generateRecommendations(testResults, effectSizes, algorithms);

                    if obj.verbose
                        obj.printMetricSummary(metric, testResults, effectSizes, algorithms);
                    end
                else
                    if obj.verbose
                        fprintf('Warning: Invalid data for metric %s, skipping analysis\n', metric);
                    end
                end
            end

            % Overall recommendations
            results.overallRecommendations = obj.generateOverallRecommendations(results);

            % Save results if requested
            if obj.saveResults
                obj.saveStatisticalResults(results, 'algorithm_comparison');
            end
        end

        function results = analyzeAblationStudy(obj, ablationResults, varargin)
            % Statistical analysis for ablation studies
            % Usage: results = analyzeAblationStudy(results, 'Baseline', 'full_fml')

            p = inputParser;
            addParameter(p, 'Baseline', 'full_fml', @ischar);
            addParameter(p, 'Metrics', {'HV', 'FeasibilityRate', 'CommunicationOverhead'}, @iscell);
            addParameter(p, 'RelativeImprovement', true, @islogical);
            addParameter(p, 'StatisticalSignificance', true, @islogical);
            parse(p, varargin{:});

            baseline = p.Results.Baseline;
            metrics = p.Results.Metrics;

            % Initialize results
            results = struct();
            results.baseline = baseline;
            results.variants = fieldnames(ablationResults);
            results.metrics = metrics;
            results.comparisons = struct();
            results.significance = struct();
            recommendations = {};

            % Extract baseline data
            baselineData = obj.extractMetricData(ablationResults, {baseline}, metrics);

            % Compare each variant with baseline
            for i = 1:length(results.variants)
                variant = results.variants{i};
                if strcmp(variant, baseline)
                    continue;  % Skip baseline comparison with itself
                end

                variantData = obj.extractMetricData(ablationResults, {variant}, metrics);

                for j = 1:length(metrics)
                    metric = metrics{j};

                    % Calculate relative improvement
                    if p.Results.RelativeImprovement
                        improvement = obj.calculateRelativeImprovement(baselineData.(baseline).(metric), variantData.(variant).(metric));
                    else
                        improvement = variantData.(variant).(metric) - baselineData.(baseline).(metric);
                    end

                    % Statistical significance test
                    if p.Results.StatisticalSignificance
                        sigTest = obj.performTwoSampleTest(baselineData.(baseline).(metric), variantData.(variant).(metric));
                    else
                        sigTest = struct();
                    end

                    % Store results
                    results.comparisons.(variant).(metric) = improvement;
                    results.significance.(variant).(metric) = sigTest;

                    % Generate recommendation
                    if sigTest.pvalue < obj.confidenceLevel && abs(improvement) > obj.effectSizeThreshold
                        if improvement > 0
                            recommendations{end+1} = sprintf('Variant %s significantly improves %s by %.3f', variant, metric, improvement);
                        else
                            recommendations{end+1} = sprintf('Variant %s significantly degrades %s by %.3f', variant, metric, abs(improvement));
                        end
                    end
                end
            end

            results.recommendations = recommendations;

            % Save results if requested
            if obj.saveResults
                obj.saveStatisticalResults(results, 'ablation_study');
            end
        end

        function results = analyzePerformanceScaling(obj, scalingResults, varargin)
            % Statistical analysis of performance scaling experiments
            % Usage: results = analyzePerformanceScaling(results, 'TrendAnalysis', true)

            p = inputParser;
            addParameter(p, 'Metrics', {'HV', 'Time', 'Memory'}, @iscell);
            addParameter(p, 'TrendAnalysis', true, @islogical);
            addParameter(p, 'CorrelationAnalysis', true, @islogical);
            addParameter(p, 'EfficiencyAnalysis', true, @islogical);
            parse(p, varargin{:});

            metrics = p.Results.Metrics;

            % Initialize results
            results = struct();
            results.metrics = metrics;
            results.trends = struct();
            results.correlations = struct();
            results.efficiency = struct();

            % Extract scaling data
            scales = fieldnames(scalingResults);
            scaleValues = cellfun(@(x) str2double(regexp(x, '\d+', 'match', 'once')), scales, 'UniformOutput', false);
            scaleValues = cellfun(@str2double, scaleValues, 'UniformOutput', true);
            [scaleValues, sortIdx] = sort(scaleValues);
            scales = scales(sortIdx);

            for i = 1:length(metrics)
                metric = metrics{i};

                % Extract metric values across scales
                metricValues = zeros(length(scales), 1);
                for j = 1:length(scales)
                    if isfield(scalingResults.(scales{j}), metric)
                        metricValues(j) = scalingResults.(scales{j}).(metric);
                    end
                end

                % Trend analysis
                if p.Results.TrendAnalysis
                    results.trends.(metric) = obj.analyzeTrend(scaleValues, metricValues);
                end

                % Correlation analysis
                if p.Results.CorrelationAnalysis
                    results.correlations.(metric) = obj.analyzeCorrelation(scaleValues, metricValues);
                end

                % Efficiency analysis
                if p.Results.EfficiencyAnalysis
                    results.efficiency.(metric) = obj.analyzeEfficiency(scaleValues, metricValues);
                end
            end

            % Save results if requested
            if obj.saveResults
                obj.saveStatisticalResults(results, 'performance_scaling');
            end
        end

        function results = performRobustnessAnalysis(obj, results, varargin)
            % Robustness analysis using bootstrap and permutation tests
            % Usage: results = performRobustnessAnalysis(results, 'BootstrapSamples', 2000)

            p = inputParser;
            addParameter(p, 'BootstrapSamples', obj.bootstrapSamples, @isnumeric);
            addParameter(p, 'PermutationSamples', 1000, @isnumeric);
            addParameter(p, 'ConfidenceLevel', obj.confidenceLevel, @isnumeric);
            parse(p, varargin{:});

            nBootstrap = p.Results.BootstrapSamples;
            nPermutation = p.Results.PermutationSamples;
            confLevel = p.Results.ConfidenceLevel;

            % Initialize results
            results = struct();
            results.bootstrap = struct();
            results.permutation = struct();
            results.robustness = struct();

            % Extract data for analysis
            if isfield(results, 'algorithmResults')
                algorithms = fieldnames(results.algorithmResults);
                metrics = {'HV', 'FeasibilityRate', 'CommunicationOverhead'};

                for i = 1:length(metrics)
                    metric = metrics{i};

                    % Bootstrap analysis
                    if obj.nonParametricTests
                        bootstrapResults = obj.performBootstrapAnalysis(results.algorithmResults, algorithms, metric, nBootstrap, confLevel);
                        results.bootstrap.(metric) = bootstrapResults;
                    end

                    % Permutation tests
                    if obj.permutationTests
                        permutationResults = obj.performPermutationTests(results.algorithmResults, algorithms, metric, nPermutation);
                        results.permutation.(metric) = permutationResults;
                    end

                    % Robustness assessment
                    results.robustness.(metric) = obj.assessRobustness(results.bootstrap.(metric), results.permutation.(metric));
                end
            end

            % Save results if requested
            if obj.saveResults
                obj.saveStatisticalResults(results, 'robustness_analysis');
            end
        end

        function report = generateStatisticalReport(obj, allResults, varargin)
            % Generate comprehensive statistical report
            % Usage: report = generateStatisticalReport(results, 'Format', 'html', 'SaveAs', 'statistical_report.html')

            p = inputParser;
            addParameter(p, 'Format', 'html', @ischar);
            addParameter(p, 'SaveAs', 'statistical_report.html', @ischar);
            addParameter(p, 'IncludePlots', true, @islogical);
            addParameter(p, 'IncludeRawData', false, @islogical);
            parse(p, varargin{:});

            switch lower(p.Results.Format)
                case 'html'
                    report = obj.generateHTMLStatisticalReport(allResults, p.Results.SaveAs, p.Results.IncludePlots, p.Results.IncludeRawData);
                case 'latex'
                    report = obj.generateLatexStatisticalReport(allResults, p.Results.SaveAs, p.Results.IncludePlots, p.Results.IncludeRawData);
                case 'markdown'
                    report = obj.generateMarkdownStatisticalReport(allResults, p.Results.SaveAs, p.Results.IncludePlots, p.Results.IncludeRawData);
                otherwise
                    error('Unknown format: %s', p.Results.Format);
            end
        end

        % Private helper methods
        function data = extractMetricData(~, results, algorithms, metric)
            % Extract metric data from results structure
            data = struct();
            for i = 1:length(algorithms)
                algorithm = algorithms{i};
                if isfield(results.(algorithm), metric)
                    data.(algorithm) = results.(algorithm).(metric);
                elseif isfield(results.(algorithm), lower(metric))
                    data.(algorithm) = results.(algorithm).(lower(metric));
                else
                    data.(algorithm) = [];
                end
            end
        end

        function isValid = validateData(~, data, algorithms)
            % Validate data for statistical analysis
            isValid = true;

            for i = 1:length(algorithms)
                algorithm = algorithms{i};
                if isempty(data.(algorithm)) || length(data.(algorithm)) < 3
                    isValid = false;
                    if obj.verbose
                        fprintf('Invalid data for algorithm %s: insufficient samples\n', algorithm);
                    end
                    break;
                end
            end
        end

        function testType = determineTestType(obj, data, specifiedType)
            % Determine appropriate statistical test type
            if ~strcmp(specifiedType, 'auto')
                testType = specifiedType;
                return;
            end

            % Check normality for each algorithm
            normalityResults = struct();
            algorithms = fieldnames(data);

            for i = 1:length(algorithms)
                algorithm = algorithms{i};
                normalityResults.(algorithm) = obj.testNormality(data.(algorithm));
            end

            % Check if all algorithms have normal distributions
            allNormal = true;
            for i = 1:length(algorithms)
                if normalityResults.(algorithms{i}).pvalue < obj.confidenceLevel
                    allNormal = false;
                    break;
                end
            end

            if allNormal
                testType = 'parametric';
            else
                testType = 'nonparametric';
            end

            if obj.verbose
                fprintf('Selected test type: %s\n', testType);
            end
        end

        function [testResults, detailedTests] = performStatisticalTests(obj, data, algorithms, testType, metric)
            % Perform appropriate statistical tests
            detailedTests = struct();

            if length(algorithms) == 2
                % Two-sample tests
                [testResults, detailedTests] = obj.performTwoSampleComparison(data, algorithms, testType);
            else
                % Multiple-sample tests
                [testResults, detailedTests] = obj.performMultipleSampleComparison(data, algorithms, testType);
            end

            % Add metric information
            testResults.metric = metric;
            testResults.testType = testType;
            testResults.algorithms = algorithms;
        end

        function [testResults, detailedTests] = performTwoSampleComparison(obj, data, algorithms, testType)
            % Perform two-sample statistical comparison
            alg1 = algorithms{1};
            alg2 = algorithms{2};
            data1 = data.(alg1);
            data2 = data.(alg2);

            detailedTests = struct();

            switch lower(testType)
                case 'parametric'
                    % t-test
                    [h, p, ci, stats] = ttest2(data1, data2);
                    testResults.test = 't-test';
                    testResults.pvalue = p;
                    testResults.confidenceInterval = ci;
                    testResults.testStatistic = stats.tstat;
                    testResults.degreesOfFreedom = stats.df;

                    % Effect size (Cohen's d)
                    pooledStd = sqrt(((length(data1)-1)*var(data1) + (length(data2)-1)*var(data2)) / (length(data1)+length(data2)-2));
                    testResults.effectSize = (mean(data1) - mean(data2)) / pooledStd;

                case 'nonparametric'
                    % Wilcoxon rank-sum test
                    [p, h, stats] = ranksum(data1, data2);
                    testResults.test = 'Wilcoxon rank-sum';
                    testResults.pvalue = p;
                    testResults.testStatistic = stats.ranksum;

                    % Effect size (r = Z/sqrt(N))
                    z = stats.ranksum / sqrt(length(data1)*length(data2)*(length(data1)+length(data2)+1)/12);
                    testResults.effectSize = z / sqrt(length(data1) + length(data2));

                otherwise
                    error('Unknown test type: %s', testType);
            end

            testResults.significant = testResults.pvalue < obj.confidenceLevel;
            testResults.mean1 = mean(data1);
            testResults.mean2 = mean(data2);
            testResults.std1 = std(data1);
            testResults.std2 = std(data2);
            testResults.n1 = length(data1);
            testResults.n2 = length(data2);

            detailedTests.normality1 = obj.testNormality(data1);
            detailedTests.normality2 = obj.testNormality(data2);
            detailedTests.varianceTest = obj.testEqualVariances(data1, data2);
        end

        function [testResults, detailedTests] = performMultipleSampleComparison(obj, data, algorithms, testType)
            % Perform multiple-sample statistical comparison
            testData = cell(length(algorithms), 1);
            for i = 1:length(algorithms)
                testData{i} = data.(algorithms{i});
            end

            detailedTests = struct();

            switch lower(testType)
                case 'parametric'
                    % ANOVA
                    [p, anovatab, stats] = anova1(testData);
                    testResults.test = 'ANOVA';
                    testResults.pvalue = p;
                    testResults.testStatistic = stats.F;
                    testResults.degreesOfFreedom = stats.df;

                    % Post-hoc tests
                    if testResults.pvalue < obj.confidenceLevel
                        [results, ~, ~, gnames] = multcompare(stats);
                        testResults.posthoc = struct();
                        testResults.posthoc.comparisons = results;
                        testResults.posthoc.groupNames = gnames;
                    end

                case 'nonparametric'
                    % Kruskal-Wallis test
                    [p, anovatab, stats] = kruskalwallis(testData);
                    testResults.test = 'Kruskal-Wallis';
                    testResults.pvalue = p;
                    testResults.testStatistic = stats.kruskalwallisstat;

                    % Post-hoc tests (Dunn's test)
                    if testResults.pvalue < obj.confidenceLevel
                        testResults.posthoc = obj.performDunnTest(testData, algorithms);
                    end

                otherwise
                    error('Unknown test type: %s', testType);
            end

            testResults.significant = testResults.pvalue < obj.confidenceLevel;
            testResults.means = cellfun(@mean, testData);
            testResults.stds = cellfun(@std, testData);
            testResults.sampleSizes = cellfun(@length, testData);
            testResults.algorithms = algorithms;

            % Normality tests for each group
            detailedTests.normality = struct();
            for i = 1:length(algorithms)
                detailedTests.normality.(algorithms{i}) = obj.testNormality(testData{i});
            end

            % Variance homogeneity test
            detailedTests.varianceTest = obj.testEqualVariancesMultiple(testData);
        end

        function normalityResult = testNormality(obj, data)
            % Test for normality
            switch lower(obj.normalityTest)
                case 'shapiro-wilk'
                    [h, p] = swtest(data, obj.confidenceLevel);
                    normalityResult.test = 'Shapiro-Wilk';
                case 'kolmogorov-smirnov'
                    [h, p] = kstest(data);
                    normalityResult.test = 'Kolmogorov-Smirnov';
                case 'anderson-darling'
                    [h, p] = adtest(data);
                    normalityResult.test = 'Anderson-Darling';
                otherwise
                    error('Unknown normality test: %s', obj.normalityTest);
            end

            normalityResult.pvalue = p;
            normalityResult.normal = p >= obj.confidenceLevel;
            normalityResult.h = h;
        end

        function varianceResult = testEqualVariances(obj, data1, data2)
            % Test for equal variances between two samples
            switch lower(obj.varianceTest)
                case 'levene'
                    p = leveneTest([data1; data2], [ones(length(data1),1); 2*ones(length(data2),1)]);
                    varianceResult.test = 'Levene''s test';
                case 'bartlett'
                    [~, p] = bartlett([data1; data2], [ones(length(data1),1); 2*ones(length(data2),1)]);
                    varianceResult.test = 'Bartlett''s test';
                case 'brown-forsythe'
                    p = brownforsytheTest([data1; data2], [ones(length(data1),1); 2*ones(length(data2),1)]);
                    varianceResult.test = 'Brown-Forsythe test';
                otherwise
                    error('Unknown variance test: %s', obj.varianceTest);
            end

            varianceResult.pvalue = p;
            varianceResult.equalVariances = p >= obj.confidenceLevel;
        end

        function varianceResult = testEqualVariancesMultiple(obj, data)
            % Test for equal variances across multiple samples
            allData = [];
            groups = [];

            for i = 1:length(data)
                allData = [allData; data{i}];
                groups = [groups; i*ones(length(data{i}), 1)];
            end

            varianceResult = obj.testEqualVariances(allData(1:length(data{1})), allData(length(data{1})+1:end));
        end

        function effectSizes = calculateEffectSizes(obj, data, algorithms, metric)
            % Calculate effect sizes for all pairwise comparisons
            effectSizes = struct();
            effectSizes.metric = metric;
            effectSizes.comparisons = struct();

            for i = 1:length(algorithms)
                for j = i+1:length(algorithms)
                    alg1 = algorithms{i};
                    alg2 = algorithms{j};

                    data1 = data.(alg1);
                    data2 = data.(alg2);

                    % Cohen's d
                    pooledStd = sqrt(((length(data1)-1)*var(data1) + (length(data2)-1)*var(data2)) / (length(data1)+length(data2)-2));
                    cohensD = (mean(data1) - mean(data2)) / pooledStd;

                    % Glass's delta
                    glassDelta = (mean(data1) - mean(data2)) / std(data2);

                    % Hedges' g (small sample correction)
                    hedgesG = cohensD * (1 - 3/(4*(length(data1)+length(data2))-9));

                    comparisonName = sprintf('%s_vs_%s', alg1, alg2);
                    effectSizes.comparisons.(comparisonName) = struct();
                    effectSizes.comparisons.(comparisonName).cohensD = cohensD;
                    effectSizes.comparisons.(comparisonName).glassDelta = glassDelta;
                    effectSizes.comparisons.(comparisonName).hedgesG = hedgesG;

                    % Interpret effect size
                    if abs(cohensD) < 0.2
                        interpretation = 'negligible';
                    elseif abs(cohensD) < 0.5
                        interpretation = 'small';
                    elseif abs(cohensD) < 0.8
                        interpretation = 'medium';
                    else
                        interpretation = 'large';
                    end

                    effectSizes.comparisons.(comparisonName).interpretation = interpretation;
                    effectSizes.comparisons.(comparisonName).significant = abs(cohensD) >= obj.effectSizeThreshold;
                end
            end
        end

        function recommendations = generateRecommendations(obj, testResults, effectSizes, algorithms)
            % Generate statistical recommendations
            recommendations = {};

            if testResults.significant
                if strcmp(testResults.testType, 'parametric')
                    if testResults.testStatistic > 0
                        betterAlg = algorithms{1};
                    else
                        betterAlg = algorithms{2};
                    end

                    recommendations{end+1} = sprintf('%s shows statistically significant difference (p=%.4f) using %s', ...
                        testResults.test, testResults.pvalue, testResults.test);
                end

                % Check effect sizes
                if isfield(effectSizes, 'comparisons')
                    comparisons = fieldnames(effectSizes.comparisons);
                    for i = 1:length(comparisons)
                        comparison = comparisons{i};
                        effectSize = effectSizes.comparisons.(comparison);

                        if effectSize.significant
                            recommendations{end+1} = sprintf('%s: %s effect size (%.3f - %s)', ...
                                comparison, effectSize.interpretation, effectSize.cohensD, effectSize.interpretation);
                        end
                    end
                end
            else
                recommendations{end+1} = sprintf('No significant difference found (p=%.4f)', testResults.pvalue);
            end
        end

        function overallRecs = generateOverallRecommendations(obj, results)
            % Generate overall recommendations across all metrics
            overallRecs = {};
            metrics = fieldnames(results.summary);

            for i = 1:length(metrics)
                metric = metrics{i};
                metricRecs = results.recommendations.(metric);
                overallRecs = [overallRecs, metricRecs];
            end

            % Remove duplicates
            overallRecs = unique(overallRecs);
        end

        function printMetricSummary(obj, metric, testResults, effectSizes, algorithms)
            % Print summary for a specific metric
            fprintf('\n=== %s Analysis ===\n', metric);
            fprintf('Test: %s\n', testResults.test);
            fprintf('P-value: %.6f\n', testResults.pvalue);
            fprintf('Significant: %s\n', mat2str(testResults.significant));

            if isfield(testResults, 'effectSize')
                fprintf('Effect size: %.4f\n', testResults.effectSize);
            end

            if isfield(effectSizes, 'comparisons')
                fprintf('\nEffect Sizes:\n');
                comparisons = fieldnames(effectSizes.comparisons);
                for i = 1:length(comparisons)
                    comparison = comparisons{i};
                    effectSize = effectSizes.comparisons.(comparison);
                    fprintf('  %s: d=%.3f (%s)\n', comparison, effectSize.cohensD, effectSize.interpretation);
                end
            end

            fprintf('\nRecommendations:\n');
            recs = obj.generateRecommendations(testResults, effectSizes, algorithms);
            for i = 1:length(recs)
                fprintf('  %s\n', recs{i});
            end
        end

        function saveStatisticalResults(obj, results, filename)
            % Save statistical results to file
            timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
            fullFilename = fullfile(obj.outputPath, sprintf('%s_%s.mat', filename, timestamp));
            save(fullFilename, 'results');

            if obj.verbose
                fprintf('Statistical results saved to: %s\n', fullFilename);
            end
        end

        % Additional helper methods for trend analysis, correlation, etc.
        function trendResults = analyzeTrend(~, x, y)
            % Analyze trend in scaling data
            trendResults = struct();

            % Linear regression
            p = polyfit(x, y, 1);
            yfit = polyval(p, x);

            % Calculate R-squared
            ssTotal = sum((y - mean(y)).^2);
            ssResidual = sum((y - yfit).^2);
            rSquared = 1 - ssResidual/ssTotal;

            trendResults.slope = p(1);
            trendResults.intercept = p(2);
            trendResults.rSquared = rSquared;
            trendResults.fittedValues = yfit;

            % Trend classification
            if abs(p(1)) < 0.01
                trendType = 'stable';
            elseif p(1) > 0
                trendType = 'increasing';
            else
                trendType = 'decreasing';
            end

            trendResults.type = trendType;
        end

        function correlationResults = analyzeCorrelation(~, x, y)
            % Analyze correlation between scale and metric
            correlationResults = struct();

            % Pearson correlation
            [r, p] = corr(x, y);

            correlationResults.pearsonR = r;
            correlationResults.pvalue = p;
            correlationResults.significant = p < 0.05;

            % Spearman correlation (non-parametric)
            [rho, p_spearman] = corr(x, y, 'Type', 'Spearman');

            correlationResults.spearmanRho = rho;
            correlationResults.spearmanPvalue = p_spearman;

            % Interpretation
            if abs(r) < 0.3
                strength = 'weak';
            elseif abs(r) < 0.7
                strength = 'moderate';
            else
                strength = 'strong';
            end

            correlationResults.strength = strength;
        end

        function efficiencyResults = analyzeEfficiency(~, scale, metric)
            % Analyze efficiency (metric per unit scale)
            efficiencyResults = struct();

            % Calculate efficiency
            efficiency = metric ./ scale;

            efficiencyResults.efficiency = efficiency;
            efficiencyResults.meanEfficiency = mean(efficiency);
            efficiencyResults.stdEfficiency = std(efficiency);

            % Efficiency trend
            p = polyfit(scale, efficiency, 1);
            efficiencyResults.efficiencyTrend = p(1);

            % Classify efficiency
            if p(1) > -0.01
                efficiencyType = 'maintained';
            else
                efficiencyType = 'degrading';
            end

            efficiencyResults.type = efficiencyType;
        end

        function improvement = calculateRelativeImprovement(~, baseline, variant)
            % Calculate relative improvement
            if mean(baseline) == 0
                improvement = 0;
            else
                improvement = (mean(variant) - mean(baseline)) / abs(mean(baseline)) * 100;
            end
        end

        function sigTest = performTwoSampleTest(obj, data1, data2)
            % Perform two-sample statistical test
            [testResults, ~] = obj.performTwoSampleComparison(struct('alg1', data1, 'alg2', data2), {'alg1', 'alg2'}, 'auto');
            sigTest = struct();
            sigTest.pvalue = testResults.pvalue;
            sigTest.significant = testResults.significant;
            sigTest.test = testResults.test;
        end

        function dunnResults = performDunnTest(~, data, groupNames)
            % Perform Dunn's post-hoc test for Kruskal-Wallis
            % This is a simplified implementation
            dunnResults = struct();
            dunnResults.test = 'Dunn''s test';

            % Calculate pairwise rank sum comparisons
            nGroups = length(data);
            comparisons = [];
            pvalues = [];

            for i = 1:nGroups
                for j = i+1:nGroups
                    [p, ~] = ranksum(data{i}, data{j});
                    comparisons = [comparisons; i, j];
                    pvalues = [pvalues; p];
                end
            end

            dunnResults.comparisons = comparisons;
            dunnResults.pvalues = pvalues;
            dunnResults.groupNames = groupNames;
        end

        function bootstrapResults = performBootstrapAnalysis(~, data, algorithms, metric, nSamples, confLevel)
            % Perform bootstrap analysis for robust statistics
            bootstrapResults = struct();
            bootstrapResults.metric = metric;
            bootstrapResults.nSamples = nSamples;
            bootstrapResults.confidenceLevel = confLevel;

            for i = 1:length(algorithms)
                algorithm = algorithms{i};
                originalData = data.(algorithm);
                n = length(originalData);

                % Bootstrap sampling
                bootstrapMeans = zeros(nSamples, 1);
                for j = 1:nSamples
                    bootstrapSample = originalData(randi(n, n, 1));
                    bootstrapMeans(j) = mean(bootstrapSample);
                end

                % Calculate confidence interval
                alpha = 1 - confLevel;
                ci = quantile(bootstrapMeans, [alpha/2, 1-alpha/2]);

                bootstrapResults.(algorithm) = struct();
                bootstrapResults.(algorithm).bootstrapMeans = bootstrapMeans;
                bootstrapResults.(algorithm).confidenceInterval = ci;
                bootstrapResults.(algorithm).bias = mean(bootstrapMeans) - mean(originalData);
                bootstrapResults.(algorithm).standardError = std(bootstrapMeans);
            end
        end

        function permutationResults = performPermutationTests(~, data, algorithms, metric, nPermutations)
            % Perform permutation tests for robust significance testing
            permutationResults = struct();
            permutationResults.metric = metric;
            permutationResults.nPermutations = nPermutations;

            if length(algorithms) == 2
                % Two-sample permutation test
                alg1 = algorithms{1};
                alg2 = algorithms{2};
                data1 = data.(alg1);
                data2 = data.(alg2);

                % Original test statistic
                originalStat = abs(mean(data1) - mean(data2));

                % Permutation test
                combinedData = [data1; data2];
                n1 = length(data1);
                nTotal = length(combinedData);

                permutationStats = zeros(nPermutations, 1);
                for i = 1:nPermutations
                    permutedIndices = randperm(nTotal);
                    permGroup1 = combinedData(permutedIndices(1:n1));
                    permGroup2 = combinedData(permutedIndices(n1+1:end));
                    permutationStats(i) = abs(mean(permGroup1) - mean(permGroup2));
                end

                % P-value
                pvalue = sum(permutationStats >= originalStat) / nPermutations;

                permutationResults.test = 'Permutation test (two-sample)';
                permutationResults.originalStatistic = originalStat;
                permutationResults.permutationStatistics = permutationStats;
                permutationResults.pvalue = pvalue;
                permutationResults.significant = pvalue < 0.05;
            end
        end

        function robustness = assessRobustness(~, bootstrapResults, permutationResults)
            % Assess robustness of statistical conclusions
            robustness = struct();

            % Bootstrap robustness
            if ~isempty(fieldnames(bootstrapResults))
                algorithms = fieldnames(bootstrapResults);
                bootstrapRobustness = true;

                for i = 1:length(algorithms)
                    algorithm = algorithms{i};
                    bias = abs(bootstrapResults.(algorithm).bias);
                    meanVal = mean(bootstrapResults.(algorithm).bootstrapMeans);

                    if bias / abs(meanVal) > 0.1  % 10% bias threshold
                        bootstrapRobustness = false;
                        break;
                    end
                end

                robustness.bootstrapRobust = bootstrapRobustness;
            end

            % Permutation robustness
            if ~isempty(fieldnames(permutationResults))
                robustness.permutationRobust = permutationResults.significant;
                robustness.permutationPvalue = permutationResults.pvalue;
            end

            % Overall robustness
            if isfield(robustness, 'bootstrapRobust') && isfield(robustness, 'permutationRobust')
                robustness.overall = robustness.bootstrapRobust && robustness.permutationRobust;
            elseif isfield(robustness, 'bootstrapRobust')
                robustness.overall = robustness.bootstrapRobust;
            elseif isfield(robustness, 'permutationRobust')
                robustness.overall = robustness.permutationRobust;
            else
                robustness.overall = false;
            end
        end

        % Report generation methods
        function report = generateHTMLStatisticalReport(~, allResults, filename, includePlots, includeRawData)
            % Generate HTML statistical report
            fid = fopen(filename, 'w');

            % HTML header
            fprintf(fid, '<html>\n<head>\n<title>Edge-FML Statistical Analysis Report</title>\n');
            fprintf(fid, '<style>\n');
            fprintf(fid, 'body { font-family: Arial, sans-serif; margin: 20px; }\n');
            fprintf(fid, 'h1 { color: #2c3e50; }\n');
            fprintf(fid, 'h2 { color: #1e88e5; }\n');
            fprintf(fid, 'h3 { color: #43a047; }\n');
            fprintf(fid, 'table { border-collapse: collapse; width: 100%%; margin: 20px 0; }\n');
            fprintf(fid, 'th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }\n');
            fprintf(fid, 'th { background-color: #f2f2f2; }\n');
            fprintf(fid, '.significant { color: #d32f2f; font-weight: bold; }\n');
            fprintf(fid, '.not-significant { color: #388e3c; }\n');
            fprintf(fid, '.effect-small { color: #f57c00; }\n');
            fprintf(fid, '.effect-medium { color: #f57c00; font-weight: bold; }\n');
            fprintf(fid, '.effect-large { color: #d32f2f; font-weight: bold; }\n');
            fprintf(fid, '</style>\n</head>\n<body>\n');

            % Report title
            fprintf(fid, '<h1>Edge-FML Statistical Analysis Report</h1>\n');
            fprintf(fid, '<p>Generated: %s</p>\n', datestr(now));

            % Algorithm comparison results
            if isfield(allResults, 'algorithmComparison')
                fprintf(fid, '<h2>Algorithm Comparison Results</h2>\n');
                obj.writeAlgorithmComparisonHTML(fid, allResults.algorithmComparison);
            end

            % Ablation study results
            if isfield(allResults, 'ablationStudy')
                fprintf(fid, '<h2>Ablation Study Results</h2>\n');
                obj.writeAblationStudyHTML(fid, allResults.ablationStudy);
            end

            % Performance scaling results
            if isfield(allResults, 'performanceScaling')
                fprintf(fid, '<h2>Performance Scaling Analysis</h2>\n');
                obj.writePerformanceScalingHTML(fid, allResults.performanceScaling);
            end

            % Robustness analysis
            if isfield(allResults, 'robustnessAnalysis')
                fprintf(fid, '<h2>Robustness Analysis</h2>\n');
                obj.writeRobustnessAnalysisHTML(fid, allResults.robustnessAnalysis);
            end

            % HTML footer
            fprintf(fid, '</body>\n</html>\n');
            fclose(fid);

            report = filename;
            fprintf('HTML statistical report generated: %s\n', filename);
        end

        function writeAlgorithmComparisonHTML(~, fid, results)
            % Write algorithm comparison results to HTML
            metrics = fieldnames(results.summary);

            for i = 1:length(metrics)
                metric = metrics{i};
                summary = results.summary.(metric);

                fprintf(fid, '<h3>%s Analysis</h3>\n', metric);
                fprintf(fid, '<table>\n');
                fprintf(fid, '<tr><th>Test</th><th>P-value</th><th>Significant</th><th>Effect Size</th><th>Interpretation</th></tr>\n');

                fprintf(fid, '<tr>\n');
                fprintf(fid, '<td>%s</td>\n', summary.test);
                fprintf(fid, '<td>%.6f</td>\n', summary.pvalue);

                if summary.significant
                    fprintf(fid, '<td class="significant">Yes</td>\n');
                else
                    fprintf(fid, '<td class="not-significant">No</td>\n');
                end

                if isfield(summary, 'effectSize')
                    fprintf(fid, '<td>%.4f</td>\n', summary.effectSize);
                else
                    fprintf(fid, '<td>-</td>\n');
                end

                fprintf(fid, '<td>%s</td>\n', summary.test);
                fprintf(fid, '</tr>\n');

                fprintf(fid, '</table>\n');

                % Effect sizes
                if isfield(results.effectSizes, metric)
                    fprintf(fid, '<h4>Effect Sizes</h4>\n');
                    fprintf(fid, '<table>\n');
                    fprintf(fid, '<tr><th>Comparison</th><th>Cohen''s d</th><th>Interpretation</th></tr>\n');

                    effectSizes = results.effectSizes.(metric);
                    comparisons = fieldnames(effectSizes.comparisons);

                    for j = 1:length(comparisons)
                        comparison = comparisons{j};
                        effectSize = effectSizes.comparisons.(comparison);

                        fprintf(fid, '<tr>\n');
                        fprintf(fid, '<td>%s</td>\n', comparison);
                        fprintf(fid, '<td>%.4f</td>\n', effectSize.cohensD);

                        switch effectSize.interpretation
                            case 'small'
                                fprintf(fid, '<td class="effect-small">%s</td>\n', effectSize.interpretation);
                            case 'medium'
                                fprintf(fid, '<td class="effect-medium">%s</td>\n', effectSize.interpretation);
                            case 'large'
                                fprintf(fid, '<td class="effect-large">%s</td>\n', effectSize.interpretation);
                            otherwise
                                fprintf(fid, '<td>%s</td>\n', effectSize.interpretation);
                        end

                        fprintf(fid, '</tr>\n');
                    end

                    fprintf(fid, '</table>\n');
                end

                % Recommendations
                if isfield(results.recommendations, metric)
                    fprintf(fid, '<h4>Recommendations</h4>\n');
                    fprintf(fid, '<ul>\n');

                    recs = results.recommendations.(metric);
                    for j = 1:length(recs)
                        fprintf(fid, '<li>%s</li>\n', recs{j});
                    end

                    fprintf(fid, '</ul>\n');
                end
            end
        end

        % Additional HTML writing methods for other result types would be implemented here
        % ...

    end
end