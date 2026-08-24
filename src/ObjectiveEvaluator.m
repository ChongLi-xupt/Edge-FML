classdef ObjectiveEvaluator
    % ObjectiveEvaluator - Evaluates objectives and constraints
    % Implements the tri-objective optimization model from Section 2

    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Tri-Objective Optimization Model

    properties
        region            % RegionConfig object
        tasks             % Array of TaskData objects
        T                 % Number of task types
        K                 % Number of devices

        % System parameters
        P_tx              % Transmission power (W)
        P_idle            % Idle power (W)
        kappa             % Effective switched capacitance
        B_channel         % Channel bandwidth (Hz)
        N0                % Noise power spectral density
        securityCosts     % Security overhead coefficients [level 1-4]
    end

    methods
        function obj = ObjectiveEvaluator(region, tasks)
            % Constructor
            obj.region = region;
            obj.tasks = tasks;
            obj.T = length(tasks);
            obj.K = region.numDevices;

            % Default system parameters
            obj.P_tx = 0.5;      % 0.5W transmission power
            obj.P_idle = 0.1;    % 0.1W idle power
            obj.kappa = 1e-28;   % Effective switched capacitance
            obj.B_channel = 5e6; % 5 MHz channel bandwidth
            obj.N0 = 1e-13;      % Noise power spectral density
            obj.securityCosts = [0.05, 0.12, 0.25, 0.45]; % Security overhead
        end

        function [objectives, violations, CV] = evaluate(obj, sol)
            % Evaluate solution: compute objectives and constraint violations
            % Returns: objectives [T_total, E_total, Psi], violations [g1,g2,g3,g4], CV

            % Objective 1: Total Latency
            T_total = obj.computeTotalLatency(sol);

            % Objective 2: Total Energy
            E_total = obj.computeTotalEnergy(sol);

            % Objective 3: Security Risk
            Psi = obj.computeSecurityRisk(sol);

            objectives = [T_total, E_total, Psi];

            % Constraint violations
            g1 = obj.computeConstraint_g1(sol);  % Compute capacity
            g2 = obj.computeConstraint_g2(sol);  % Cache limit
            g3 = obj.computeConstraint_g3(sol);  % Deadline
            g4 = obj.computeConstraint_g4(sol);  % Security compliance

            violations = [g1, g2, g3, g4];
            CV = sum(max(0, violations));  % Total constraint violation
        end

        function T_total = computeTotalLatency(obj, sol)
            % Compute total latency (Objective 1)
            T_total = 0;

            for k = 1:obj.K
                if sol.x_offload(k) == 1
                    % Offloaded task
                    taskType = mod(k-1, obj.T) + 1;  % Map device to task type
                    task = obj.tasks(taskType);

                    % Transmission time
                    % dataSize: MB, bandwidth: Mbps -> need to convert
                    % Time = Size(MB) / Speed(MB/s) = Size(MB) / (Bandwidth(Mbps) / 8)
                    T_tx = task.dataSize / (obj.region.bandwidth / 8);  % seconds

                    % Edge computing time
                    T_edge = task.workload / (sol.f_resource(taskType) * obj.region.computeCapacity * 1e9);

                    % Security overhead
                    secLevel = sol.z_security(k);
                    T_sec = T_edge * obj.securityCosts(secLevel);

                    T_total = T_total + T_tx + T_edge + T_sec;
                else
                    % Local processing - minimal latency model
                    taskType = mod(k-1, obj.T) + 1;
                    task = obj.tasks(taskType);
                    % Assume local device has 1/5 of edge capacity
                    T_local = task.workload / (0.2 * obj.region.computeCapacity * 1e9);
                    T_total = T_total + T_local;
                end
            end
        end

        function E_total = computeTotalEnergy(obj, sol)
            % Compute total energy consumption (Objective 2)
            E_total = 0;

            for k = 1:obj.K
                taskType = mod(k-1, obj.T) + 1;
                task = obj.tasks(taskType);

                if sol.x_offload(k) == 1
                    % Transmission energy
                    T_tx = task.dataSize / (obj.region.bandwidth / 8);
                    E_tx = obj.P_tx * T_tx;

                    % Edge computation energy
                    T_edge = task.workload / (sol.f_resource(taskType) * obj.region.computeCapacity * 1e9);
                    f_edge = sol.f_resource(taskType) * obj.region.computeCapacity * 1e9;
                    E_edge = obj.kappa * f_edge^3 * T_edge;

                    % Security energy overhead
                    secLevel = sol.z_security(k);
                    E_sec = E_edge * obj.securityCosts(secLevel);

                    E_total = E_total + E_tx + E_edge + E_sec;
                else
                    % Local processing energy
                    f_local = 0.2 * obj.region.computeCapacity * 1e9;
                    T_local = task.workload / f_local;
                    E_local = obj.kappa * f_local^3 * T_local;
                    E_total = E_total + E_local;
                end
            end
        end

        function Psi = computeSecurityRisk(obj, sol)
            % Compute security risk (Objective 3)
            Psi = 0;

            for k = 1:obj.K
                taskType = mod(k-1, obj.T) + 1;
                task = obj.tasks(taskType);

                if sol.x_offload(k) == 1
                    % Risk for offloaded task
                    secLevel = sol.z_security(k);
                    % Risk decreases with higher security level
                    risk = task.dataSize * (5 - secLevel) / 4;  % Higher level -> lower risk
                    Psi = Psi + risk;
                end
            end
        end

        function g1 = computeConstraint_g1(obj, sol)
            % Compute capacity constraint g1
            % sum(x_k * W_k / (f_k * F_r)) <= 1.0 (total compute time <= 1 second)
            % Or: sum(f_k) <= 1.0 (total resource allocation <= 100%)
            % Implements Eq. 2.3.1: Compute capacity constraint

            % Method 1: Resource allocation constraint (simpler and more direct)
            % Total allocated resource should not exceed 100%
            totalAllocation = sum(sol.f_resource);
            g1 = totalAllocation - obj.T;  % Each task type can use up to f=1.0
        end

        function g2 = computeConstraint_g2(obj, sol)
            % Cache limit constraint g2
            % sum(y_t * D_t) <= C_r^max
            % Implements Eq. 2.3.2: Cache capacity constraint
            cacheUsed = 0;

            for t = 1:obj.T
                if sol.y_cache(t) == 1
                    cacheUsed = cacheUsed + obj.tasks(t).dataSize;
                end
            end

            g2 = cacheUsed - obj.region.cacheCapacity;
        end

        function g3 = computeConstraint_g3(obj, sol)
            % Deadline constraint g3
            % Only for offloaded tasks
            % Implements Eq. 2.3.3: Task deadline constraint
            maxViolation = 0;

            for k = 1:obj.K
                if sol.x_offload(k) == 1
                    taskType = mod(k-1, obj.T) + 1;
                    task = obj.tasks(taskType);

                    % Compute total time
                    T_tx = task.dataSize / (obj.region.bandwidth / 8);
                    T_edge = task.workload / (sol.f_resource(taskType) * obj.region.computeCapacity * 1e9);
                    secLevel = sol.z_security(k);
                    T_sec = T_edge * obj.securityCosts(secLevel);

                    totalTime = T_tx + T_edge + T_sec;
                    violation = totalTime - task.deadline;
                    maxViolation = max(maxViolation, violation);
                end
            end

            g3 = maxViolation;
        end

        function g4 = computeConstraint_g4(obj, sol)
            % Security compliance constraint g4
            % z_{r,k} >= s_min for offloaded tasks
            % Implements Eq. 2.3.4: Security level constraint
            maxViolation = 0;

            for k = 1:obj.K
                if sol.x_offload(k) == 1
                    taskType = mod(k-1, obj.T) + 1;
                    task = obj.tasks(taskType);
                    violation = task.securityLevel - sol.z_security(k);
                    maxViolation = max(maxViolation, violation);
                end
            end

            g4 = maxViolation;
        end
    end
end
