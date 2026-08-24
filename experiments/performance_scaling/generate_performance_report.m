% Generate Performance Report for Edge-FML Scaling Experiments
% This script analyzes and visualizes the results from performance scaling experiments

clear; clc; close all;

% Resolve project root and add source/experiments to path (robust across cwd)
scriptFull = which('generate_performance_report.m');
if isempty(scriptFull)
    scriptFull = mfilename('fullpath');
end
scriptDir = fileparts(scriptFull);
projectRoot = fileparts(fileparts(scriptDir));

% Add common src and experiments directories to path
addpath(fullfile(projectRoot, 'src'));
addpath(fullfile(projectRoot, 'experiments'));

% Load configuration using absolute path
run(fullfile(projectRoot, 'experiments', 'config.m'));

% Normalize config paths: ensure results_dir and figures_dir are absolute
if ~isfield(commonConfig, 'results_dir') || isempty(commonConfig.results_dir)
    error('commonConfig.results_dir is not set in experiments/config.m');
end
% If configured path is relative, make it absolute relative to projectRoot
if ~isfolder(commonConfig.results_dir)
    commonConfig.results_dir = fullfile(projectRoot, commonConfig.results_dir);
end
if ~isfolder(commonConfig.figures_dir)
    commonConfig.figures_dir = fullfile(projectRoot, commonConfig.figures_dir);
end

% Find the latest results file. Try both the configured path and the absolute path
resultsFiles = [];
resultsDirCandidates = {commonConfig.results_dir, fullfile(projectRoot, commonConfig.results_dir)};
resultsDirUsed = '';
for c = 1:length(resultsDirCandidates)
    candidate = resultsDirCandidates{c};
    if isfolder(candidate)
        candidateFiles = dir(fullfile(candidate, 'performance_results_*.mat'));
        if ~isempty(candidateFiles)
            resultsFiles = candidateFiles;
            resultsDirUsed = candidate;
            break;
        end
    end
end

if isempty(resultsFiles)
    error('No performance results files found in any of the candidate locations: %s', strjoin(resultsDirCandidates, ', '));
end

% Sort by date (newest first)
[~, idx] = sort([resultsFiles.datenum], 'descend');
latestFile = resultsFiles(idx(1));

fprintf('Loading latest results from: %s\n', latestFile.name);
load(fullfile(resultsDirUsed, latestFile.name), 'results');

% Create figures directory (ensure base is absolute)
if isfolder(commonConfig.figures_dir)
    figuresBase = commonConfig.figures_dir;
else
    figuresBase = fullfile(projectRoot, commonConfig.figures_dir);
end
figuresDir = fullfile(figuresBase, sprintf('performance_%s', results.timestamp));
if ~exist(figuresDir, 'dir')
    mkdir(figuresDir);
end

fprintf('Generating performance report...\n\n');

% =======================================
% 1. Extract and organize data
% =======================================


% Extract all run keys
runKeys = fieldnames(results.runs);

% Build comprehensive lists of regions, scenarios and datasets from all runs
allRegions = [];
allScenarios = {};
allDatasets = {};
for k = 1:length(runKeys)
    r = results.runs.(runKeys{k});
    % Some run entries might be empty or partial; guard against missing fields
    if isfield(r, 'numRegions') && ~isempty(r.numRegions)
        allRegions(end+1) = r.numRegions; %#ok<AGROW>
    end
    if isfield(r, 'scenarioType') && ~isempty(r.scenarioType)
        allScenarios{end+1} = r.scenarioType; %#ok<AGROW>
    end
    if isfield(r, 'dataset') && ~isempty(r.dataset)
        allDatasets{end+1} = r.dataset; %#ok<AGROW>
    end
end

% Initialize data structures for analysis using the aggregated unique lists
data = struct();
data.regionCounts = unique(allRegions);
data.scenarioTypes = unique(allScenarios);
data.datasets = unique(allDatasets);

