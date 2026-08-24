# Edge-FML 实验使用说明（中文）

## 概述

本说明面向初学者，详细介绍如何配置和运行 Edge-FML 项目中的实验、如何修改参数以进行性能对比、常见错误与排查建议，以及算法设计思想的简介。项目以 MATLAB 实现，建议使用 MATLAB R2021b 及以上版本。若需并行加速，请安装 Parallel Computing Toolbox。

项目根目录示例：`j:\VSCodeAIDemos\Edge-FML`

--------------------

## 快速上手（3 步）

1. 在 MATLAB 中设置工作目录为项目根，例如在 MATLAB 命令窗口输入：

```matlab
cd('j:\\VSCodeAIDemos\\Edge-FML')
```

或者在 Windows 命令行（cmd）使用无交互方式运行脚本：

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\run_minimal_test.m')"
```

2. 运行冒烟测试（快速，验证环境与依赖）：

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\run_minimal_test.m')"
```

3. 运行完整实验（耗时，视配置而定）：

性能扩展实验（会在 `experiments/results` 写入结果）：

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\experiments\\performance_scaling\\run_performance_experiments.m')"
```

或运行顶层实验集：

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\run_experiments.m')"
```

--------------------

## 重要文件/目录说明

- `experiments/config.m`：实验配置（已包含详细中文注释），修改此文件可以控制实验参数（轮数、种群、数据集、实验组合等）。
- `experiments/performance_scaling/run_performance_experiments.m`：性能扩展实验入口脚本（会将 `.mat` 结果存入 `experiments/results`）。
- `experiments/performance_scaling/generate_performance_report.m`：从结果生成图像与 HTML 报告的脚本。脚本已增强以处理相对/绝对路径与单点情况。
- `src/EdgeFML.m`：Edge-FML 主框架实现（训练循环的 4 个阶段）。
- `src/ClusterManager.m`：区域聚类管理器（支持 `ClusterManager(regions)` 与 `ClusterManager(regions,'flat')`）。
- `src/ShamirSecretSharing.m`：秘密共享实现（支持 `ShamirSecretSharing()` 与 `ShamirSecretSharing('fixed')`）。
- `benchmarks/`：示例数据集（例如 `benchmark_small.mat`）。
- `experiments/results/`：运行时保存的 `.mat` 结果文件。
- `experiments/figures/`：生成的图像文件（PNG/EPS）。

--------------------

## 如何修改与配置实验（详细指南）

### 1) 全局常用参数（`experiments/config.m` 中的 `commonConfig`）

- `R_max`：联邦轮数（全局协调次数）。
  - 建议：调试 1-5；常规实验 10-50；严格对比 100+。

- `M_local`：每轮本地进化代数（local evolution generations）。
  - 控制局部搜索深度，越大运行时间越长。示例：20-200。

- `M_elite`：每个区域交换的精英个数。
  - 值越大通信与存储需求越高，但有利于信息共享。示例：5-20。

- `population_size`：本地优化器的种群规模。
  - 建议 50-200，取决于可用内存与时间预算。

- `repeat_runs`：同一配置的独立重复次数，用于计算均值和标准差。
  - 建议至少 3，调试时可设为 1。

- `metrics_ref`：计算超体积（HV）所用的参考点（应与目标数一致）。

- 路径相关：`data_dir`、`results_dir`、`figures_dir`。建议使用相对路径（相对于项目根），脚本会自动将其解析为绝对路径。

### 2) 性能扫描参数（`performanceConfig`）

- `datasets`：数据集文件名列表（在 `benchmarks/` 中），示例：`{'benchmark_small.mat','benchmark_medium.mat'}`。
- `region_counts`：要测试的区域数量数组，如 `[5, 10, 20, 30]`，作为横轴绘制性能曲线。
- `scenario_types`：仿真场景名称（由 `SimulationDataGenerator` 支持的名称）。常见：`'homogeneous'`、`'heterogeneous'`。

> 注意：若绘图只显示单点，通常是因为 `datasets`、`region_counts` 或 `repeat_runs` 仅包含一个值。请增加值数量以生成曲线。

### 3) 消融实验（`ablationConfig`）

- `variants`：各类消融试验的字符串列表，例如：
  - `'full'`：完整算法
  - `'no_clustering'`：禁用聚类（平坦结构）
  - `'no_atsss'`：禁用/固定阈值的秘密共享
  - `'no_compat'`：禁用解适配机制
  - `'no_local_enhance'`：移除本地增强
  - `'no_comm_compress'`：禁用通信压缩

- `ablationConfig.dataset`、`ablationConfig.scenario_type`、`ablationConfig.num_regions`：指定用于消融的固定场景。

--------------------

## 如何生成多点曲线（常见问题与示例）

**问题**：图上只有 1 个点。

**原因**：实验配置只包含单个 dataset、单个 region_count 或 `repeat_runs = 1`。

**示例配置（生成多点曲线）**：在 `experiments/config.m` 中设置：

```matlab
performanceConfig.datasets = {'benchmark_small.mat','benchmark_medium.mat'};
performanceConfig.region_counts = [5,10,20,30];
commonConfig.repeat_runs = 3;
```

