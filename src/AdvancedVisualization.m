classdef AdvancedVisualization
    % AdvancedVisualization - Comprehensive visualization tools for Edge-FML results
    % Provides multi-objective visualization, statistical analysis, and reporting
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Multi-Objective Optimization Visualization

    properties
        % Visualization settings
        figureSize        % Default figure size [width, height]
        colorScheme       % Color scheme for plots
        lineStyles       % Line styles for plots
        markerStyles     % Marker styles for plots
        fontSettings     % Font settings

        % Output settings
        saveFormat       % File format for saving figures
        saveResolution   % Resolution for saved figures
        interactiveMode  % Enable interactive features

        % Analysis settings
        statisticalTests  % Enable statistical significance tests
        confidenceLevel  % Confidence level for statistical tests
        referencePoints  % Reference points for hypervolume calculation
    end

    methods
        function obj = AdvancedVisualization(varargin)
            % Constructor with customizable settings
            % Usage: AdvancedVisualization('FigureSize', [1200, 800], 'ColorScheme', 'professional')

            % Parse input arguments
            p = inputParser;
            addParameter(p, 'FigureSize', [1200, 800], @(x) isnumeric(x) && length(x) == 2);
            addParameter(p, 'ColorScheme', 'professional', @ischar);
            addParameter(p, 'SaveFormat', 'png', @ischar);
            addParameter(p, 'SaveResolution', 300, @isnumeric);
            addParameter(p, 'Interactive', false, @islogical);
            addParameter(p, 'StatisticalTests', true, @islogical);
            addParameter(p, 'ConfidenceLevel', 0.05, @isnumeric);
            parse(p, varargin{:});

            % Initialize settings
            obj.figureSize = p.Results.FigureSize;
            obj.saveFormat = p.Results.SaveFormat;
            obj.saveResolution = p.Results.SaveResolution;
            obj.interactiveMode = p.Results.Interactive;
            obj.statisticalTests = p.Results.StatisticalTests;
            obj.confidenceLevel = p.Results.ConfidenceLevel;

            % Set color scheme
            obj.setColorScheme(p.Results.ColorScheme);

            % Set reference points for hypervolume
            obj.referencePoints = [1000, 1000, 1000];

            % Initialize font settings
            obj.fontSettings = struct();
            obj.fontSettings.family = 'Arial';
            obj.fontSettings.size = 12;
            obj.fontSettings.weight = 'normal';

            fprintf('Advanced Visualization initialized\n');
            fprintf('Figure size: [%d, %d]\n', obj.figureSize(1), obj.figureSize(2));
            fprintf('Color scheme: %s\n', p.Results.ColorScheme);
            fprintf('Save format: %s\n', obj.saveFormat);
        end

        function visualizeParetoFront(obj, population, varargin)
            % Enhanced Pareto front visualization
            % Usage: visualizeParetoFront(population, 'Title', 'Pareto Front', 'SaveAs', 'pareto_front.png')

            p = inputParser;
            addParameter(p, 'Title', 'Pareto Front', @ischar);
            addParameter(p, 'SaveAs', '', @ischar);
            addParameter(p, 'ShowReference', true, @islogical);
            addParameter(p, 'Interactive', obj.interactiveMode, @islogical);
            addParameter(p, 'ShowStatistics', true, @islogical);
            parse(p, varargin{:});

            % Extract objectives
            objectives = obj.extractObjectives(population);

            % Create figure
            fig = figure('Position', [100, 100, obj.figureSize(1), obj.figureSize(2)], ...
                'Color', obj.colorScheme.background);

            % 3D scatter plot with enhanced features
            if size(objectives, 2) == 3
                % 3D visualization
                scatter3(objectives(:,1), objectives(:,2), objectives(:,3), ...
                    50, obj.colorScheme.markers{1}, 'filled', obj.colorScheme.markers{2}, ...
                    'MarkerEdgeColor', obj.colorScheme.markerEdges, 'MarkerFaceColor', obj.colorScheme.markerFaces{1});

                xlabel(obj.fontSettings, 'Total Latency (s)');
                ylabel(obj.fontSettings, 'Total Energy (J)');
                zlabel(obj.fontSettings, 'Security Risk');
                title(obj.fontSettings, p.Results.Title);
                grid on;
                obj.set3DAppearance();

                if p.Results.ShowReference
                    obj.plot3DReferencePoint();
                end

            else
                % 2D projection
                obj.create2DParetoPlot(objectives, p.Results.Title, p.Results.ShowReference);
            end

            % Add statistical information
            if p.Results.ShowStatistics
                obj.addParetoStatistics(fig, population, objectives);
            end

            % Interactive features
            if p.Results.Interactive
                obj.addInteractiveFeatures(fig, objectives);
            end

            % Save figure
            if ~isempty(p.Results.SaveAs)
                saveas(fig, p.Results.SaveAs);
            end
        end

        function visualizeConvergence(obj, convergenceHistory, varargin)
            % Enhanced convergence visualization
            % Usage: visualizeConvergence(history, 'Metrics', {'HV', 'Feasibility'}, 'SaveAs', 'convergence.png')

            p = inputParser;
            addParameter(p, 'Metrics', {'HV', 'Feasibility'}, @iscell);
            addParameter(p, 'Title', 'Convergence Analysis', @ischar);
            addParameter(p, 'SaveAs', '', @ischar);
            addParameter(p, 'ShowTrend', true, @islogical);
            addParameter(p, 'ConfidenceBands', false, @islogical);
            parse(p, varargin{:});

            % Extract convergence data
            rounds = [convergenceHistory.round];
            metrics = cell(length(p.Results.Metrics), 1);

            for i = 1:length(p.Results.Metrics)
                metric = p.Results.Metrics{i};
                switch lower(metric)
                    case 'hv'
                        values = [convergenceHistory.HV];
                        metrics{i} = values;
                    case 'feasibility'
                        values = [convergenceHistory.feasibilityRate];
                        metrics{i} = values;
                    case 'communication'
                        values = [convergenceHistory.communicationOverhead] / 1e6;  % Convert to MB
                        metrics{i} = values;
                    otherwise
                        error('Unknown metric: %s', metric);
                end
            end

            % Create figure
            fig = figure('Position', [100, 100, obj.figureSize(1), obj.figureSize(2)], ...
                'Color', obj.colorScheme.background);

            % Plot each metric
            colors = obj.colorScheme.lines;
            lineStyles = obj.lineStyles;

            for i = 1:length(metrics)
                subplot(length(metrics), 1, i);
                plot(rounds, metrics{i}, colors{mod(i-1, length(colors))+1}, ...
                    'LineWidth', 2, 'LineStyle', lineStyles{mod(i-1, length(lineStyles))+1}, ...
                    'Marker', 'o', 'MarkerSize', 6);

                xlabel(obj.fontSettings, 'Federated Round');
                ylabel(obj.fontSettings, sprintf('%s', p.Results.Metrics{i}));
                title(obj.fontSettings, sprintf('%s Convergence', p.Results.Metrics{i}));
                grid on;

                % Add trend line if requested
                if p.Results.ShowTrend && length(metrics{i}) > 1
                    obj.addTrendLine(rounds, metrics{i});
                end

                % Add confidence bands if requested
                if p.Results.ConfidenceBands && length(metrics{i}) > 1
                    obj.addConfidenceBands(rounds, metrics{i});
                end
            end

            sgtitle(p.Results.Title);

            % Save figure
            if ~isempty(p.Results.SaveAs)
                saveas(fig, p.Results.SaveAs);
            end
        end

        function visualizePerformanceComparison(obj, results, varargin)
            % Enhanced performance comparison visualization
            % Usage: visualizePerformanceComparison(results, 'Type', 'boxplot', 'SaveAs', 'comparison.png')

            p = inputParser;
            addParameter(p, 'Type', 'boxplot', @ischar);
            addParameter(p, 'Metrics', {'HV', 'Feasibility', 'Communication'}, @iscell);
            addParameter(p, 'Title', 'Algorithm Performance Comparison', @ischar);
            addParameter(p, 'SaveAs', '', @ischar);
            addParameter(p, 'ShowStatisticalTest', obj.statisticalTests, @islogical);
            parse(p, varargin{:});

            % Extract data for visualization
            algorithms = fieldnames(results);
            metrics = cell(length(algorithms), 1);
            data = cell(length(algorithms), 1);

            for i = 1:length(algorithms)
                algorithm = algorithms{i};
                metrics{i} = p.Results.Metrics;

                for j = 1:length(p.Results.Metrics)
                    metric = p.Results.Metrics{j};
                    switch lower(metric)
                        case 'hv'
                            data{i}(j) = [results.(algorithm).hypervolume];
                        case 'feasibility'
                            data{i}(j) = [results.(algorithm).feasibilityRate];
                        case 'communication'
                            data{i}(j) = [results.(algorithm).communicationOverhead] / 1e6;  % Convert to MB
                        otherwise
                            error('Unknown metric: %s', metric);
                    end
                end
            end

            % Create figure
            fig = figure('Position', [100, 100, obj.figureSize(1), obj.figureSize(2)], ...
                'Color', obj.colorScheme.background);

            % Create visualization based on type
            switch lower(p.Results.Type)
                case 'boxplot'
                    obj.createBoxPlot(data, algorithms, metrics, p.Results.Title);
                case 'bar'
                    obj.createBarPlot(data, algorithms, metrics, p.Results.Title);
                case 'radar'
                    obj.createRadarPlot(data, algorithms, metrics, p.Results.Title);
                case 'parallel'
                    obj.createParallelCoordinatesPlot(data, algorithms, metrics, p.Results.Title);
                otherwise
                    error('Unknown visualization type: %s', p.Results.Type);
            end

            % Add statistical test results
            if p.Results.ShowStatisticalTest
                obj.addStatisticalTestResults(fig, data, algorithms);
            end

            % Save figure
            if ~isempty(p.Results.SaveAs)
                saveas(fig, p.Results.SaveAs);
            end
        end

        function visualizeAblationResults(obj, results, varargin)
            % Enhanced ablation study visualization
            % Usage: visualizeAblationResults(results, 'SaveAs', 'ablation.png')

            p = inputParser;
            addParameter(p, 'SaveAs', '', @ischar);
            addParameter(p, 'Title', 'Ablation Study Results', @ischar);
            addParameter(p, 'ShowRelative', true, @islogical);
            addParameter(p, 'ShowErrorBars', true, @islogical);
            parse(p, varargin{:});

            % Extract ablation data
            variants = fieldnames(results);
            metrics = {'HV', 'FeasibilityRate', 'CommunicationOverhead'};

            % Create data matrices
            hvData = zeros(length(variants), 1);
            feasData = zeros(length(variants), 1);
            commData = zeros(length(variants), 1);

            for i = 1:length(variants)
                variant = variants{i};
                if isfield(results.(variant), 'hypervolume')
                    hvData(i) = results.(variant).hypervolume;
                end
                if isfield(results.(variant), 'feasibilityRate')
                    feasData(i) = results.(variant).feasibilityRate;
                end
                if isfield(results.(variant), 'communicationOverhead')
                    commData(i) = results.(variant).communicationOverhead / 1e6;  % Convert to MB
                end
            end

            % Create figure
            fig = figure('Position', [100, 100, obj.figureSize(1), obj.figureSize(2)], ...
                'Color', obj.colorScheme.background);

            % Create subplot layout
            subplot(3, 1, 1);
            obj.createAblationBarPlot(hvData, variants, 'Hypervolume', 'Relative', p.Results.ShowRelative, p.Results.ShowErrorBars);
            title(obj.fontSettings, 'Hypervolume Comparison');

            subplot(3, 1, 2);
            obj.createAblationBarPlot(feasData, variants, 'Feasibility Rate', 'Relative', p.Results.ShowRelative, p.Results.ShowErrorBars);
            title(obj.fontSettings, 'Feasibility Rate Comparison');

            subplot(3, 1, 3);
            obj.createAblationBarPlot(commData, variants, 'Communication (MB)', 'Relative', p.Results.ShowRelative, p.Results.ShowErrorBars);
            title(obj.fontSettings, 'Communication Overhead Comparison');

            sgtitle(p.Results.Title);

            % Save figure
            if ~isempty(p.Results.SaveAs)
                saveas(fig, p.Results.SaveAs);
            end
        end

        function generateComprehensiveReport(obj, allResults, varargin)
            % Generate comprehensive analysis report
            % Usage: generateComprehensiveReport(results, 'OutputFormat', 'html', 'SaveAs', 'comprehensive_report.html')

            p = inputParser;
            addParameter(p, 'OutputFormat', 'html', @ischar);
            addParameter(p, 'SaveAs', 'comprehensive_report.html', @ischar);
            addParameter(p, 'IncludeStatisticalAnalysis', true, @islogical);
            addParameter(p, 'IncludeVisualization', true, @islogical);
            parse(p, varargin{:});

            switch lower(p.Results.OutputFormat)
                case 'html'
                    obj.generateHTMLReport(allResults, p.Results.SaveAs, p.Results.IncludeStatisticalAnalysis, p.Results.IncludeVisualization);
                case 'pdf'
                    obj.generatePDFReport(allResults, p.Results.SaveAs, p.Results.IncludeStatisticalAnalysis, p.Results.IncludeVisualization);
                case 'excel'
                    obj.generateExcelReport(allResults, p.Results.SaveAs, p.Results.IncludeStatisticalAnalysis, p.Results.IncludeVisualization);
                otherwise
                    error('Unknown output format: %s', p.Results.OutputFormat);
            end
        end

        % Helper methods
        function setColorScheme(obj, schemeName)
            % Set color scheme based on name
            switch lower(schemeName)
                case 'professional'
                    obj.colorScheme.background = [1, 1, 1];
                    obj.colorScheme.lines = {[0, 0.447, 0.741], [0.85, 0.329, 0.498], [0.929, 0.694, 0.125]};
                    obj.colorScheme.markers = {[0.2, 0.2, 0.2], [0.8, 0.8, 0.8], [0.6, 0.6, 0.6]};
                    obj.colorScheme.markerEdges = [0.2, 0.2, 0.2];
                    obj.colorScheme.markerFaces = {[0.8, 0.8, 0.8], [0.6, 0.6, 0.6]};
                case 'colorblind'
                    obj.colorScheme.background = [1, 1, 1];
                    obj.colorScheme.lines = {[0, 0.376, 0.675], [0.498, 0.466, 0.733], [0.647, 0.051, 0.224]};
                    obj.colorScheme.markers = {[0.8, 0.2, 0.2], [0.2, 0.8, 0.8], [0.6, 0.6, 0.6]};
                    obj.colorScheme.markerEdges = [0.2, 0.2, 0.2];
                    obj.colorScheme.markerFaces = {[0.8, 0.2, 0.2], [0.2, 0.8, 0.8], [0.6, 0.6, 0.6]};
                case 'high_contrast'
                    obj.colorScheme.background = [0, 0, 0];
                    obj.colorScheme.lines = {[0, 0, 1], [1, 0, 1], [1, 1, 0], [1, 1, 0]};
                    obj.colorScheme.markers = {[1, 1, 1], [1, 1, 1], [1, 1, 1], [1, 1, 1]};
                    obj.colorScheme.markerEdges = [0, 0, 0];
                    obj.colorScheme.markerFaces = {[1, 1, 1], [1, 1, 1], [1, 1, 1], [1, 1, 1]};
                otherwise
                    % Default to professional
                    obj.setColorScheme('professional');
            end

            % Set line styles
            obj.lineStyles = {'-', '--', ':', '-.'};
        end

        function objectives = extractObjectives(~, population)
            % Extract objectives from population
            n = length(population);
            objectives = zeros(n, 3);

            for i = 1:n
                if isfield(population(i), 'objectives')
                    objectives(i, :) = population(i).objectives;
                end
            end
        end

        function set3DAppearance(~)
            % Set 3D plot appearance
            grid on;
            box on;
            view(3, 30);
            xlabel(obj.fontSettings, 'X');
            ylabel(obj.fontSettings, 'Y');
            zlabel(obj.fontSettings, 'Z');
            set(gca, 'FontName', obj.fontSettings.family, 'FontSize', obj.fontSettings.size);
        end

        function plot3DReferencePoint(~)
            % Plot 3D reference point
            hold on;
            plot3(obj.referencePoints(1), obj.referencePoints(2), obj.referencePoints(3), ...
                'r*', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
            hold off;
        end

        function create2DParetoPlot(~, objectives, title, showReference)
            % Create 2D Pareto front plot
            scatter(objectives(:,1), objectives(:,2), 50, obj.colorScheme.markers{1}, 'filled');
            xlabel(obj.fontSettings, 'Total Latency (s)');
            ylabel(obj.fontSettings, 'Total Energy (J)');
            title(obj.fontSettings, title);
            grid on;

            if showReference
                obj.plot2DReferencePoint();
            end
        end

        function plot2DReferencePoint(~)
            % Plot 2D reference point
            hold on;
            plot(obj.referencePoints(1), obj.referencePoints(2), 'r*', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
            hold off;
        end

        function addParetoStatistics(~, fig, population, objectives)
            % Add statistical information to Pareto front plot
            n = length(population);

            % Count feasible solutions
            feasibleCount = 0;
            for i = 1:n
                if population(i).constraintViolation <= 1e-6
                    feasibleCount = feasibleCount + 1;
                end
            end

            % Add text box with statistics
            infoText = sprintf('Solutions: %d\nFeasible: %d (%.1f%%)\nHV: %.4e', ...
                n, feasibleCount, 100*feasibleCount/n, ...
                obj.computeHypervolume(objectives));

            text(0.02, 0.98, infoText, 'Units', 'normalized', ...
                'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
                'FontSize', 10, 'BackgroundColor', [1, 1, 1, 0.8]);
        end

        function addInteractiveFeatures(~, fig, objectives)
            % Add interactive features to plot
            if length(objectives) > 0
                % Enable data cursor
                datacursormode on;

                % Add click callback
                set(fig, 'WindowButtonDownFcn', @(src, event) obj.onPlotClick(src, event, objectives));
            end
        end

        function onPlotClick(~, src, event, objectives)
            % Handle plot click events
            if strcmp(event.getModifier, 'shift')
                % Shift+click: show solution details
                point = event.IntersectionPoint;
                if ~isempty(point)
                    nearestIdx = obj.findNearestSolution(objectives, point);
                    if ~isempty(nearestIdx)
                        sol = objectives(nearestIdx, :);
                        msg = sprintf('Solution %d:\nLatency: %.4f s\nEnergy: %.4f J\nSecurity: %.4f', ...
                            nearestIdx, sol(1), sol(2), sol(3));
                        msgbox(msg, 'Solution Details', 'help');
                    end
                end
            end
        end

        function idx = findNearestSolution(~, objectives, point)
            % Find nearest solution to click point
            distances = sqrt(sum((objectives - point(ones(size(objectives, 1), 2))).^2, 2));
            [~, idx] = min(distances);
        end

        function addTrendLine(~, x, y)
            % Add trend line to plot
            hold on;
            p = polyfit(x, 1);
            yfit = polyval(p, x);
            plot(x, yfit, '--', 'Color', [0.5, 0.5, 0.5]);
            hold off;
        end

        function addConfidenceBands(~, x, y)
            % Add confidence bands to plot
            hold on;

            % Calculate confidence intervals
            alpha = 1 - obj.confidenceLevel;
            n = length(x);

            % Simple linear regression for confidence bands
            p = polyfit(x, 1);
            yfit = polyval(p, x);
            residuals = y - yfit;
            mse = sum(residuals.^2) / (n - 2);

            % Confidence bands
            t = tinv(alpha/2, n-2) * sqrt(mse);
            y_upper = yfit + t * sqrt(1 + 1/n + (x - mean(x)).^2 / sum((x - mean(x)).^2));
            y_lower = yfit - t * sqrt(1 + 1/n + (x - mean(x)).^2 / sum((x - mean(x)).^2));

            % Plot bands
            fill([x, fliplr(x)], [y_upper, fliplr(y_lower)], ...
                [0.8, 0.8, 0.8, 0.3], 'EdgeColor', 'none', 'FaceColor', [0.8, 0.8, 0.8, 0.3]);

            hold off;
        end

        function createBoxPlot(~, data, algorithms, metrics, title)
            % Create box plot
            for i = 1:length(metrics)
                subplot(length(metrics), 1, i);
                boxplot(data{i}, algorithms);
                ylabel(obj.fontSettings, sprintf('%s', metrics{i}));
                title(obj.fontSettings, sprintf('%s - %s', title, metrics{i}));
                grid on;
            end
        end

        function createBarPlot(~, data, algorithms, metrics, title)
            % Create bar plot
            for i = 1:length(metrics)
                subplot(length(metrics), 1, i);
                bar(data{i});
                set(gca, 'XTickLabel', algorithms);
                ylabel(obj.fontSettings, sprintf('%s', metrics{i}));
                title(obj.fontSettings, sprintf('%s - %s', title, metrics{i}));
                grid on;
            end
        end

        function createRadarPlot(~, data, algorithms, metrics, title)
            % Create radar plot
            angles = linspace(0, 2*pi, length(algorithms)+1);

            for i = 1:length(metrics)
                subplot(length(metrics), 1, i);
                polarData = [data{i}(:), data{i}(1)];  % Close the loop

                polar(angles, polarData, 'LineWidth', 2);
                hold on;
            end

            % Add labels
            for i = 1:length(algorithms)
                angle = angles(i);
                label = algorithms{i};
                [x, y] = pol2cart(angle, max(data{i}(:)));
                text(x, y, label, 'HorizontalAlignment', 'center');
            end

            sgtitle(title);
        end

        function createParallelCoordinatesPlot(~, data, algorithms, metrics, title)
            % Create parallel coordinates plot
            for i = 1:length(metrics)
                subplot(length(metrics), 1, i);

                % Normalize data for parallel coordinates
                normData = data{i} / max(data{i}(:));

                % Create parallel coordinates plot
                plot(normData, 'LineWidth', 2);
                set(gca, 'XTickLabel', algorithms);
                ylabel(obj.fontSettings, sprintf('Normalized %s', metrics{i}));
                title(obj.fontSettings, sprintf('%s - %s', title, metrics{i}));
                grid on;
            end
        end

        function createAblationBarPlot(~, data, variants, ylabel, relative, showErrorBars, errorBars)
            % Create ablation study bar plot
            if relative
                % Normalize to baseline (first variant)
                baseline = data(1);
                normalizedData = data / baseline;
                yData = normalizedData;
                yLabel = sprintf('%s (Relative to %s)', ylabel, variants{1});
            else
                yData = data;
                yLabel = ylabel;
            end

            if showErrorBars && ~isempty(errorBars)
                bar(yData, errorBars);
            else
                bar(yData);
            end

            set(gca, 'XTickLabel', variants);
            ylabel(obj.fontSettings, yLabel);
            grid on;
        end

        function hv = computeHypervolume(~, objectives)
            % Compute hypervolume
            ref = obj.referencePoints;
            n = size(objectives, 1);

            hv = 0;
            for i = 1:n
                if all(objectives(i, :) <= ref)
                    contribution = prod(ref - objectives(i, :));
                    hv = hv + contribution;
                end
            end
        end

        function addStatisticalTestResults(~, fig, data, algorithms)
            % Add statistical test results to plot
            if length(algorithms) < 2
                return;  % Need at least 2 algorithms for comparison
            end

            % Perform ANOVA test for each metric
            for i = 1:size(data, 2)
                metricData = squeeze(data(:, i, :));

                % One-way ANOVA
                [p, anovatab, stats] = anova1(metricData);

                % Add significance information
                if p < obj.confidenceLevel
                    sigText = sprintf('p < %.3f (significant)', obj.confidenceLevel);
                    textColor = [0, 0.5, 0];
                else
                    sigText = sprintf('p ≥ %.3f (not significant)', obj.confidenceLevel);
                    textColor = [0.5, 0, 0];
                end

                % Add text annotation
                text(0.7, max(metricData(:)), sigText, ...
                    'Color', textColor, 'FontSize', 10, 'FontWeight', 'bold');
            end
        end

        function generateHTMLReport(~, allResults, filename, includeStats, includeViz)
            % Generate comprehensive HTML report
            fid = fopen(filename, 'w');

            % HTML header
            fprintf(fid, '<html>\n<head>\n<title>Edge-FML Comprehensive Report</title>\n');
            fprintf(fid, '<style>\n');
            fprintf(fid, 'body { font-family: Arial, sans-serif; margin: 20px; }\n');
            fprintf(fid, 'h1 { color: #2c3e50; }\n');
            fprintf(fid, 'h2 { color: #1e88e5; }\n');
            fprintf(fid, 'table { border-collapse: collapse; width: 100%%; margin: 20px 0; }\n');
            fprintf(fid, 'th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }\n');
            fprintf(fid, 'th { background-color: #f2f2f2; }\n');
            fprintf(fid, '.metric { color: #666; }\n');
            fprintf(fid, '.success { color: #28a745; }\n');
            fprintf(fid, '.error { color: #d32f2f; }\n');
            fprintf(fid, '</style>\n</head>\n<body>\n');

            % Report title
            fprintf(fid, '<h1>Edge-FML Comprehensive Analysis Report</h1>\n');
            fprintf(fid, '<p>Generated: %s</p>\n', datestr(now));

            % Performance results
            if isfield(allResults, 'performance')
                fprintf(fid, '<h2>Performance Test Results</h2>\n');
                obj.writePerformanceHTMLTable(fid, allResults.performance);
            end

            % Comparison results
            if isfield(allResults, 'comparison')
                fprintf(fid, '<h2>Algorithm Comparison Results</h2>\n');
                obj.writeComparisonHTMLTable(fid, allResults.comparison);
            end

            % Ablation results
            if isfield(allResults, 'ablation')
                fprintf(fid, '<h2>Ablation Study Results</h2>\n');
                obj.writeAblationHTMLTable(fid, allResults.ablation);
            end

            % Statistical analysis
            if includeStats
                fprintf(fid, '<h2>Statistical Analysis</h2>\n');
                obj.writeStatisticalAnalysisHTML(fid, allResults);
            end

            % HTML footer
            fprintf(fid, '</body>\n</html>\n');
            fclose(fid);

            fprintf('HTML report generated: %s\n', filename);
        end

        function writePerformanceHTMLTable(~, fid, performanceResults)
            % Write performance results HTML table
            fprintf(fid, '<table>\n<tr><th>Configuration</th><th>Hypervolume</th><th>Feasibility Rate</th><th>Communication (MB)</th><th>Time (s)</th></tr>\n');

            configs = fieldnames(performanceResults);
            for i = 1:length(configs)
                config = performanceResults.(configs{i});
                class = '';
                if config.success
                    class = 'success';
                else
                    class = 'error';
                end

                fprintf(fid, '<tr class="%s">\n', class);
                fprintf(fid, '<td>%s</td>\n', configs{i});
                fprintf(fid, '<td class="metric">%.4e</td>\n', config.hypervolume);
                fprintf(fid, '<td class="metric">%.2f%%</td>\n', config.feasibilityRate);
                fprintf(fid, '<td class="metric">%.2f</td>\n', config.communicationOverhead);
                fprintf(fid, '<td class="metric">%.2f</td>\n', config.elapsedTime);
                fprintf(fid, '</tr>\n');
            end

            fprintf(fid, '</table>\n');
        end

        function writeComparisonHTMLTable(~, fid, comparisonResults)
            % Write comparison results HTML table
            fprintf(fid, '<table>\n<tr><th>Algorithm</th><th>Dataset</th><th>Hypervolume</th><th>Feasibility Rate</th><th>Communication (MB)</th><th>Time (s)</th></tr>\n');

            keys = fieldnames(comparisonResults);
            for i = 1:length(keys)
                result = comparisonResults.(keys{i});
                class = '';
                if result.success
                    class = 'success';
                else
                    class = 'error';
                end

                fprintf(fid, '<tr class="%s">\n', class);
                fprintf(fid, '<td>%s</td>\n', result.algorithm);
                fprintf(fid, '<td>%s</td>\n', result.dataset);
                fprintf(fid, '<td class="metric">%.4e</td>\n', result.hypervolume);
                fprintf(fid, '<td class="metric">%.2f%%</td>\n', result.feasibilityRate);
                fprintf(fid, '<td class="metric">%.2f</td>\n', result.communicationOverhead);
                fprintf(fid, '<td class="metric">%.2f</td>\n', result.elapsedTime);
                fprintf(fid, '</tr>\n');
            end

            fprintf(fid, '</table>\n');
        end

        function writeAblationHTMLTable(~, fid, ablationResults)
            % Write ablation results HTML table
            fprintf(fid, '<table>\n<tr><th>Variant</th><th>Hypervolume</th><th>Feasibility Rate</th><th>Communication (MB)</th><th>Time (s)</th></tr>\n');

            variants = fieldnames(ablationResults);
            for i = 1:length(variants)
                result = ablationResults.(variants{i});
                class = '';
                if result.success
                    class = 'success';
                else
                    class = 'error';
                end

                fprintf(fid, '<tr class="%s">\n', class);
                fprintf(fid, '<td>%s</td>\n', variants{i});
                fprintf(fid, '<td class="metric">%.4e</td>\n', result.hypervolume);
                fprintf(fid, '<td class="metric">%.2f%%</td>\n', result.feasibilityRate);
                fprintf(fid, '<td class="metric">%.2f</td>\n', result.communicationOverhead);
                fprintf(fid, '<td class="metric">%.2f</td>\n', result.elapsedTime);
                fprintf(fid, '</tr>\n');
            end

            fprintf(fid, '</table>\n');
        end

        function writeStatisticalAnalysisHTML(~, fid, allResults)
            % Write statistical analysis HTML
            fprintf(fid, '<div class="analysis">\n');
            fprintf(fid, '<h3>Statistical Significance Tests</h3>\n');

            % Add statistical test results
            if isfield(allResults, 'comparison')
                fprintf(fid, '<p>Statistical tests performed on algorithm comparison results with confidence level %.2f</p>\n', obj.confidenceLevel);
            end

            fprintf(fid, '</div>\n');
        end

        % Additional helper methods for PDF and Excel generation would be implemented here
        % ...

    end
end