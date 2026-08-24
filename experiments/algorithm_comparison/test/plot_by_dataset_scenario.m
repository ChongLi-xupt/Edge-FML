% Plot per-dataset and per-scenario Pareto comparisons (3D aggregated, 2D pairs, enlarged top-20)
% Produces for each dataset x scenario:
%  - aggregated 3D (with and without Centralized)
%  - 2D pairwise (with and without Centralized)
%  - enlarged top-20 2D (with and without Centralized)

K = 20;
% If true, select top-K by raw objective sums (no normalization).
% Set to false to use the previous normalization-based scoring.
useRawScoring = true;
resDir = fullfile(pwd, 'experiments', 'results');
files = dir(fullfile(resDir, 'comparison_results_*.mat'));
if isempty(files), error('No comparison result files found in %s', resDir); end
[~, idx] = max([files.datenum]); fname = fullfile(resDir, files(idx).name);
fprintf('Loading results from: %s\n', fname);
S = load(fname, 'results'); results = S.results;

% collect dataset and scenario types
runKeys = fieldnames(results.runs);
allDatasets = {};
allScenarios = {};
for k = 1:length(runKeys)
    r = results.runs.(runKeys{k});
    if isfield(r, 'dataset'), allDatasets{end+1} = r.dataset; end
    if isfield(r, 'scenarioType'), allScenarios{end+1} = r.scenarioType; end
end
allDatasets = unique(allDatasets);
allScenarios = unique(allScenarios);

excludePatterns = {'Centralized', 'Centralized-MTDMS'};
markers = {'o','s','^','d','v','p','h','>','<','x','+'};

outDir = fullfile(pwd, 'experiments', 'figures'); if ~exist(outDir,'dir'), mkdir(outDir); end

