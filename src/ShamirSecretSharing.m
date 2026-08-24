classdef ShamirSecretSharing
    % ShamirSecretSharing - Adaptive Threshold Shamir Secret Sharing (AT-SSS)
    % Implements privacy-preserving knowledge sharing (Section 3.2)
    %
    % Author: 拓守恒 (Shouheng Tuo)
    % Email: shouheng.tuo@example.com
    % Date: 2025-12-01
    % Reference: FML.MD - Adaptive Threshold Secret Sharing Protocol

    properties
        prime             % Large prime for finite field operations
        scaleFactor       % Scale factor for continuous variables
        mode              % Mode (e.g., 'adaptive' or 'fixed')
    end

    methods
        function obj = ShamirSecretSharing(varargin)
            % Constructor with optional mode: ShamirSecretSharing() or ShamirSecretSharing('fixed')
            obj.prime = 2^31 - 1;  % Mersenne prime
            obj.scaleFactor = 1e6;  % Scale factor for continuous->integer conversion
            obj.mode = 'adaptive';

            if ~isempty(varargin)
                arg1 = varargin{1};
                if ischar(arg1) || isstring(arg1)
                    obj.mode = char(arg1);
                end
            end
        end

        function shares = split(obj, secret, n, t)
            % Split secret into n shares with threshold t
            % secret: scalar or vector
            % n: number of shares
            % t: threshold (need t shares to reconstruct)
            % Returns: n x length(secret) matrix of shares

            secretVec = secret(:)';  % Ensure row vector
            secretLen = length(secretVec);

            % Convert continuous values to integers
            secretInt = round(secretVec * obj.scaleFactor);
            secretInt = mod(secretInt, obj.prime);  % Ensure in field

            shares = zeros(n, secretLen);

            for idx = 1:secretLen
                s = secretInt(idx);

                % Generate random polynomial coefficients [a0=s, a1, ..., a_{t-1}]
                coeffs = [s, randi([0, obj.prime-1], 1, t-1)];

                % Evaluate polynomial at points 1, 2, ..., n
                for i = 1:n
                    shares(i, idx) = obj.evaluatePolynomial(coeffs, i);
                end
            end
        end

        function secret = reconstruct(obj, shares, indices)
            % Reconstruct secret from shares
            % shares: k x length(secret) matrix (k >= t)
            % indices: indices of shares (e.g., [1,3,5])
            % Returns: reconstructed secret vector

            k = size(shares, 1);
            secretLen = size(shares, 2);

            if k < 2
                error('Need at least 2 shares to reconstruct');
            end

            secretInt = zeros(1, secretLen);

            for idx = 1:secretLen
                % Lagrange interpolation to find a0 (secret)
                secretInt(idx) = obj.lagrangeInterpolation(shares(:, idx), indices, 0);
            end

            % Convert back to continuous values
            secretInt = mod(secretInt, obj.prime);
            secret = double(secretInt) / obj.scaleFactor;
        end

        function y = evaluatePolynomial(obj, coeffs, x)
            % Evaluate polynomial at point x in finite field
            % coeffs: [a0, a1, ..., a_{t-1}]
            % Returns: y = sum(a_i * x^i) mod prime

            y = 0;
            for i = 1:length(coeffs)
                term = mod(coeffs(i) * obj.modPower(x, i-1), obj.prime);
                y = mod(y + term, obj.prime);
            end
        end

        function result = lagrangeInterpolation(obj, yValues, xIndices, x0)
            % Lagrange interpolation to find f(x0)
            % yValues: function values at xIndices
            % xIndices: x coordinates
            % x0: point to evaluate (typically 0 for secret)

            k = length(yValues);
            result = 0;

            for i = 1:k
                xi = xIndices(i);
                yi = yValues(i);

                % Compute Lagrange basis polynomial L_i(x0)
                numerator = 1;
                denominator = 1;

                for j = 1:k
                    if i ~= j
                        xj = xIndices(j);
                        numerator = mod(numerator * (x0 - xj), obj.prime);
                        denominator = mod(denominator * (xi - xj), obj.prime);
                    end
                end

                % Compute modular inverse of denominator
                denomInv = obj.modInverse(denominator);

                % Add contribution
                basis = mod(numerator * denomInv, obj.prime);
                term = mod(yi * basis, obj.prime);
                result = mod(result + term, obj.prime);
            end
        end

        function result = modPower(obj, base, exp)
            % Compute base^exp mod prime efficiently
            result = 1;
            base = mod(base, obj.prime);

            while exp > 0
                if mod(exp, 2) == 1
                    result = mod(result * base, obj.prime);
                end
                exp = floor(exp / 2);
                base = mod(base * base, obj.prime);
            end
        end

        function result = modInverse(obj, a)
            % Compute modular multiplicative inverse using extended Euclidean algorithm
            % Returns: a^(-1) mod prime

            a = mod(a, obj.prime);
            if a == 0
                error('Cannot compute inverse of 0');
            end

            % Extended Euclidean algorithm
            [g, x, ~] = obj.extendedGCD(a, obj.prime);

            if g ~= 1
                error('Modular inverse does not exist');
            end

            result = mod(x, obj.prime);
        end

        function [g, x, y] = extendedGCD(~, a, b)
            % Extended Euclidean algorithm
            % Returns: g = gcd(a,b), and x,y such that ax + by = g

            if b == 0
                g = a;
                x = 1;
                y = 0;
                return;
            end

            x2 = 1; x1 = 0;
            y2 = 0; y1 = 1;

            while b > 0
                q = floor(a / b);
                r = a - q * b;
                x = x2 - q * x1;
                y = y2 - q * y1;

                a = b;
                b = r;
                x2 = x1; x1 = x;
                y2 = y1; y1 = y;
            end

            g = a;
            x = x2;
            y = y2;
        end

        function encShares = encryptSolution(obj, sol, n, t)
            % Encrypt a solution using SSS
            % Returns: struct with encrypted decision variables

            % Extract solution variables as vectors
            x_vec = double(sol.x_offload(:)');
            y_vec = double(sol.y_cache(:)');
            f_vec = sol.f_resource(:)';
            z_vec = double(sol.z_security(:)');

            % Split each variable type
            encShares.x_shares = obj.split(x_vec, n, t);
            encShares.y_shares = obj.split(y_vec, n, t);
            encShares.f_shares = obj.split(f_vec, n, t);
            encShares.z_shares = obj.split(z_vec, n, t);
        end

        function sol = decryptSolution(obj, encShares, indices, K, T)
            % Decrypt solution from shares
            % K: number of devices, T: number of task types

            % Reconstruct variables
            x_vec = obj.reconstruct(encShares.x_shares(indices, :), indices);
            y_vec = obj.reconstruct(encShares.y_shares(indices, :), indices);
            f_vec = obj.reconstruct(encShares.f_shares(indices, :), indices);
            z_vec = obj.reconstruct(encShares.z_shares(indices, :), indices);

            % Create solution object
            sol = Solution(K, T);
            sol.x_offload = round(x_vec(:));
            sol.y_cache = round(y_vec(:));
            sol.f_resource = f_vec(:);
            sol.z_security = round(z_vec(:));

            % Ensure valid ranges
            sol.x_offload = max(0, min(1, sol.x_offload));
            sol.y_cache = max(0, min(1, sol.y_cache));
            sol.f_resource = max(0.1, min(1.0, sol.f_resource));
            sol.z_security = max(1, min(4, sol.z_security));
        end
    end
end
