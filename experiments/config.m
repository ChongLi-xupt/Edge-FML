% Experiment Configuration for Edge-FML
% -----------------------------------
% This file contains all parameters that control the experiments used by the
% Edge-FML project. The file is intentionally written as a MATLAB script that
% builds a set of structs (commonConfig, performanceConfig, ablationConfig,
% comparisonConfig) and saves them to `experiments/config_struct.mat` so the
% experiment runners can load a single canonical configuration.
%
% This file is executed by experiment runner scripts such as:
% - `experiments/performance_scaling/run_performance_experiments.m`
% - `experiments/ablation_studies/run_ablation_experiments.m`
% - `run_experiments.m`
%
% Guidelines for editing:
% - Keep this file MATLAB-syntax valid. Avoid complex expressions that depend
%   on runtime state (the runners expect this to be a pure configuration).
% - For faster, local debugging, reduce `R_max`, `M_local`, `population_size`,
%   and `repeat_runs`. For publication-grade experiments, increase them.
% - Use relative dataset/result/figure paths (relative to project root). The
%   report scripts resolve them to absolute paths automatically.
%
% Terminology (used across the codebase):
% - federated round: one global coordination step where regions evolve and
%   exchange elites.
% - local evolution generation: one generation inside a local optimizer.
% - elite: a top solution exchanged between regions/clusters.

% =======================================
% Common Configuration
% =======================================
% `commonConfig` holds parameters that affect all types of experiments.
% Edit these to tune runtime vs. fidelity. Short explanation + recommended
% ranges are provided for each option.
commonConfig = struct();

% ----------------------- Algorithm runtime parameters --------------------
% `R_max` : number of federated rounds (global coordination steps).
% - Small (quick smoke tests): 1-5
% - Typical experiments: 10-50
% - Longer experiments: 100+
commonConfig.R_max = 10;            % Default small value for quick runs

% `M_local` : number of local evolution generations per federated round.
% - Controls local search depth. Increasing improves solution quality,
%   increases runtime roughly linearly.
% 本地进化次数[5, 10, 20, 40, 60]
commonConfig.M_local = 20;         % Default reduced local budget for faster runs
% commonConfig.M_local = 40;
% `M_elite` : number of elite solutions each region shares when exchanging.
% - Small values reduce communication & memory; large values increase
%   diversity transferred between regions.
commonConfig.M_elite = 5;          % Conservative default

% `population_size` : population size for local optimizers (per region).
% - Larger population increases exploration but uses more memory and CPU.
commonConfig.population_size = 50; % Moderate default for example experiments
% commonConfig.population_size = 60;
% -------------------------- Evaluation / statistics ---------------------
% `repeat_runs` : how many repeated independent runs per configuration.
% - Use >1 to compute mean±std. 3-5 is common for quick experiments; 10+ for
%   robust statistics.
commonConfig.repeat_runs = 5;      % Small default; increase for statistical power

% `metrics_ref` : reference point for hypervolume (one per objective).
% - Provide a vector sized to the number of objectives (e.g., 3 objectives).
commonConfig.metrics_ref = [1000, 1000, 1000]; % Example reference point
% commonConfig.metrics_ref = [3000, 3000, 3000];



% ------------------------------- Paths ---------------------------------
% Paths are relative to the repository root. The reporting scripts resolve
% them to absolute paths at runtime. Typical directories:
% - `data_dir`: where benchmark .mat files live
% - `results_dir`: where experiment run .mat files are written
% - `figures_dir`: where generated PNG/EPS figures are saved
commonConfig.data_dir = 'benchmarks';
commonConfig.results_dir = 'experiments/results';
commonConfig.figures_dir = 'experiments/figures';

% =======================================
% Performance Scaling Experiments
% =======================================
% `performanceConfig` enumerates the parameter sweep used in performance
% scaling experiments. The runner will iterate over Cartesian product of
% `datasets x region_counts x scenario_types x repeat_runs`.
performanceConfig = struct();

