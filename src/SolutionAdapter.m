classdef SolutionAdapter
    % SolutionAdapter - Solution compatibility enhancement
    % Implements Section 3.4: Parameter Normalizer and Feasibility Mapper
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Region Heterogeneity-Aware Solution Compatibility

    properties
        targetRegion      % Target region (RegionConfig)
        targetTasks       % Target task set
        targetEvaluator   % ObjectiveEvaluator for target region
        beta              % Heterogeneity decay coefficient
        theta_keep        % Compatibility threshold
    end

    methods
        function obj = SolutionAdapter(targetRegion, targetTasks, mode, varargin)
            % Constructor
            if nargin < 3
                mode = 'default';
            end

            obj.targetRegion = targetRegion;
            obj.targetTasks = targetTasks;
            obj.targetEvaluator = ObjectiveEvaluator(targetRegion, targetTasks);
            obj.beta = 2.0;

            if strcmp(mode, 'no_compat')
                obj.theta_keep = -1.0; % Disable compatibility filtering
            else
                % obj.theta_keep = 0.3; % original threshold (commented for future tuning)
                obj.theta_keep = 0.35; % default increased threshold (lowered from 0.45)
            end

            % Optional override for theta_keep sweep: SolutionAdapter(..., 'ThetaKeep', value)
            if ~isempty(varargin)
                for i = 1:2:length(varargin)
                    key = varargin{i};
                    if ischar(key) || isstring(key)
                        key = char(key);
                        if strcmpi(key, 'ThetaKeep')
                            val = varargin{i+1};
                            % original: no override
                            obj.theta_keep = val; % allow sweep values e.g., 0.40, 0.45, 0.50, 0.55
                        end
                    end
                end
            end
        end

        function adaptedSol = adaptSolution(obj, externalSol, sourceRegion, importance)
            % Adapt external solution to target region
            % Step 1: Parameter normalization
            % Step 2: Feasibility mapping
            % Returns: adapted solution or empty if incompatible

            if nargin < 4
                importance = 1.0;  % Default importance
            end

            % Step 1: Parameter Normalization
            normalizedSol = obj.parameterNormalizer(externalSol, sourceRegion);

            % Step 2: Feasibility Mapping
            fixedSol = obj.feasibilityMapper(normalizedSol);

            % Evaluate compatibility
            RD = sourceRegion.computeDissimilarity(obj.targetRegion);
            compatScore = obj.computeCompatibility(fixedSol, RD, importance);

            if compatScore > obj.theta_keep
                adaptedSol = fixedSol;
            else
                adaptedSol = [];  % Reject incompatible solution
            end
        end

        function normalizedSol = parameterNormalizer(obj, externalSol, sourceRegion)
            % Parameter Normalizer (Section 3.4.1)
            % Map external solution to local parameter space

            K = obj.targetRegion.numDevices;
            T = length(obj.targetTasks);
            normalizedSol = Solution(K, T);

            % 1. Resource mapping (scale by compute capacity ratio)
            capacityRatio = obj.targetRegion.computeCapacity / sourceRegion.computeCapacity;
            % Distributed clamp based on capacity dominance
            % original clamp: [0.7, 1.3]
            if capacityRatio >= 1
                capacityRatio = min(1.4, capacityRatio);
            else
                capacityRatio = max(0.8, capacityRatio);
            end

            T_source = length(externalSol.f_resource);
            T_target = length(obj.targetTasks);

            for t = 1:T_target
                % Map to corresponding source task type (circular mapping if sizes differ)
                t_source = mod(t - 1, T_source) + 1;
                normalizedSol.f_resource(t) = externalSol.f_resource(t_source) * capacityRatio;
                % Clip to valid range
                normalizedSol.f_resource(t) = max(0.1, min(1.0, normalizedSol.f_resource(t)));
            end

            % 2. Cache adaptation (only cache if fits in local capacity)
            % Compute cache load-based margin: cacheMargin = 0.85 + 0.1*(1 - util)
            totalData = 0;
            for tt = 1:T_target
                if ~isempty(obj.targetTasks(tt)) && isprop(obj.targetTasks(tt), 'dataSize')
                    totalData = totalData + obj.targetTasks(tt).dataSize;
                end
            end
            util = min(1.0, totalData / max(obj.targetRegion.cacheCapacity, eps));
            cacheMargin = 0.85 + 0.1 * (1.0 - util);
            for t = 1:T_target
                t_source = mod(t - 1, T_source) + 1;

                if t_source <= T_source && externalSol.y_cache(t_source) == 1
                    % original margin: 1.0 or 0.9 (commented above)
                    if obj.targetTasks(t).dataSize <= obj.targetRegion.cacheCapacity * cacheMargin
                        normalizedSol.y_cache(t) = 1;
                    else
                        normalizedSol.y_cache(t) = 0;
                    end
                else
                    normalizedSol.y_cache(t) = 0;
                end
            end

            % 3. Offloading decision mapping (preserve pattern if device counts match)
            K_source = length(externalSol.x_offload);

            for k = 1:K
                k_source = mod(k - 1, K_source) + 1;
                normalizedSol.x_offload(k) = externalSol.x_offload(k_source);
            end

            % 4. Security level calibration (ensure meets local minimum requirements)
            RD = sourceRegion.computeDissimilarity(obj.targetRegion);
            for k = 1:K
                k_source = mod(k - 1, K_source) + 1;

                if normalizedSol.x_offload(k) == 1
                    taskType = mod(k - 1, T) + 1;
                    minSecLevel = obj.targetTasks(taskType).securityLevel;
                    sourceSecLevel = externalSol.z_security(k_source);

                    % Differential calibration:
                    % original conservative: max(sourceSecLevel, minSecLevel+1)
                    if minSecLevel >= 3 || RD > 0.5
                        normalizedSol.z_security(k) = max(sourceSecLevel, minSecLevel + 1);
                    else
                        normalizedSol.z_security(k) = max(sourceSecLevel, minSecLevel);
                    end
                else
                    normalizedSol.z_security(k) = 1;  % Default level
                end
                normalizedSol.z_security(k) = max(1, min(4, normalizedSol.z_security(k)));
            end
        end

        function fixedSol = feasibilityMapper(obj, normalizedSol)
            % Feasibility Mapper (Section 3.4.2)
            % Local optimization to improve feasibility

            fixedSol = normalizedSol;

            % Evaluate initial constraint violation
            [~, violations, CV] = obj.targetEvaluator.evaluate(fixedSol);

            if CV <= 1e-6
                return;  % Already feasible
            end

            % Apply repair rules for each constraint
            % Increase repair iterations for deadline/security-focused fixes
            % original: maxIterations = 10
            maxIterations = 20;
            for iter = 1:maxIterations
                % Constraint 1: Compute capacity overload
                if violations(1) > 0
                    fixedSol = obj.repairComputeCapacity(fixedSol);
                end

                % Constraint 2: Cache overflow
                if violations(2) > 0
                    fixedSol = obj.repairCacheOverflow(fixedSol);
                end

                % Constraint 3: Deadline violation
                if violations(3) > 0
                    fixedSol = obj.repairDeadlineViolation(fixedSol);
                end

                % Constraint 4: Security compliance
                if violations(4) > 0
                    fixedSol = obj.repairSecurityCompliance(fixedSol);
                end

                % Re-evaluate
                [~, violations, CV] = obj.targetEvaluator.evaluate(fixedSol);

                if CV <= 1e-6
                    break;  % Became feasible
                end
            end

            % Gradient-guided microtuning (simplified local search)
            if CV > 1e-6
                fixedSol = obj.localMicrotuning(fixedSol, 10);
            end
        end

        function sol = repairComputeCapacity(obj, sol)
            % Repair compute capacity violation
            % Reduce resource allocation for non-critical tasks

            T = length(obj.targetTasks);

            % Sort tasks by priority (lower priority = reduce first)
            priorities = zeros(T, 1);
            for t = 1:T
                priorities(t) = obj.targetTasks(t).priority;
            end
            [~, sortedIdx] = sort(priorities);

            % Reduce allocation iteratively
            for i = 1:T
                t = sortedIdx(i);
                sol.f_resource(t) = sol.f_resource(t) * 0.9;
                sol.f_resource(t) = max(0.1, sol.f_resource(t));

                % Check if fixed
                [~, ~, CV] = obj.targetEvaluator.evaluate(sol);
                if CV < 1e-6 || obj.targetEvaluator.computeConstraint_g1(sol) <= 0
                    break;
                end
            end
        end

        function sol = repairCacheOverflow(obj, sol)
            % Repair cache overflow
            % Remove low-priority cached items

            T = length(obj.targetTasks);

            % Compute cache priority: dataSize / accessFreq (lower = remove first)
            cachePriority = zeros(T, 1);
            for t = 1:T
                if sol.y_cache(t) == 1
                    cachePriority(t) = obj.targetTasks(t).accessFreq / ...
                        (obj.targetTasks(t).dataSize + eps);
                else
                    cachePriority(t) = inf;  % Not cached
                end
            end

            [~, sortedIdx] = sort(cachePriority);

            % Remove cached items iteratively
            for i = 1:T
                t = sortedIdx(i);
                if sol.y_cache(t) == 1
                    sol.y_cache(t) = 0;

                    % Check if fixed
                    if obj.targetEvaluator.computeConstraint_g2(sol) <= 0
                        break;
                    end
                end
            end
        end

        function sol = repairDeadlineViolation(obj, sol)
            % Repair deadline violations
            % Increase resource allocation for high-priority tasks

            K = length(sol.x_offload);
            T = length(obj.targetTasks);

            % Find tasks with deadline violations
            for k = 1:K
                if sol.x_offload(k) == 1
                    taskType = mod(k - 1, T) + 1;

                    % Increase resource allocation
                    sol.f_resource(taskType) = min(1.0, sol.f_resource(taskType) * 1.1);
                end
            end
        end

        function sol = repairSecurityCompliance(obj, sol)
            % Repair security compliance violations
            % Ensure z_k >= s_min for offloaded tasks

            K = length(sol.x_offload);
            T = length(obj.targetTasks);

            for k = 1:K
                if sol.x_offload(k) == 1
                    taskType = mod(k - 1, T) + 1;
                    minSec = obj.targetTasks(taskType).securityLevel;
                    sol.z_security(k) = max(sol.z_security(k), minSec);
                end
            end
        end

        function sol = localMicrotuning(obj, sol, numGen)
            % Gradient-guided microtuning using simple local search

            bestSol = sol;
            [~, ~, bestCV] = obj.targetEvaluator.evaluate(bestSol);

            for gen = 1:numGen
                % Small perturbation
                trial = sol;

                % Perturb resource allocation
                T = length(trial.f_resource);
                idx = randi(T);
                delta = 0.05 * (2 * rand - 1);
                trial.f_resource(idx) = max(0.1, min(1.0, trial.f_resource(idx) + delta));

                % Evaluate
                [~, ~, trialCV] = obj.targetEvaluator.evaluate(trial);

                if trialCV < bestCV
                    bestSol = trial;
                    bestCV = trialCV;
                end
            end

            sol = bestSol;
        end

        function compatScore = computeCompatibility(obj, sol, RD, importance)
            % Compute compatibility score (Eq. 3.4.2)
            % Compat(r,l,s) = exp(-beta*RD) * (1 - CV_r(s_norm)) * I_l(s)

            [~, ~, CV] = obj.targetEvaluator.evaluate(sol);

            heterogeneityTerm = exp(-obj.beta * RD);
            feasibilityTerm = 1 - min(CV, 1.0);  % Clip to [0,1]
            importanceTerm = importance;

            compatScore = heterogeneityTerm * feasibilityTerm * importanceTerm;
        end
    end
end
