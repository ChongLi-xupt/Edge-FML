% Generate aggregated 3D Pareto figure excluding Centralized algorithms

resDir = fullfile(pwd, 'experiments', 'results');
files = dir(fullfile(resDir, 'comparison_results_*.mat'));
if isempty(files), error('No comparison result files found in %s', resDir); end
[~, idx] = max([files.datenum]); fname = fullfile(resDir, files(idx).name);
fprintf('Loading results from: %s\n', fname);
S = load(fname, 'results'); results = S.results;

% Exclude centralized runs
excludePatterns = {'Centralized', 'Centralized-MTDMS'};

% Build alg list excluding patterns
runNames = fieldnames(results.runs);
algSet = containers.Map(); algList = {};
for k = 1:length(runNames)
    r = results.runs.(runNames{k});
    if ~isfield(r, 'algorithm'), continue; end
    alg = r.algorithm;
    if any(contains(alg, excludePatterns)), continue; end
    if ~isKey(algSet, alg)
        algSet(alg) = true;
        algList{end+1} = alg;
    end
end

if isempty(algList)
    error('No algorithms found after excluding centralized');
end

% Collect all points per algorithm for the given dataset/scenario combinations
% Here we aggregate across all datasets/scenarios
algPoints = containers.Map();
for ai = 1:length(algList)
    alg = algList{ai};
    pts = [];
    for k = 1:length(runNames)
        r = results.runs.(runNames{k});
        if strcmp(r.algorithm, alg)
            if isfield(r, 'globalFrontObjectives') && ~isempty(r.globalFrontObjectives)
                pts = [pts; r.globalFrontObjectives];
            end
        end
    end
    if isempty(pts), continue; end
    pts = unique(pts, 'rows');
    algPoints(alg) = pts;
end

if isempty(keys(algPoints)), error('No objective points found'); end

% Determine bounds
allPts = [];
keysA = keys(algPoints);
for i = 1:length(keysA)
    allPts = [allPts; algPoints(keysA{i})];
end
mins = min(allPts, [], 1);
maxs = max(allPts, [], 1);
spans = maxs - mins;
margins = max(1, 0.05 .* spans);
xL = [mins(1)-margins(1), maxs(1)+margins(1)];
yL = [mins(2)-margins(2), maxs(2)+margins(2)];
zL = [mins(3)-margins(3), maxs(3)+margins(3)];

% Plot aggregated 3D
fig = figure('Visible','off','Position',[200 200 1400 1000]);
hold on; grid on; box on;
colorsAgg = lines(length(keysA));
markersAgg = {'o','s','^','d','v','p','h','>','<','x','+','*'};
legendEntries = {};
for ai = 1:length(keysA)
    alg = keysA{ai};
    pts = algPoints(alg);
    if isempty(pts), continue; end
    m = markersAgg{mod(ai-1, length(markersAgg)) + 1};
    c = colorsAgg(ai, :);
    sz = 80;
    scatter3(pts(:,1), pts(:,2), pts(:,3), sz, m, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', c, 'LineWidth', 0.9, 'MarkerFaceAlpha', 0.9);
    legendEntries{end+1} = alg;
end
xlabel('Latency'); ylabel('Energy'); zlabel('Security Risk');
title('Aggregated Pareto Fronts (no Centralized)');
set(gca, 'FontSize', 12);
xlim(xL); ylim(yL); zlim(zL);
legend(legendEntries, 'Location', 'bestoutside');

outDir = fullfile(pwd, 'experiments', 'figures'); if ~exist(outDir,'dir'), mkdir(outDir); end
outFile = fullfile(outDir, 'pareto_fronts_aggregated_nocentralized.png');
print(fig, outFile, '-dpng', '-r300');
close(fig);
fprintf('Saved aggregated pareto figure (no Centralized): %s\n', outFile);
