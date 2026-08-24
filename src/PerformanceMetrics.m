classdef PerformanceMetrics
    % PerformanceMetrics - Performance evaluation metrics
    % Implements HV, IGD, and other quality indicators (Section 5)
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Performance Evaluation Metrics

    properties
        referencePoint    % Reference point for hypervolume
    end

    methods
        function obj = PerformanceMetrics(refPoint)
            % Constructor
            if nargin > 0
                obj.referencePoint = refPoint;
            else
                obj.referencePoint = [1000, 1000, 1000];  % Default reference
            end
        end

        function HV = computeHypervolume(obj, population)
            % Compute hypervolume indicator
            % population: array of Solution objects

            if isempty(population)
                HV = 0;
                return;
            end

            % FIXED: Extract feasible solutions using indices
            popSize = length(population);
            feasible = zeros(popSize, 1);
            feasCount = 0;

            for i = 1:popSize
                if population(i).constraintViolation <= 1e-6
                    feasCount = feasCount + 1;
                    feasible(feasCount) = i;
                end
            end

            if feasCount == 0
                HV = 0;
                return;
            end

            feasible = feasible(1:feasCount);

            % Extract objectives
            objectives = zeros(feasCount, 3);
            for i = 1:feasCount
                objectives(i, :) = population(feasible(i)).objectives;
            end

            % Filter non-dominated solutions
            paretoFront = obj.extractParetoFront(objectives);

            if isempty(paretoFront)
                HV = 0;
                return;
            end

            HV = obj.computeHV(paretoFront, obj.referencePoint);
        end

        function HV = computeHV(obj, front, refPoint)
            if isempty(front)
                HV = 0;
                return;
            end
            valid = all(front < refPoint, 2);
            front = front(valid, :);
            if isempty(front)
                HV = 0;
                return;
            end
            n = size(front, 1);
            m = size(front, 2);
            if ((m <= 3 && n <= 200) || (m <= 5 && n <= 100))
                HV = obj.hv_recursive(front, refPoint);
            else
                samples = min(20000, 2000 * n);
                HV = obj.hv_montecarlo(front, refPoint, samples);
            end
        end

        function HV = hv_recursive(obj, front, refPoint)
            if isempty(front)
                HV = 0;
                return;
            end
            m = size(front, 2);
            if m == 1
                minv = min(front(:, 1));
                w = refPoint(1) - minv;
                HV = max(0, w);
                return;
            end
            front = obj.extractParetoFront(front);
            [~, sortIdx] = sort(front(:, 1), 'descend');
            front = front(sortIdx, :);
            prev = refPoint(1);
            HV = 0;
            n = size(front, 1);
            for i = 1:n
                width = prev - front(i, 1);
                if width > 0
                    S = front(i:n, 2:end);
                    if ~isempty(S)
                        valid = all(S < refPoint(2:end), 2);
                        S = S(valid, :);
                    end
                    subHV = obj.hv_recursive(S, refPoint(2:end));
                    HV = HV + width * subHV;
                end
                prev = front(i, 1);
            end
        end

        function HV = hv_montecarlo(~, front, refPoint, samples)
            lows = min(front, [], 1);
            box = refPoint - lows;
            box(box < 0) = 0;
            volume = prod(box);
            if volume <= 0
                HV = 0;
                return;
            end
            dims = numel(refPoint);
            U = rand(samples, dims);
            pts = bsxfun(@plus, lows, bsxfun(@times, U, box));
            dominated = false(samples, 1);
            for i = 1:size(front, 1)
                dominated = dominated | all(bsxfun(@ge, pts, front(i, :)), 2);
            end
            frac = sum(dominated) / samples;
            HV = frac * volume;
        end

        function paretoFront = extractParetoFront(~, objectives)
            % Extract non-dominated solutions from objective matrix
            % objectives: N x M matrix

            n = size(objectives, 1);
            dominated = false(n, 1);

            for i = 1:n
                for j = 1:n
                    if i ~= j
                        % Check if j dominates i
                        if all(objectives(j, :) <= objectives(i, :)) && ...
                           any(objectives(j, :) < objectives(i, :))
                            dominated(i) = true;
                            break;
                        end
                    end
                end
            end

            paretoFront = objectives(~dominated, :);
        end

        function IGD = computeIGD(~, population, trueParetoFront)
            % Compute Inverted Generational Distance
            % population: array of Solution objects
            % trueParetoFront: P x 3 matrix of true Pareto front

            if isempty(population) || isempty(trueParetoFront)
                IGD = inf;
                return;
            end

            % FIXED: Extract feasible objectives with pre-allocation
            popSize = length(population);
            feasible = zeros(popSize, 3);
            feasCount = 0;

            for i = 1:popSize
                if population(i).constraintViolation <= 1e-6
                    feasCount = feasCount + 1;
                    feasible(feasCount, :) = population(i).objectives;
                end
            end

            if feasCount == 0
                IGD = inf;
                return;
            end

            feasible = feasible(1:feasCount, :);

            % Compute minimum distance from each true Pareto point to approximation
            P = size(trueParetoFront, 1);
            distances = zeros(P, 1);

            for i = 1:P
                minDist = inf;
                for j = 1:size(feasible, 1)
                    dist = norm(trueParetoFront(i, :) - feasible(j, :));
                    minDist = min(minDist, dist);
                end
                distances(i) = minDist;
            end

            IGD = mean(distances);
        end

        function feasibilityRate = computeFeasibilityRate(~, population)
            % Compute percentage of feasible solutions

            if isempty(population)
                feasibilityRate = 0;
                return;
            end

            numFeasible = 0;
            for i = 1:length(population)
                if population(i).constraintViolation <= 1e-6
                    numFeasible = numFeasible + 1;
                end
            end

            feasibilityRate = 100 * numFeasible / length(population);
        end

        function diversity = computeDiversity(~, population)
            % Compute diversity metric (spread of solutions)

            if isempty(population) || length(population) < 2
                diversity = 0;
                return;
            end

            % FIXED: Extract feasible objectives with pre-allocation
            popSize = length(population);
            objectives = zeros(popSize, 3);
            objCount = 0;

            for i = 1:popSize
                if population(i).constraintViolation <= 1e-6
                    objCount = objCount + 1;
                    objectives(objCount, :) = population(i).objectives;
                end
            end

            if objCount < 2
                diversity = 0;
                return;
            end

            objectives = objectives(1:objCount, :);

            % Compute average distance to nearest neighbor
            n = objCount;
            minDistances = zeros(n, 1);

            for i = 1:n
                minDist = inf;
                for j = 1:n
                    if i ~= j
                        dist = norm(objectives(i, :) - objectives(j, :));
                        minDist = min(minDist, dist);
                    end
                end
                minDistances(i) = minDist;
            end

            diversity = mean(minDistances);
        end

        function spacing = computeSpacing(~, population)
            % Compute spacing metric (uniformity of distribution)

            if isempty(population) || length(population) < 2
                spacing = 0;
                return;
            end

            % FIXED: Extract feasible objectives with pre-allocation
            popSize = length(population);
            objectives = zeros(popSize, 3);
            objCount = 0;

            for i = 1:popSize
                if population(i).constraintViolation <= 1e-6
                    objCount = objCount + 1;
                    objectives(objCount, :) = population(i).objectives;
                end
            end

            if objCount < 2
                spacing = 0;
                return;
            end

            objectives = objectives(1:objCount, :);

            % Compute minimum distances
            n = objCount;
            minDistances = zeros(n, 1);

            for i = 1:n
                minDist = inf;
                for j = 1:n
                    if i ~= j
                        dist = norm(objectives(i, :) - objectives(j, :));
                        minDist = min(minDist, dist);
                    end
                end
                minDistances(i) = minDist;
            end

            % Spacing is std of minimum distances
            avgDist = mean(minDistances);
            spacing = sqrt(mean((minDistances - avgDist).^2));
        end

        function printMetrics(obj, population, methodName)
            % Print all performance metrics

            fprintf('\n=== Performance Metrics: %s ===\n', methodName);
            fprintf('Population Size: %d\n', length(population));
            fprintf('Feasibility Rate: %.2f%%\n', obj.computeFeasibilityRate(population));
            fprintf('Hypervolume (HV): %.4f\n', obj.computeHypervolume(population));
            fprintf('Diversity: %.4f\n', obj.computeDiversity(population));
            fprintf('Spacing: %.4f\n', obj.computeSpacing(population));

            % FIXED: Average objective values (feasible only) with pre-allocation
            popSize = length(population);
            feasibleObjs = zeros(popSize, 3);
            feasCount = 0;

            for i = 1:popSize
                if population(i).constraintViolation <= 1e-6
                    feasCount = feasCount + 1;
                    feasibleObjs(feasCount, :) = population(i).objectives;
                end
            end

            if feasCount > 0
                feasibleObjs = feasibleObjs(1:feasCount, :);
                fprintf('Average Latency: %.4f\n', mean(feasibleObjs(:, 1)));
                fprintf('Average Energy: %.4f\n', mean(feasibleObjs(:, 2)));
                fprintf('Average Security Risk: %.4f\n', mean(feasibleObjs(:, 3)));
            end

            fprintf('================================\n\n');
        end
    end
end