% ----------------------------- Datasets --------------------------------
% `datasets` : cell array of dataset filenames (relative to `data_dir`)
% - Example: {'benchmark_small.mat', 'benchmark_medium.mat'}
% - Each dataset will be loaded and used to instantiate region/device
%   characteristics. Add or remove datasets depending on which benchmarks
%   you have available in `benchmarks/`.
performanceConfig.datasets = {
      'benchmark_small.mat', 'benchmark_medium.mat','benchmark_large.mat'
};

% --------------------------- Region counts ------------------------------
% `region_counts` : vector of number of regions to test (scaling axis)
% - e.g., [5, 10, 20, 30]
% - Use values that reflect the scale you want to evaluate.
performanceConfig.region_counts = [5, 10, 15];

% --------------------------- Scenario types -----------------------------
% `scenario_types` : simulation scenario variants (strings)
% - 'homogeneous' : regions with similar properties
% - 'heterogeneous' : regions with diverse capacities/loads
% - Additional scenario names may be supported by the Scenario generator
performanceConfig.scenario_types = {
    'homogeneous', 'heterogeneous'
};


% =======================================
% Ablation Studies
% =======================================
% Use ablation studies to selectively disable or alter components of
% Edge-FML to measure their contribution. The `variants` list drives the
% ablation runner which maps names to concrete code paths.
ablationConfig = struct();

% `variants` : names of ablation variants. The following example variants
% are implemented by the ablation runner:
% - 'full' : default, no change
% - 'no_clustering' : disable clustering (flat clusters)
% - 'no_atsss' : use fixed threshold / disable adaptive threshold SSS
% - 'no_compat' : disable solution compatibility adaptation
% - 'no_local_enhance' : remove local optimizer enhancements
% - 'no_comm_compress' : disable communication compression
ablationConfig.variants = {
    'full',
    'no_clustering',
    'no_atsss',
    'no_compat',
    'no_comm_compress'
};

% Default dataset and scenario used by ablation experiments (can be overridden)
% ablationConfig.dataset = 'benchmark_medium.mat';
% ablationConfig.dataset = 'benchmark_large.mat';
ablationConfig.dataset = 'benchmark_heterogeneous.mat';
ablationConfig.scenario_type = 'heterogeneous';
ablationConfig.num_regions = 30;
% ablationConfig.num_regions = 50;
% ablationConfig.num_regions = 60;
% =======================================
% Algorithm Comparison Experiments
% =======================================
% `comparisonConfig` enumerates algorithm names and datasets used for
% cross-algorithm benchmarks.
comparisonConfig = struct();

% `algorithms` : names recognized by the runner (each maps to an
% implementation wrapper that configures the optimizer accordingly).
comparisonConfig.algorithms = {
    'Edge-FML'
    'MTDMS',
    'IMTCMO',
    'IMTCMO-BS',
    'ICMA',
    'DRLOS-EMCMO'

};

% Datasets for comparison experiments
comparisonConfig.datasets = {
    % 'benchmark_medium.mat',
    'benchmark_heterogeneous.mat'
    'benchmark_small.mat',
    'benchmark_medium.mat',
    'benchmark_large.mat'
    % 'benchmark_large.mat'
};

% Scenario types for comparison
comparisonConfig.scenario_types = {
    % 'moderate',
    'heterogeneous'
};

% =======================================
% Create results and figures directories (if they don't exist)
% The directories are created relative to the current working directory.
% Runner code may also resolve these to absolute paths based on project root.
% If you prefer an absolute directory, change the strings above to absolute
% paths (e.g., 'J:/data/edgefml/results').
if ~exist(commonConfig.results_dir, 'dir')
    mkdir(commonConfig.results_dir);
end

if ~exist(commonConfig.figures_dir, 'dir')
    mkdir(commonConfig.figures_dir);
end

% =======================================
% Save configuration to file
% =======================================
% Save consolidated config for faster loading by runner scripts
save('experiments/config_struct.mat', 'commonConfig', 'performanceConfig', 'ablationConfig', 'comparisonConfig');

fprintf('Experiment configuration loaded successfully.\n');
