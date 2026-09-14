# Edge-FML: Edge Federated Membrane Learning

**Edge-FML** (Edge Federated Membrane Learning) is a MATLAB implementation of a privacy-preserving distributed multi-objective optimization framework for heterogeneous edge computing environments. It addresses the tri-objective optimization problem of **latency**, **energy consumption**, and **security risk** under privacy and communication constraints.

## Key Features

- **Privacy-Preserving**: Adaptive Threshold Shamir Secret Sharing (AT-SSS) for secure knowledge exchange across regions
- **Communication-Efficient**: Hierarchical (spectral) clustering reduces communication complexity from O(N²) to O(N log N)
- **Heterogeneity-Aware**: Solution compatibility mechanism (normalization + feasibility repair) handles diverse edge region characteristics
- **Dual-Membrane Architecture**: Local membrane evolution + global membrane coordination for personalized optimization
- **Theoretically Grounded**: Converges to ε-Pareto optimal solutions with (ε, δ)-differential privacy guarantees
- **Comprehensive Evaluation**: Built-in HV / IGD / diversity / feasibility metrics, ablation studies, sensitivity analysis, and statistical tests (Bootstrap, Holm)

## Architecture

```
Edge-FML
├── Local Layer   : Each edge region runs an independent MTDMS-CMOEA membrane optimizer
├── Cluster Layer : Spectral clustering groups similar regions; intra-cluster direct knowledge exchange
└── Federated Layer : Inter-cluster encrypted knowledge aggregation via AT-SSS + dual-membrane coordination
```

## Project Structure

```
Edge-FML/
├── src/                         # Core source code (MATLAB classes)
│   ├── EdgeFML.m                # Main federated framework (4-stage pipeline)
│   ├── EdgeFML_Enhanced.m       # Enhanced variant with robust error handling
│   ├── EdgeFML_Parallel.m       # Parallel (parfor) variant
│   ├── MTDMS_CMOEA_Local.m      # Local dual-membrane multi-task optimizer
│   ├── ClusterManager.m         # Spectral clustering of regions
│   ├── SolutionAdapter.m        # Cross-region solution compatibility
│   ├── ShamirSecretSharing.m    # AT-SSS privacy mechanism
│   ├── ObjectiveEvaluator.m     # Tri-objective + constraint evaluation
│   ├── PerformanceMetrics.m     # HV, IGD, diversity, spacing metrics
│   ├── StatisticalAnalyzer.m    # Bootstrap / Holm statistical tests
│   ├── SimulationDataGenerator.m # Scenario & benchmark data generation
│   └── ...                      # 25 classes in total (see docs/)
├── experiments/                 # Experiment framework
│   ├── config.m                 # Central configuration (scenarios, datasets, params)
│   ├── comprehensive_testing_framework.m  # Programmatic runner (all test modes)
│   ├── ablation_studies/        # Ablation experiments (A0-A9, A12 variants)
│   ├── algorithm_comparison/    # Comparison vs IMTCMO / IMTCMO-BS / ICMA / DRLOS-EMCMO / MTDMS
│   ├── performance_scaling/     # Scaling vs region count / rounds
│   └── sensitivity_experiment/  # Parameter sensitivity analysis
├── baselines/                   # Baseline algorithm implementations (self-contained)
│   ├── IMTCMO/
│   ├── IMTCMO_BS/
│   ├── ICMA/
│   └── DRLOS-EMCMO/
├── benchmarks/                  # Benchmark datasets (.mat, loaded via config data_dir)
├── tests/                       # Smoke tests
├── docs/                        # Detailed documentation (Chinese & English)
└── *.m                          # Root entry scripts (run_example, run_experiments, ...)
```

## Requirements

- **MATLAB R2020a or later** (string arrays and `pdist2` require recent versions)
- **Statistics and Machine Learning Toolbox** (clustering / statistical tests)
- **Parallel Computing Toolbox** (optional, only for `EdgeFML_Parallel.m` and multi-core experiment runs)

No third-party toolboxes or compilers are required. All dependencies are bundled in this repository.

## Quick Start

### 1. Run the built-in example

```matlab
>> run_example
```

This runs a small 6-region, moderate-heterogeneity scenario through the full federated pipeline and prints HV / feasibility / diversity results.

### 2. Use the API directly

