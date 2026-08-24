# PAR‑MTDMS‑CMOEA 对比实验说明

## 概览
- 项目名称：PAR‑MTDMS‑CMOEA（并行多任务动态膜计算 + 约束多目标进化，三目标：时延、能耗、安全）
- 适用场景：IoT 边缘计算任务卸载的三目标优化（最小化时延、能耗、风险）
- 开发环境：MATLAB R2020a+（可选并行工具箱）
- 核心入口：`PAR_MTDMS_CMOEA_Main.m`，核心算法：`PAR_MTDMS_CMOEA.m:1`

## 问题与变量
- 决策变量维度：`D = K*6 + 120`（`PAR_MTDMS_CMOEA.m:45`）
- 卸载决策：前 `K*6`，每个任务取值 `0`（本地）或 `1..6`（边缘节点）（`evaluation/get_objective.m:24`）
- 缓存状态：后 `120`，为 `6×20` 二值矩阵（`evaluation/get_objective.m:25`）
- 阶段3安全变量：每个被卸载任务的安全等级（1..5），维度为被卸载任务数 `L`（`core/PAR_stage3.m:16`）

## 目标与约束
- 阶段1/2（双目标 + 约束）
  - 目标1：总时延 `T_sum`（本地与边缘时延的最大值）（`evaluation/get_objective.m:75`）
  - 目标2：总能耗 `E`（`evaluation/get_objective.m:76`）
  - 约束：节点计算能力超限累计 + 任务截止期违约累计（`evaluation/get_objective.m:59`,`64`）
  - 评估封装：`[objective, CV] = get_f_CV(pop, K)`（`evaluation/get_f_CV.m:1`）
- 阶段3（安全双目标 + 约束）
  - 目标1：安全成本（等级成本系数）与 目标2：安全风险（等级风险系数）（`evaluation/get_safe_f_CV.m:31`,`34`）
  - 约束：安全等级方差上限，鼓励均衡策略（`evaluation/get_safe_f_CV.m:60`）
  - 输出归一化：两目标均按任务数取平均（`evaluation/get_safe_f_CV.m:78`）

## 三阶段流程
- 阶段1：四膜并行探索（`core/PAR_stage1.m:1`）
  - 膜1：约束多目标（`core/PAR_evolve1.m:1`）
  - 膜2：无约束多目标（`core/PAR_evolve2.m:1`）
  - 膜3：时延单目标（能耗作为约束）（`core/PAR_evolve3.m:1`）
  - 膜4：能耗单目标（时延作为约束）（`core/PAR_evolve4.m:1`）
  - 流程：分群 → 锦标赛选父 → DE 生成子代 → 环境选择（`selection/EnvironmentalSelection.m:1`）
- 阶段2：动态约束收敛（`core/PAR_stage2.m:2`）
  - 主种群严格可行；辅助种群使用阈值 `VAR` 放宽（`selection/Main_task_EnvironmentalSelection.m:1`,`selection/Auxiliray_task_EnvironmentalSelection.m:1`）
  - 阈值对数衰减并线性过渡到最终值 `VAR_final = τ0 * final_relax_rate`（`core/PAR_stage2.m:81`,`84`,`61`）
  - 子代生成：主/辅各用 `DE/rand/1` 与 `DE/pbest/1`（`core/PAR_stage2.m:110`,`114`,`124`,`128`）
- 阶段3：安全优化与三目标合成（`core/PAR_stage3.m:1`）
  - 基于阶段2代表解搜索安全等级，评估安全成本与风险（`evaluation/get_safe_f_CV.m:1`）
  - 合成三目标：`Latency = T_stage2 + Security_Cost`，`Energy = Stage2_Energy`，`Risk = Security_Risk`；`CV = Stage2_CV + Stage3_CV`（`core/PAR_MTDMS_CMOEA.m:231`–`240`）
  - 对可行解进行非支配排序，输出第一前沿（`selection/nonDominatedSorting.m:1`）

## 差分进化算子
- `DE/rand/1`：`operators/OperatorDE_rand_1.m:1`
- `DE/best/1`：`operators/PAR_OperatorDE_best.m:1`
- `DE/current-to-rand/1`：`operators/PAR_OperatorDE_current.m:1`
- `DE/pbest/1`（主/辅）：`operators/OperatorDE_pbest_1_main.m:1`,`operators/OperatorDE_pbest_1.m:1`
- 安全策略 DE：`operators/OperatorSafeDE.m:1`

