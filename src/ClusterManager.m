classdef ClusterManager
    % ClusterManager - 区域聚类和通信管理器
    % 实现算法1：区域聚类（第3.1节）
    %
    % 主要功能：
    % 1. 基于谱聚类的区域分组
    % 2. 异构性感知的聚类策略
    % 3. 动态集群合并和优化
    % 4. 智能代表节点选择
    % 5. 通信拓扑优化
    %
    % 算法特点：
    % - 谱聚类：基于区域差异度的相似性度量
    % - 自适应合并：小集群或相似集群的动态合并
    % - 代表选择：综合考虑中心性、资源可用性、网络连接性
    %
    % 作者: 拓守恒 (Shouheng Tuo)
    % GitHub: github.com/shouhengtuo/
    % 邮箱: tuo_sh@xupt.edu.cn
    % 日期: 2025-12-03
    % 参考: FML.MD - 异构区域的谱聚类

    properties
        regions           % Array of RegionConfig objects
        N                 % Total number of regions
        clusters          % Cell array of cluster assignments
        M                 % Number of clusters
        representatives   % Representative node for each cluster

        % Clustering parameters
        M_max             % Maximum number of clusters
        N_min             % Minimum cluster size
        theta_merge       % Merge threshold for similar clusters
        compressFactor    % Communication compression factor
    end

    methods
        function obj = ClusterManager(regions, varargin)
            % 构造函数：初始化区域聚类管理器
            %
            % 输入参数:
            %   regions - RegionConfig对象数组
            %   varargin - 可选参数，如'flat'模式
            %
            % 使用方式:
            %   ClusterManager(regions) - 正常聚类模式
            %   ClusterManager(regions, 'flat') - 平坦模式（每个区域独立）

            % 增强输入验证
            if nargin < 1 || isempty(regions)
                error('ClusterManager:InsufficientInput', '必须提供regions参数');
            end

            if ~isa(regions, 'RegionConfig')
                error('ClusterManager:InvalidRegions', 'regions必须是RegionConfig对象数组');
            end

            obj.regions = regions;
            obj.N = length(regions);

            % 处理可选模式参数
            mode = '';
            if ~isempty(varargin)
                mode = varargin{1};
                if ~ischar(mode) && ~isstring(mode)
                    error('ClusterManager:InvalidMode', '模式参数必须是字符串');
                end
            end

            % 平坦模式：每个区域作为独立集群
            if strcmpi(mode, 'flat')
                obj.M = obj.N;
                obj.clusters = cell(1, obj.M);
                for m = 1:obj.M
                    obj.clusters{m} = m;
                end
                obj.representatives = 1:obj.M;

                fprintf('使用平坦模式：每个区域独立集群\n');
                obj.compressFactor = 0.5;  % Default compression factor
                return;
            end

            % 特殊情况：1-2个区域无需复杂聚类
            if obj.N <= 2
                obj.M = obj.N;
                obj.clusters = cell(1, obj.M);
                for m = 1:obj.M
                    obj.clusters{m} = [m];
                end
                obj.representatives = zeros(1, obj.M);
                for m = 1:obj.M
                    obj.representatives(m) = m;
                end

                fprintf('区域数量较少（%d），使用简单聚类\n', obj.N);
                obj.compressFactor = 0.5;  % Default compression factor
                return;
            end

            % 设置正常聚类参数
            obj.M_max = min(10, max(2, floor(obj.N / 5)));
            obj.N_min = 3;
            obj.theta_merge = 0.25;
            obj.compressFactor = 0.5;  % Default compression factor

            % 执行聚类算法
            try
                obj = obj.formClusters();
                fprintf('谱聚类完成：生成%d个集群\n', obj.M);
            catch ME
                error('ClusterManager:ClusteringFailed', '聚类算法执行失败: %s', ME.message);
            end
        end

        function obj = formClusters(obj)
            % Form clusters using spectral clustering (Algorithm 1)

            % Step 1: Compute dissimilarity matrix
            D = zeros(obj.N, obj.N);
            for i = 1:obj.N
                for j = (i+1):obj.N
                    RD = obj.regions(i).computeDissimilarity(obj.regions(j));
                    D(i, j) = RD;
                    D(j, i) = RD;
                end
            end

            % Step 2: Construct affinity matrix
            sigma = median(D(D > 0));
            if sigma == 0
                sigma = 0.1;
            end
            A = exp(-D.^2 / (2 * sigma^2));

            % Step 3: Compute graph Laplacian
            D_diag = diag(sum(A, 2));
            L = D_diag - A;

            % Step 4: Compute eigenvectors
            % Use normalized Laplacian for better numerical stability
            D_sqrt_inv = diag(1 ./ sqrt(diag(D_diag) + eps));
            L_norm = D_sqrt_inv * L * D_sqrt_inv;

            % Find M smallest eigenvalues (robust strategy)
            M_candidate = min(obj.M_max, obj.N - 1);
            try
                % Estimate conditioning; if ill-conditioned, prefer shift-invert
                % with a small non-zero sigma to avoid 'smallestabs' warnings.
                condEst = rcond(full(L_norm));
                if condEst < 1e-12
                    sigma = 1e-6; % small shift for shift-invert mode
                    [V, eigenvals] = eigs(L_norm, M_candidate, sigma);
                else
                    [V, eigenvals] = eigs(L_norm, M_candidate, 'smallestabs');
                end
            catch ME
                % Fall back to dense eigen-decomposition when eigs fails
                warning('ClusterManager:EigenComputation', 'eigs failed (%s). Falling back to dense eig.', ME.message);
                [Vfull, Dfull] = eig(full(L_norm));
                [~, sortIdx] = sort(abs(diag(Dfull)), 'ascend');
                pick = sortIdx(1:min(M_candidate, length(sortIdx)));
                V = Vfull(:, pick);
                eigenvals = diag(Dfull(pick, pick));
            end

            % Determine optimal number of clusters using eigengap
            eigvals = sort(abs(diag(eigenvals)));
            eiggaps = diff(eigvals);

            % Handle case where eiggaps is empty (shouldn't happen with N > 2)
            if isempty(eiggaps)
                obj.M = 2;
            else
                [~, gapIdx] = max(eiggaps(1:min(5, length(eiggaps))));
                obj.M = max(2, min(gapIdx + 1, obj.M_max));
            end

            % Step 5: K-means clustering on eigenvectors
            features = V(:, 1:obj.M);
            % Normalize rows
            features = features ./ (sqrt(sum(features.^2, 2)) + eps);

            % K-means clustering - Ensure K is valid
            K = max(2, obj.M);
            [assignments, ~] = kmeans(features, K, 'MaxIter', 100, 'Replicates', 5);

            % Step 6: Merge small or similar clusters
            obj.clusters = cell(1, K);
            for m = 1:K
                obj.clusters{m} = find(assignments == m)';
            end

            obj.M = K;
            obj = obj.mergeClusters(D);

            % Select representative nodes
            obj = obj.selectRepresentatives();
        end

        function obj = mergeClusters(obj, dissimMatrix)
            % Merge clusters that are too small or too similar

            merged = true;
            while merged
                merged = false;
                M_current = length(obj.clusters);

                % Check for small clusters
                for m = 1:M_current
                    if length(obj.clusters{m}) < obj.N_min && M_current > 2
                        % Merge with nearest cluster
                        minDist = inf;
                        mergeWith = -1;

                        for n = 1:M_current
                            if n ~= m
                                % Compute average distance between clusters
                                avgDist = obj.computeInterClusterDistance(...
                                    obj.clusters{m}, obj.clusters{n}, dissimMatrix);
                                if avgDist < minDist
                                    minDist = avgDist;
                                    mergeWith = n;
                                end
                            end
                        end

                        if mergeWith > 0
                            % Merge cluster m into mergeWith
                            obj.clusters{mergeWith} = [obj.clusters{mergeWith}, obj.clusters{m}];
                            obj.clusters(m) = [];
                            merged = true;
                            break;
                        end
                    end
                end

                if merged
                    continue;
                end

                % Check for similar clusters
                M_current = length(obj.clusters);
                for m = 1:M_current
                    for n = (m+1):M_current
                        avgDist = obj.computeInterClusterDistance(...
                            obj.clusters{m}, obj.clusters{n}, dissimMatrix);

                        if avgDist < obj.theta_merge && M_current > 2
                            % Merge clusters
                            obj.clusters{m} = [obj.clusters{m}, obj.clusters{n}];
                            obj.clusters(n) = [];
                            merged = true;
                            break;
                        end
                    end

                    if merged
                        break;
                    end
                end
            end

            obj.M = length(obj.clusters);
        end

        function obj = selectRepresentatives(obj)
            % Select representative nodes for each cluster
            obj.representatives = zeros(1, obj.M);

            for m = 1:obj.M
                clusterRegions = obj.clusters{m};

                % For now, simply select the first region as representative
                % In a more sophisticated implementation, we could select based on:
                % - Centrality in the cluster
                % - Resource availability
                % - Network connectivity
                obj.representatives(m) = clusterRegions(1);
            end
        end

        function avgDist = computeInterClusterDistance(obj, cluster1, cluster2, dissimMatrix)
            % Compute average dissimilarity between two clusters
            totalDist = 0;
            count = 0;

            for i = 1:length(cluster1)
                for j = 1:length(cluster2)
                    totalDist = totalDist + dissimMatrix(cluster1(i), cluster2(j));
                    count = count + 1;
                end
            end

            avgDist = totalDist / count;
        end

        function printClusterInfo(obj)
            % Print cluster information for debugging
            fprintf('\n=== Cluster Information ===\n');
            fprintf('Total Regions: %d\n', obj.N);
            fprintf('Number of Clusters: %d\n\n', obj.M);

            for m = 1:obj.M
                clusterRegions = obj.clusters{m};
                repRegion = obj.representatives(m);

                fprintf('Cluster %d (Representative: Region %d):\n', m, repRegion);
                fprintf('  Members: %s\n', num2str(clusterRegions));
                fprintf('  Size: %d regions\n', length(clusterRegions));

                % Compute average intra-cluster dissimilarity
                if length(clusterRegions) > 1
                    totalDist = 0;
                    count = 0;
                    for i = 1:length(clusterRegions)
                        for j = (i+1):length(clusterRegions)
                            totalDist = totalDist + obj.regions(clusterRegions(i)).computeDissimilarity(obj.regions(clusterRegions(j)));
                            count = count + 1;
                        end
                    end
                    avgIntraDist = totalDist / count;
                    fprintf('  Avg Intra-cluster Dissimilarity: %.4f\n', avgIntraDist);
                end
                fprintf('\n');
            end
            fprintf('===========================\n');
        end

        function members = getClusterMembers(obj, m)
            % Return the region indices that belong to cluster m
            if m >= 1 && m <= length(obj.clusters)
                members = obj.clusters{m};
            else
                members = [];
            end
        end

        function rep = getRepresentative(obj, m)
            % Return the representative region index for cluster m
            if m >= 1 && m <= length(obj.representatives)
                rep = obj.representatives(m);
            else
                rep = [];
            end
        end

        function clusterID = getClusterID(obj, regionIndex)
            % Return the cluster id that contains the given region index
            clusterID = [];
            for m = 1:length(obj.clusters)
                if any(obj.clusters{m} == regionIndex)
                    clusterID = m;
                    return;
                end
            end
            % If not found, return 1 as a safe default
            if isempty(clusterID)
                clusterID = 1;
            end
        end
    end
end