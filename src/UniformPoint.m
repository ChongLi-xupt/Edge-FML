function [W, N] = UniformPoint(N, M)
if M == 1
    W = ones(N,1);
    N = size(W,1);
    return;
end
H1 = 1;
while nchoosek(H1+M-1,M-1) <= N
    H1 = H1 + 1;
end
H1 = H1 - 1;
W = [];
if H1 > 0
    A = intCompositions(M, H1);
    W = A / H1;
end
if size(W,1) < N
    H2 = 0;
    while nchoosek(H2+M-1,M-1) < N - size(W,1)
        H2 = H2 + 1;
    end
    if H2 > 0
        A2 = intCompositions(M, H2);
        W2 = A2 / H2;
        W = [W; (W2 + 1/M)/2];
    end
end
W = max(W, 0);
rowSums = sum(W,2);
rowSums(rowSums==0) = 1;
W = W ./ rowSums;
N = size(W,1);

end

function A = intCompositions(M, H)
if M == 1
    A = H;
    return;
end
if H == 0
    A = zeros(1, M);
    return;
end
A = [];
prefix = zeros(1, M);
recurse(1, H, prefix);
    function recurse(pos, remaining, vec)
        if pos == M
            vec(pos) = remaining;
            A(end+1, :) = vec; %#ok<AGROW>
            return;
        end
        for v = 0:remaining
            vec(pos) = v;
            recurse(pos+1, remaining - v, vec);
        end
    end
end
