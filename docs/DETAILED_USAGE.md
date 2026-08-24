# Edge-FML 使用与实验参数详尽指南（中文）

> 目标：帮助初学者与研究人员快速理解、运行、配置与扩展 Edge-FML 代码库，并解释算法设计要点与常见问题排查方法。

---

## 目录
- 概述
- 环境与依赖
- 快速开始（3 步上手）
- 文件与模块一览
- 详细配置说明（`experiments/config.m`）
  - `commonConfig`
  - `performanceConfig`
  - `ablationConfig`
  - `comparisonConfig`
- 运行实验（示例命令）
- 生成与查看报告
- 并行/性能注意事项
- 常见错误与排查方案
- 算法设计思想（详细）
- 开发者指南：扩展与调试建议
- 附录：快速命令汇总

---

## 概述
Edge-FML（Edge Federated Membrane Learning）是一个在边缘/分布式环境中进行多目标优化的研究代码库。它模拟不同区域（region）在资源、带宽和任务分布上的差异，通过局部演化与分层知识交换（cluster-level 与 federated aggregation）来协同优化系统级指标，同时考虑通信成本和隐私保护（例如使用秘密共享）。

代码基于 MATLAB 实现，包含实验脚本、结果分析和可视化工具。

---

## 环境与依赖
- 推荐 MATLAB 版本：R2021b 或更高（已在 R2022b 上验证）
- 可选（但推荐）：Parallel Computing Toolbox（用于 `parfor` 并行加速）
- 工作目录：把 MATLAB 工作目录切到项目根目录，例如 `j:\\VSCodeAIDemos\\Edge-FML`。

注意：若路径中包含非 ASCII 字符或空格，MATLAB 可能出现路径相关问题；建议使用无空格、标准 ASCII 的路径。

---

## 快速开始（3 步上手）
1. 打开 MATLAB 并设置工作目录到项目根：

```matlab
cd('j:\\VSCodeAIDemos\\Edge-FML')
```

2. 运行冒烟测试（快速验证各模块存在并能执行）——在 Windows cmd 中无交互地运行：

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\run_minimal_test.m')"
```

3. 运行性能实验（耗时，按配置规模而定）：

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\experiments\\performance_scaling\\run_performance_experiments.m')"
```

或运行全集（所有实验脚本）：

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\run_experiments.m')"
```

---

## 文件与模块一览（高层）
- `src/`：核心实现文件夹
  - `EdgeFML.m`：主框架（训练/联邦循环）
  - `ClusterManager.m`：区域聚类管理器（支持自动谱聚类与 `flat` 模式）
  - `MTDMS_CMOEA_Local.m`：本地多目标进化器实现
  - `ShamirSecretSharing.m`：秘密共享实现（支持 `adaptive`/`fixed` 模式）
  - `Solution.m`、`SolutionAdapter.m`：解表示与适配器
  - `PerformanceMetrics.m`：HV、Feasibility 等指标计算
- `experiments/`：实验脚本、配置与结果
  - `config.m`：实验配置（主入口、中文注释）
  - `performance_scaling/`：性能扩展实验与报告生成脚本
  - `ablation_studies/`：消融试验脚本
  - `algorithm_comparison/`：算法比较脚本
- `benchmarks/`：示例 benchmark 数据（`.mat`）
- `experiments/results/`：运行时保存的 `.mat` 结果文件
- `README_EXPERIMENTS.md` / `DETAILED_USAGE.md`：使用说明

---

## 详细配置说明（`experiments/config.m`）
在 `config.m` 中你将看到四个主要配置结构：`commonConfig`、`performanceConfig`、`ablationConfig` 和 `comparisonConfig`。

下面逐项解释（包含含义、典型值与调参建议）：

### `commonConfig`（全局参数）
- `R_max`：联邦轮数（每轮包含本地演化 + 交换 + 聚合 + 整合）。
  - 调试时：1-5；常规实验：10-50；严格对比：100+。
- `M_local`：本地演化代数（每个本地优化器内部）。
  - 示例：20-200，代数越高局部搜索越深入但更耗时。
- `M_elite`：每个区域交换的精英数（影响通信与融合质量）。
  - 推荐：5-20。
- `population_size`：本地优化器的种群规模。
  - 建议：50-200，受内存与运行时间限制。
- `repeat_runs`：每个配置重复独立运行次数（用于计算均值与方差）。
  - 推荐 >=3（实验统计可信度更高）。
- `metrics_ref`：计算 Hypervolume（HV）的参考点向量（目标数目相同）。
- `data_dir`、`results_dir`、`figures_dir`：相对于项目根的路径，用于存放数据、结果和图像。脚本会把相对路径解析为绝对路径。

### `performanceConfig`（性能扫描）
- `datasets`：字符串 cell 数组，包含 benchmark 文件名（位于 `benchmarks/`）。
- `region_counts`：整数数组，表示不同的区域数（用于绘制横轴扩展曲线）。
- `scenario_types`：仿真场景名称（由 `SimulationDataGenerator` 支持，例如 `'homogeneous'`、`'heterogeneous'`）。

> 注意：如果绘图只显示一个点，通常是 `datasets`、`region_counts` 或 `repeat_runs` 仅包含一个元素，扩展任一维即可得到多点曲线。

### `ablationConfig`（消融实验）
- `variants`：例如 `{'full','no_clustering','no_atsss','no_compat','no_local_enhance','no_comm_compress'}`。
- `dataset`、`scenario_type`、`num_regions`：消融实验默认使用的数据集与场景参数。

### `comparisonConfig`（算法比较）
- `algorithms`：字符串列表（如 `Centralized-MTDMS`, `Independent-MTDMS`, `FedAvg-MOEAs`, `Original-FML`, `Edge-FML`）。
- `datasets`、`scenario_types`：用于比较的集合。

---

## 运行实验（常用示例）
- 冒烟测试（快速验证）

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\run_minimal_test.m')"
```

