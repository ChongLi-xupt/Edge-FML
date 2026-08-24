classdef DiversityEnhancer
    % DiversityEnhancer - Diversity enhancement for multi-objective optimization
    % Provides various diversity-based selection mechanisms
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01

    methods(Static)
        function selected = diversityBasedSelection(population, M, method)
            % Select M solutions from population using diversity-based methods
            % population: array of Solution objects
            % M: number of solutions to select
            % method: 'crowding', 'niche', 'hybrid'

            if nargin < 3
                method = 'hybrid';
            end

            if isempty(population) || length(population) <= M
                selected = population;
                return;
            end

            switch lower(method)
                case 'crowding'
                    selected = crowdingDistanceSelection(population, M);
                case 'niche'
                    selected = nicheSelection(population, M);
                case 'hybrid'
                    selected = hybridSelection(population, M);
                otherwise
                    warning('Unknown diversity method: %s. Using hybrid.', method);
                    selected = hybridSelection(population, M);
            end
        end

        function selected = crowdingDistanceSelection(population, M)
            % Selection based on crowding distance
            % Pre-allocate for efficiency
            n = length(population);

            % Extract objectives
            objectives = zeros(n, 3);
            for i = 1:n
                objectives(i, :) = population(i).objectives;
            end

            % Non-dominated sorting
            [fronts, ~] = nonDominatedSorting(objectives);

            selected = Solution.empty(M, 0);
            count = 0;

            % Select from fronts in order
            for f = 1:length(fronts)
                front = fronts{f};
                if count + length(front) <= M
                    % Take entire front
                    for idx = front
                        count = count + 1;
                        selected(count) = population(idx);
                    end
                else
                    % Need to select from this front based on crowding distance
                    if length(front) > 2
                        % Compute crowding distance for this front
                        frontObjectives = objectives(front, :);
                        crowdingDist = computeCrowdingDistance(frontObjectives);

                        % Sort by crowding distance (descending)
                        [~, sortIdx] = sort(crowdingDist, 'descend');
                        sortedFront = front(sortIdx);

                        % Select remaining solutions
                        remaining = M - count;
                        for i = 1:remaining
                            if i <= length(sortedFront)
                                count = count + 1;
                                selected(count) = population(sortedFront(i));
                            end
                        end
                    else
                        % Front too small, just take first solutions
                        remaining = M - count;
                        for i = 1:min(remaining, length(front))
                            count = count + 1;
                            selected(count) = population(front(i));
                        end
                    end
                    break;
                end

                if count >= M
                    break;
                end
            end

            % Trim to exact size
            selected = selected(1:min(count, M));
        end

        function selected = nicheSelection(population, M)
            % Selection based on niche counting (uniform distribution)
            n = length(population);

            % Extract objectives
            objectives = zeros(n, 3);
            for i = 1:n
                objectives(i, :) = population(i).objectives;
            end

            % Normalize objectives to [0,1]
            minObj = min(objectives);
            maxObj = max(objectives);
            rangeObj = maxObj - minObj;
            rangeObj(rangeObj == 0) = 1; % Avoid division by zero

            normObjectives = (objectives - minObj) ./ rangeObj;

            selected = Solution.empty(M, 0);
            selectedIdx = false(n, 1);

            % Greedy niche selection
            for k = 1:M
                if k == 1
                    % Select first solution randomly
                    idx = randi(n);
                else
                    % Select solution with maximum distance to already selected
                    minDistances = inf(n, 1);

                    for i = 1:n
                        if ~selectedIdx(i)
                            % Find minimum distance to already selected solutions
                            for j = 1:n
                                if selectedIdx(j)
                                    dist = norm(normObjectives(i, :) - normObjectives(j, :));
                                    minDistances(i) = min(minDistances(i), dist);
                                end
                            end
                        end
                    end

                    % Select solution with maximum minimum distance
                    [~, idx] = max(minDistances);
                end

                selected(k) = population(idx);
                selectedIdx(idx) = true;
            end
        end

        function selected = hybridSelection(population, M)
            % Hybrid selection combining crowding distance and niche diversity
            n = length(population);

            if n <= M
                selected = population;
                return;
            end

            % Extract objectives
            objectives = zeros(n, 3);
            for i = 1:n
                objectives(i, :) = population(i).objectives;
            end

            % Non-dominated sorting
            [fronts, ~] = nonDominatedSorting(objectives);

            selected = Solution.empty(M, 0);
            count = 0;

            % Select from fronts in order
            for f = 1:length(fronts)
                front = fronts{f};
                frontSize = length(front);

                if count + frontSize <= M
                    % Take entire front
                    for idx = front
                        count = count + 1;
                        selected(count) = population(idx);
                    end
                else
                    % Need to select from this front
                    remaining = M - count;

                    if frontSize <= remaining
                        % Take all from this front
                        for idx = front
                            count = count + 1;
                            selected(count) = population(idx);
                        end
                    else
                        % Use hybrid selection within this front
                        frontObjectives = objectives(front, :);

                        % Compute crowding distance
                        crowdingDist = computeCrowdingDistance(frontObjectives);

                        % Compute niche scores
                        nicheScores = computeNicheScores(frontObjectives);

                        % Combine scores (weighted sum)
                        alpha = 0.6; % Weight for crowding distance
                        combinedScores = alpha * crowdingDist + (1 - alpha) * nicheScores;

                        % Sort by combined score (descending)
                        [~, sortIdx] = sort(combinedScores, 'descend');
                        sortedFront = front(sortIdx);

                        % Select top solutions
                        for i = 1:remaining
                            if i <= length(sortedFront)
                                count = count + 1;
                                selected(count) = population(sortedFront(i));
                            end
                        end
                    end
                    break;
                end

                if count >= M
                    break;
                end
            end

            % Trim to exact size
            selected = selected(1:min(count, M));
        end

        function crowdingDist = computeCrowdingDistance(objectives)
            % Compute crowding distance for a set of objectives
            n = size(objectives, 1);
            numObj = size(objectives, 2);

            crowdingDist = inf(n, 1);

            % For each objective dimension
            for m = 1:numObj
                % Sort by objective m
                [~, sortIdx] = sort(objectives(:, m));
                sortedObj = objectives(sortIdx, m);

                % Boundary solutions get infinite distance
                crowdingDist(sortIdx(1)) = inf;
                crowdingDist(sortIdx(end)) = inf;

                % Interior solutions
                objRange = sortedObj(end) - sortedObj(1);
                if objRange > 0
                    for i = 2:(n-1)
                        if crowdingDist(sortIdx(i)) == inf
                            continue; % Skip boundary solutions
                        end
                        distance = (sortedObj(i+1) - sortedObj(i-1)) / objRange;
                        crowdingDist(sortIdx(i)) = crowdingDist(sortIdx(i)) + distance;
                    end
                end
            end
        end

        function nicheScores = computeNicheScores(objectives)
            % Compute niche scores based on distance to k-nearest neighbors
            n = size(objectives, 1);
            k = min(3, n - 1); % Number of neighbors

            nicheScores = zeros(n, 1);

            for i = 1:n
                distances = zeros(n, 1);
                for j = 1:n
                    if i ~= j
                        distances(j) = norm(objectives(i, :) - objectives(j, :));
                    else
                        distances(j) = inf;
                    end
                end

                % Average distance to k nearest neighbors
                sortedDist = sort(distances);
                nicheScores(i) = mean(sortedDist(1:k));
            end
        end

        function [fronts, ranks] = nonDominatedSorting(objectives)
            % Non-dominated sorting
            n = size(objectives, 1);
            dominated = false(n, 1);
            ranks = inf(n, 1);

            fronts = {};
            currentFront = [];

            % Find first front (non-dominated solutions)
            for i = 1:n
                isDominated = false;
                for j = 1:n
                    if i ~= j && dominates(objectives(j, :), objectives(i, :))
                        isDominated = true;
                        break;
                    end
                end

                if ~isDominated
                    ranks(i) = 1;
                    currentFront = [currentFront, i];
                end
            end

            fronts{1} = currentFront;

            % Find subsequent fronts (simplified for diversity selection)
            remaining = setdiff(1:n, currentFront);
            frontRank = 2;

            while ~isempty(remaining)
                nextFront = [];
                for i = remaining
                    isDominated = false;
                    for j = currentFront
                        if dominates(objectives(j, :), objectives(i, :))
                            isDominated = true;
                            break;
                        end
                    end

                    if ~isDominated
                        ranks(i) = frontRank;
                        nextFront = [nextFront, i];
                    end
                end

                if isempty(nextFront)
                    break;
                end

                fronts{frontRank} = nextFront;
                currentFront = [currentFront, nextFront];
                remaining = setdiff(remaining, nextFront);
                frontRank = frontRank + 1;
            end
        end

        function isDominated = dominates(objA, objB)
            % Check if objA dominates objB
            % objA dominates objB if objA is better or equal in all objectives
            % and strictly better in at least one objective

            allBetterOrEqual = all(objA <= objB);
            atLeastOneBetter = any(objA < objB);

            isDominated = allBetterOrEqual && atLeastOneBetter;
        end
    end
end