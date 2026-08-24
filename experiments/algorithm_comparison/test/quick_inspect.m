% Quick script to inspect comparison results
% Run this in the experiments/algorithm_comparison directory

clear; clc;

resultsDir = 'experiments/results';
files = dir(fullfile(resultsDir, 'comparison_results_*.mat'));

if isempty(files)
    error('No comparison results files found');
end

% Get the latest file
[~, idx] = sort({files.date}, 'descend');
latestFile = files(idx(1)).name;
fprintf('Loading: %s\n', latestFile);

load(fullfile(resultsDir, latestFile), 'results');

runKeys = fieldnames(results.runs);
fprintf('\nTotal runs: %d\n\n', length(runKeys));

for k = 1:min(10, length(runKeys))  % Show first 10 runs
    key = runKeys{k};
    run = results.runs.(key);

    fprintf('--- Run: %s ---\n', key);
    fprintf('  Algorithm: %s\n', run.algorithm);
    fprintf('  Dataset: %s\n', run.dataset);
    fprintf('  Scenario: %s\n', run.scenarioType);

    if isfield(run, 'hypervolume')
        fprintf('  HV (saved): %.4e\n', run.hypervolume);
    end

    if isfield(run, 'globalFront')
        gf = run.globalFront;
        fprintf('  GlobalFront length: %d\n', length(gf));
        if length(gf) > 0 && isobject(gf) && isfield(gf(1), 'objectives')
            objs = zeros(length(gf), 3);
            for j = 1:length(gf)
                objs(j, :) = gf(j).objectives;
            end
            fprintf('  Objectives - Min: [%.2f, %.2f, %.2f]\n', min(objs));
            fprintf('  Objectives - Max: [%.2f, %.2f, %.2f]\n', max(objs));
            fprintf('  Objectives - Mean: [%.2f, %.2f, %.2f]\n', mean(objs, 1));
        end
    end

    if isfield(run, 'globalFrontObjectives')
        objs = run.globalFrontObjectives;
        if ~isempty(objs)
            fprintf('  globalFrontObjectives size: %d x %d\n', size(objs, 1), size(objs, 2));
            fprintf('  Objectives - Min: [%.2f, %.2f, %.2f]\n', min(objs));
            fprintf('  Objectives - Max: [%.2f, %.2f, %.2f]\n', max(objs));
        else
            fprintf('  globalFrontObjectives: EMPTY\n');
        end
    end

    fprintf('\n');
end