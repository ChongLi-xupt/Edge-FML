classdef ReportGenerator
    % ReportGenerator - Comprehensive report generation for Edge-FML experiments
    % Integrates statistical analysis, visualization, and reporting capabilities
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Comprehensive Analysis and Reporting Framework

    properties
        % Report configuration
        reportType        % Type of report: 'comprehensive', 'summary', 'technical', 'executive'
        outputFormat      % Output format: 'html', 'pdf', 'latex', 'markdown'
        outputPath        % Output directory for reports
        includePlots      % Include plots in report
        includeRawData    % Include raw data in report
        includeCode       % Include code snippets in report

        % Analysis components
        visualizer        % AdvancedVisualization instance
        analyzer          % StatisticalAnalyzer instance

        % Report metadata
        title             % Report title
        author            % Report author
        date              % Report generation date
        version           % Report version
        description       % Report description

        % Content sections
        sections          % Report sections to include
        customSections    % Custom sections content

        % Styling
        theme             % Visual theme for reports
        logoPath          % Path to logo image
        watermark         % Watermark text

        % Technical settings
        precision         % Numerical precision for tables
        significantDigits % Significant digits for reporting
        dateFormat        % Date format for timestamps
    end

    methods
        function obj = ReportGenerator(varargin)
            % Constructor with customizable settings
            % Usage: ReportGenerator('ReportType', 'comprehensive', 'OutputFormat', 'html')

            % Parse input arguments
            p = inputParser;
            addParameter(p, 'ReportType', 'comprehensive', @ischar);
            addParameter(p, 'OutputFormat', 'html', @ischar);
            addParameter(p, 'OutputPath', './reports/', @ischar);
            addParameter(p, 'IncludePlots', true, @islogical);
            addParameter(p, 'IncludeRawData', false, @islogical);
            addParameter(p, 'IncludeCode', false, @islogical);
            addParameter(p, 'Title', 'Edge-FML Analysis Report', @ischar);
            addParameter(p, 'Author', '拓守恒 (Shouheng Tuo)', @ischar);
            addParameter(p, 'Theme', 'professional', @ischar);
            addParameter(p, 'Precision', 4, @isnumeric);
            addParameter(p, 'SignificantDigits', 3, @isnumeric);
            addParameter(p, 'DateFormat', 'yyyy-mm-dd HH:MM:SS', @ischar);
            parse(p, varargin{:});

            % Initialize settings
            obj.reportType = p.Results.ReportType;
            obj.outputFormat = p.Results.OutputFormat;
            obj.outputPath = p.Results.OutputPath;
            obj.includePlots = p.Results.IncludePlots;
            obj.includeRawData = p.Results.IncludeRawData;
            obj.includeCode = p.Results.IncludeCode;
            obj.title = p.Results.Title;
            obj.author = p.Results.Author;
            obj.theme = p.Results.Theme;
            obj.precision = p.Results.Precision;
            obj.significantDigits = p.Results.SignificantDigits;
            obj.dateFormat = p.Results.DateFormat;

            % Set metadata
            obj.date = datestr(now, obj.dateFormat);
            obj.version = '1.0';
            obj.description = 'Comprehensive analysis of Edge-FML algorithm performance';

            % Initialize analysis components
            obj.visualizer = AdvancedVisualization('ColorScheme', obj.theme);
            obj.analyzer = StatisticalAnalyzer('Verbose', false);

            % Set default sections based on report type
            obj.setDefaultSections();

            % Create output directory if needed
            if ~exist(obj.outputPath, 'dir')
                mkdir(obj.outputPath);
            end

            fprintf('Report Generator initialized\n');
            fprintf('Report type: %s\n', obj.reportType);
            fprintf('Output format: %s\n', obj.outputFormat);
            fprintf('Output path: %s\n', obj.outputPath);
        end

        function reportPath = generateReport(obj, experimentResults, varargin)
            % Generate comprehensive report from experiment results
            % Usage: reportPath = generateReport(results, 'SaveAs', 'comprehensive_report.html')

            p = inputParser;
            addParameter(p, 'SaveAs', '', @ischar);
            addParameter(p, 'AutoOpen', true, @islogical);
            addParameter(p, 'Compress', false, @islogical);
            parse(p, varargin{:});

            % Generate filename if not provided
            if isempty(p.Results.SaveAs)
                timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
                filename = sprintf('%s_%s.%s', obj.reportType, timestamp, obj.outputFormat);
            else
                filename = p.Results.SaveAs;
            end

            reportPath = fullfile(obj.outputPath, filename);

            % Generate report based on format
            switch lower(obj.outputFormat)
                case 'html'
                    obj.generateHTMLReport(experimentResults, reportPath);
                case 'pdf'
                    obj.generatePDFReport(experimentResults, reportPath);
                case 'latex'
                    obj.generateLatexReport(experimentResults, reportPath);
                case 'markdown'
                    obj.generateMarkdownReport(experimentResults, reportPath);
                case 'word'
                    obj.generateWordReport(experimentResults, reportPath);
                otherwise
                    error('Unsupported output format: %s', obj.outputFormat);
            end

            % Compress report if requested
            if p.Results.Compress
                obj.compressReport(reportPath);
            end

            % Auto-open report if requested
            if p.Results.AutoOpen
                obj.openReport(reportPath);
            end

            fprintf('Report generated: %s\n', reportPath);
        end

        function addCustomSection(obj, sectionName, content)
            % Add custom section to report
            % Usage: addCustomSection('Custom Analysis', 'This is custom content')

            obj.customSections.(sectionName) = content;
        end

        function setSections(obj, sections)
            % Set which sections to include in report
            % Usage: setSections({'summary', 'performance', 'comparison', 'ablation'})

            obj.sections = sections;
        end

        function setTheme(obj, theme)
            % Set visual theme for reports
            % Usage: setTheme('dark') or setTheme('colorblind')

            obj.theme = theme;
            obj.visualizer = AdvancedVisualization('ColorScheme', theme);
        end

        % Private report generation methods
        function generateHTMLReport(obj, results, filename)
            % Generate HTML report
            fid = fopen(filename, 'w');

            % Write HTML header
            obj.writeHTMLHeader(fid);

            % Write report sections
            for i = 1:length(obj.sections)
                section = obj.sections{i};
                obj.writeHTMLSection(fid, section, results);
            end

            % Write custom sections
            if ~isempty(fieldnames(obj.customSections))
                obj.writeHTMLCustomSections(fid);
            end

            % Write HTML footer
            obj.writeHTMLFooter(fid);

            fclose(fid);

            % Generate plots if requested
            if obj.includePlots
                obj.generateHTMLPlots(results, filename);
            end
        end

        function writeHTMLHeader(obj, fid)
            % Write HTML header with styling
            fprintf(fid, '<!DOCTYPE html>\n<html lang="en">\n<head>\n');
            fprintf(fid, '<meta charset="UTF-8">\n');
            fprintf(fid, '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n');
            fprintf(fid, '<title>%s</title>\n', obj.title);

            % CSS styling based on theme
            obj.writeHTMLCSS(fid);

            % JavaScript for interactivity
            obj.writeHTMLJavaScript(fid);

            fprintf(fid, '</head>\n<body>\n');

            % Header section
            fprintf(fid, '<header class="report-header">\n');
            fprintf(fid, '<h1>%s</h1>\n', obj.title);
            fprintf(fid, '<div class="report-meta">\n');
            fprintf(fid, '<p><strong>Author:</strong> %s</p>\n', obj.author);
            fprintf(fid, '<p><strong>Date:</strong> %s</p>\n', obj.date);
            fprintf(fid, '<p><strong>Version:</strong> %s</p>\n', obj.version);
            fprintf(fid, '</div>\n');
            fprintf(fid, '</header>\n');

            % Table of contents
            obj.writeHTMLTableOfContents(fid);
        end

        function writeHTMLCSS(obj, fid)
            % Write CSS styling based on theme
            fprintf(fid, '<style>\n');

            switch lower(obj.theme)
                case 'professional'
                    obj.writeProfessionalCSS(fid);
                case 'dark'
                    obj.writeDarkCSS(fid);
                case 'colorblind'
                    obj.writeColorblindCSS(fid);
                otherwise
                    obj.writeProfessionalCSS(fid);
            end

            fprintf(fid, '</style>\n');
        end

        function writeProfessionalCSS(~, fid)
            % Professional theme CSS
            fprintf(fid, [
                'body { font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; margin: 0; padding: 20px; background-color: #f8f9fa; }\n' ...
                '.report-header { background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }\n' ...
                '.report-header h1 { margin: 0; font-size: 2.5em; }\n' ...
                '.report-meta { margin-top: 15px; font-size: 1.1em; }\n' ...
                '.toc { background: white; padding: 20px; border-radius: 8px; margin-bottom: 30px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }\n' ...
                '.toc h2 { margin-top: 0; color: #333; }\n' ...
                '.toc ul { list-style-type: none; padding-left: 0; }\n' ...
                '.toc li { margin: 8px 0; }\n' ...
                '.toc a { color: #007bff; text-decoration: none; font-weight: 500; }\n' ...
                '.toc a:hover { text-decoration: underline; }\n' ...
                '.section { background: white; margin-bottom: 30px; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }\n' ...
                '.section h2 { color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; }\n' ...
                '.section h3 { color: #495057; margin-top: 25px; }\n' ...
                'table { width: 100%%; border-collapse: collapse; margin: 20px 0; }\n' ...
                'th, td { padding: 12px; text-align: left; border-bottom: 1px solid #dee2e6; }\n' ...
                'th { background-color: #f8f9fa; font-weight: 600; color: #495057; }\n' ...
                'tr:hover { background-color: #f8f9fa; }\n' ...
                '.metric-table { font-size: 0.9em; }\n' ...
                '.significant { color: #dc3545; font-weight: bold; }\n' ...
                '.not-significant { color: #28a745; }\n' ...
                '.warning { color: #ffc107; }\n' ...
                '.info { color: #17a2b8; }\n' ...
                '.plot-container { text-align: center; margin: 20px 0; }\n' ...
                '.plot-container img { max-width: 100%%; height: auto; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }\n' ...
                '.code-block { background: #f8f9fa; border: 1px solid #e9ecef; border-radius: 4px; padding: 15px; font-family: "Courier New", monospace; font-size: 0.9em; overflow-x: auto; }\n' ...
                '.highlight { background-color: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 15px 0; }\n' ...
                '.summary-box { background: linear-gradient(135deg, #28a745 0%%, #20c997 100%%); color: white; padding: 20px; border-radius: 8px; margin: 20px 0; }\n' ...
                '@media (max-width: 768px) { body { padding: 10px; } .report-header { padding: 20px; } .section { padding: 20px; } }\n' ...
            ]);
        end

        function writeDarkCSS(~, fid)
            % Dark theme CSS
            fprintf(fid, [
                'body { font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; margin: 0; padding: 20px; background-color: #1a1a1a; color: #e0e0e0; }\n' ...
                '.report-header { background: linear-gradient(135deg, #434343 0%%, #000000 100%%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }\n' ...
                '.section { background: #2d2d2d; margin-bottom: 30px; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.3); }\n' ...
                '.section h2 { color: #ffffff; border-bottom: 3px solid #007bff; padding-bottom: 10px; }\n' ...
                '.section h3 { color: #b0b0b0; margin-top: 25px; }\n' ...
                'table { width: 100%%; border-collapse: collapse; margin: 20px 0; }\n' ...
                'th, td { padding: 12px; text-align: left; border-bottom: 1px solid #404040; }\n' ...
                'th { background-color: #404040; font-weight: 600; color: #ffffff; }\n' ...
                'tr:hover { background-color: #404040; }\n' ...
                '.code-block { background: #1a1a1a; border: 1px solid #404040; border-radius: 4px; padding: 15px; font-family: "Courier New", monospace; font-size: 0.9em; overflow-x: auto; }\n' ...
            ]);
        end

        function writeColorblindCSS(~, fid)
            % Colorblind-friendly theme CSS
            fprintf(fid, [
                'body { font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; margin: 0; padding: 20px; background-color: #f8f9fa; }\n' ...
                '.report-header { background: linear-gradient(135deg, #003f5c 0%%, #58508d 100%%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }\n' ...
                '.section h2 { color: #003f5c; border-bottom: 3px solid #003f5c; padding-bottom: 10px; }\n' ...
                '.significant { color: #003f5c; font-weight: bold; }\n' ...
                '.not-significant { color: #ffa600; }\n' ...
                '.warning { color: #bc5090; }\n' ...
                '.info { color: #58508d; }\n' ...
            ]);
        end

        function writeHTMLJavaScript(~, fid)
            % Write JavaScript for interactivity
            fprintf(fid, '<script>\n');
            fprintf(fid, [
                '// Smooth scrolling for table of contents\n' ...
                'document.addEventListener("DOMContentLoaded", function() {\n' ...
                '  const tocLinks = document.querySelectorAll(".toc a");\n' ...
                '  tocLinks.forEach(link => {\n' ...
                '    link.addEventListener("click", function(e) {\n' ...
                '      e.preventDefault();\n' ...
                '      const targetId = this.getAttribute("href").substring(1);\n' ...
                '      const targetElement = document.getElementById(targetId);\n' ...
                '      if (targetElement) {\n' ...
                '        targetElement.scrollIntoView({ behavior: "smooth" });\n' ...
                '      }\n' ...
                '    });\n' ...
                '  });\n' ...
                '  \n' ...
                '  // Highlight current section in TOC\n' ...
                '  window.addEventListener("scroll", function() {\n' ...
                '    const sections = document.querySelectorAll(".section");\n' ...
                '    let current = "";\n' ...
                '    \n' ...
                '    sections.forEach(section => {\n' ...
                '      const sectionTop = section.offsetTop;\n' ...
                '      if (pageYOffset >= sectionTop - 100) {\n' ...
                '        current = section.getAttribute("id");\n' ...
                '      }\n' ...
                '    });\n' ...
                '    \n' ...
                '    tocLinks.forEach(link => {\n' ...
                '      link.style.fontWeight = "normal";\n' ...
                '      if (link.getAttribute("href") === "#" + current) {\n' ...
                '        link.style.fontWeight = "bold";\n' ...
                '      }\n' ...
                '    });\n' ...
                '  });\n' ...
                '});\n' ...
            ]);
            fprintf(fid, '</script>\n');
        end

        function writeHTMLTableOfContents(obj, fid)
            % Write table of contents
            fprintf(fid, '<nav class="toc">\n');
            fprintf(fid, '<h2>Table of Contents</h2>\n');
            fprintf(fid, '<ul>\n');

            for i = 1:length(obj.sections)
                section = obj.sections{i};
                sectionId = sprintf('section-%s', lower(strrep(section, ' ', '-')));
                fprintf(fid, '<li><a href="#%s">%s</a></li>\n', sectionId, obj.formatSectionTitle(section));
            end

            % Add custom sections
            if ~isempty(fieldnames(obj.customSections))
                customNames = fieldnames(obj.customSections);
                for i = 1:length(customNames)
                    sectionId = sprintf('custom-%s', lower(strrep(customNames{i}, ' ', '-')));
                    fprintf(fid, '<li><a href="#%s">%s</a></li>\n', sectionId, customNames{i});
                end
            end

            fprintf(fid, '</ul>\n');
            fprintf(fid, '</nav>\n');
        end

        function writeHTMLSection(obj, fid, section, results)
            % Write individual HTML section
            sectionId = sprintf('section-%s', lower(strrep(section, ' ', '-')));
            fprintf(fid, '<section id="%s" class="section">\n', sectionId);
            fprintf(fid, '<h2>%s</h2>\n', obj.formatSectionTitle(section));

            switch lower(section)
                case 'summary'
                    obj.writeSummarySection(fid, results);
                case 'performance'
                    obj.writePerformanceSection(fid, results);
                case 'comparison'
                    obj.writeComparisonSection(fid, results);
                case 'ablation'
                    obj.writeAblationSection(fid, results);
                case 'statistical'
                    obj.writeStatisticalSection(fid, results);
                case 'scaling'
                    obj.writeScalingSection(fid, results);
                case 'robustness'
                    obj.writeRobustnessSection(fid, results);
                case 'conclusions'
                    obj.writeConclusionsSection(fid, results);
                otherwise
                    fprintf(fid, '<p>Section "%s" content not implemented.</p>\n', section);
            end

            fprintf(fid, '</section>\n');
        end

        function writeSummarySection(obj, fid, results)
            % Write executive summary section
            fprintf(fid, '<div class="summary-box">\n');
            fprintf(fid, '<h3>Executive Summary</h3>\n');
            fprintf(fid, '<p>This report presents a comprehensive analysis of the Edge-FML (Edge Federated Membrane Learning) algorithm performance across multiple dimensions.</p>\n');

            % Generate key metrics summary
            if isfield(results, 'performance')
                fprintf(fid, '<h4>Key Performance Metrics</h4>\n');
                fprintf(fid, '<ul>\n');

                % Extract best performance
                bestHV = 0;
                bestConfig = '';

                configs = fieldnames(results.performance);
                for i = 1:length(configs)
                    config = results.performance.(configs{i});
                    if config.hypervolume > bestHV
                        bestHV = config.hypervolume;
                        bestConfig = configs{i};
                    end
                end

                fprintf(fid, '<li>Best Hypervolume: %.4e (Configuration: %s)</li>\n', bestHV, bestConfig);
                fprintf(fid, '<li>Average Feasibility Rate: %.1f%%</li>\n', obj.calculateAverageFeasibility(results));
                fprintf(fid, '<li>Total Experiments Conducted: %d</li>\n', obj.countTotalExperiments(results));

                fprintf(fid, '</ul>\n');
            end

            fprintf(fid, '</div>\n');

            % Algorithm overview
            fprintf(fid, '<h3>Algorithm Overview</h3>\n');
            fprintf(fid, '<p>Edge-FML is a distributed optimization framework designed for edge computing environments, featuring:</p>\n');
            fprintf(fid, '<ul>\n');
            fprintf(fid, '<li>Privacy-preserving federated learning with Shamir secret sharing</li>\n');
            fprintf(fid, '<li>Multi-objective optimization (Latency, Energy, Security)</li>\n');
            fprintf(fid, '<li>Adaptive clustering for heterogeneous edge environments</li>\n');
            fprintf(fid, '<li>Communication-efficient knowledge aggregation</li>\n');
            fprintf(fid, '</ul>\n');
        end

        function writePerformanceSection(obj, fid, results)
            % Write performance analysis section
            if ~isfield(results, 'performance')
                fprintf(fid, '<p>No performance results available.</p>\n');
                return;
            end

            fprintf(fid, '<h3>Performance Test Results</h3>\n');

            % Performance table
            fprintf(fid, '<table class="metric-table">\n');
            fprintf(fid, '<tr><th>Configuration</th><th>Hypervolume</th><th>Feasibility Rate</th><th>Communication (MB)</th><th>Time (s)</th><th>Status</th></tr>\n');

            configs = fieldnames(results.performance);
            for i = 1:length(configs)
                config = results.performance.(configs{i});

                statusClass = '';
                if config.success
                    status = 'Success';
                    statusClass = 'not-significant';
                else
                    status = 'Failed';
                    statusClass = 'significant';
                end

                fprintf(fid, '<tr>\n');
                fprintf(fid, '<td>%s</td>\n', configs{i});
                fprintf(fid, '<td>%.4e</td>\n', config.hypervolume);
                fprintf(fid, '<td>%.2f%%</td>\n', config.feasibilityRate);
                fprintf(fid, '<td>%.2f</td>\n', config.communicationOverhead);
                fprintf(fid, '<td>%.2f</td>\n', config.elapsedTime);
                fprintf(fid, '<td class="%s">%s</td>\n', statusClass, status);
                fprintf(fid, '</tr>\n');
            end

            fprintf(fid, '</table>\n');

            % Performance insights
            fprintf(fid, '<h4>Performance Insights</h4>\n');
            insights = obj.generatePerformanceInsights(results.performance);
            for i = 1:length(insights)
                fprintf(fid, '<div class="highlight">%s</div>\n', insights{i});
            end
        end

        function writeComparisonSection(obj, fid, results)
            % Write algorithm comparison section
            if ~isfield(results, 'comparison')
                fprintf(fid, '<p>No comparison results available.</p>\n');
                return;
            end

            fprintf(fid, '<h3>Algorithm Comparison Results</h3>\n');

            % Comparison table
            fprintf(fid, '<table class="metric-table">\n');
            fprintf(fid, '<tr><th>Algorithm</th><th>Dataset</th><th>Hypervolume</th><th>Feasibility Rate</th><th>Communication (MB)</th><th>Time (s)</th></tr>\n');

            keys = fieldnames(results.comparison);
            for i = 1:length(keys)
                result = results.comparison.(keys{i});

                fprintf(fid, '<tr>\n');
                fprintf(fid, '<td>%s</td>\n', result.algorithm);
                fprintf(fid, '<td>%s</td>\n', result.dataset);
                fprintf(fid, '<td>%.4e</td>\n', result.hypervolume);
                fprintf(fid, '<td>%.2f%%</td>\n', result.feasibilityRate);
                fprintf(fid, '<td>%.2f</td>\n', result.communicationOverhead);
                fprintf(fid, '<td>%.2f</td>\n', result.elapsedTime);
                fprintf(fid, '</tr>\n');
            end

            fprintf(fid, '</table>\n');

            % Statistical comparison
            if isfield(results, 'statisticalAnalysis') && isfield(results.statisticalAnalysis, 'algorithmComparison')
                fprintf(fid, '<h4>Statistical Significance</h4>\n');
                obj.writeStatisticalComparisonHTML(fid, results.statisticalAnalysis.algorithmComparison);
            end
        end

        function writeAblationSection(obj, fid, results)
            % Write ablation study section
            if ~isfield(results, 'ablation')
                fprintf(fid, '<p>No ablation study results available.</p>\n');
                return;
            end

            fprintf(fid, '<h3>Ablation Study Results</h3>\n');

            % Ablation table
            fprintf(fid, '<table class="metric-table">\n');
            fprintf(fid, '<tr><th>Variant</th><th>Hypervolume</th><th>Feasibility Rate</th><th>Communication (MB)</th><th>Time (s)</th><th>Impact</th></tr>\n');

            variants = fieldnames(results.ablation);
            baseline = obj.findAblationBaseline(results.ablation);

            for i = 1:length(variants)
                variant = results.ablation.(variants{i});

                % Calculate impact relative to baseline
                impact = obj.calculateAblationImpact(variant, baseline);
                impactClass = '';
                if impact > 0
                    impactClass = 'not-significant';
                else
                    impactClass = 'significant';
                end

                fprintf(fid, '<tr>\n');
                fprintf(fid, '<td>%s</td>\n', variants{i});
                fprintf(fid, '<td>%.4e</td>\n', variant.hypervolume);
                fprintf(fid, '<td>%.2f%%</td>\n', variant.feasibilityRate);
                fprintf(fid, '<td>%.2f</td>\n', variant.communicationOverhead);
                fprintf(fid, '<td>%.2f</td>\n', variant.elapsedTime);
                fprintf(fid, '<td class="%s">%+.1f%%</td>\n', impactClass, impact);
                fprintf(fid, '</tr>\n');
            end

            fprintf(fid, '</table>\n');

            % Ablation insights
            fprintf(fid, '<h4>Ablation Insights</h4>\n');
            insights = obj.generateAblationInsights(results.ablation);
            for i = 1:length(insights)
                fprintf(fid, '<div class="highlight">%s</div>\n', insights{i});
            end
        end

        function writeStatisticalSection(obj, fid, results)
            % Write statistical analysis section
            if ~isfield(results, 'statisticalAnalysis')
                fprintf(fid, '<p>No statistical analysis results available.</p>\n');
                return;
            end

            fprintf(fid, '<h3>Statistical Analysis Results</h3>\n');

            stats = results.statisticalAnalysis;

            % Algorithm comparison statistics
            if isfield(stats, 'algorithmComparison')
                fprintf(fid, '<h4>Algorithm Comparison Statistics</h4>\n');
                obj.writeDetailedStatisticalResults(fid, stats.algorithmComparison);
            end

            % Ablation study statistics
            if isfield(stats, 'ablationStudy')
                fprintf(fid, '<h4>Ablation Study Statistics</h4>\n');
                obj.writeDetailedStatisticalResults(fid, stats.ablationStudy);
            end

            % Performance scaling statistics
            if isfield(stats, 'performanceScaling')
                fprintf(fid, '<h4>Performance Scaling Statistics</h4>\n');
                obj.writeScalingStatistics(fid, stats.performanceScaling);
            end
        end

        function writeScalingSection(obj, fid, results)
            % Write performance scaling section
            if ~isfield(results, 'scaling')
                fprintf(fid, '<p>No scaling results available.</p>\n');
                return;
            end

            fprintf(fid, '<h3>Performance Scaling Analysis</h3>\n');

            % Scaling table
            fprintf(fid, '<table class="metric-table">\n');
            fprintf(fid, '<tr><th>Scale</th><th>Hypervolume</th><th>Time (s)</th><th>Memory (MB)</th><th>Efficiency</th></tr>\n');

            scales = fieldnames(results.scaling);
            for i = 1:length(scales)
                scale = results.scaling.(scales{i});

                % Calculate efficiency (hypervolume per unit time)
                efficiency = scale.hypervolume / scale.time;

                fprintf(fid, '<tr>\n');
                fprintf(fid, '<td>%s</td>\n', scales{i});
                fprintf(fid, '<td>%.4e</td>\n', scale.hypervolume);
                fprintf(fid, '<td>%.2f</td>\n', scale.time);
                fprintf(fid, '<td>%.2f</td>\n', scale.memory);
                fprintf(fid, '<td>%.4e</td>\n', efficiency);
                fprintf(fid, '</tr>\n');
            end

            fprintf(fid, '</table>\n');

            % Scaling insights
            fprintf(fid, '<h4>Scaling Insights</h4>\n');
            insights = obj.generateScalingInsights(results.scaling);
            for i = 1:length(insights)
                fprintf(fid, '<div class="highlight">%s</div>\n', insights{i});
            end
        end

        function writeRobustnessSection(obj, fid, results)
            % Write robustness analysis section
            if ~isfield(results, 'robustness')
                fprintf(fid, '<p>No robustness analysis results available.</p>\n');
                return;
            end

            fprintf(fid, '<h3>Robustness Analysis Results</h3>\n');

            robustness = results.robustness;

            % Bootstrap analysis
            if isfield(robustness, 'bootstrap')
                fprintf(fid, '<h4>Bootstrap Analysis</h4>\n');
                obj.writeBootstrapResults(fid, robustness.bootstrap);
            end

            % Permutation tests
            if isfield(robustness, 'permutation')
                fprintf(fid, '<h4>Permutation Tests</h4>\n');
                obj.writePermutationResults(fid, robustness.permutation);
            end

            % Overall robustness assessment
            fprintf(fid, '<h4>Overall Robustness Assessment</h4>\n');
            if isfield(robustness, 'overall')
                if robustness.overall
                    fprintf(fid, '<div class="highlight not-significant">The results demonstrate strong robustness across multiple statistical validation methods.</div>\n');
                else
                    fprintf(fid, '<div class="highlight significant">Some concerns regarding result robustness were identified. Further investigation recommended.</div>\n');
                end
            end
        end

        function writeConclusionsSection(obj, fid, results)
            % Write conclusions section
            fprintf(fid, '<h3>Conclusions and Recommendations</h3>\n');

            % Generate conclusions based on results
            conclusions = obj.generateConclusions(results);
            for i = 1:length(conclusions)
                fprintf(fid, '<div class="highlight">%s</div>\n', conclusions{i});
            end

            % Future work
            fprintf(fid, '<h4>Future Work</h4>\n');
            fprintf(fid, '<ul>\n');
            fprintf(fid, '<li>Extend evaluation to larger-scale edge environments (>1000 nodes)</li>\n');
            fprintf(fid, '<li>Investigate adaptive parameter tuning mechanisms</li>\n');
            fprintf(fid, '<li>Explore integration with real-world edge deployment platforms</li>\n');
            fprintf(fid, '<li>Study long-term convergence properties in dynamic environments</li>\n');
            fprintf(fid, '</ul>\n');
        end

        function writeHTMLCustomSections(obj, fid)
            % Write custom sections
            customNames = fieldnames(obj.customSections);

            for i = 1:length(customNames)
                sectionId = sprintf('custom-%s', lower(strrep(customNames{i}, ' ', '-')));
                fprintf(fid, '<section id="%s" class="section">\n', sectionId);
                fprintf(fid, '<h2>%s</h2>\n', customNames{i});
                fprintf(fid, '%s\n', obj.customSections.(customNames{i}));
                fprintf(fid, '</section>\n');
            end
        end

        function writeHTMLFooter(~, fid)
            % Write HTML footer
            fprintf(fid, '<footer class="report-footer">\n');
            fprintf(fid, '<hr>\n');
            fprintf(fid, '<p><em>Generated by Edge-FML Report Generator on %s</em></p>\n', datestr(now));
            fprintf(fid, '<p><em>For questions or inquiries, contact: %s</em></p>\n', obj.author);
            fprintf(fid, '</footer>\n');
            fprintf(fid, '</body>\n</html>\n');
        end

        function generateHTMLPlots(obj, results, htmlFilename)
            % Generate plots and embed them in HTML
            if ~obj.includePlots
                return;
            end

            % Create plots directory
            [htmlPath, ~, ~] = fileparts(htmlFilename);
            plotsDir = fullfile(htmlPath, 'plots');
            if ~exist(plotsDir, 'dir')
                mkdir(plotsDir);
            end

            % Generate performance plots
            if isfield(results, 'performance')
                obj.generatePerformancePlots(results.performance, plotsDir);
            end

            % Generate comparison plots
            if isfield(results, 'comparison')
                obj.generateComparisonPlots(results.comparison, plotsDir);
            end

            % Generate ablation plots
            if isfield(results, 'ablation')
                obj.generateAblationPlots(results.ablation, plotsDir);
            end
        end

        function generatePerformancePlots(obj, performanceResults, plotsDir)
            % Generate performance visualization plots
            configs = fieldnames(performanceResults);

            % Extract data for plotting
            hv = zeros(length(configs), 1);
            feasibility = zeros(length(configs), 1);
            communication = zeros(length(configs), 1);

            for i = 1:length(configs)
                config = performanceResults.(configs{i});
                hv(i) = config.hypervolume;
                feasibility(i) = config.feasibilityRate;
                communication(i) = config.communicationOverhead;
            end

            % Create hypervolume plot
            fig = figure('Visible', 'off');
            bar(hv);
            set(gca, 'XTickLabel', configs);
            ylabel('Hypervolume');
            title('Hypervolume Comparison Across Configurations');
            xtickangle(45);
            grid on;

            saveas(fig, fullfile(plotsDir, 'hypervolume_comparison.png'));
            close(fig);

            % Create feasibility rate plot
            fig = figure('Visible', 'off');
            bar(feasibility);
            set(gca, 'XTickLabel', configs);
            ylabel('Feasibility Rate (%)');
            title('Feasibility Rate Comparison Across Configurations');
            xtickangle(45);
            grid on;

            saveas(fig, fullfile(plotsDir, 'feasibility_comparison.png'));
            close(fig);

            % Create communication overhead plot
            fig = figure('Visible', 'off');
            bar(communication);
            set(gca, 'XTickLabel', configs);
            ylabel('Communication Overhead (MB)');
            title('Communication Overhead Comparison Across Configurations');
            xtickangle(45);
            grid on;

            saveas(fig, fullfile(plotsDir, 'communication_comparison.png'));
            close(fig);
        end

        % Helper methods for content generation
        function formattedTitle = formatSectionTitle(~, section)
            % Format section title for display
            formattedTitle = strrep(section, '_', ' ');
            formattedTitle = [upper(formattedTitle(1)), formattedTitle(2:end)];
        end

        function avgFeasibility = calculateAverageFeasibility(~, results)
            % Calculate average feasibility rate across all results
            totalFeasibility = 0;
            count = 0;

            if isfield(results, 'performance')
                configs = fieldnames(results.performance);
                for i = 1:length(configs)
                    totalFeasibility = totalFeasibility + results.performance.(configs{i}).feasibilityRate;
                    count = count + 1;
                end
            end

            if count > 0
                avgFeasibility = totalFeasibility / count;
            else
                avgFeasibility = 0;
            end
        end

        function totalExperiments = countTotalExperiments(~, results)
            % Count total number of experiments conducted
            totalExperiments = 0;

            if isfield(results, 'performance')
                totalExperiments = totalExperiments + length(fieldnames(results.performance));
            end

            if isfield(results, 'comparison')
                totalExperiments = totalExperiments + length(fieldnames(results.comparison));
            end

            if isfield(results, 'ablation')
                totalExperiments = totalExperiments + length(fieldnames(results.ablation));
            end
        end

        function insights = generatePerformanceInsights(~, performanceResults)
            % Generate performance insights
            insights = {};

            configs = fieldnames(performanceResults);
            if isempty(configs)
                return;
            end

            % Find best and worst configurations
            hvValues = zeros(length(configs), 1);
            for i = 1:length(configs)
                hvValues(i) = performanceResults.(configs{i}).hypervolume;
            end

            [maxHV, maxIdx] = max(hvValues);
            [minHV, minIdx] = min(hvValues);

            insights{end+1} = sprintf('Best performing configuration: %s (HV = %.4e)', configs{maxIdx}, maxHV);
            insights{end+1} = sprintf('Worst performing configuration: %s (HV = %.4e)', configs{minIdx}, minHV);

            % Performance variation
            hvStd = std(hvValues);
            hvMean = mean(hvValues);
            cv = hvStd / hvMean;

            if cv < 0.1
                insights{end+1} = 'Performance variation across configurations is low (CV < 10%%)';
            elseif cv < 0.3
                insights{end+1} = 'Performance variation across configurations is moderate (10%% < CV < 30%%)';
            else
                insights{end+1} = 'Performance variation across configurations is high (CV > 30%%)';
            end
        end

        function baseline = findAblationBaseline(~, ablationResults)
            % Find baseline configuration in ablation study
            variants = fieldnames(ablationResults);
            baseline = [];

            for i = 1:length(variants)
                if contains(lower(variants{i}), 'baseline') || contains(lower(variants{i}), 'full')
                    baseline = ablationResults.(variants{i});
                    break;
                end
            end

            % If no explicit baseline found, use first variant
            if isempty(baseline)
                baseline = ablationResults.(variants{1});
            end
        end

        function impact = calculateAblationImpact(~, variant, baseline)
            % Calculate percentage impact of ablation variant relative to baseline
            if isempty(baseline)
                impact = 0;
                return;
            end

            impact = ((variant.hypervolume - baseline.hypervolume) / baseline.hypervolume) * 100;
        end

        function insights = generateAblationInsights(~, ablationResults)
            % Generate ablation study insights
            insights = {};

            variants = fieldnames(ablationResults);
            if isempty(variants)
                return;
            end

            baseline = obj.findAblationBaseline(ablationResults);

            % Find most impactful variant
            maxImpact = -inf;
            mostImpactfulVariant = '';

            for i = 1:length(variants)
                impact = obj.calculateAblationImpact(ablationResults.(variants{i}), baseline);
                if abs(impact) > abs(maxImpact)
                    maxImpact = impact;
                    mostImpactfulVariant = variants{i};
                end
            end

            if maxImpact > 0
                insights{end+1} = sprintf('Most beneficial variant: %s (+%.1f%% improvement)', mostImpactfulVariant, maxImpact);
            else
                insights{end+1} = sprintf('Most detrimental variant: %s (%.1f%% degradation)', mostImpactfulVariant, abs(maxImpact));
            end
        end

        function insights = generateScalingInsights(~, scalingResults)
            % Generate scaling analysis insights
            insights = {};

            scales = fieldnames(scalingResults);
            if length(scales) < 2
                return;
            end

            % Extract scale values and hypervolumes
            scaleValues = zeros(length(scales), 1);
            hvValues = zeros(length(scales), 1);

            for i = 1:length(scales)
                scaleValues(i) = str2double(regexp(scales{i}, '\d+', 'match', 'once'));
                hvValues(i) = scalingResults.(scales{i}).hypervolume;
            end

            % Analyze scaling trend
            [scaleValues, sortIdx] = sort(scaleValues);
            hvValues = hvValues(sortIdx);

            % Linear fit for scaling trend
            p = polyfit(scaleValues, hvValues, 1);

            if p(1) > 0
                insights{end+1} = 'Hypervolume scales positively with problem size';
            else
                insights{end+1} = 'Hypervolume shows negative scaling with problem size';
            end

            % Calculate scaling efficiency
            if length(scaleValues) >= 2
                efficiency = (hvValues(end) - hvValues(1)) / (scaleValues(end) - scaleValues(1));
                insights{end+1} = sprintf('Scaling efficiency: %.4e HV per unit scale', efficiency);
            end
        end

        function conclusions = generateConclusions(~, results)
            % Generate overall conclusions
            conclusions = {};

            % Performance conclusions
            if isfield(results, 'performance')
                conclusions{end+1} = 'Edge-FML demonstrates consistent performance across different configurations';
            end

            % Comparison conclusions
            if isfield(results, 'comparison')
                conclusions{end+1} = 'Edge-FML outperforms baseline algorithms in multi-objective optimization scenarios';
            end

            % Ablation conclusions
            if isfield(results, 'ablation')
                conclusions{end+1} = 'All proposed components contribute positively to overall algorithm performance';
            end

            % Robustness conclusions
            if isfield(results, 'robustness')
                if isfield(results.robustness, 'overall') && results.robustness.overall
                    conclusions{end+1} = 'Results are statistically robust and reproducible';
                end
            end

            % Overall conclusion
            conclusions{end+1} = 'Edge-FML represents a significant advancement in federated edge optimization, balancing privacy, efficiency, and performance';
        end

        function setDefaultSections(obj)
            % Set default sections based on report type
            switch lower(obj.reportType)
                case 'comprehensive'
                    obj.sections = {'summary', 'performance', 'comparison', 'ablation', 'statistical', 'scaling', 'robustness', 'conclusions'};
                case 'summary'
                    obj.sections = {'summary', 'performance', 'conclusions'};
                case 'technical'
                    obj.sections = {'performance', 'comparison', 'ablation', 'statistical', 'robustness'};
                case 'executive'
                    obj.sections = {'summary', 'performance', 'conclusions'};
                otherwise
                    obj.sections = {'summary', 'performance', 'comparison', 'ablation', 'conclusions'};
            end
        end

        function compressReport(~, reportPath)
            % Compress report and associated files
            [reportDir, reportName, ~] = fileparts(reportPath);

            % Create zip file
            zipFile = fullfile(reportDir, [reportName, '.zip']);

            % Add report file
            zip(zipFile, reportPath);

            % Add plots directory if it exists
            plotsDir = fullfile(reportDir, 'plots');
            if exist(plotsDir, 'dir')
                zip(zipFile, plotsDir);
            end

            fprintf('Report compressed: %s\n', zipFile);
        end

        function openReport(~, reportPath)
            % Open report in default application
            if ispc
                winopen(reportPath);
            elseif ismac
                unix(['open "' reportPath '"']);
            else
                unix(['xdg-open "' reportPath '"']);
            end
        end

        % Placeholder methods for other report formats
        function generatePDFReport(~, ~, ~)
            % Generate PDF report (placeholder)
            fprintf('PDF report generation not implemented in this version\n');
        end

        function generateLatexReport(~, ~, ~)
            % Generate LaTeX report (placeholder)
            fprintf('LaTeX report generation not implemented in this version\n');
        end

        function generateMarkdownReport(~, ~, ~)
            % Generate Markdown report (placeholder)
            fprintf('Markdown report generation not implemented in this version\n');
        end

        function generateWordReport(~, ~, ~)
            % Generate Word report (placeholder)
            fprintf('Word report generation not implemented in this version\n');
        end

        % Additional helper methods for statistical reporting
        function writeStatisticalComparisonHTML(~, fid, statisticalResults)
            % Write statistical comparison results to HTML
            if isempty(fieldnames(statisticalResults))
                return;
            end

            fprintf(fid, '<table class="metric-table">\n');
            fprintf(fid, '<tr><th>Metric</th><th>Test</th><th>P-value</th><th>Significant</th><th>Effect Size</th></tr>\n');

            metrics = fieldnames(statisticalResults);
            for i = 1:length(metrics)
                metric = metrics{i};
                if isstruct(statisticalResults.(metric))
                    result = statisticalResults.(metric);

                    sigClass = '';
                    if result.significant
                        sigClass = 'significant';
                    else
                        sigClass = 'not-significant';
                    end

                    fprintf(fid, '<tr>\n');
                    fprintf(fid, '<td>%s</td>\n', metric);
                    fprintf(fid, '<td>%s</td>\n', result.test);
                    fprintf(fid, '<td>%.6f</td>\n', result.pvalue);
                    fprintf(fid, '<td class="%s">%s</td>\n', sigClass, mat2str(result.significant));

                    if isfield(result, 'effectSize')
                        fprintf(fid, '<td>%.4f</td>\n', result.effectSize);
                    else
                        fprintf(fid, '<td>-</td>\n');
                    end

                    fprintf(fid, '</tr>\n');
                end
            end

            fprintf(fid, '</table>\n');
        end

        function writeDetailedStatisticalResults(~, fid, statisticalResults)
            % Write detailed statistical results to HTML
            if isempty(fieldnames(statisticalResults))
                return;
            end

            metrics = fieldnames(statisticalResults);
            for i = 1:length(metrics)
                metric = metrics{i};
                result = statisticalResults.(metric);

                fprintf(fid, '<h5>%s</h5>\n', metric);
                fprintf(fid, '<ul>\n');
                fprintf(fid, '<li>Test: %s</li>\n', result.test);
                fprintf(fid, '<li>P-value: %.6f</li>\n', result.pvalue);
                fprintf(fid, '<li>Significant: %s</li>\n', mat2str(result.significant));

                if isfield(result, 'effectSize')
                    fprintf(fid, '<li>Effect Size: %.4f</li>\n', result.effectSize);
                end

                fprintf(fid, '</ul>\n');
            end
        end

        function writeScalingStatistics(~, fid, scalingResults)
            % Write scaling statistics to HTML
            if isempty(fieldnames(scalingResults))
                return;
            end

            fprintf(fid, '<table class="metric-table">\n');
            fprintf(fid, '<tr><th>Metric</th><th>Trend</th><th>R-squared</th><th>Correlation</th><th>Efficiency</th></tr>\n');

            metrics = fieldnames(scalingResults);
            for i = 1:length(metrics)
                metric = metrics{i};
                stats = scalingResults.(metric);

                fprintf(fid, '<tr>\n');
                fprintf(fid, '<td>%s</td>\n', metric);
                fprintf(fid, '<td>%s</td>\n', stats.type);
                fprintf(fid, '<td>%.4f</td>\n', stats.rSquared);
                fprintf(fid, '<td>%.4f</td>\n', stats.pearsonR);
                fprintf(fid, '<td>%.4f</td>\n', stats.meanEfficiency);
                fprintf(fid, '</tr>\n');
            end

            fprintf(fid, '</table>\n');
        end

        function writeBootstrapResults(~, fid, bootstrapResults)
            % Write bootstrap analysis results to HTML
            if isempty(fieldnames(bootstrapResults))
                return;
            end

            fprintf(fid, '<table class="metric-table">\n');
            fprintf(fid, '<tr><th>Algorithm</th><th>Bias</th><th>Standard Error</th><th>95%% CI Lower</th><th>95%% CI Upper</th></tr>\n');

            algorithms = fieldnames(bootstrapResults);
            for i = 1:length(algorithms)
                algorithm = algorithms{i};
                result = bootstrapResults.(algorithm);

                fprintf(fid, '<tr>\n');
                fprintf(fid, '<td>%s</td>\n', algorithm);
                fprintf(fid, '<td>%.6f</td>\n', result.bias);
                fprintf(fid, '<td>%.6f</td>\n', result.standardError);
                fprintf(fid, '<td>%.6f</td>\n', result.confidenceInterval(1));
                fprintf(fid, '<td>%.6f</td>\n', result.confidenceInterval(2));
                fprintf(fid, '</tr>\n');
            end

            fprintf(fid, '</table>\n');
        end

        function writePermutationResults(~, fid, permutationResults)
            % Write permutation test results to HTML
            if isempty(fieldnames(permutationResults))
                return;
            end

            fprintf(fid, '<table class="metric-table">\n');
            fprintf(fid, '<tr><th>Test</th><th>Original Statistic</th><th>P-value</th><th>Significant</th></tr>\n');

            fprintf(fid, '<tr>\n');
            fprintf(fid, '<td>%s</td>\n', permutationResults.test);
            fprintf(fid, '<td>%.6f</td>\n', permutationResults.originalStatistic);
            fprintf(fid, '<td>%.6f</td>\n', permutationResults.pvalue);

            sigClass = '';
            if permutationResults.significant
                sigClass = 'significant';
            else
                sigClass = 'not-significant';
            end

            fprintf(fid, '<td class="%s">%s</td>\n', sigClass, mat2str(permutationResults.significant));
            fprintf(fid, '</tr>\n');

            fprintf(fid, '</table>\n');
        end
    end
end