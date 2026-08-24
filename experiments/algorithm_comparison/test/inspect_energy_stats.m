% Inspect energy (Objective2) stats across runs
resDir = fullfile(pwd, 'experiments', 'results');
files = dir(fullfile(resDir, 'comparison_results_*.mat'));
if isempty(files), error('No comparison result files found in %s', resDir); end
[~, idx] = max([files.datenum]); fname = fullfile(resDir, files(idx).name);
fprintf('Loading: %s\n', fname);
S = load(fname, 'results'); results = S.results;

runKeys = fieldnames(results.runs);
summary = struct();
negRuns = {};

for i = 1:length(runKeys)
    key = runKeys{i};
    run = results.runs.(key);
    energyVals = [];
    if isfield(run, 'globalFrontObjectives') && ~isempty(run.globalFrontObjectives)
        energyVals = run.globalFrontObjectives(:,2);
    end
    if isempty(energyVals)
        summary.(key) = struct('algorithm', run.algorithm, 'n', 0, 'min', NaN, 'mean', NaN, 'max', NaN);
        continue;
    end
    summary.(key) = struct('algorithm', run.algorithm, 'n', length(energyVals), 'min', min(energyVals), 'mean', mean(energyVals), 'max', max(energyVals));
    if any(energyVals < 0)
        negRuns{end+1} = key; %#ok<SAGROW>
    end
end

% Print summary table grouped by algorithm
algNames = unique(cellfun(@(k) results.runs.(k).algorithm, runKeys, 'UniformOutput', false));
fprintf('\nPer-run Objective2 (Energy) summary:\n');
fprintf('%-50s %-20s %-8s %-12s %-12s %-12s\n','RunKey','Algorithm','N','Min','Mean','Max');
for i=1:length(runKeys)
    k = runKeys{i}; s = summary.(k);
    fprintf('%-50s %-20s %-8d %-12.6g %-12.6g %-12.6g\n', k, s.algorithm, s.n, s.min, s.mean, s.max);
end

if isempty(negRuns)
    fprintf('\nNo runs contain negative Objective2 values.\n');
else
    fprintf('\nRuns with negative Objective2 found:\n');
    disp(negRuns(:));
end

% Save summary CSV
out = fullfile(pwd, 'experiments', 'figures', 'energy_summary_per_run.csv');
keysAll = runKeys;
T = table(keysAll(:), cellfun(@(k) summary.(k).algorithm, keysAll, 'UniformOutput', false)', ...
    cellfun(@(k) summary.(k).n, keysAll)', cellfun(@(k) summary.(k).min, keysAll)', ...
    cellfun(@(k) summary.(k).mean, keysAll)', cellfun(@(k) summary.(k).max, keysAll)', ...
    'VariableNames', {'runKey','algorithm','n','min_Energy','mean_Energy','max_Energy'});
if ~exist(fileparts(out),'dir'), mkdir(fileparts(out)); end
writetable(T, out);
fprintf('\nSaved energy summary to: %s\n', out);
