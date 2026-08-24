% Plot diagnostics for ablation study results
% Loads latest ablation_results_*.mat in experiments/ablation_studies/experiments/results
resDir = fullfile(pwd, 'experiments', 'results');
files = dir(fullfile(resDir, 'ablation_results_*.mat'));
if isempty(files)
    error('No ablation result files found in %s', resDir);
end
% pick latest by datenum
[~, idx] = max([files.datenum]);
fname = fullfile(resDir, files(idx).name);
fprintf('Loading results from: %s\n', fname);
S = load(fname, 'results');
results = S.results;

% Collect variant summaries
runNames = fieldnames(results.runs);
variants = {};
variantMap = containers.Map();
for i = 1:length(runNames)
    r = results.runs.(runNames{i});
    v = r.variant;
    if ~isKey(variantMap, v)
        variantMap(v) = {};
        variants{end+1} = v;
    end
    arr = variantMap(v);
    arr{end+1} = r;
    variantMap(v) = arr;
end

% Extract base filename without extension to create subdirectory
baseFileName = strrep(files(idx).name, '.mat', '');
outDir = fullfile(pwd, 'experiments', 'figures', baseFileName);
if ~exist(outDir, 'dir'), mkdir(outDir); end

% 1) Pareto overlay (Obj1 vs Obj2 and Obj1 vs Obj3)
colors = lines(length(variants));
figure('Visible','off','Position',[100 100 1200 500]);
subplot(1,2,1); hold on; title('Pareto overlay: Obj1 vs Obj2'); xlabel('Obj1'); ylabel('Obj2');
subplot(1,2,2); hold on; title('Pareto overlay: Obj1 vs Obj3'); xlabel('Obj1'); ylabel('Obj3');
for vi = 1:length(variants)
    v = variants{vi};
    arr = variantMap(v);
    % merge globalFrontObjectives across repeats
    allObjs = [];
    for k = 1:length(arr)
        if isfield(arr{k}, 'globalFrontObjectives')
            allObjs = [allObjs; arr{k}.globalFrontObjectives];
        end
    end
    if isempty(allObjs)
        continue;
    end
    subplot(1,2,1);
    scatter(allObjs(:,1), allObjs(:,2), 18, 'MarkerEdgeColor', colors(vi,:), 'DisplayName', v);
    subplot(1,2,2);
    scatter(allObjs(:,1), allObjs(:,3), 18, 'MarkerEdgeColor', colors(vi,:), 'DisplayName', v);
end
for s=1:2, subplot(1,2,s); legend('Location','best'); grid on; end
saveas(gcf, fullfile(outDir, 'ablation_pareto_overlay.png'));
close(gcf);

% 2) Communication vs HV scatter (per variant mean)
figure('Visible','off'); hold on; title('Communication vs HV (per-variant mean)'); xlabel('Comm (MB)'); ylabel('Hypervolume');
meansComm = zeros(length(variants),1); meansHV = zeros(length(variants),1);
for vi = 1:length(variants)
    v = variants{vi}; arr = variantMap(v);
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
    meansComm(vi) = nanmean(comms);
    meansHV(vi) = nanmean(hvs);
    scatter(meansComm(vi), meansHV(vi), 80, 'filled', 'MarkerFaceColor', colors(vi,:), 'DisplayName', v);
end
for i=1:length(variants), text(meansComm(i), meansHV(i), [' ' variants{i}]); end
grid on; saveas(gcf, fullfile(outDir, 'ablation_comm_vs_hv.png'));
close(gcf);

% 3) Per-objective boxplots across variants (collect all pareto points per variant)
% Obj1, Obj2, Obj3
allObjData = cell(length(variants),1);
for vi = 1:length(variants)
    v = variants{vi}; arr = variantMap(v);
    allObjs = [];
    for k = 1:length(arr)
        if isfield(arr{k}, 'globalFrontObjectives')
            allObjs = [allObjs; arr{k}.globalFrontObjectives];
        end
    end
    allObjData{vi} = allObjs; % Nx3 or []
end

% For each objective, create boxplot matrix where columns = variants, rows pooled points
for objId = 1:3
    % build data vector and group index
    data = []; grp = [];
    for vi=1:length(variants)
        objs = allObjData{vi};
        if isempty(objs)
            continue;
        end
        data = [data; objs(:,objId)];
        grp = [grp; repmat(vi, size(objs,1), 1)];
    end
    if isempty(data)
        continue;
    end
    figure('Visible','off');
    boxplot(data, grp, 'Labels', variants);
    title(sprintf('Objective %d distributions by variant', objId));
    ylabel(sprintf('Obj%d', objId));
    xtickangle(45);
    saveas(gcf, fullfile(outDir, sprintf('ablation_obj%d_boxplot.png', objId)));
    close(gcf);
end

fprintf('Diagnostic plots saved to %s\n', outDir);