% Organize results by region count, scenario type, and dataset
data.hv = cell(length(data.regionCounts), length(data.scenarioTypes), length(data.datasets));
data.feasRate = cell(length(data.regionCounts), length(data.scenarioTypes), length(data.datasets));
data.elapsedTime = cell(length(data.regionCounts), length(data.scenarioTypes), length(data.datasets));
data.commBytes = cell(length(data.regionCounts), length(data.scenarioTypes), length(data.datasets));
data.diversity = cell(length(data.regionCounts), length(data.scenarioTypes), length(data.datasets));

for keyIdx = 1:length(runKeys)
    run = results.runs.(runKeys{keyIdx});

    % Find indices
    regionIdx = find(data.regionCounts == run.numRegions);
    scenarioIdx = find(strcmp(data.scenarioTypes, run.scenarioType));
    datasetIdx = find(strcmp(data.datasets, run.dataset));

    % Store data
    data.hv{regionIdx, scenarioIdx, datasetIdx} = [data.hv{regionIdx, scenarioIdx, datasetIdx}; run.hypervolume];
    data.feasRate{regionIdx, scenarioIdx, datasetIdx} = [data.feasRate{regionIdx, scenarioIdx, datasetIdx}; run.feasibilityRate];
    data.elapsedTime{regionIdx, scenarioIdx, datasetIdx} = [data.elapsedTime{regionIdx, scenarioIdx, datasetIdx}; run.elapsedTime];
    data.commBytes{regionIdx, scenarioIdx, datasetIdx} = [data.commBytes{regionIdx, scenarioIdx, datasetIdx}; run.totalCommBytes];
    data.diversity{regionIdx, scenarioIdx, datasetIdx} = [data.diversity{regionIdx, scenarioIdx, datasetIdx}; run.diversity];
end

% =======================================
% 2. Generate statistical summary
% =======================================

fprintf('=== Statistical Summary ===\n\n');

% Create summary table
for scenarioIdx = 1:length(data.scenarioTypes)
    scenario = data.scenarioTypes{scenarioIdx};
    fprintf('Scenario: %s\n', scenario);
    fprintf('%-10s %-15s %-15s %-15s %-15s\n', 'Regions', 'HV (mean±std)', 'FeasRate (%)', 'Time (s)', 'Comm (MB)');
    fprintf('%-10s %-15s %-15s %-15s %-15s\n', '--------', '---------------', '---------------', '---------------', '---------------');

    for regionIdx = 1:length(data.regionCounts)
        regions = data.regionCounts(regionIdx);

        % Use medium dataset for summary
        datasetIdx = find(strcmp(data.datasets, 'benchmark_medium.mat'));
        if isempty(datasetIdx)
            datasetIdx = 1; % Fallback to first dataset
        end

        hv = data.hv{regionIdx, scenarioIdx, datasetIdx};
        feas = data.feasRate{regionIdx, scenarioIdx, datasetIdx};
        time = data.elapsedTime{regionIdx, scenarioIdx, datasetIdx};
        comm = data.commBytes{regionIdx, scenarioIdx, datasetIdx} / 1e6;

        fprintf('%-10d %-15s %-15.2f %-15.2f %-15.2f\n', ...
            regions, sprintf('%.2e±%.2e', mean(hv), std(hv)), ...
            mean(feas), mean(time), mean(comm));
    end
    fprintf('\n');
end

% =======================================
% 3. Generate visualizations
% =======================================

% Set figure parameters
fontSize = 12;
lineWidth = 2;
markerSize = 8;

% ---------------------------------------
% 3.1 Hypervolume vs Region Count
% ---------------------------------------
fprintf('Generating Hypervolume vs Region Count plots...\n');

