% generate_all_plots_raw.m
% Single entry script to generate aggregated 3D, 2D pairwise, and enlarged
% top-K plots for each dataset x scenario. Uses raw objective values (no
% normalization or axis scaling) and saves results under a timestamped
% subfolder of experiments/figures.

K = 20;
resDir = fullfile(pwd, 'experiments', 'results');
files = dir(fullfile(resDir, 'comparison_results_*.mat'));
if isempty(files), error('No comparison result files found in %s', resDir); end
[~, idx] = max([files.datenum]); fname = fullfile(resDir, files(idx).name);
% fname = 'D:\桌面\Edge-FML\experiments\algorithm_comparison\experiments\results\comparison_results_2026-02-24_12-30-31.mat'
fprintf('Loading results from: %s\n', fname);
S = load(fname, 'results'); results = S.results;

timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
outBase = fullfile(pwd, 'experiments', 'figures', timestamp);
if ~exist(outBase, 'dir'), mkdir(outBase); end

fprintf('Saving plots to: %s\n', outBase);

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
labels = {'Total Latency (s)','Total Energy (J)','Security Risk'};

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

        % gather all points
        allPts = [];
        keysA = keys(algPoints);
        for i = 1:length(keysA)
            pts = algPoints(keysA{i});
            if ~isempty(pts), allPts = [allPts; pts]; end
        end
        if isempty(allPts), fprintf('  No objective points, skipping.\n'); continue; end
        mins = min(allPts, [], 1); maxs = max(allPts, [], 1);
        posMins = zeros(1, size(allPts,2));
        for d = 1:size(allPts,2)
            posVals = allPts(allPts(:,d) > 0, d);
            if isempty(posVals)
                posMins(d) = eps;
            else
                posMins(d) = min(posVals);
            end
        end
        lowerBounds = max(mins, posMins);

        % (selectTopK implemented as a local helper below)

        % ---- Plot aggregated 3D (with Centralized) ----
        keysAll = keysA;
        cols = lines(length(keysAll)); legendEntries = {};
        fig1 = figure('Visible','off','Position',[100,100,1400,1000]); hold on; grid on; box on;
        for ai = 1:length(keysAll)
            alg = keysAll{ai}; pts = unique(algPoints(alg),'rows');
            if isempty(pts), continue; end
            scatter3(pts(:,1), pts(:,2), pts(:,3), 48, markers{mod(ai-1,length(markers))+1}, 'MarkerFaceColor', cols(ai,:), 'MarkerEdgeColor', 'k', 'LineWidth', 0.8, 'MarkerFaceAlpha',0.9);
            legendEntries{end+1} = alg;
        end
        xlabel(labels{1}); ylabel(labels{2}); zlabel(labels{3}); title(sprintf('Aggregated Pareto (all): %s | %s', dataset, scenario));
        set(gca,'XScale','log','YScale','log','ZScale','log');
        xlim([lowerBounds(1), maxs(1)]); ylim([lowerBounds(2), maxs(2)]); zlim([lowerBounds(3), maxs(3)]);
        legend(legendEntries, 'Location','bestoutside');
        out1 = fullfile(outBase, sprintf('pareto_aggregated_%s_%s_all.png', sanitize(dataset), sanitize(scenario)));
        print(fig1, out1, '-dpng', '-r300'); close(fig1);

        % ---- 2D pairwise (with Centralized) ----
        topKMap = selectTopK(keysAll, algPoints, K);
        pltPairs = {[1 2], [1 3], [2 3]}; pairTitles = {sprintf('%s vs %s', labels{1}, labels{2}), sprintf('%s vs %s', labels{1}, labels{3}), sprintf('%s vs %s', labels{2}, labels{3})};
        fig2 = figure('Visible','off','Position',[50,50,1800,900]);
        for pi = 1:3
            subplot(1,3,pi); hold on; grid on; pair = pltPairs{pi}; xlabel(labels{pair(1)}); ylabel(labels{pair(2)}); title(pairTitles{pi});
            legendEntries2 = {};
            for ai = 1:length(keysAll)
                alg = keysAll{ai}; if ~isKey(topKMap, alg), continue; end
                tpts = topKMap(alg);
                scatter(tpts(:,pair(1)), tpts(:,pair(2)), 72, 'Marker', markers{mod(ai-1,length(markers))+1}, 'MarkerFaceColor', cols(ai,:), 'MarkerEdgeColor','k', 'LineWidth',0.9, 'MarkerFaceAlpha',0.9);
                legendEntries2{end+1} = alg;
            end
            set(gca,'XScale','log','YScale','log');
            xlim([lowerBounds(pair(1)), maxs(pair(1))]); ylim([lowerBounds(pair(2)), maxs(pair(2))]);
            legend(legendEntries2, 'Location','bestoutside');
        end
        out2 = fullfile(outBase, sprintf('pareto_pairs_%s_%s_all.png', sanitize(dataset), sanitize(scenario)));
        print(fig2, out2, '-dpng', '-r300'); close(fig2);

        % ---- Enlarged top-K (with Centralized) ----
        fig3 = figure('Visible','off','Position',[50,50,2400,900]); fontSize = 16; edgeMarkerSize = 360; otherMarkerSize = 220;
        topKMap = selectTopK(keysAll, algPoints, K);
        for pi = 1:3
            ax = subplot(1,3,pi); hold(ax,'on'); grid(ax,'on'); pair = pltPairs{pi}; xlabel(ax,labels{pair(1)},'FontSize',fontSize); ylabel(ax,labels{pair(2)},'FontSize',fontSize); title(ax,pairTitles{pi}, 'FontSize',fontSize+2);
            legendEntries3 = {};
            for ai = 1:length(keysAll)
                alg = keysAll{ai}; if ~isKey(topKMap, alg), continue; end
                tpts = topKMap(alg);
                if strcmp(alg, 'Edge-FML')
                    scatter(ax, tpts(:,pair(1)), tpts(:,pair(2)), edgeMarkerSize, 'p', 'MarkerFaceColor', [1 .85 0], 'MarkerEdgeColor','k','LineWidth',1.4,'MarkerFaceAlpha',0.98);
                else
                    scatter(ax, tpts(:,pair(1)), tpts(:,pair(2)), otherMarkerSize, 'Marker', markers{mod(ai-1,length(markers))+1}, 'MarkerFaceColor', cols(ai,:), 'MarkerEdgeColor','k','LineWidth',1.2,'MarkerFaceAlpha',0.95);
                end
                legendEntries3{end+1} = alg;
            end
            set(ax,'XScale','log','YScale','log');
            xlim([lowerBounds(pair(1)), maxs(pair(1))]); ylim([lowerBounds(pair(2)), maxs(pair(2))]);
            legend(ax, legendEntries3, 'Location','bestoutside','FontSize',12); set(ax,'FontSize',14);
        end
        out3 = fullfile(outBase, sprintf('pareto_pairs_%s_%s_enlarged_all.png', sanitize(dataset), sanitize(scenario)));
        print(fig3, out3, '-dpng', '-r600'); close(fig3);

        % ---- Repeat excluding Centralized ----
        keysNo = {};
        for i = 1:length(keysA)
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
            xlabel(labels{1}); ylabel(labels{2}); zlabel(labels{3}); title(sprintf('Aggregated Pareto (no Centralized): %s | %s', dataset, scenario));
            set(gca,'XScale','log','YScale','log','ZScale','log');
            xlim([lowerBounds(1), maxs(1)]); ylim([lowerBounds(2), maxs(2)]); zlim([lowerBounds(3), maxs(3)]);
            legend(legendEntriesN,'Location','bestoutside');
            out4 = fullfile(outBase, sprintf('pareto_aggregated_%s_%s_nocentralized.png', sanitize(dataset), sanitize(scenario)));
            print(fig4, out4, '-dpng','-r300'); close(fig4);

            % 2D pairs no-centralized
            topKMapNo = selectTopK(keysNo, algPoints, K);
            fig5 = figure('Visible','off','Position',[50,50,1800,900]);
            for pi = 1:3
                subplot(1,3,pi); hold on; grid on; pair = pltPairs{pi}; xlabel(labels{pair(1)}); ylabel(labels{pair(2)}); title(pairTitles{pi}); legendEntries5 = {};
                for ai = 1:length(keysNo)
                    alg = keysNo{ai}; if ~isKey(topKMapNo, alg), continue; end
                    tpts = topKMapNo(alg);
                    scatter(tpts(:,pair(1)), tpts(:,pair(2)), 72, 'Marker', markers{mod(ai-1,length(markers))+1}, 'MarkerFaceColor', colsNo(ai,:), 'MarkerEdgeColor','k', 'LineWidth',0.9, 'MarkerFaceAlpha',0.9);
                    legendEntries5{end+1} = alg;
                end
                set(gca,'XScale','log','YScale','log');
                xlim([lowerBounds(pair(1)), maxs(pair(1))]); ylim([lowerBounds(pair(2)), maxs(pair(2))]);
                legend(legendEntries5,'Location','bestoutside');
            end
            out5 = fullfile(outBase, sprintf('pareto_pairs_%s_%s_nocentralized.png', sanitize(dataset), sanitize(scenario)));
            print(fig5, out5, '-dpng', '-r300'); close(fig5);

            % enlarged no-centralized
            fig6 = figure('Visible','off','Position',[50,50,2400,900]);
            topKMapNo = selectTopK(keysNo, algPoints, K);
            for pi = 1:3
                ax = subplot(1,3,pi); hold(ax,'on'); grid(ax,'on'); pair = pltPairs{pi}; xlabel(ax,labels{pair(1)},'FontSize',fontSize); ylabel(ax,labels{pair(2)},'FontSize',fontSize); title(ax,pairTitles{pi}, 'FontSize',fontSize+2);
                legendEntries6 = {};
                for ai = 1:length(keysNo)
                    alg = keysNo{ai}; if ~isKey(topKMapNo, alg), continue; end
                    tpts = topKMapNo(alg);
                    scatter(ax, tpts(:,pair(1)), tpts(:,pair(2)), otherMarkerSize, 'Marker', markers{mod(ai-1,length(markers))+1}, 'MarkerFaceColor', colsNo(ai,:), 'MarkerEdgeColor','k', 'LineWidth',1.2, 'MarkerFaceAlpha',0.96);
                    legendEntries6{end+1} = alg;
                end
                set(ax,'XScale','log','YScale','log');
                xlim([lowerBounds(pair(1)), maxs(pair(1))]); ylim([lowerBounds(pair(2)), maxs(pair(2))]);
                legend(ax, legendEntries6, 'Location','bestoutside','FontSize',12); set(ax,'FontSize',14);
            end
            out6 = fullfile(outBase, sprintf('pareto_pairs_%s_%s_enlarged_nocentralized.png', sanitize(dataset), sanitize(scenario)));
            print(fig6, out6, '-dpng', '-r600'); close(fig6);
        end

    end
