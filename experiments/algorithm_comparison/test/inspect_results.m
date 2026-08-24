% Inspect recent comparison result files and print summaries
% Use results directory under this script folder: <repo>/experiments/algorithm_comparison/experiments/results
resDir = fullfile(pwd, 'experiments', 'results');
files = {
    fullfile(resDir, 'comparison_results_2025-12-28_17-39-58.mat'), ... % FedAvg run
    fullfile(resDir, 'comparison_results_2025-12-28_17-49-56.mat')  ... % Centralized run
};
for f = 1:length(files)
    fname = files{f};
    if ~exist(fname, 'file')
        fprintf('File not found: %s\n', fname);
        continue;
    end
    fprintf('\n--- Inspecting %s ---\n', fname);
    S = load(fname, 'results');
    if ~isfield(S, 'results')
        fprintf('No ''results'' struct in %s\n', fname);
        continue;
    end
    results = S.results;
    runNames = fieldnames(results.runs);
    for i = 1:length(runNames)
        key = runNames{i};
        run = results.runs.(key);
        fprintf('\nRun key: %s\n', key);
            % Print basic known fields if present
            if isfield(run, 'algorithm'), fprintf(' Algorithm: %s\n', run.algorithm); end
            if isfield(run, 'dataset'), fprintf(' Dataset: %s\n', run.dataset); end
            if isfield(run, 'scenarioType'), fprintf(' Scenario: %s\n', run.scenarioType); end
            if isfield(run, 'elapsedTime'), fprintf(' Time (s): %.2f\n', run.elapsedTime); end
            if isfield(run, 'hv'), fprintf(' HV (hv): %g\n', run.hv); end
            if isfield(run, 'hypervolume'), fprintf(' HV (hypervolume): %g\n', run.hypervolume); end
            if isfield(run, 'feasibilityRate'), fprintf(' FeasibilityRate: %.2f%%\n', run.feasibilityRate); end
            if isfield(run, 'feasRate'), fprintf(' FeasRate (feasRate): %.2f%%\n', run.feasRate); end
            if isfield(run, 'diversity'), fprintf(' Diversity: %g\n', run.diversity); end
            % List all stored fields for debugging
            fn = fieldnames(run);
            fprintf(' Stored fields: %s\n', strjoin(fn', ', '));
        if isfield(run, 'globalFront'),
            gf = run.globalFront;
            fprintf(' GlobalFront length: %d\n', length(gf));
            if length(gf) > 0 && isfield(gf(1), 'objectives')
                % collect objectives matrix
                objs = zeros(length(gf), 3);
                for j = 1:length(gf)
                    objs(j, :) = gf(j).objectives;
                end
                % print first 5
                nPrint = min(5, size(objs,1));
                fprintf(' First %d objective rows:\n', nPrint);
                disp(objs(1:nPrint, :));
            end
        elseif isfield(run, 'globalFrontObjectives')
            objs = run.globalFrontObjectives;
            fprintf(' globalFrontObjectives size: %s\n', mat2str(size(objs)));
            nPrint = min(5, size(objs,1));
            disp(objs(1:nPrint, :));
        end

            % Also check globalFrontObjectives explicitly if present (even when globalFront exists but is empty)
            if isfield(run, 'globalFrontObjectives')
                objsGF = run.globalFrontObjectives;
                if ~isempty(objsGF)
                    fprintf(' globalFrontObjectives present, size: %s\n', mat2str(size(objsGF)));
                    nPrint = min(5, size(objsGF,1));
                    disp(objsGF(1:nPrint, :));
                    % Compute basic statistics per objective
                    mins = min(objsGF, [], 1);
                    maxs = max(objsGF, [], 1);
                    means = mean(objsGF, 1);
                    meds = median(objsGF, 1);
                    fprintf(' Objective stats (min | mean | median | max) per column:\n');
                    for c = 1:size(objsGF,2)
                        fprintf('  Obj%d: %.4f | %.4f | %.4f | %.4f\n', c, mins(c), means(c), meds(c), maxs(c));
                    end
                else
                    fprintf(' globalFrontObjectives is empty.\n');
                end
            end
    end
end
fprintf('\nInspection complete.\n');