for scenarioIdx = 1:length(data.scenarioTypes)
    scenario = data.scenarioTypes{scenarioIdx};

    figure('Position', [100, 100, 1800, 500]);

    for datasetIdx = 1:length(data.datasets)
        dataset = data.datasets{datasetIdx};

        hvMeans = zeros(length(data.regionCounts), 1);
        hvStds = zeros(length(data.regionCounts), 1);

        for regionIdx = 1:length(data.regionCounts)
            hv = data.hv{regionIdx, scenarioIdx, datasetIdx};
            hvMeans(regionIdx) = mean(hv);
            hvStds(regionIdx) = std(hv);
        end

        subplot(1, 3, datasetIdx);
        plot(data.regionCounts, hvMeans, ...
            'LineWidth', lineWidth, 'MarkerSize', markerSize, 'Marker', 'o');

        title(sprintf('%s Dataset', dataset), 'FontSize', fontSize+2, 'FontWeight', 'bold', 'Interpreter', 'none');
        xlabel('Number of Regions', 'FontSize', fontSize);
        ylabel('Hypervolume', 'FontSize', fontSize);
        grid on;
        xlim([min(data.regionCounts)-5, max(data.regionCounts)+5]);
        set(gca, 'FontSize', fontSize);
    end

    % Add main title
    sgtitle(sprintf('Hypervolume vs Region Count (%s Scenario)', scenario), 'FontSize', fontSize+4, 'FontWeight', 'bold');

    % Save figure
    figName = sprintf('%s/hv_vs_regions_%s.png', figuresDir, scenario);
    saveas(gcf, figName, 'png');
    saveas(gcf, strrep(figName, '.png', '.eps'), 'epsc');
    fprintf('  Saved: %s\n', figName);
end

% ---------------------------------------
% 3.2 Communication Overhead vs Region Count
% ---------------------------------------
fprintf('Generating Communication Overhead vs Region Count plots...\n');

for scenarioIdx = 1:length(data.scenarioTypes)
    scenario = data.scenarioTypes{scenarioIdx};

    figure('Position', [100, 100, 1800, 500]);

    for datasetIdx = 1:length(data.datasets)
        dataset = data.datasets{datasetIdx};

        commMeans = zeros(length(data.regionCounts), 1);
        commStds = zeros(length(data.regionCounts), 1);

        for regionIdx = 1:length(data.regionCounts)
            comm = data.commBytes{regionIdx, scenarioIdx, datasetIdx} / 1e6;
            commMeans(regionIdx) = mean(comm);
            commStds(regionIdx) = std(comm);
        end

        subplot(1, 3, datasetIdx);
        plot(data.regionCounts, commMeans, ...
            'LineWidth', lineWidth, 'MarkerSize', markerSize, 'Marker', 'o');

        title(sprintf('%s Dataset', dataset), 'FontSize', fontSize+2, 'FontWeight', 'bold', 'Interpreter', 'none');
        xlabel('Number of Regions', 'FontSize', fontSize);
        ylabel('Communication Overhead (MB)', 'FontSize', fontSize);
        grid on;
        xlim([min(data.regionCounts)-5, max(data.regionCounts)+5]);
        set(gca, 'FontSize', fontSize);
    end

    % Add main title
    sgtitle(sprintf('Communication Overhead vs Region Count (%s Scenario)', scenario), 'FontSize', fontSize+4, 'FontWeight', 'bold');

    % Save figure
    figName = sprintf('%s/comm_vs_regions_%s.png', figuresDir, scenario);
    saveas(gcf, figName, 'png');
    saveas(gcf, strrep(figName, '.png', '.eps'), 'epsc');
    fprintf('  Saved: %s\n', figName);
end

% ---------------------------------------
% 3.3 Feasibility Rate vs Region Count
% ---------------------------------------
fprintf('Generating Feasibility Rate vs Region Count plots...\n');