end

% ---- Create per-dataset-per-scenario 3D plots for all algorithms ----
fprintf('Creating per-dataset-per-scenario 3D plots...\n');

% Process each dataset and scenario combination
for di = 1:length(allDatasets)
    dataset = allDatasets{di};
    for si = 1:length(allScenarios)
        scenario = allScenarios{si};
        fprintf('Processing dataset=%s, scenario=%s\n', dataset, scenario);

        % Collect algorithm points for this dataset+scenario
        algPoints = containers.Map();

        for k = 1:length(runKeys)
            run = results.runs.(runKeys{k});
            if ~isfield(run, 'dataset') || ~isfield(run, 'scenarioType'), continue; end
            if ~strcmp(run.dataset, dataset) || ~strcmp(run.scenarioType, scenario), continue; end
            if ~isfield(run, 'algorithm'), continue; end
            alg = run.algorithm;

            % Add points
            if ~isKey(algPoints, alg)
                algPoints(alg) = [];
            end

            if isfield(run, 'globalFrontObjectives') && ~isempty(run.globalFrontObjectives)
                pts = algPoints(alg);
                pts = [pts; run.globalFrontObjectives];
                algPoints(alg) = pts;
            end
        end

        % Gather all points for axis limits
        allPts = [];
        keysA = keys(algPoints);
        for i = 1:length(keysA)
            pts = algPoints(keysA{i});
            if ~isempty(pts), allPts = [allPts; pts]; end
        end

        if ~isempty(allPts)
            mins = min(allPts, [], 1); maxs = max(allPts, [], 1);
            posMins = zeros(1, size(allPts,2));
            for d = 1:size(allPts,2)
                posVals = allPts(allPts(:,d) > 0, d);
                if isempty(posVals)
                    posMins(d) = eps;
                else
                    posMins(d) = min(posVals);
                end
            end
            lowerBounds = max(mins, posMins);

            % Create 3D plot for this dataset+scenario
            figCombination = figure('Visible','off','Position',[100,100,1600,1200]); hold on; grid on; box on;

            % Prepare colors for algorithms
            numAlgs = length(keysA);
            algColors = lines(numAlgs);

            legendEntries = {};

            % Plot each algorithm's points
            for ai = 1:length(keysA)
                alg = keysA{ai};
                pts = unique(algPoints(alg),'rows');
                if isempty(pts), continue; end

                % Filter to only non-dominated points (Pareto front)
                ndPts = findNonDominated(pts);
                if isempty(ndPts), continue; end

                scatter3(ndPts(:,1), ndPts(:,2), ndPts(:,3), 60, markers{mod(ai-1,length(markers))+1}, 'MarkerFaceColor', algColors(ai,:), 'MarkerEdgeColor', 'k', 'LineWidth', 1.0, 'MarkerFaceAlpha',0.8);
                legendEntries{end+1} = alg;
            end

            xlabel(labels{1}); ylabel(labels{2}); zlabel(labels{3});
            % 使用texmode off确保数据集名称正确显示，避免下标问题
            title(sprintf('3D Pareto Front: All Algorithms | Dataset: %s | Scenario: %s', dataset, scenario), 'Interpreter', 'none');
            set(gca,'XScale','log','YScale','log','ZScale','log');
            xlim([lowerBounds(1), maxs(1)]); ylim([lowerBounds(2), maxs(2)]); zlim([lowerBounds(3), maxs(3)]);
            legend(legendEntries, 'Location','bestoutside','FontSize',10);

            % Set view angle for better visualization
            view(30, 30);

            % Save high-resolution image
            outCombination = fullfile(outBase, sprintf('pareto_3d_%s_%s.png', sanitize(dataset), sanitize(scenario)));
            print(figCombination, outCombination, '-dpng', '-r600');
            close(figCombination);
            fprintf('3D plot for dataset=%s, scenario=%s saved to: %s\n', dataset, scenario, outCombination);
        end
    end
