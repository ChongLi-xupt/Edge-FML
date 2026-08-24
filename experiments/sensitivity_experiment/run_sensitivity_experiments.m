% Sensitivity Analysis Experiments for Edge-FML
% Sweeps: M_local, M_elite, population_size (single-factor scans)

if ~exist('preserveWorkspace', 'var') || ~preserveWorkspace
    clear;
end
clc; close all;

% Add source directory to path
addpath('../../src');
addpath('../');

% Load canonical config (commonConfig, performanceConfig, ...)
if exist('experiments/config_struct.mat','file')
    load('experiments/config_struct.mat', 'commonConfig', 'comparisonConfig', 'ablationConfig');
else
    run('../config.m');
end
sensitivityConfig.recommended_R_max = 10;  % 确保这里是 50
commonConfig.R_max = 10;                   % 确保这里也是 50
% Sensitivity parameters (as requested)
sensitivityParams = struct();
sensitivityParams.M_local_vals = [5, 10, 20, 40, 60];
sensitivityParams.M_elite_vals = [1, 3, 5, 10, 15];
sensitivityParams.pop_vals = [30, 50, 70, 100];
sensitivityParams.baseline.M_local = 20;
sensitivityParams.baseline.M_elite = 5;
sensitivityParams.baseline.population_size = 50;

% Number of independent seeds per configuration (overrideable)
if exist('sensitivity_nSeeds','var')
    nSeeds = sensitivity_nSeeds;
else
    % nSeeds = 20; % recommended default for statistical power
    nSeeds = 5
end

% Use datasets/scenario_types from comparisonConfig if available
if exist('comparisonConfig','var') && isfield(comparisonConfig,'datasets')
    datasets = comparisonConfig.datasets;
else
    datasets = {'benchmark_medium.mat'};
end
if exist('comparisonConfig','var') && isfield(comparisonConfig,'scenario_types')
    scenario_types = comparisonConfig.scenario_types;
else
    scenario_types = {'heterogeneous'};
end

% Regions default (can be overridden by user variable numRegionsOverride)
if exist('ablationConfig','var') && isfield(ablationConfig,'num_regions')
    defaultNumRegions = ablationConfig.num_regions;
else
    defaultNumRegions = 30;
end

% Prepare results container
results = struct();
results.timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
results.sensitivityParams = sensitivityParams;
results.nSeeds = nSeeds;
results.runs = struct();
results.commonConfig = commonConfig;

% Compute total runs (single-factor scans across three parameters)
totalSingleFactor = (length(sensitivityParams.M_local_vals) + length(sensitivityParams.M_elite_vals) + length(sensitivityParams.pop_vals));
totalRuns = totalSingleFactor * length(datasets) * length(scenario_types) * nSeeds;
runCount = 0;

fprintf('========================================\n');
fprintf('Starting Sensitivity Analysis Experiments\n');
fprintf('Total runs (approx): %d\n', totalRuns);
fprintf('========================================\n');

% Create timestamped results and figures directories (match comparison experiments style)
results_subdir = fullfile(commonConfig.results_dir, sprintf('sensitivity_%s', results.timestamp));
if ~exist(results_subdir, 'dir'), mkdir(results_subdir); end
figures_subdir = fullfile(commonConfig.figures_dir, sprintf('sensitivity_%s', results.timestamp));
if ~exist(figures_subdir, 'dir'), mkdir(figures_subdir); end



% Outer loop: handle each parameter as a single-factor scan
paramSets = { {'M_local', sensitivityParams.M_local_vals}, {'M_elite', sensitivityParams.M_elite_vals}, {'population_size', sensitivityParams.pop_vals} };