for scenarioIdx = 1:length(data.scenarioTypes)
    scenario = data.scenarioTypes{scenarioIdx};

    figure('Position', [100, 100, 1800, 500]);

    for datasetIdx = 1:length(data.datasets)
        dataset = data.datasets{datasetIdx};

        feasMeans = zeros(length(data.regionCounts), 1);
        feasStds = zeros(length(data.regionCounts), 1);

        for regionIdx = 1:length(data.regionCounts)
            feas = data.feasRate{regionIdx, scenarioIdx, datasetIdx};
            feasMeans(regionIdx) = mean(feas);
            feasStds(regionIdx) = std(feas);
        end

        subplot(1, 3, datasetIdx);
        plot(data.regionCounts, feasMeans, ...
            'LineWidth', lineWidth, 'MarkerSize', markerSize, 'Marker', 'o');

        title(sprintf('%s Dataset', dataset), 'FontSize', fontSize+2, 'FontWeight', 'bold', 'Interpreter', 'none');
        xlabel('Number of Regions', 'FontSize', fontSize);
        ylabel('Feasibility Rate (%)', 'FontSize', fontSize);
        grid on;
        xlim([min(data.regionCounts)-5, max(data.regionCounts)+5]);
        ylim([0, 105]);
        set(gca, 'FontSize', fontSize);
    end

    % Add main title
    sgtitle(sprintf('Feasibility Rate vs Region Count (%s Scenario)', scenario), 'FontSize', fontSize+4, 'FontWeight', 'bold');

    % Save figure
    figName = sprintf('%s/feas_vs_regions_%s.png', figuresDir, scenario);
    saveas(gcf, figName, 'png');
    saveas(gcf, strrep(figName, '.png', '.eps'), 'epsc');
    fprintf('  Saved: %s\n', figName);
end

% ---------------------------------------
% 3.4 Convergence Curves
% ---------------------------------------
fprintf('Generating Convergence Curve plots...\n');

% Extract convergence data for a representative run
% Use medium dataset, heterogeneous scenario, 30 regions
representativeRunKey = '';
for keyIdx = 1:length(runKeys)
    run = results.runs.(runKeys{keyIdx});
    if strcmp(run.dataset, 'benchmark_medium.mat') && ...
       strcmp(run.scenarioType, 'heterogeneous') && ...
       run.numRegions == 30
        representativeRunKey = runKeys{keyIdx};
        break;
    end
end

if ~isempty(representativeRunKey)
    fprintf('Using representative run: %s\n', representativeRunKey);

    % Extract convergence history
    convHistory = results.runs.(representativeRunKey).convergenceHistory;
    rounds = [convHistory.round];
    hvValues = [convHistory.HV];
    feasValues = [convHistory.feasibilityRate];

    figure('Position', [100, 100, 1200, 600]);

    % Hypervolume convergence
    subplot(1, 2, 1);
    plot(rounds, hvValues, 'LineWidth', lineWidth, 'MarkerSize', markerSize, 'Marker', 'o');
    title('Hypervolume Convergence', 'FontSize', fontSize+2, 'FontWeight', 'bold');
    xlabel('Federated Round', 'FontSize', fontSize);
    ylabel('Hypervolume', 'FontSize', fontSize);
    grid on;
    set(gca, 'FontSize', fontSize);

    % Feasibility convergence
    subplot(1, 2, 2);
    plot(rounds, feasValues, 'LineWidth', lineWidth, 'MarkerSize', markerSize, 'Marker', 's', 'Color', [0.8500 0.3250 0.0980]);
    title('Feasibility Rate Convergence', 'FontSize', fontSize+2, 'FontWeight', 'bold');
    xlabel('Federated Round', 'FontSize', fontSize);
    ylabel('Feasibility Rate (%)', 'FontSize', fontSize);
    grid on;
    ylim([0, 105]);
    set(gca, 'FontSize', fontSize);

    % Add main title
    sgtitle('Convergence Curves (Medium Dataset, Heterogeneous, 30 Regions)', 'FontSize', fontSize+4, 'FontWeight', 'bold');

    % Save figure
    figName = sprintf('%s/convergence_curve.png', figuresDir);
    saveas(gcf, figName, 'png');
    saveas(gcf, strrep(figName, '.png', '.eps'), 'epsc');
    fprintf('  Saved: %s\n', figName);