```matlab
addpath('src');

% Generate a heterogeneous edge scenario (10 regions)
dataGen = SimulationDataGenerator();
[regions, taskSets] = dataGen.generateScenario(10, 'heterogeneous');

% Create and run the framework
edgeFML = EdgeFML(regions, taskSets, 10, 30);   % R_max=10 rounds, M_local=30
edgeFML = edgeFML.run();

% Extract the global Pareto front
globalFront = edgeFML.globalElites;

% Evaluate performance
metrics = PerformanceMetrics([1000, 1000, 1000]);
HV        = metrics.computeHypervolume(globalFront);
feasRate  = metrics.computeFeasibilityRate(globalFront);
diversity = metrics.computeDiversity(globalFront);
```

Scenario types: `'homogeneous'`, `'moderate'`, `'heterogeneous'` (high heterogeneity).

## Reproducing Experiments

All experiments are configured centrally in `experiments/config.m` (scenarios, datasets, population size, federated rounds, repeated runs, output directories).

### Interactive runner

```matlab
>> run_experiments
```

Prompts for experiment type (1: performance scaling, 2: ablation, 3: algorithm comparison) and allows parameter overrides.

### Programmatic runner

```matlab
>> run_comprehensive_experiments
```

Runs all experiment suites (`all`); switch `testMode` in the script to run a subset:
`'performance' | 'comparison' | 'ablation' | 'stress'`.

### Individual experiment suites

| Suite | Entry script | Purpose |
|-------|--------------|---------|
| Ablation | `experiments/ablation_studies/run_ablation_experiments.m` | Component removal tests (A0-A9, A12): dual-membrane, fast repair, minimal variant, etc. |
| Comparison | `experiments/algorithm_comparison/run_comparison_experiments.m` | Edge-FML vs IMTCMO / IMTCMO-BS / ICMA / DRLOS-EMCMO / MTDMS baselines |
| Performance | `experiments/performance_scaling/run_performance_experiments.m` | Scaling vs number of regions / federated rounds |
| Sensitivity | `experiments/sensitivity_experiment/run_sensitivity_experiments.m` | Parameter sensitivity analysis |

Each suite also ships a `generate_*_report.m` / `plot_*` script to produce tables, figures, and statistical test reports (Bootstrap + Holm correction) from saved results.

**Note**: For paper-grade results, use 200 generations × 10 repeated runs per scenario and the algorithm-independent HV reference point (`worst × 1.2 + 0.1`) configured in `experiments/config.m`.

## Core Components

| Component | File | Responsibility |
|-----------|------|----------------|
| Regional config | `RegionConfig.m` | Heterogeneous region attributes (compute, bandwidth, latency, security level) |
| Task spec | `TaskData.m` | Task requirements (data size, workload, deadline, security) |
| Local optimizer | `MTDMS_CMOEA_Local.m` | Dual-membrane local evolution, DE operators, dynamic constraints |
| Privacy | `ShamirSecretSharing.m` | Adaptive-threshold secret sharing, type-aware encoding |
| Clustering | `ClusterManager.m` | Spectral clustering, eigengap-based cluster count |
| Adaptation | `SolutionAdapter.m` | Parameter normalization + feasibility repair |
| Metrics | `PerformanceMetrics.m` | HV, IGD, diversity, spacing |
| Statistics | `StatisticalAnalyzer.m` | Bootstrap confidence intervals, Holm-corrected tests |

## Documentation

Detailed documentation is under [`docs/`](docs/):

- [`FML.MD`](docs/FML.MD) — Complete algorithm description (Chinese)
- [`ALGORITHM_STRUCTURE.md`](docs/ALGORITHM_STRUCTURE.md) — Architecture with Mermaid diagrams
- [`USAGE_GUIDE.md`](docs/USAGE_GUIDE.md) — Comprehensive usage guide
- [`Edge-FML论文级算法描述.md`](docs/Edge-FML论文级算法描述.md) — Paper-level algorithm description (Chinese)
- [`PROJECT_STRUCTURE.md`](docs/PROJECT_STRUCTURE.md) — Detailed module inventory
- [`README_EXPERIMENTS.md`](docs/README_EXPERIMENTS.md) — Experiment documentation

## Tests

```matlab
>> run tests/smoke_test.m
```

Runs a lightweight smoke test to verify the framework initializes and executes correctly.

## Citing

If you use this code in your research, please cite:

```bibtex
@article{Edge-FML,
  title={Federated Membrane Learning for Heterogeneous Edge Intelligence: A Privacy-Preserving, Communication-Efficient Framework for Constrained Multi-Objective Optimization},
  author={Shouheng Tuo, Chong Li, Ye Tian, Yixin Yang, and Huiying Hu},
  journal={Swarm and Evolutionary Computation},
  year={2026}, 
  note={Under review}
}
```

## License

MIT License — see [LICENSE](LICENSE).