for di = 1:length(allDatasets)
    dataset = allDatasets{di};
    for si = 1:length(allScenarios)
        scenario = allScenarios{si};
        fprintf('Processing dataset=%s, scenario=%s\n', dataset, scenario);

        % Build per-algorithm point sets for this dataset+scenario
        algPoints = containers.Map(); algList = {};
        for k = 1:length(runKeys)
            run = results.runs.(runKeys{k});
            if ~isfield(run, 'dataset') || ~isfield(run, 'scenarioType'), continue; end
            if ~strcmp(run.dataset, dataset) || ~strcmp(run.scenarioType, scenario), continue; end
            if ~isfield(run, 'algorithm'), continue; end
            alg = run.algorithm;
            if ~isKey(algPoints, alg)
                algPoints(alg) = [];
                algList{end+1} = alg;
            end
            if isfield(run, 'globalFrontObjectives') && ~isempty(run.globalFrontObjectives)
                pts = algPoints(alg);
                pts = [pts; run.globalFrontObjectives];
                algPoints(alg) = pts;
            end
        end

        if isempty(algList)
            fprintf('  No runs for this dataset/scenario, skipping.\n');
            continue;
        end

        % normalize bounds from all collected points
        allPts = [];
        keysA = keys(algPoints);
        for i = 1:length(keysA)
            pts = algPoints(keysA{i});
            if ~isempty(pts), allPts = [allPts; pts]; end
        end
        if isempty(allPts), fprintf('  No objective points, skipping.\n'); continue; end
        % Use fractional margins relative to the data span to avoid
        % introducing large absolute offsets that can push non-negative
        % objective ranges below zero (causing negative axis ticks).
        mins = min(allPts, [], 1);
        maxs = max(allPts, [], 1);
        spans = maxs - mins;
        marginFrac = 0.05; % 5% of span
        margins = marginFrac .* spans;
        % For zero spans, fall back to a small absolute margin proportional
        % to magnitude (1% of min or 1e-3 minimum).
        zeroMask = (margins == 0);
        margins(zeroMask) = max(abs(mins(zeroMask)) * 0.01, 1e-3);
        % Compute lower bounds and clamp to zero when data are non-negative.
        xLow = mins(1) - margins(1);
        yLow = mins(2) - margins(2);
        zLow = mins(3) - margins(3);
        if mins(1) >= 0, xLow = max(0, xLow); end
        if mins(2) >= 0, yLow = max(0, yLow); end
        if mins(3) >= 0, zLow = max(0, zLow); end
        xL = [xLow, maxs(1) + margins(1)];
        yL = [yLow, maxs(2) + margins(2)];
        zL = [zLow, maxs(3) + margins(3)];

        % 1) Aggregated 3D (with Centralized)
        fig1 = figure('Visible','off','Position',[100,100,1400,1000]); hold on; grid on; box on;
        cols = lines(length(keysA)); legendEntries = {};
        for ai = 1:length(keysA)
            alg = keysA{ai}; pts = unique(algPoints(alg), 'rows');
            if isempty(pts), continue; end
            scatter3(pts(:,1), pts(:,2), pts(:,3), 48, markers{mod(ai-1,length(markers))+1}, 'MarkerFaceColor', cols(ai,:), 'MarkerEdgeColor', 'k', 'LineWidth', 0.8, 'MarkerFaceAlpha',0.9);
            legendEntries{end+1} = alg;
        end
        xlabel('Obj1'); ylabel('Obj2'); zlabel('Obj3'); title(sprintf('Aggregated Pareto (all): %s | %s', dataset, scenario));
        xlim(xL); ylim(yL); zlim(zL); legend(legendEntries, 'Location','bestoutside');
        out1 = fullfile(outDir, sprintf('pareto_aggregated_%s_%s_all.png', sanitize(dataset), sanitize(scenario)));
        print(fig1, out1, '-dpng', '-r300'); close(fig1);

        % 2) 2D pairwise (with Centralized) - top-K per alg
        % compute global min/max for normalization
        maxVals = max(allPts, [], 1); minVals = min(allPts, [], 1);
        denom = maxVals - minVals; denom(denom==0)=1;
        topKMap = containers.Map();
        for ai = 1:length(keysA)
            alg = keysA{ai}; pts = unique(algPoints(alg), 'rows');
            if isempty(pts), continue; end
            if useRawScoring
                scores = sum(pts, 2); % lower is better
            else
                normed = (pts - minVals) ./ denom; scores = sum(normed,2);
            end
            [~, order] = sort(scores,'ascend'); idxs = order(1:min(K, size(pts,1))); topKMap(alg) = pts(idxs,:);
        end

        fig2 = figure('Visible','off','Position',[50,50,1800,900]); pltPairs = {[1 2],[1 3],[2 3]}; pairTitles = {'Obj1 vs Obj2','Obj1 vs Obj3','Obj2 vs Obj3'};
        ranges = maxVals - minVals; ranges(ranges==0)=1; jitterScale = 0.006;
        for pi=1:3
            subplot(1,3,pi); hold on; grid on; pair = pltPairs{pi}; xlabel(sprintf('Obj%d',pair(1))); ylabel(sprintf('Obj%d',pair(2))); title(pairTitles{pi});
            legendEntries2 = {};
            for ai=1:length(keysA)
                alg = keysA{ai}; if ~isKey(topKMap, alg), continue; end
                tpts = topKMap(alg); jitter = randn(size(tpts,1),2) .* (ranges(pair) * jitterScale); plotPts = tpts(:,pair) + jitter; c = cols(ai,:); m = markers{mod(ai-1,length(markers))+1};
                scatter(plotPts(:,1), plotPts(:,2), 72, m, 'MarkerFaceColor', c, 'MarkerEdgeColor','k', 'LineWidth',0.9, 'MarkerFaceAlpha',0.9);
                legendEntries2{end+1} = alg;
            end
            legend(legendEntries2, 'Location','bestoutside');
        end
        out2 = fullfile(outDir, sprintf('pareto_pairs_%s_%s_all.png', sanitize(dataset), sanitize(scenario)));
        print(fig2, out2, '-dpng', '-r300'); close(fig2);

        % 3) Enlarged top-20 2D (with Centralized)
        fig3 = figure('Visible','off','Position',[50,50,2400,900]); fontSize = 16; edgeMarkerSize = 360; otherMarkerSize = 220;
        for pi=1:3
            ax = subplot(1,3,pi); hold(ax,'on'); grid(ax,'on'); pair = pltPairs{pi}; xlabel(ax,sprintf('Obj%d',pair(1)),'FontSize',fontSize); ylabel(ax,sprintf('Obj%d',pair(2)),'FontSize',fontSize); title(ax,pairTitles{pi}, 'FontSize',fontSize+2);
            legendEntries3 = {};
            for ai=1:length(keysA)
                alg = keysA{ai}; if ~isKey(topKMap, alg), continue; end
                tpts = topKMap(alg); jitter = randn(size(tpts,1),2) .* (ranges(pair) * (jitterScale/2)); plotPts = tpts(:,pair) + jitter; c = cols(ai,:); m = markers{mod(ai-1,length(markers))+1};
                if strcmp(alg, 'Edge-FML')
                    scatter(ax, plotPts(:,1), plotPts(:,2), edgeMarkerSize, 'p', 'MarkerFaceColor', [1 .85 0], 'MarkerEdgeColor','k','LineWidth',1.4,'MarkerFaceAlpha',0.98);
                else
                    scatter(ax, plotPts(:,1), plotPts(:,2), otherMarkerSize, 'Marker', m, 'MarkerFaceColor', c, 'MarkerEdgeColor','k','LineWidth',1.2,'MarkerFaceAlpha',0.95);
                end
                legendEntries3{end+1} = alg;
            end
            legend(ax, legendEntries3, 'Location','bestoutside','FontSize',12); set(ax,'FontSize',14);
        end
        out3 = fullfile(outDir, sprintf('pareto_pairs_%s_%s_enlarged_all.png', sanitize(dataset), sanitize(scenario)));
        print(fig3, out3, '-dpng', '-r600'); close(fig3);

        % 4) Repeat 1-3 excluding Centralized
        % filter keys
        keysNo = {};
        for i=1:length(keysA)
            if any(contains(keysA{i}, excludePatterns)), continue; end
            keysNo{end+1} = keysA{i};
        end
        if ~isempty(keysNo)
            colsNo = lines(length(keysNo));
            % aggregated no-centralized
            fig4 = figure('Visible','off','Position',[100,100,1400,1000]); hold on; grid on; box on; legendEntriesN = {};
            for ai = 1:length(keysNo)
                alg = keysNo{ai}; pts = unique(algPoints(alg),'rows'); if isempty(pts), continue; end
                scatter3(pts(:,1), pts(:,2), pts(:,3), 56, markers{mod(ai-1,length(markers))+1}, 'MarkerFaceColor', colsNo(ai,:), 'MarkerEdgeColor','k','LineWidth',0.9,'MarkerFaceAlpha',0.92);
                legendEntriesN{end+1} = alg;
            end
            xlabel('Obj1'); ylabel('Obj2'); zlabel('Obj3'); title(sprintf('Aggregated Pareto (no Centralized): %s | %s', dataset, scenario)); xlim(xL); ylim(yL); zlim(zL); legend(legendEntriesN,'Location','bestoutside');
            out4 = fullfile(outDir, sprintf('pareto_aggregated_%s_%s_nocentralized.png', sanitize(dataset), sanitize(scenario)));
            print(fig4, out4, '-dpng','-r300'); close(fig4);

            % 2D pairs no-centralized (topK)
            topKMapNo = containers.Map();
            for ai = 1:length(keysNo)
                alg = keysNo{ai}; pts = unique(algPoints(alg),'rows'); if isempty(pts), continue; end
                if useRawScoring
                    scores = sum(pts, 2);
                else
                    normed = (pts - minVals) ./ denom; scores = sum(normed,2);
                end
                [~, order] = sort(scores,'ascend'); idxs = order(1:min(K, size(pts,1))); topKMapNo(alg) = pts(idxs,:);
            end
            fig5 = figure('Visible','off','Position',[50,50,1800,900]);
            for pi=1:3
                subplot(1,3,pi); hold on; grid on; pair = pltPairs{pi}; xlabel(sprintf('Obj%d',pair(1))); ylabel(sprintf('Obj%d',pair(2))); title(pairTitles{pi}); legendEntries5 = {};
                for ai=1:length(keysNo)
                    alg = keysNo{ai}; if ~isKey(topKMapNo, alg), continue; end
                    tpts = topKMapNo(alg); jitter = randn(size(tpts,1),2) .* (ranges(pair) * jitterScale); plotPts = tpts(:,pair) + jitter; c = colsNo(ai,:); m = markers{mod(ai-1,length(markers))+1};
                    scatter(plotPts(:,1), plotPts(:,2), 72, m, 'MarkerFaceColor', c, 'MarkerEdgeColor','k','LineWidth',0.9,'MarkerFaceAlpha',0.9);
                    legendEntries5{end+1} = alg;
                end
                legend(legendEntries5,'Location','bestoutside');
            end
            out5 = fullfile(outDir, sprintf('pareto_pairs_%s_%s_nocentralized.png', sanitize(dataset), sanitize(scenario)));
            print(fig5, out5, '-dpng', '-r300'); close(fig5);

            % enlarged no-centralized
            fig6 = figure('Visible','off','Position',[50,50,2400,900]);
            for pi=1:3
                ax = subplot(1,3,pi); hold(ax,'on'); grid(ax,'on'); pair = pltPairs{pi}; xlabel(ax,sprintf('Obj%d',pair(1)),'FontSize',fontSize); ylabel(ax,sprintf('Obj%d',pair(2)),'FontSize',fontSize); title(ax,pairTitles{pi}, 'FontSize',fontSize+2);
                legendEntries6 = {};
                for ai=1:length(keysNo)
                    alg = keysNo{ai}; if ~isKey(topKMapNo, alg), continue; end
                    tpts = topKMapNo(alg); jitter = randn(size(tpts,1),2) .* (ranges(pair) * (jitterScale/2)); plotPts = tpts(:,pair) + jitter; c = colsNo(ai,:); m = markers{mod(ai-1,length(markers))+1};
                    scatter(ax, plotPts(:,1), plotPts(:,2), otherMarkerSize, 'Marker', m, 'MarkerFaceColor', c, 'MarkerEdgeColor','k', 'LineWidth',1.2, 'MarkerFaceAlpha',0.96);
                    legendEntries6{end+1} = alg;
                end
                legend(ax, legendEntries6, 'Location','bestoutside','FontSize',12); set(ax,'FontSize',14);
            end
            out6 = fullfile(outDir, sprintf('pareto_pairs_%s_%s_enlarged_nocentralized.png', sanitize(dataset), sanitize(scenario)));
            print(fig6, out6, '-dpng', '-r600'); close(fig6);
        end

    end
end

fprintf('All per-dataset/scenario figures saved to %s\n', outDir);

% helper: sanitize filename fragments
function s = sanitize(t)
    s = char(t);
    s = strrep(s, '/', '_'); s = strrep(s, '\\', '_'); s = strrep(s, ' ', '_');
end