end

% ---------------------------------------
% 3.5 Scenario Comparison
% ---------------------------------------
fprintf('Generating Scenario Comparison plots...\n');

% Use medium dataset for scenario comparison
datasetIdx = find(strcmp(data.datasets, 'benchmark_medium.mat'));
if isempty(datasetIdx)
    datasetIdx = 1;
end

figure('Position', [100, 100, 1200, 800]);

% Hypervolume comparison
subplot(2, 2, 1);
for scenarioIdx = 1:length(data.scenarioTypes)
    scenario = data.scenarioTypes{scenarioIdx};

    hvMeans = zeros(length(data.regionCounts), 1);
    hvStds = zeros(length(data.regionCounts), 1);

    for regionIdx = 1:length(data.regionCounts)
        hv = data.hv{regionIdx, scenarioIdx, datasetIdx};
        hvMeans(regionIdx) = mean(hv);
        hvStds(regionIdx) = std(hv);
    end

    plot(data.regionCounts, hvMeans, 'LineWidth', lineWidth, 'MarkerSize', markerSize, ...
        'Marker', 'o', 'DisplayName', scenario);
    hold on;
end

legend('Location', 'best', 'FontSize', fontSize-1);
title('Hypervolume Comparison', 'FontSize', fontSize+2, 'FontWeight', 'bold');
xlabel('Number of Regions', 'FontSize', fontSize);
ylabel('Hypervolume', 'FontSize', fontSize);
grid on;
set(gca, 'FontSize', fontSize);

% Communication comparison
subplot(2, 2, 2);
for scenarioIdx = 1:length(data.scenarioTypes)
    scenario = data.scenarioTypes{scenarioIdx};

    commMeans = zeros(length(data.regionCounts), 1);
    commStds = zeros(length(data.regionCounts), 1);

    for regionIdx = 1:length(data.regionCounts)
        comm = data.commBytes{regionIdx, scenarioIdx, datasetIdx} / 1e6; % Convert to MB
        commMeans(regionIdx) = mean(comm);
        commStds(regionIdx) = std(comm);
    end

    plot(data.regionCounts, commMeans, 'LineWidth', lineWidth, 'MarkerSize', markerSize, ...
        'Marker', 'o', 'DisplayName', scenario);
    hold on;
end

legend('Location', 'best', 'FontSize', fontSize-1);
title('Communication Overhead Comparison', 'FontSize', fontSize+2, 'FontWeight', 'bold');
xlabel('Number of Regions', 'FontSize', fontSize);
ylabel('Communication Overhead (MB)', 'FontSize', fontSize);
grid on;
set(gca, 'FontSize', fontSize);

% Feasibility comparison
subplot(2, 2, 3);
for scenarioIdx = 1:length(data.scenarioTypes)
    scenario = data.scenarioTypes{scenarioIdx};

    feasMeans = zeros(length(data.regionCounts), 1);
    feasStds = zeros(length(data.regionCounts), 1);

    for regionIdx = 1:length(data.regionCounts)
        feas = data.feasRate{regionIdx, scenarioIdx, datasetIdx};
        feasMeans(regionIdx) = mean(feas);
        feasStds(regionIdx) = std(feas);
    end

    plot(data.regionCounts, feasMeans, 'LineWidth', lineWidth, 'MarkerSize', markerSize, ...
        'Marker', 'o', 'DisplayName', scenario);
    hold on;
end

legend('Location', 'best', 'FontSize', fontSize-1);
title('Feasibility Rate Comparison', 'FontSize', fontSize+2, 'FontWeight', 'bold');
xlabel('Number of Regions', 'FontSize', fontSize);
ylabel('Feasibility Rate (%)', 'FontSize', fontSize);
grid on;
ylim([0, 105]);
set(gca, 'FontSize', fontSize);