运行：

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\experiments\\performance_scaling\\run_performance_experiments.m')"
```

生成的结果会包括每组的多个重复值，`generate_performance_report.m` 会绘制均值与标准差误差条。

--------------------

## 并行运行（加速）

- 若安装 `Parallel Computing Toolbox`，脚本会尝试使用 `parfor` 加速。也可以在运行前手动启动并行池：

```matlab
parpool('local',4); % 启动 4 个 worker
```

- 并行运行时注意 worker 内存开销：若遇内存不足，降低 `population_size` 或 `M_local`。

--------------------

## 常见错误与排查建议

- “Illegal use of reserved keyword 'end'”
  - 原因：脚本中存在多余或不匹配的 `end`。解决：检查报错脚本附近的结构并修复。我已删除 `generate_performance_report.m` 中的多余 `end`。若仍报错，请贴出堆栈信息。

- “Invalid field name” (字段名称无效)
  - 原因：使用包含非法字符（如 `.`）的动态 struct 字段名。已在 runner 中使用 `matlab.lang.makeValidName` 进行了保护。

- “输入参数太多” for constructor
  - 原因：某些类原构造函数不接受额外参数。已为 `ClusterManager` 和 `ShamirSecretSharing` 添加了可选模式参数（`'flat'`、`'fixed'`）。如出现类似错误，请把完整错误输出发来。

- “No performance results files found”
  - 原因：报告脚本在当前工作目录下未找到 `experiments/results`，已增强脚本以使用项目根路径尝试查找。请确认 `experiments/results` 有 `performance_results_*.mat` 文件。

--------------------

## 如何查看与解释结果

- 打开 `.mat` 文件（示例：`experiments/results/performance_results_2025-12-02_08-56-05.mat`），变量 `results` 包含：
  - `results.runs`：以安全字段名存放每次运行的指标（hypervolume、feasibility、diversity、elapsedTime 等）。
  - `results.timestamp`：时间戳。
  - `results.commonConfig`、`results.performanceConfig`：配置快照。

- 报告（HTML）会展示：Hypervolume、通信开销、可行率、执行时间、收敛曲线、场景比较等图表。Hypervolume（HV）越大通常表示 Pareto 前沿越靠近参考点（优越性越高）。

--------------------

## 算法设计思想（面向初学者）

### 问题背景

在边缘计算场景中，不同区域拥有不同计算能力、缓存容量与网络带宽。目标是针对这些区域内的任务在多目标下优化资源分配，同时考虑通信成本与隐私保护。

### Edge-FML 的核心思想

Edge-FML 将整体优化分为四个阶段，循环进行：

1. **本地演化（Local Evolution）**
   - 每个区域独立运行基于多目标进化算法（MOEA）的本地优化器，搜索本地解空间。

2. **聚类级别交换（Cluster-Level Exchange）**
   - 将相似区域聚成簇，在簇内或簇代表间交换精英解，减少跨域不兼容和通信量。

3. **联邦聚合（Federated Aggregation）**
   - 在集群代表层汇总并筛选全局精英，必要时使用秘密共享（AT-SSS）保护解隐私，同时计算通信开销与加密开销。

4. **本地整合（Local Integration）**
   - 各区域接收并适配外部精英，把经过适配的解合并到本地种群，再进入下一轮本地演化。

### 关键模块说明

- `ClusterManager`：谱聚类实现，自动选择簇数并合并小簇，支持平坦（flat）模式用于对照实验。
- `ShamirSecretSharing`：实现秘密共享（支持 adaptive/fixed 模式），用于在保隐私的同时进行知识传递。
- `SolutionAdapter`：把外部解适配到目标区域的表示与约束。
- `MTDMS_CMOEA_Local`：局部多目标约束优化器（核心本地算法实现）。

--------------------

## 调试与扩展建议（开发者向）

- 新场景：将数据集加入 `benchmarks/`，并在 `performanceConfig.datasets` 中加入文件名。
- 新消融：在 `ablationConfig.variants` 增加名字，并在 `experiments/ablation_studies/run_ablation_experiments.m` 中实现对应行为。
- 单元测试：建议为 `ClusterManager`、`ShamirSecretSharing`、`EdgeFML.localEvolution` 等编写小型测试以便 CI 验证。

--------------------

## 示例：快速配置（生成曲线的最小示例）

在 `experiments/config.m` 中设置：

```matlab
performanceConfig.datasets = {'benchmark_small.mat','benchmark_medium.mat'};
performanceConfig.region_counts = [5,10,20,30];
commonConfig.repeat_runs = 3;
```

然后运行：

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\experiments\\performance_scaling\\run_performance_experiments.m')"
```

--------------------

## 我可以继续为你做的事（选项）

- 我可以把本说明作为 `README_EXPERIMENTS.md` 提交到仓库（已完成）。
- 我可以替你把 `experiments/config.m` 设置为推荐的实验组合并显示 diff（需你确认）。
- 我可以帮助你运行一次示例实验（我无法直接在你机器上跑 MATLAB，但会给出精确命令与检查点），并在得到输出后帮助解析并修复可能的问题。

如需我继续，请告诉我下一步：例如 “把 config 改为示例并运行” 或 “只修改 config，不运行”。