## 选择与适应度
- 适应度：约束优先支配 + 局部拥挤度近似（第 `sqrt(N)` 邻居）（`evaluation/CalFitness.m:1`）
- 环境选择（约束/非约束视图）：`selection/EnvironmentalSelection.m:1`
- 非支配排序：`selection/nonDominatedSorting.m:1`
- 锦标赛选父：`selection/TournamentSelection.m:1`

## 数据依赖与模型
- 设备与任务数据：`data/data_<K>.mat`（按 K 自动选择，字段 `envir`, `Users`）（`evaluation/get_objective.m:8`）
- 其它数据：`dataOffT.mat`, `dataOfftasks.mat`
- 通信与计算模型：路径损耗与传输速率、缓存影响（通信开销），计算能耗与周期（`evaluation/get_objective.m:78` 起）

## 使用方法（对比实验接口）
- 默认运行
  - MATLAB 执行：`PAR_MTDMS_CMOEA_Main`（`PAR_MTDMS_CMOEA_Main.m:86`）
- 自定义调用（建议用于批量对比）
  - 函数：`[pop_final, pop_stage2, fes, runtime] = PAR_MTDMS_CMOEA(N, iter_max, K, use_parallel, final_relax_rate)`（`core/PAR_MTDMS_CMOEA.m:1`）
  - 常用参数：`N=100/200`, `iter_max=1000`, `K=10/30/50`, `use_parallel=true`, `final_relax_rate=0.05`
- 可视化
  - 调用：`visualize_pareto_front(pop_final)`（`visualize_pareto_front.m:1`）
  - 输出：3D/2D 前沿与直方图（`visualize_pareto_front.m:50`）

## 输出格式（统一评测）
```text
pop_final: [M × (D+4)]
  1:D       决策变量（卸载与缓存）
  D+1       时延（ms）
  D+2       能耗（J）
  D+3       安全风险（归一化）
  D+4       约束违反（0 为可行）
```
- `pop_stage2`：阶段2合并后的候选集
- `fes`：函数评估次数（`core/PAR_MTDMS_CMOEA.m:275`）
- `runtime`：累计运行时长

## 对比实验建议
- 规模设置
  - K=10：`N=100`, `iter_max=500`
  - K=30：`N=100–150`, `iter_max=1000`
  - K=50：`N=200`, `iter_max=1000–1500`, `final_relax_rate=0.05`
- 指标记录
  - Pareto 点数量、可行解比例、三目标统计（min/max/mean）、`fes`、`runtime`（`PAR_MTDMS_CMOEA_Main.m:91`）
- 集成流程
  - 统一数据加载接口（按 K 命名的数据文件）
  - 以 `pop_final` 为标准比较对象
  - 使用统一的非支配排序与可视化作对照（`selection/nonDominatedSorting.m:1`,`visualize_pareto_front.m:1`）

## 设计亮点与局限
- 亮点
  - 多膜并行 + 多算子协同，兼顾探索与利用
  - 阶段2动态约束阈值对数衰减，适配约束严格场景（如 K=50）（`core/PAR_stage2.m:53`,`61`）
  - 阶段3将安全成本累加到时延形成三目标可比性（`core/PAR_MTDMS_CMOEA.m:231`）
- 局限
  - 安全模型系数经验化，未与特定加密算法完全耦合（`evaluation/get_safe_f_CV.m:31`,`34`）
  - 计算能力与缓存模型为简化近似，需按真实场景调参

## 关键文件索引
- 阶段流程控制：`core/PAR_MTDMS_CMOEA.m:59`（阶段1）、`118`（阶段2）、`194`（阶段3）
- 目标与约束：`evaluation/get_objective.m:1`，`evaluation/get_f_CV.m:1`
- 安全评估与合成：`evaluation/get_safe_f_CV.m:1`，`selection/nonDominatedSorting.m:1`
- 可视化：`visualize_pareto_front.m:50`

## 复现与引用
- 环境与运行：MATLAB R2020a+，依赖 `data/*.mat`，主脚本 `PAR_MTDMS_CMOEA_Main.m`
- 引用：使用仓库 `README.md` 中 BibTeX（`README.md:250`）