end

fprintf('All plots saved to %s\n', outBase);

% helper: sanitize filename fragments
function s = sanitize(t)
    s = char(t);
    s = strrep(s, '/', '_'); s = strrep(s, '\\', '_'); s = strrep(s, ' ', '_');
end

% Select top-K points by raw objective sums (no normalization)
function topMap = selectTopK(keysList, algPoints, K)
    topMap = containers.Map();
    for ai = 1:length(keysList)
        algn = keysList{ai};
        pts = unique(algPoints(algn), 'rows');
        if isempty(pts), continue; end
        scores = sum(pts, 2); % raw sum of objectives (lower better)
        [~, order] = sort(scores, 'ascend');
        idxs = order(1:min(K, size(pts,1)));
        topMap(algn) = pts(idxs, :);
    end
end

% Find non-dominated points (Pareto front)
function ndPoints = findNonDominated(pts)
    % pts: N x D matrix where D is the number of objectives
    % Returns only non-dominated points (minimization)
    if isempty(pts), ndPoints = []; return; end

    n = size(pts, 1);
    dominated = false(n, 1);

    for i = 1:n
        for j = 1:n
            if i ~= j
                % Check if j dominates i
                if all(pts(j,:) <= pts(i,:)) && any(pts(j,:) < pts(i,:))
                    dominated(i) = true;
                    break;
                end
            end
        end
    end

    ndPoints = pts(~dominated, :);
end