- 只运行性能扩展实验

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\experiments\\performance_scaling\\run_performance_experiments.m')"
```

- 运行算法对比实验

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\experiments\\algorithm_comparison\\run_comparison_experiments.m')"
```

- 运行消融实验

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\experiments\\ablation_studies\\run_ablation_experiments.m')"
```

- 运行全部实验（顶层脚本）

```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\run_experiments.m')"
```

> 提示：`-batch` 会在运行后自动退出 MATLAB。若你想在 MATLAB 会话内逐步调试，请直接在 MATLAB 命令窗口执行 `run('...')`。

---

## 生成与查看报告
- 运行实验后，结果会保存为 `experiments/results/performance_results_<timestamp>.mat`（或 comparison/ablation 的类似命名）。
- 报表脚本已增强为在项目根下解析相对路径；生成的 HTML 报告与图像会保存到 `experiments/performance_scaling/.../performance_report_<timestamp>.html`（具体位置由配置控制）。
- 使用浏览器打开生成的 HTML 报告即可查看图表与汇总表格。

---

## 并行/性能注意事项
- 若使用 `parfor`，MATLAB 会自动使用可用的并行池（若存在）。也可手动启动：

```matlab
parpool('local',4); % 4 个 worker
```

- 并行运行时注意 worker 内存：如果出现内存不足或 OOM，请减小 `population_size`、`M_local`，或减少并行 worker 数量。
- 为减少并行写冲突，代码使用“先在 worker 收集，再合并”的模式（已修复多个 parfor 写冲突问题）。

---

## 常见错误与排查方案（按错误类型）

1. **“字段名称无效” (Invalid field name)**
   - 原因：用包含非法字符（如 `.`、`-`）的字符串直接作为动态 struct 字段。
   - 处理：脚本中使用 `matlab.lang.makeValidName` 自动清洗动态字段名；如果仍出现，检查产生字段名的字符串来源（例如 dataset 文件名）。

2. **“输入参数太多” (Too many input arguments)**
   - 原因：某些类构造函数没有接受可选参数的签名。
   - 处理：已为 `ClusterManager`（支持 `'flat'` 模式）和 `ShamirSecretSharing`（支持 `'fixed'` 模式）添加可选参数支持。若其他类报错，请把错误堆栈发上来。

3. **`eigs` 警告：矩阵接近奇异或缩放不良**
   - 原因：谱聚类时拉普拉斯矩阵条件数差，`eigs(...,'smallestabs')` 可能不稳。
   - 处理：已在 `ClusterManager.formClusters` 中实现鲁棒策略：检测 `rcond`，条件极差时使用 shift-invert（小 sigma）或回退到稠密 `eig`。

4. **数组拼接维度不一致（`vertcat` error）**
   - 原因：尝试直接使用 `[]` 拼接不定形的数组（例如对象数组与空矩阵拼接）。
   - 处理：已修改代码以使用 `Solution.empty(0,1)` 初始化并以正确维度追加对象数组。

5. **找不到结果文件/报告为空**
   - 原因：实验并未成功写入 `experiments/results`，或报告脚本未定位到正确目录。
   - 处理：报告脚本已增强，尝试 `projectRoot` 与配置路径的组合；若仍报错，请确认 `experiments/results` 下确实存在 `performance_results_*.mat`。

---

## 算法设计思想（详细）
下面从问题、算法结构与工程实现角度做深入说明，帮助理解各模块如何协同工作。

### 问题设定
在边缘计算场景中有多种资源与约束：设备计算能力、缓存容量、带宽与任务类型。目标通常为多个：最小化延迟、最大化完成率、最小化能耗等（多目标，多约束）。同时考虑通信成本与隐私保护，不能把所有数据集中到中心。

### Edge-FML 高层设计（四阶段）
1. **本地演化（Local Evolution）**
   - 各区域独立运行多目标进化算法（CMOEA 变种），基于局部任务与资源搜索解空间。
   - 输出：本地的精英归档（eliteArchive）。

2. **聚类级交换（Cluster-Level Exchange）**
   - 将相似区域分簇（谱聚类实现），集群内或代表间交换精英以提高协同效率并减少不必要通信。
   - 聚类减少了跨域不兼容问题（不相似区域直接交换解可能产生无效或不可行的解）。

3. **联邦聚合（Federated Aggregation）**
   - 各集群代表将精英汇总到更高层，进行筛选和聚合（可能使用 HV 贡献或可行性过滤）。
   - 隐私敏感时可对精英做秘密共享（AT-SSS）或加密后再传输。

4. **本地整合（Local Integration）**
   - 区域接收外部解后，通过 `SolutionAdapter` 适配到本地表达与约束，然后重插入本地种群进行演化。

### 关键工程权衡点
- 聚类的好处：减少通信、提高交换实用性；代价：额外的聚类计算（但聚类可在较低频率下执行）。
- 精英数（`M_elite`）与通信：精英越多通信越大，表征知识越全面。
- 秘密共享：带来隐私，但增加通信与计算开销（编码/解码/重构）。

---

## 开发者指南（扩展与调试）
- 添加新数据集：把 `.mat` 放入 `benchmarks/` 并在 `performanceConfig.datasets` 添加文件名。
- 添加新消融：在 `ablationConfig.variants` 加名字，并在对应 runner 中实现 switch-case 行为。
- 新算法比较：在 `comparisonConfig.algorithms` 添加名字，并在 `experiments/algorithm_comparison/run_comparison_experiments.m` 中添加对应 case（实现 `runYourAlgo()` 函数）。
- 写单元测试：建议为 `ClusterManager.formClusters`、`ShamirSecretSharing.split/reconstruct`、`MTDMS_CMOEA_Local` 的关键方法写测试（放在 `tests/`）。

---

## 附录：常用命令速览
- 冒烟测试：
```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\run_minimal_test.m')"
```
- 性能实验：
```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\experiments\\performance_scaling\\run_performance_experiments.m')"
```
- 算法比较：
```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\experiments\\algorithm_comparison\\run_comparison_experiments.m')"
```
- 消融实验：
```bat
matlab -batch "run('j:\\VSCodeAIDemos\\Edge-FML\\experiments\\ablation_studies\\run_ablation_experiments.m')"
```

---

如果你希望我把这份文档转为仓库的 `README.md`（替换或补充现有 README），或把其中的示例配置直接写入 `experiments/config.m` 并显示 diff，请回复：
- `写入 config 并显示 diff` 或
- `只显示 README` 或
- `现在运行性能实验（我将提供命令）`。

我可以继续帮你（例如：修改 config、运行实验或分析最新输出）。
