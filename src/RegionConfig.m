classdef RegionConfig
    % RegionConfig - Configuration class for edge region
    % Defines heterogeneous characteristics of each edge region
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Edge Region Configuration Model

    properties
        regionID          % Region identifier
        computeCapacity   % F_r: Compute capacity in GHz
        cacheCapacity     % C_r^max: Cache capacity in MB
        numDevices        % K_r: Number of devices
        bandwidth         % B_r: Network bandwidth in Mbps
        latency           % delta_r: Network latency in ms
        riskLevel         % R_r: Security risk level [0,1]
    end

    methods
        function obj = RegionConfig(id, F, C, K, B, delta, R)
            % Constructor
            if nargin > 0
                obj.regionID = id;
                obj.computeCapacity = F;
                obj.cacheCapacity = C;
                obj.numDevices = K;
                obj.bandwidth = B;
                obj.latency = delta;
                obj.riskLevel = R;
            end
        end

        function RD = computeDissimilarity(obj, other)
            % Compute region dissimilarity (Eq. 2.4)
            % RD(r,l) = 1/4 * sum of relative differences

            term1 = abs(obj.computeCapacity - other.computeCapacity) / ...
                    (obj.computeCapacity + other.computeCapacity);
            term2 = abs(obj.cacheCapacity - other.cacheCapacity) / ...
                    (obj.cacheCapacity + other.cacheCapacity);
            term3 = abs(obj.numDevices - other.numDevices) / ...
                    (obj.numDevices + other.numDevices);
            term4 = abs(obj.bandwidth - other.bandwidth) / ...
                    (obj.bandwidth + other.bandwidth);

            RD = 0.25 * (term1 + term2 + term3 + term4);
        end

        function alpha = getSecurityCoefficient(obj, R_min, R_max)
            % Compute adaptive threshold coefficient for AT-SSS
            % alpha = 0.5 + 0.4 * (R_r - R_min) / (R_max - R_min)

            if R_max > R_min
                alpha = 0.5 + 0.4 * (obj.riskLevel - R_min) / (R_max - R_min);
            else
                alpha = 0.5;
            end
            alpha = max(0.5, min(0.9, alpha));
        end
    end
end
