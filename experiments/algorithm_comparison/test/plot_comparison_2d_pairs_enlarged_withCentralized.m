% Enlarged 2D pairwise plots for top-K (=20) per algorithm (WITH Centralized)
% Same as plot_comparison_2d_pairs_enlarged.m but does not filter Centralized runs

K = 20;
resDir = fullfile(pwd, 'experiments', 'results');
files = dir(fullfile(resDir, 'comparison_results_*.mat'));
if isempty(files), error('No comparison result files found in %s', resDir); end
[~, idx] = max([files.datenum]); fname = fullfile(resDir, files(idx).name);
fprintf('Loading results from: %s\n', fname);
S = load(fname, 'results'); results = S.results;

% Group runs by algorithm (include all)
runNames = fieldnames(results.runs);
algMap = containers.Map(); algList = {};
for i = 1:length(runNames)
    r = results.runs.(runNames{i});
    if ~isfield(r, 'algorithm'), continue; end
    alg = r.algorithm;
    if ~isKey(algMap, alg)
        algMap(alg) = {};
        algList{end+1} = alg;
    end
    arr = algMap(alg); arr{end+1} = r; algMap(alg) = arr;
end

% Collect points per algorithm
algPoints = containers.Map();
for ai = 1:length(algList)
    alg = algList{ai}; arr = algMap(alg);
    pts = [];
    for k = 1:length(arr)
        if isfield(arr{k}, 'globalFrontObjectives')
            pts = [pts; arr{k}.globalFrontObjectives];
        end
    end
    if isempty(pts), continue; end
    pts = unique(pts, 'rows');
    algPoints(alg) = pts;
end

if isempty(keys(algPoints)), error('No objective points found'); end

% Determine global normalization for scoring
allPts = [];
algKeys = keys(algPoints);
for i = 1:length(algKeys)
    allPts = [allPts; algPoints(algKeys{i})];
end
maxVals = max(allPts, [], 1);
minVals = min(allPts, [], 1);

% markers and colors
markers = {'o','s','^','d','v','p','h','>','<','x','+'};
colors = lines(length(algKeys));

% select top-K per algorithm by normalized sum (lower better)
topKMap = containers.Map();
for ai = 1:length(algKeys)
    alg = algKeys{ai}; pts = algPoints(alg);
    if isempty(pts), continue; end
    denom = maxVals - minVals; denom(denom==0)=1;
    normed = (pts - minVals) ./ denom;
    scores = sum(normed, 2);
    [~, order] = sort(scores, 'ascend');
    topIdx = order(1:min(K, length(order)));
    topPts = pts(topIdx, :);
    topKMap(alg) = topPts;
end

% Create enlarged figure (one row, three large subplots)
fig = figure('Visible','off','Position',[50 50 2400 900]);
pltPairs = {[1 2], [1 3], [2 3]};
pairTitles = {'Obj1 vs Obj2','Obj1 vs Obj3','Obj2 vs Obj3'};

% Jitter very small to avoid exact overlap
ranges = maxVals - minVals; ranges(ranges==0)=1;
jitterScale = 0.004;

fontSize = 18;
edgeMarkerSize = 380;
otherMarkerSize = 260;

for pi = 1:3
    ax = subplot(1,3,pi);
    hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    pair = pltPairs{pi};
    xlabel(ax, sprintf('Obj%d', pair(1)), 'FontSize', fontSize);
    ylabel(ax, sprintf('Obj%d', pair(2)), 'FontSize', fontSize);
    title(ax, pairTitles{pi}, 'FontSize', fontSize+2);

    legendEntries = {};
    for ai = 1:length(algKeys)
        alg = algKeys{ai};
        if ~isKey(topKMap, alg), continue; end
        tpts = topKMap(alg);
        jitter = randn(size(tpts,1),2) .* (ranges(pair) * jitterScale);
        plotPts = tpts(:, pair) + jitter;
        m = markers{mod(ai-1,length(markers))+1};
        c = colors(ai,:);
        if strcmp(alg, 'Edge-FML')
            scatter(ax, plotPts(:,1), plotPts(:,2), edgeMarkerSize, 'p', 'MarkerFaceColor', [1 .85 0], 'MarkerEdgeColor', 'k', 'LineWidth', 1.6, 'MarkerFaceAlpha',0.98);
            % annotate up to 4 points
            nAnn = min(4, size(plotPts,1));
            for r = 1:nAnn
                text(ax, plotPts(r,1)*1.01, plotPts(r,2)*1.01, sprintf('Edge-%d', r), 'FontWeight','bold', 'FontSize',12, 'BackgroundColor','w', 'Margin',1);
            end
        else
            scatter(ax, plotPts(:,1), plotPts(:,2), otherMarkerSize, 'Marker', m, 'MarkerFaceColor', c, 'MarkerEdgeColor', 'k', 'LineWidth',1.2, 'MarkerFaceAlpha',0.95);
        end
        legendEntries{end+1} = sprintf('%s (top-%d)', alg, min(K, size(tpts,1)));
    end
    legend(ax, legendEntries, 'Location','bestoutside', 'FontSize', 12);
    set(ax, 'FontSize', 14);
end

% Extract base filename without extension to create subdirectory
baseFileName = strrep(files(idx).name, '.mat', '');
outDir = fullfile(pwd, 'experiments', 'figures', baseFileName);
if ~exist(outDir, 'dir'), mkdir(outDir); end

% Save high-res PNG for presentation (600 dpi)
outFile = fullfile(outDir, sprintf('comparison_top%d_pareto_2d_pairs_enlarged_withCentralized.png', K));
print(fig, outFile, '-dpng', '-r600');
close(fig);
fprintf('Saved enlarged 2D pairwise top-%d plot (with Centralized) to: %s\n', K, outFile);