% Time comparison
subplot(2, 2, 4);
for scenarioIdx = 1:length(data.scenarioTypes)
    scenario = data.scenarioTypes{scenarioIdx};

    timeMeans = zeros(length(data.regionCounts), 1);
    timeStds = zeros(length(data.regionCounts), 1);

    for regionIdx = 1:length(data.regionCounts)
        time = data.elapsedTime{regionIdx, scenarioIdx, datasetIdx};
        timeMeans(regionIdx) = mean(time);
        timeStds(regionIdx) = std(time);
    end

    plot(data.regionCounts, timeMeans, 'LineWidth', lineWidth, 'MarkerSize', markerSize, ...
        'Marker', 'o', 'DisplayName', scenario);
    hold on;
end

legend('Location', 'best', 'FontSize', fontSize-1);
title('Execution Time Comparison', 'FontSize', fontSize+2, 'FontWeight', 'bold');
xlabel('Number of Regions', 'FontSize', fontSize);
ylabel('Execution Time (seconds)', 'FontSize', fontSize);
grid on;
set(gca, 'FontSize', fontSize);

% Add main title
sgtitle('Scenario Comparison (Medium Dataset)', 'FontSize', fontSize+4, 'FontWeight', 'bold');

% Save figure
figName = sprintf('%s/scenario_comparison.png', figuresDir);
saveas(gcf, figName, 'png');
saveas(gcf, strrep(figName, '.png', '.eps'), 'epsc');
fprintf('  Saved: %s\n', figName);
% (end removed) — no matching block to close here

% =======================================
% 4. Generate HTML Report
% =======================================
fprintf('\nGenerating HTML report...\n');

reportFileName = sprintf('%s/performance_report_%s.html', commonConfig.results_dir, results.timestamp);
fid = fopen(reportFileName, 'w');

% Write HTML header
fprintf(fid, '<!DOCTYPE html>\n');
fprintf(fid, '<html lang="en">\n');
fprintf(fid, '<head>\n');
fprintf(fid, '    <meta charset="UTF-8">\n');
fprintf(fid, '    <meta name="viewport" content="width=device-width, initial-scale=1.0">\n');
fprintf(fid, '    <title>Edge-FML Performance Scaling Report</title>\n');
fprintf(fid, '    <style>\n');
fprintf(fid, '        body { font-family: Arial, sans-serif; margin: 20px; }\n');
fprintf(fid, '        h1 { color: #2c3e50; text-align: center; }\n');
fprintf(fid, '        h2 { color: #3498db; margin-top: 30px; }\n');
fprintf(fid, '        h3 { color: #2ecc71; }\n');
fprintf(fid, '        .container { max-width: 1200px; margin: 0 auto; }\n');
fprintf(fid, '        .figure { margin: 30px 0; text-align: center; }\n');
fprintf(fid, '        .figure img { max-width: 100%%; height: auto; border: 1px solid #ddd; padding: 10px; }\n');
fprintf(fid, '        .figure-caption { font-style: italic; color: #7f8c8d; margin-top: 10px; }\n');
fprintf(fid, '        .summary-table { width: 100%%; border-collapse: collapse; margin: 20px 0; }\n');
fprintf(fid, '        .summary-table th, .summary-table td { border: 1px solid #ddd; padding: 12px; text-align: left; }\n');
fprintf(fid, '        .summary-table th { background-color: #f2f2f2; font-weight: bold; }\n');
fprintf(fid, '        .timestamp { text-align: center; color: #95a5a6; margin-bottom: 30px; }\n');
fprintf(fid, '    </style>\n');
fprintf(fid, '    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>\n');
fprintf(fid, '</head>\n');
fprintf(fid, '<body>\n');
fprintf(fid, '    <div class="container">\n');
fprintf(fid, '        <h1>Edge-FML Performance Scaling Report</h1>\n');
fprintf(fid, '        <div class="timestamp">Generated on %s</div>\n', datestr(now));

