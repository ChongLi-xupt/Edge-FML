% Plot diagnostics for comparison experiment results
% Loads latest comparison_results_*.mat in experiments/algorithm_comparison/experiments/results
resDir = fullfile(pwd, 'experiments', 'results');
files = dir(fullfile(resDir, 'comparison_results_*.mat'));
if isempty(files)
    error('No comparison result files found in %s', resDir);
end
[~, idx] = max([files.datenum]);
fname = fullfile(resDir, files(idx).name);
fprintf('Loading results from: %s\n', fname);
S = load(fname, 'results');
results = S.results;

% Collect runs grouped by algorithm
runNames = fieldnames(results.runs);
algMap = containers.Map();
algorithms = {};
for i = 1:length(runNames)
    r = results.runs.(runNames{i});
    alg = r.algorithm;
    if ~isKey(alMapSafe(algMap, alg), alg) && ~isKey(algMap, alg)
        % noop (keeps map creation below)
    end
    if ~isKey(algMap, alg)
        algMap(alg) = {};
        algorithms{end+1} = alg;
    end
    arr = algMap(alg);
    arr{end+1} = r;
    algMap(alg) = arr;
end

% Extract base filename without extension to create subdirectory
baseFileName = strrep(files(idx).name, '.mat', '');
outDir = fullfile(pwd, 'experiments', 'figures', baseFileName);
if ~exist(outDir, 'dir'), mkdir(outDir); end

% Colors
colors = lines(length(algorithms));

% 1) Pareto overlay: Obj1 vs Obj2 and Obj1 vs Obj3
figure('Visible','off','Position',[100 100 1200 500]);
subplot(1,2,1); hold on; title('Pareto overlay: Obj1 vs Obj2'); xlabel('Obj1'); ylabel('Obj2');
subplot(1,2,2); hold on; title('Pareto overlay: Obj1 vs Obj3'); xlabel('Obj1'); ylabel('Obj3');
for ai = 1:length(algorithms)
    alg = algorithms{ai}; arr = algMap(alg);
    allObjs = [];
    for k = 1:length(arr)
        if isfield(arr{k}, 'globalFrontObjectives')
            allObjs = [allObjs; arr{k}.globalFrontObjectives];
        end
    end
    if isempty(allObjs), continue; end
    subplot(1,2,1);
    scatter(allObjs(:,1), allObjs(:,2), 18, 'MarkerEdgeColor', colors(ai,:), 'DisplayName', alg);
    subplot(1,2,2);
    scatter(allObjs(:,1), allObjs(:,3), 18, 'MarkerEdgeColor', colors(ai,:), 'DisplayName', alg);
end
for s=1:2, subplot(1,2,s); legend('Location','best'); grid on; end
saveas(gcf, fullfile(outDir, 'comparison_pareto_overlay.png'));
close(gcf);

% 2) Communication vs HV (per-algorithm mean)
figure('Visible','off'); hold on; title('Communication vs HV (per-algorithm mean)'); xlabel('Comm (MB)'); ylabel('Hypervolume');
meansComm = zeros(length(algorithms),1); meansHV = zeros(length(algorithms),1);
for ai = 1:length(algorithms)
    alg = algorithms{ai}; arr = algMap(alg);
    comms = zeros(length(arr),1); hvs = zeros(length(arr),1);
    for k = 1:length(arr)
        if isfield(arr{k}, 'totalCommBytes')
            comms(k) = arr{k}.totalCommBytes / 1e6;
        else
            comms(k) = NaN;
        end
        if isfield(arr{k}, 'hypervolume')
            hvs(k) = arr{k}.hypervolume;
        elseif isfield(arr{k}, 'hv')
            hvs(k) = arr{k}.hv;
        else
            hvs(k) = NaN;
        end
    end
    meansComm(ai) = nanmean(comms);
    meansHV(ai) = nanmean(hvs);
    scatter(meansComm(ai), meansHV(ai), 80, 'filled', 'MarkerFaceColor', colors(ai,:), 'DisplayName', alg);
end
for i=1:length(algorithms), text(meansComm(i), meansHV(i), [' ' algorithms{i}]); end
grid on; saveas(gcf, fullfile(outDir, 'comparison_comm_vs_hv.png'));
close(gcf);

% 3) Per-objective boxplots across algorithms
allObjData = cell(length(algorithms),1);
for ai = 1:length(algorithms)
    alg = algorithms{ai}; arr = algMap(alg);
    allObjs = [];
    for k = 1:length(arr)
        if isfield(arr{k}, 'globalFrontObjectives')
            allObjs = [allObjs; arr{k}.globalFrontObjectives];
        end
    end
    allObjData{ai} = allObjs;
end
for objId = 1:3
    data = []; grp = [];
    for ai=1:length(algorithms)
        objs = allObjData{ai};
        if isempty(objs), continue; end
        data = [data; objs(:,objId)];
        grp = [grp; repmat(ai, size(objs,1), 1)];
    end
    if isempty(data), continue; end
    figure('Visible','off'); boxplot(data, grp, 'Labels', algorithms);
    title(sprintf('Objective %d distributions by algorithm', objId)); ylabel(sprintf('Obj%d', objId)); xtickangle(45);
    saveas(gcf, fullfile(outDir, sprintf('comparison_obj%d_boxplot.png', objId)));
    close(gcf);
end

fprintf('Comparison diagnostic plots saved to %s\n', outDir);

% helper to avoid isKey issue when no map yet
function val = alMapSafe(mapObj, key)
    if isempty(mapObj)
        val = containers.Map();
    else
        val = mapObj;
    end
end