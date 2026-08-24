# Edge-FML Usage Guide

## Table of Contents

1. [Getting Started](#getting-started)
2. [Basic Workflow](#basic-workflow)
3. [Advanced Usage](#advanced-usage)
4. [Parameter Tuning](#parameter-tuning)
5. [Customization](#customization)
6. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Step 1: Verify Installation

```matlab
% Verify all classes are accessible
addpath('src');
clear; clc;

% Test basic functionality
region = RegionConfig(1, 2.5, 80, 40, 100, 20, 0.3);
fprintf('Region created: ID=%d, F=%.1f GHz\n', region.regionID, region.computeCapacity);
```

Expected output:
```
Region created: ID=1, F=2.5 GHz
```

### Step 2: Run Quick Test

```matlab
% Quick component test
SimulationDataGenerator.testSSS();
```

### Step 3: Run Full Test Suite

```matlab
% Complete test with visualization
test_EdgeFML
```

This will:
- Test all components
- Run federated optimization
- Generate visualizations
- Create analysis report

---

## Basic Workflow

### 1. Generate Scenario

```matlab
% Define scenario parameters
N = 10;              % Number of regions
scenarioType = 'moderate';  % 'homogeneous', 'moderate', or 'heterogeneous'

% Generate regions and tasks
[regions, taskSets] = SimulationDataGenerator.generateScenario(N, scenarioType);
```

**Scenario Types:**
- `'homogeneous'`: Low heterogeneity (RD < 0.15)
- `'moderate'`: Medium heterogeneity (0.15 < RD < 0.35)
- `'heterogeneous'`: High heterogeneity (RD > 0.35)

### 2. Configure Algorithm

```matlab
% Algorithm parameters
R_max = 10;      % Federated rounds (recommended: 10-20)
M_local = 30;    % Local generations per round (recommended: 20-50)
```

### 3. Create and Run Framework

```matlab
% Initialize Edge-FML
edgeFML = EdgeFML(regions, taskSets, R_max, M_local);

% Run federated optimization
edgeFML = edgeFML.run();
```

### 4. Extract Results

```matlab
% Global Pareto front
globalFront = edgeFML.globalElites;

% Convergence history
history = edgeFML.roundHistory;

% Performance metrics
metrics = PerformanceMetrics([1000, 1000, 1000]);
HV = metrics.computeHypervolume(globalFront);
fprintf('Final Hypervolume: %.4f\n', HV);
```

---

## Advanced Usage

### Custom Region Configuration

```matlab
% Manually create regions with specific characteristics
regions = RegionConfig.empty(5, 0);

% High-performance edge server
regions(1) = RegionConfig(1, 4.0, 150, 80, 150, 10, 0.1);

% Medium-capacity regional node
regions(2) = RegionConfig(2, 2.5, 80, 50, 100, 20, 0.3);

% Resource-constrained IoT gateway
regions(3) = RegionConfig(3, 1.0, 30, 20, 40, 50, 0.6);

% Mobile edge node
regions(4) = RegionConfig(4, 1.8, 60, 35, 70, 30, 0.4);

% Cloud-edge hybrid
regions(5) = RegionConfig(5, 3.5, 120, 70, 130, 15, 0.2);
```

### Custom Task Definition

```matlab
T = 5;  % Number of task types
tasks = TaskData.empty(T, 0);

% Video processing task
tasks(1) = TaskData(1, 50, 8e9, 2.0, 3, 5, 80);
%         (type, dataSize(MB), workload(cycles), deadline(s), secLevel, priority, accessFreq)

% Sensor data aggregation
tasks(2) = TaskData(2, 5, 1e9, 0.5, 2, 3, 120);

% Machine learning inference
tasks(3) = TaskData(3, 30, 5e9, 1.5, 4, 4, 60);

% Real-time monitoring
tasks(4) = TaskData(4, 10, 2e9, 0.8, 3, 5, 100);

% Batch analytics
tasks(5) = TaskData(5, 80, 15e9, 5.0, 2, 2, 20);
```

### Analyze Specific Region

```matlab
% Extract local optimizer for region 3
localOpt = edgeFML.localOptimizers{3};

% Get region's elite solutions
elites = localOpt.getEliteSolutions(10);

% Evaluate local performance
metrics.printMetrics(elites, 'Region 3 Local Front');
```

### Compare Cluster Performance

```matlab
M = edgeFML.clusterManager.M;

for m = 1:M
    members = edgeFML.clusterManager.getClusterMembers(m);
    
    % Collect all solutions from cluster
    clusterSols = [];
    for r = members
        clusterSols = [clusterSols; edgeFML.localOptimizers{r}.eliteArchive];
    end
    
    % Evaluate cluster performance
    HV_cluster = metrics.computeHypervolume(clusterSols);
    fprintf('Cluster %d (size=%d): HV=%.4f\n', m, length(members), HV_cluster);
end
```

---

## Parameter Tuning

### Population Size Tuning

The population size is automatically adaptive, but you can override:

```matlab
% Modify MTDMS_CMOEA_Local.m constructor
% Default: N_base = 100
% For faster execution: N_base = 50
% For better quality: N_base = 150
```

### Constraint Handling Tuning

```matlab
% Modify MTDMS_CMOEA_Local properties
optimizer = MTDMS_CMOEA_Local(region, tasks, 50);

% Adjust initial threshold
optimizer.theta0 = 0.5;  % Default: 1.0 (stricter: 0.5, looser: 2.0)

% Adjust resource utilization decay
optimizer.lambda = 0.6;  % Default: 0.8 (less sensitive: 0.6, more: 1.0)
```

### Communication Optimization

```matlab
% Modify EdgeFML properties
edgeFML.M_elite = 5;  % Default: 10 (less communication but lower quality)
```

### Compatibility Threshold

```matlab
% Modify SolutionAdapter properties
adapter = SolutionAdapter(targetRegion, targetTasks);
adapter.theta_keep = 0.4;  % Default: 0.3 (stricter: 0.5, looser: 0.2)
adapter.beta = 3.0;        % Default: 2.0 (more sensitive to heterogeneity)
```

---

## Customization

### Add Custom Objective

To add a fourth objective (e.g., cost):

1. **Modify `ObjectiveEvaluator.m`:**

```matlab
% In evaluate() method
function [objectives, violations, CV] = evaluate(obj, sol)
    T_total = obj.computeTotalLatency(sol);
    E_total = obj.computeTotalEnergy(sol);
    Psi = obj.computeSecurityRisk(sol);
    Cost = obj.computeTotalCost(sol);  % NEW
    
    objectives = [T_total, E_total, Psi, Cost];  % Changed to 4D
    % ... rest of code
end

% Add new method
function Cost = computeTotalCost(obj, sol)
    % Implement cost model
    Cost = 0;
    for k = 1:length(sol.x_offload)
        if sol.x_offload(k) == 1
            Cost = Cost + 0.01;  % Cost per offloaded task
        end
    end
end
```

2. **Update `PerformanceMetrics.m`:**

```matlab
% Change numObj from 3 to 4 in computeCrowdingDistance()
numObj = 4;
```

3. **Adjust reference point:**

```matlab
metrics = PerformanceMetrics([1000, 1000, 1000, 100]);  % Add 4th dimension
```

### Add Custom Constraint

To add a bandwidth constraint:

1. **Modify `ObjectiveEvaluator.m`:**

```matlab
% Add g5 method
function g5 = computeConstraint_g5(obj, sol)
    % Bandwidth constraint
    totalBandwidth = 0;
    for k = 1:length(sol.x_offload)
        if sol.x_offload(k) == 1
            taskType = mod(k-1, obj.T) + 1;
            totalBandwidth = totalBandwidth + obj.tasks(taskType).dataSize;
        end
    end
    
    maxBandwidth = obj.region.bandwidth * 10;  % 10 MB limit
    g5 = totalBandwidth - maxBandwidth;
end

% Update evaluate() to include g5
violations = [g1, g2, g3, g4, g5];
```

2. **Update repair mechanisms in `SolutionAdapter.m`:**

```matlab
% Add repair method for g5
function sol = repairBandwidthViolation(obj, sol)
    % Remove some offloading decisions to reduce bandwidth
    while obj.targetEvaluator.computeConstraint_g5(sol) > 0
        % Find offloaded task and switch to local
        offloadedIdx = find(sol.x_offload == 1);
        if isempty(offloadedIdx)
            break;
        end
        sol.x_offload(offloadedIdx(1)) = 0;
    end
end
```

### Custom Visualization

```matlab
% Extract solution data
if ~isempty(globalFront)
    objs = zeros(length(globalFront), 3);
    for i = 1:length(globalFront)
        objs(i, :) = globalFront(i).objectives;
    end
    
    % Custom parallel coordinates plot
    figure('Name', 'Parallel Coordinates');
    parallelcoords(objs, 'Labels', {'Latency', 'Energy', 'Security'});
    title('Pareto Front - Parallel Coordinates', 'FontSize', 14);
    
    % Custom heatmap of decision variables
    figure('Name', 'Decision Heatmap');
    decisionMatrix = zeros(length(globalFront), globalFront(1).x_offload);
    for i = 1:length(globalFront)
        decisionMatrix(i, :) = globalFront(i).x_offload';
    end
    imagesc(decisionMatrix);
    colormap(gray);
    xlabel('Device Index');
    ylabel('Solution Index');
    title('Offloading Decisions Heatmap', 'FontSize', 14);
    colorbar;
end
```

---

## Troubleshooting

### Issue 1: MATLAB Out of Memory

**Symptom:** Error message "Out of memory"

**Solution:**
```matlab
% Reduce population size
% In MTDMS_CMOEA_Local.m, change:
N_base = 50;  % Instead of 100

% Reduce number of regions
N = 5;  % Instead of 10

% Reduce elite exchange
edgeFML.M_elite = 5;  % Instead of 10
```

### Issue 2: Low Feasibility Rate

**Symptom:** Feasibility rate < 50%

**Solution:**
```matlab
% Increase local evolution budget
M_local = 50;  % Instead of 30

% Relax initial constraint threshold
% In MTDMS_CMOEA_Local.m:
obj.theta0 = 2.0;  % Instead of 1.0

% Check task deadlines are realistic
for t = 1:length(tasks)
    tasks(t).deadline = tasks(t).deadline * 2;  % Double all deadlines
end
```

### Issue 3: Slow Convergence

**Symptom:** HV improvement < 5% after 10 rounds

**Solution:**
```matlab
% Increase federated rounds
R_max = 20;  % Instead of 10

% Increase local generations
M_local = 50;  % Instead of 30

% Increase crossover rate
% In MTDMS_CMOEA_Local.m:
obj.CR = 0.95;  % Instead of 0.9
```

### Issue 4: Clustering Too Coarse/Fine

**Symptom:** Only 1 cluster or too many clusters

**Solution:**
```matlab
% In ClusterManager.m constructor, adjust:
obj.M_max = 8;           % Default: min(10, N/5)
obj.theta_merge = 0.15;  % Default: 0.25 (lower = less merging)
```

### Issue 5: High Communication Overhead

**Symptom:** Total communication > 20 MB for 10 regions

**Solution:**
```matlab
% Reduce elite solutions shared
edgeFML.M_elite = 5;

% Increase compression (modify selectTopByHV to be more selective)

% Reduce number of federated rounds
R_max = 5;
```

### Issue 6: Solutions Not Compatible

**Symptom:** Adaptation rate < 30%

**Solution:**
```matlab
% Relax compatibility threshold
% In SolutionAdapter.m:
obj.theta_keep = 0.2;  % Instead of 0.3

% Reduce heterogeneity decay
obj.beta = 1.5;  % Instead of 2.0

% Or use more homogeneous scenario
[regions, taskSets] = SimulationDataGenerator.generateScenario(N, 'moderate');
% Instead of 'heterogeneous'
```

---

## Tips and Best Practices

### 1. Start Small

Begin with small scenarios to verify correctness:
```matlab
N = 5;
R_max = 5;
M_local = 20;
```

### 2. Monitor Progress

Check intermediate results:
```matlab
% After each round
for round = 1:R_max
    % ... run round ...
    fprintf('Round %d: HV=%.2f, Feasibility=%.1f%%\n', ...
        round, HV, feasRate);
end
```

### 3. Save Checkpoints

For long runs, save intermediate results:
```matlab
% After each round
save(sprintf('checkpoint_round_%d.mat', round), 'edgeFML');
```

### 4. Parallel Regions (Optional)

If you have Parallel Computing Toolbox:
```matlab
% In EdgeFML.localEvolution(), use parfor:
parfor r = 1:obj.N
    obj.localOptimizers{r} = obj.localOptimizers{r}.evolve();
end
```

### 5. Reproducibility

Set random seed for reproducible results:
```matlab
rng(42);  % Fixed seed
[regions, taskSets] = SimulationDataGenerator.generateScenario(N, 'moderate');
```

---

## Performance Benchmarks

Typical execution times (Intel i7, 16GB RAM):

| Scenario | Regions | Rounds | Time |
|----------|---------|--------|------|
| Small | 5 | 5 | ~2 min |
| Medium | 10 | 10 | ~8 min |
| Large | 20 | 10 | ~25 min |
| X-Large | 50 | 10 | ~90 min |

**Memory usage:** ~100-500 MB depending on scenario size

---

## Next Steps

1. **Experiment with different scenarios:** Try homogeneous vs heterogeneous
2. **Tune parameters:** Adjust population size, thresholds, etc.
3. **Customize objectives/constraints:** Add domain-specific requirements
4. **Extend to real data:** Replace simulated tasks with actual workload traces
5. **Deploy to edge platform:** Integrate with LF Edge Akraino or similar

---

## Support

For detailed algorithm description, see [`FML.MD`](FML.MD).

For questions or issues, please refer to the main [`README.md`](README.md).