for pIdx = 1:length(paramSets)
    paramName = paramSets{pIdx}{1};
    values = paramSets{pIdx}{2};

    for vIdx = 1:length(values)
        val = values(vIdx);

        for dIdx = 1:length(datasets)
            dataset = datasets{dIdx};

            for sIdx = 1:length(scenario_types)
                scenarioType = scenario_types{sIdx};

                for seed = 1:nSeeds
                    runCount = runCount + 1;
                    fprintf('Run %d/%d: Param=%s, Value=%s, Dataset=%s, Scenario=%s, Seed=%d\n', ...
                        runCount, totalRuns, paramName, num2str(val), dataset, scenarioType, seed);

                    rng(seed, 'twister');
                    % Instantiate scenario
                    if exist('numRegionsOverride','var')
                        numRegions = numRegionsOverride;
                    else
                        numRegions = defaultNumRegions;
                    end
                    [regions, taskSets] = SimulationDataGenerator.generateScenario(numRegions, scenarioType, dataset);

                    % Build config for this run based on commonConfig baseline
                    cfg = commonConfig;
                    cfg.seed = seed;
                    cfg.dataset = dataset;
                    % override only the parameter under test
                    switch paramName
                        case 'M_local'
                            cfg.M_local = val;
                            cfg.M_elite = sensitivityParams.baseline.M_elite;
                            cfg.population_size = sensitivityParams.baseline.population_size;
                        case 'M_elite'
                            cfg.M_elite = val;
                            cfg.M_local = sensitivityParams.baseline.M_local;
                            cfg.population_size = sensitivityParams.baseline.population_size;
                        case 'population_size'
                            cfg.population_size = val;
                            cfg.M_local = sensitivityParams.baseline.M_local;
                            cfg.M_elite = sensitivityParams.baseline.M_elite;
                        otherwise
                            error('Unknown sensitivity parameter: %s', paramName);
                    end

                    % Run the algorithm (Edge-FML) and time it.
                    % Note: helper functions such as runEdgeFML are defined as
                    % local functions inside run_comparison_experiments.m and
                    % are not callable from here. Use EdgeFML class directly.
                    try
                        tic;
                        edgeFML = EdgeFML(regions, taskSets, cfg.R_max, cfg.M_local);
                        edgeFML.M_elite = cfg.M_elite;
                        for rr = 1:length(edgeFML.localOptimizers)
                            edgeFML.localOptimizers{rr}.popSize = cfg.population_size;
                            edgeFML.localOptimizers{rr} = edgeFML.localOptimizers{rr}.initializePopulation();
                        end
                        edgeFML = edgeFML.run();

                        metrics = PerformanceMetrics(cfg.metrics_ref);
                        globalFront = edgeFML.globalElites;

                        hv = metrics.computeHypervolume(globalFront);
                        feasRate = metrics.computeFeasibilityRate(globalFront);
                        diversity = metrics.computeDiversity(globalFront);

                        objs = [];
                        if ~isempty(globalFront)
                            try
                                objs = vertcat(globalFront.objectives);
                            catch
                                % fallback: build manually
                                objs = zeros(length(globalFront), 3);
                                for oi = 1:length(globalFront)
                                    objs(oi, :) = globalFront(oi).objectives;
                                end
                            end
                        end

                        elapsedTime = toc;

                        resultsRun = struct();
                        resultsRun.hv = hv;
                        resultsRun.feasRate = feasRate;
                        resultsRun.diversity = diversity;
                        if isprop(edgeFML, 'totalCommBytes') || isfield(edgeFML, 'totalCommBytes')
                            resultsRun.commBytes = edgeFML.totalCommBytes;
                        else
                            resultsRun.commBytes = NaN;
                        end
                        resultsRun.globalFront = globalFront;
                        resultsRun.globalFrontObjectives = objs;
                        rh = edgeFML.roundHistory;
                        try
                            resultsRun.roundHV = [rh.HV];
                        catch
                            resultsRun.roundHV = [];
                        end
                        resultsRun.R_max = cfg.R_max;
                    catch ME
                        warning('Run failed: %s', ME.message);
                        resultsRun = struct();
                        elapsedTime = NaN;
                    end

                    % Record results with a safe key
                    runKey = sprintf('sensitivity_%s_%s_%s_%d', paramName, num2str(val), matlab.lang.makeValidName(dataset(1:end-4)), seed);
                    safeRunKey = matlab.lang.makeValidName(runKey);

                    results.runs.(safeRunKey) = struct();
                    results.runs.(safeRunKey).param = paramName;
                    results.runs.(safeRunKey).value = val;
                    results.runs.(safeRunKey).dataset = dataset;
                    results.runs.(safeRunKey).scenarioType = scenarioType;
                    results.runs.(safeRunKey).seed = seed;
                    results.runs.(safeRunKey).elapsedTime = elapsedTime;

                    if isstruct(resultsRun) && isfield(resultsRun, 'hv')
                        results.runs.(safeRunKey).hypervolume = resultsRun.hv;
                    else
                        results.runs.(safeRunKey).hypervolume = NaN;
                    end
                    if isstruct(resultsRun) && isfield(resultsRun, 'commBytes')
                        results.runs.(safeRunKey).commBytes = resultsRun.commBytes;
                    else
                        results.runs.(safeRunKey).commBytes = NaN;
                    end
                    if isstruct(resultsRun) && isfield(resultsRun, 'globalFrontObjectives')
                        results.runs.(safeRunKey).globalFrontObjectives = resultsRun.globalFrontObjectives;
                    else
                        results.runs.(safeRunKey).globalFrontObjectives = [];
                    end
                    if isstruct(resultsRun) && isfield(resultsRun, 'roundHV')
                        results.runs.(safeRunKey).roundHV = resultsRun.roundHV;
                    else
                        results.runs.(safeRunKey).roundHV = [];
                    end
                    results.runs.(safeRunKey).R_max = cfg.R_max;

                    % Periodically save intermediate results
                    if mod(runCount, 20) == 0
                        save_intermediate(results, results_subdir);
                    end
                end % seed
            end % scenario
        end % dataset
    end % value
end % paramSets

% Save final results (into timestamped subdir and also top-level for compatibility)
outFile_ts = fullfile(results_subdir, sprintf('sensitivity_results_%s.mat', results.timestamp));
save(outFile_ts, 'results');
outFile_top = fullfile(commonConfig.results_dir, sprintf('sensitivity_results_%s.mat', results.timestamp));
save(outFile_top, 'results');

fprintf('Sensitivity experiments completed. Results saved to: %s and %s\n', outFile_ts, outFile_top);

% Generate basic summary / plots (if plotting script exists)
scriptDir = fileparts(mfilename('fullpath'));
reportScript = fullfile(scriptDir, 'generate_sensitivity_report.m');
if exist(reportScript, 'file')
    run(reportScript);
else
    fprintf('No generate_sensitivity_report.m found; skipping report generation.\n');
end

% Local helper functions must appear after script code in MATLAB
function save_intermediate(res, results_subdir)
    % Save intermediate results into the timestamped results subdirectory if provided,
    % otherwise fall back to top-level results dir.
    if nargin < 2 || isempty(results_subdir)
        if isfield(res, 'commonConfig') && isfield(res.commonConfig, 'results_dir')
            outdir = res.commonConfig.results_dir;
        else
            outdir = 'experiments/results';
        end
    else
        outdir = results_subdir;
    end
    if ~exist(outdir,'dir'), mkdir(outdir); end
    fname = fullfile(outdir, sprintf('sensitivity_intermediate_%s.mat', res.timestamp));
    save(fname, 'res');
end
