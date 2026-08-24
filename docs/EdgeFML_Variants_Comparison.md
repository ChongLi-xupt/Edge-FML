# Edge-FML 算法变体对比分析 (Edge-FML Variants Comparison)

本文档详细对比了 Edge-FML 框架的三个主要变体：**EdgeFML.m**（标准版）、**EdgeFML_Enhanced.m**（增强版）和 **EdgeFML_Parallel.m**（并行版）。这三个版本基于相同的核心理论（联邦膜学习），但在实现架构、性能优化和稳健性方面各有侧重。

---

## 1. 算法概览 (Overview)

| 算法文件 | 核心定位 | 主要特点 | 适用场景 |
| :--- | :--- | :--- | :--- |
| **EdgeFML.m** | **基准实现 (Baseline)** | 结构清晰，逻辑串行，便于理解和调试。 | 算法原理研究、小规模验证、单线程环境。 |
| **EdgeFML_Enhanced.m** | **稳健性与质量 (Robustness)** | 强化错误处理、内存监控、自适应策略、增强的精英选择。 | 生产环境模拟、长时间运行实验、对解质量要求极高的场景。 |
| **EdgeFML_Parallel.m** | **高性能 (High Performance)** | 多级并行化设计，最大化利用多核 CPU。 | 大规模实验、参数敏感性分析、实时性要求高的场景。 |

---

## 2. 详细分析 (Detailed Analysis)

### 2.1 EdgeFML.m (标准版)

这是 Edge-FML 的基础实现，严格遵循算法文档中的 4 阶段流程。

*   **流程 (Flow):**
    1.  **Stage 1:** 串行执行每个区域的 `localEvolution()`。
    2.  **Stage 2:** 串行执行集群内知识交换。
    3.  **Stage 3:** 联邦聚合，基于 HV 选择全局精英。
    4.  **Stage 4:** 串行执行本地知识集成。
*   **方法 (Methods):**
    *   使用标准的 `try-catch` 包裹整个轮次。
    *   数据结构较为基础，部分数组操作可能涉及动态增长（但在最新版中已优化预分配）。
*   **优点:** 代码逻辑最直观，依赖最少。
*   **缺点:** 在大规模区域（如 N > 50）时运行缓慢；缺乏细粒度的错误恢复机制。

### 2.2 EdgeFML_Enhanced.m (增强版)

在标准版基础上，重点增强了系统的**稳定性**和**解的质量**。

*   **核心改进 (Key Improvements):**
    *   **输入验证:** 构造函数包含严格的 `inputParser` 和类型检查。
    *   **细粒度容错:** 在 `localEvolution` 和 `clusterLevelExchange` 中，单个区域的失败不会导致整个轮次崩溃（Fail-Safe）。
    *   **资源监控:** 内置 `memoryMonitor` 和 `performanceStats`，实时跟踪内存和各阶段耗时。
    *   **自适应策略:**
        *   `adaptiveThreshold(round)`: 通信阈值随轮次衰减，前期探索，后期收敛。
        *   `enhancedSelectGlobalElites`: 引入“多样性+收敛性”的双重打分机制，而非仅靠 HV 选择精英。
    *   **内存管理:** 显式的 `performMemoryCleanup` 防止长期运行的内存泄漏。
*   **流程差异:** 尝试在 Stage 1 使用并行计算（如果工具箱可用），否则回退到串行，具备一定的灵活性。

### 2.3 EdgeFML_Parallel.m (并行版)

专为**计算效率**设计，通过 MATLAB 的 `parfor` 并行计算工具箱大幅加速。

*   **核心改进 (Key Improvements):**
    *   **并行化架构:**
        *   **Stage 1 (Local Evolution):** 这是计算最密集的阶段，完全并行化。
        *   **Stage 4 (Local Integration):** 解的适配和评估并行化。
    *   **数据结构优化:** 为了适应 `parfor` 的限制，重构了对象访问方式，大量使用切片变量（Sliced Variables）和临时 Cell 数组。
    *   **速度提升:** 在多核 CPU 上通常能获得接近线性的加速比（取决于核数）。
*   **流程差异:**
    *   构造函数接受 `NumWorkers` 参数。
    *   `localEvolution` 被替换为 `localEvolutionParallel`。
    *   必须处理并行环境下的随机数种子同步和错误捕获问题。

---

## 3. 核心代码差异对比 (Code Level Differences)

### 3.1 本地进化阶段 (Local Evolution)

*   **EdgeFML:**
    ```matlab
    for r = 1:obj.N
        obj.localOptimizers{r} = obj.localOptimizers{r}.evolve();
    end
    ```

*   **EdgeFML_Parallel:**
    ```matlab
    parfor r = 1:N  % 并行循环
        try
            newOptimizers{r} = optimizers{r}.evolve();
        catch ME
            % 捕获错误，防止并行池崩溃
        end
    end
    ```

*   **EdgeFML_Enhanced:**
    ```matlab
    % 混合模式：尝试并行，失败则串行，并记录详细日志
    if obj.N > 3 && license('test', 'Distrib_Computing_Toolbox')
        parfor r = 1:obj.N ... end
    else
        for r = 1:obj.N ... end
    end
    ```

### 3.2 精英选择策略 (Elite Selection)

*   **EdgeFML / Parallel:**
    *   主要依赖**非支配排序**和**Hypervolume (HV)** 贡献。
    *   `selectTopByHV(globalElites, maxGlobalElites)`

*   **EdgeFML_Enhanced:**
    *   引入**综合打分机制**：
    *   `Score = 0.6 * Convergence(HV) + 0.4 * Diversity(CrowdingDistance)`
    *   确保全局精英不仅收敛性好，而且分布均匀。

### 3.3 通信开销控制 (Communication Control)

*   **EdgeFML:** 使用固定阈值 `theta_agg = 0.1`。
*   **EdgeFML_Enhanced:** 使用自适应阈值：
    ```matlab
    theta = base * (0.95 ^ (round - 1)); % 随时间衰减
    ```

---

## 4. 总结与建议 (Summary & Recommendations)

1.  **何时使用 EdgeFML.m?**
    *   当你刚开始接触代码，需要通过断点调试一步步理解算法流程时。
    *   当你的实验规模很小（例如 N=3），并行开销大于收益时。

2.  **何时使用 EdgeFML_Parallel.m?**
    *   **大规模实验首选**。例如 N=20, 50, 100。
    *   进行参数敏感性分析（Ablation Studies）时，需要快速跑完大量重复实验。

3.  **何时使用 EdgeFML_Enhanced.m?**
    *   **论文出图阶段**。其增强的精英选择策略通常能跑出分布更漂亮、HV 更高的 Pareto 前沿。
    *   **模拟真实环境**。需要验证算法在节点偶尔失效（模拟 Error）情况下的鲁棒性。
    *   需要监控内存泄漏或详细分析各阶段耗时占比时。

通过这三个变体，Edge-FML 框架能够覆盖从理论验证到高性能仿真再到鲁棒性测试的全方位需求。