% Write summary section
fprintf(fid, '        <h2>1. Summary</h2>\n');
fprintf(fid, '        <p>This report presents the performance scaling results for Edge-FML across different dataset sizes, region counts, and scenario types. The experiments were conducted with %d repeated runs for statistical significance.</p>\n', commonConfig.repeat_runs);

% Write experiment configuration
fprintf(fid, '        <h3>1.1 Experiment Configuration</h3>\n');
fprintf(fid, '        <ul>\n');
fprintf(fid, '            <li>Maximum federated rounds: %d</li>\n', commonConfig.R_max);
fprintf(fid, '            <li>Local evolution generations: %d</li>\n', commonConfig.M_local);
fprintf(fid, '            <li>Population size: %d</li>\n', commonConfig.population_size);
fprintf(fid, '            <li>Repeated runs: %d</li>\n', commonConfig.repeat_runs);
fprintf(fid, '        </ul>\n');

% Write results section
fprintf(fid, '        <h2>2. Results</h2>\n');

% Write figures
figureFiles = dir(sprintf('%s/*.png', figuresDir));
absReportDir = ensureAbsolutePath(fileparts(reportFileName), projectRoot);
absFiguresDir = ensureAbsolutePath(figuresDir, projectRoot);
imgBase = makeRelativePath(absFiguresDir, absReportDir);
for figIdx = 1:length(figureFiles)
    figName = figureFiles(figIdx).name;
    fprintf(fid, '        <div class="figure">\n');
    fprintf(fid, '            <img src="%s/%s" alt="%s">\n', imgBase, figName, figName);
    fprintf(fid, '            <div class="figure-caption">%s</div>\n', figName);
    fprintf(fid, '        </div>\n');
end

% Write HTML footer
fprintf(fid, '    </div>\n');
fprintf(fid, '</body>\n');
fprintf(fid, '</html>\n');
fclose(fid);

fprintf('HTML report saved to: %s\n', reportFileName);
fprintf('\nPerformance report generation completed!\n');
fprintf('Figures saved to: %s\n', figuresDir);

function absPath = ensureAbsolutePath(p, projectRoot)
    if isempty(p)
        absPath = p;
        return;
    end
    isAbs = ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
    if isAbs
        absPath = p;
    else
        absPath = fullfile(projectRoot, p);
    end
    absPath = char(absPath);
end

function rel = makeRelativePath(targetPath, basePath)
    targetPath = char(targetPath);
    basePath = char(basePath);

    targetPath = strrep(targetPath, '/', '\\');
    basePath = strrep(basePath, '/', '\\');

    targetParts = regexp(targetPath, '[\\]+', 'split');
    baseParts = regexp(basePath, '[\\]+', 'split');
    targetParts = targetParts(~cellfun('isempty', targetParts));
    baseParts = baseParts(~cellfun('isempty', baseParts));

    if isempty(targetParts) || isempty(baseParts) || ~strcmpi(targetParts{1}, baseParts{1})
        rel = strrep(targetPath, '\', '/');
        return;
    end

    commonLen = 0;
    maxCommon = min(length(targetParts), length(baseParts));
    for i = 1:maxCommon
        if strcmpi(targetParts{i}, baseParts{i})
            commonLen = i;
        else
            break;
        end
    end

    upCount = length(baseParts) - commonLen;
    relParts = cell(1, upCount + (length(targetParts) - commonLen));
    for i = 1:upCount
        relParts{i} = '..';
    end
    for i = 1:(length(targetParts) - commonLen)
        relParts{upCount + i} = targetParts{commonLen + i};
    end

    if isempty(relParts)
        rel = '.';
    else
        rel = fullfile(relParts{:});
    end

    rel = strrep(rel, '\', '/');
end
