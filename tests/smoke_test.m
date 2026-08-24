% smoke_test.m - minimal smoke test for Edge-FML
% Verifies the core pipeline (scenario generation -> framework init -> run)
% and records PASSED/FAILED to tests/smoke_test_result.txt.
%
% Usage:
%   >> run('tests/smoke_test.m')   % from the project root

try
    addpath('src');

    % 1. Generate a small scenario
    dataGen = SimulationDataGenerator();
    [regions, taskSets] = dataGen.generateScenario(4, 'homogeneous');
    assert(numel(regions) == 4, 'Scenario generation failed: expected 4 regions');

    % 2. Initialize the framework
    edgeFML = EdgeFML(regions, taskSets, 3, 5);   % R_max=3, M_local=5
    assert(~isempty(edgeFML), 'Framework initialization failed');

    % 3. Run a short federated optimization
    edgeFML = edgeFML.run();
    assert(~isempty(edgeFML.globalElites) || ~isempty(edgeFML.roundHistory), ...
        'Optimization produced no output');

    fprintf('SMOKE TEST: PASSED\n');
    fid = fopen('tests/smoke_test_result.txt', 'w');
    if fid > 0
        fprintf(fid, 'PASSED\n');
        fclose(fid);
    end

catch ME
    fprintf('SMOKE TEST: FAILED - %s\n', ME.message);
    fid = fopen('tests/smoke_test_result.txt', 'w');
    if fid > 0
        fprintf(fid, 'FAILED: %s\n', ME.message);
        fclose(fid);
    end
    rethrow(ME);
end
