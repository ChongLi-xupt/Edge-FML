classdef Solution
    % Solution - Represents a solution in the decision space
    % Contains decision variables and objective values

    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Solution Representation for Multi-Objective Optimization

    properties
        % Decision variables
        x_offload         % x_{r,k}: Offloading decisions (binary vector)
        y_cache           % y_{r,t}: Cache strategies (binary vector)
        f_resource        % f_{r,t}: Resource allocation (continuous vector)
        z_security        % z_{r,k}: Security levels (integer vector [1,4])

        % Objective values
        objectives        % [T_total, E_total, Psi]: 3-dimensional objective vector

        % Constraint violation
        constraintViolation  % CV: Total constraint violation
        violations           % Individual constraint violations [g1, g2, g3, g4]

        % Additional attributes
        rank              % Pareto rank
        crowdingDistance  % Crowding distance for diversity
        dominationCount   % Number of solutions dominating this one
        dominatedSet      % Set of solutions dominated by this one
    end

    methods
        function obj = Solution(K, T)
            % Constructor: Initialize empty solution
            if nargin > 0
                obj.x_offload = zeros(K, 1);
                obj.y_cache = zeros(T, 1);
                obj.f_resource = zeros(T, 1);
                obj.z_security = ones(K, 1);
                obj.objectives = zeros(1, 3);
                obj.constraintViolation = 0;
                obj.violations = zeros(1, 4);
                obj.rank = inf;
                obj.crowdingDistance = 0;
                obj.dominationCount = 0;
                obj.dominatedSet = [];
            end
        end

        function dominated = dominates(obj, other, epsilon)
            % Check if this solution epsilon-dominates another
            % obj << other iff all obj.f <= other.f - eps AND exists strict <

            if nargin < 3
                epsilon = 0;
            end

            f1 = obj.objectives;
            f2 = other.objectives;

            allLessEqual = all(f1 <= f2 - epsilon);
            atLeastOneStrictLess = any(f1 < f2 - epsilon);

            dominated = allLessEqual && atLeastOneStrictLess;
        end

        function obj = copy(obj)
            % Deep copy of the solution
            newObj = Solution(length(obj.x_offload), length(obj.y_cache));
            newObj.x_offload = obj.x_offload;
            newObj.y_cache = obj.y_cache;
            newObj.f_resource = obj.f_resource;
            newObj.z_security = obj.z_security;
            newObj.objectives = obj.objectives;
            newObj.constraintViolation = obj.constraintViolation;
            newObj.violations = obj.violations;
            newObj.rank = obj.rank;
            newObj.crowdingDistance = obj.crowdingDistance;
            obj = newObj;
        end
    end
end
