ref2 = [1000, 1000];
front2 = [200, 300; 400, 200];
pm2 = PerformanceMetrics(ref2);
hv2 = pm2.computeHypervolume(buildSolutions(front2));
expected2 = 620000;
assert(abs(hv2 - expected2) < 1e-6);

ref3 = [1000, 1000, 1000];
front3 = [200, 300, 400; 400, 200, 300];
pm3 = PerformanceMetrics(ref3);
hv3 = pm3.computeHypervolume(buildSolutions(front3));
expected3 = 420000000;
assert(abs(hv3 - expected3) < 1e-6);

function sols = buildSolutions(objs)
    n = size(objs, 1);
    sols = repmat(Solution(1, 1), n, 1);
    for i = 1:n
        sols(i).objectives = objs(i, :);
        sols(i).constraintViolation = 0;
    end
end
