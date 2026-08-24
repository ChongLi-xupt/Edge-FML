% Inspect comparison results for negative energy (Objective 2) values
resDir = fullfile(pwd, 'experiments', 'results');
files = dir(fullfile(resDir, 'comparison_results_*.mat'));
if isempty(files)
    error('No comparison result files found in %s', resDir);
end
[~, idx] = max([files.datenum]); fname = fullfile(resDir, files(idx).name);
fprintf('Loading: %s\n', fname);
S = load(fname, 'results'); results = S.results;

runKeys = fieldnames(results.runs);
negEntries = [];
for i = 1:length(runKeys)
    key = runKeys{i};
    run = results.runs.(key);
    if isfield(run, 'globalFrontObjectives') && ~isempty(run.globalFrontObjectives)
        objs = run.globalFrontObjectives;
        % check second column
        negMask = objs(:,2) < 0;
        if any(negMask)
            rows = find(negMask);
            for r = 1:length(rows)
                negEntries(end+1).runKey = key; %#ok<SAGROW>
                negEntries(end).algorithm = run.algorithm;
                negEntries(end).dataset = run.dataset;
                negEntries(end).scenario = run.scenarioType;
                negEntries(end).index = rows(r);
                negEntries(end).objective = objs(rows(r), :);
            end
        end
    end
end

if isempty(negEntries)
    fprintf('No negative energy values found in globalFrontObjectives.\n');
else
    fprintf('Found %d negative energy entries:\n', length(negEntries));
    for i = 1:length(negEntries)
        e = negEntries(i);
        fprintf('Run: %s | Alg: %s | Dataset: %s | Scenario: %s | Index: %d | Obj: [%.6g, %.6g, %.6g]\n', ...
            e.runKey, e.algorithm, e.dataset, e.scenario, e.index, e.objective(1), e.objective(2), e.objective(3));
    end
end
