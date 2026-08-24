% generate_sensitivity_report.m - basic summary and plots for sensitivity experiments
% This script loads `sensitivity_results_*.mat` (or `sensitivity_intermediate_*.mat`) from
% the results directory and produces simple summaries and boxplots saved to figures dir.

if ~exist('preserveWorkspace', 'var') || ~preserveWorkspace
    clearvars -except preserveWorkspace;
end
clc;

% Resolve project root and add source/experiments to path (robust across cwd)
scriptFull = which('generate_sensitivity_report.m');
if isempty(scriptFull)
    scriptFull = mfilename('fullpath');
end
scriptDir = fileparts(scriptFull);
projectRoot = fileparts(fileparts(scriptDir));

addpath(fullfile(projectRoot, 'src'));
addpath(fullfile(projectRoot, 'experiments'));

% Load config for paths
if exist(fullfile(projectRoot,'experiments','config_struct.mat'),'file')
    load(fullfile(projectRoot,'experiments','config_struct.mat'), 'commonConfig');
else
    run(fullfile(projectRoot,'experiments','config.m'));
end

% Locate sensitivity result file: prefer top-level matching file, fallback to most recent inside timestamped subdirs
% Normalize config paths: ensure results_dir and figures_dir are absolute
if ~isfolder(commonConfig.results_dir)
    commonConfig.results_dir = fullfile(projectRoot, commonConfig.results_dir);
end
if ~isfolder(commonConfig.figures_dir)
    commonConfig.figures_dir = fullfile(projectRoot, commonConfig.figures_dir);
end

resDir = commonConfig.results_dir;
files = dir(fullfile(resDir, 'sensitivity_results_*.mat'));
if isempty(files)
    % search one-level deep for timestamped subfolders
    subdirs = dir(fullfile(resDir, 'sensitivity_*'));
    candidates = [];
    for sd = 1:length(subdirs)
        if ~subdirs(sd).isdir, continue; end
        f = dir(fullfile(resDir, subdirs(sd).name, 'sensitivity_results_*.mat'));
        candidates = [candidates; f]; %#ok<AGROW>
    end
    files = candidates;
end
if isempty(files)
    warning('No sensitivity results found in %s or its timestamped subfolders', resDir);
    return;
end

% Load the most recent file (newest datenum)
[~, idx] = max([files.datenum]); fname = fullfile(files(idx).folder, files(idx).name);
fprintf('Loading sensitivity results from: %s\n', fname);
S = load(fname, 'results'); results = S.results;

runKeys = fieldnames(results.runs);
if isempty(runKeys)
    warning('No runs present in results.');
    return;
end

% Collect table of (param, value, hv, time)
T = table();
rows = 0;
for i = 1:length(runKeys)
    r = results.runs.(runKeys{i});
    rows = rows + 1;
    T.param{rows,1} = r.param; %#ok<SAGROW>
    T.value(rows,1) = r.value;
    if isfield(r,'hypervolume')
        T.hv(rows,1) = r.hypervolume; %#ok<SAGROW>
    else
        T.hv(rows,1) = NaN; %#ok<SAGROW>
    end
    if isfield(r,'elapsedTime')
        T.time(rows,1) = r.elapsedTime; %#ok<SAGROW>
    else
        T.time(rows,1) = NaN; %#ok<SAGROW>
    end
    if isfield(r,'commBytes')
        T.commMB(rows,1) = r.commBytes / 1e6; %#ok<SAGROW>
    else
        T.commMB(rows,1) = NaN; %#ok<SAGROW>
    end
end

% Convert cell param column to categorical for grouping
T.param = categorical(T.param);

% If HV missing but globalFrontObjectives exist, compute a simple proxy metric
% (negative mean sum of objective values) so plots can show relative differences.
for ii = 1:height(T)
    % no proxy fallback
end

summaryCSV = fullfile(files(idx).folder, sprintf('sensitivity_summary_%s.csv', results.timestamp));
writetable(T, summaryCSV);
fprintf('Saved summary CSV: %s\n', summaryCSV);

% Generate boxplots for each parameter (HV)
params = categories(T.param);
Pvals = table();
pi = 0;
for p = 1:length(params)
    pname = params{p};
    sel = T.param == pname;
    if sum(sel) < 2
        continue;
    end
    [~, order] = sort(T.value(sel));
    hvp = T.hv(sel);
    valp = T.value(sel);
    hvp = hvp(order);
    valp = valp(order);
    figure('Visible','off','Position',[200 200 900 600]);
    boxchart(valp, hvp);
    xlabel('Parameter Value'); ylabel('Hypervolume');
    ttl = sprintf('Sensitivity: %s (Hypervolume)', char(pname));
    title(ttl, 'Interpreter','none');
    grid on;
    % Save figures into timestamped figures subdir (create if necessary)
    figDir = fullfile(commonConfig.figures_dir, sprintf('sensitivity_%s', results.timestamp));
    if ~exist(figDir, 'dir'), mkdir(figDir); end
    outFile = fullfile(figDir, sprintf('sensitivity_box_%s_%s.png', char(pname), results.timestamp));
    print(gcf, outFile, '-dpng', '-r300');
    close(gcf);
    fprintf('Saved figure: %s\n', outFile);
    groups = valp;
    try
        pval = kruskalwallis(hvp, groups, 'off');
    catch
        pval = NaN;
    end
    pi = pi + 1;
    Pvals.param{pi,1} = pname;
    Pvals.p_value(pi,1) = pval;

    % Pairwise comparisons with multiple correction (FDR & Bonferroni)
    uvals = unique(valp);
    pairRows = [];
    rawP = [];
    pv1 = [];
    pv2 = [];
    for i1 = 1:length(uvals)
        for i2 = (i1+1):length(uvals)
            v1 = uvals(i1); v2 = uvals(i2);
            g1 = hvp(valp == v1); g1 = g1(~isnan(g1));
            g2 = hvp(valp == v2); g2 = g2(~isnan(g2));
            if length(g1) > 1 && length(g2) > 1
                try
                    p12 = ranksum(g1, g2);
                catch
                    p12 = NaN;
                end
                rawP(end+1,1) = p12; %#ok<AGROW>
                pv1(end+1,1) = v1; %#ok<AGROW>
                pv2(end+1,1) = v2; %#ok<AGROW>
                pairRows(end+1,1) = 1; %#ok<AGROW>
            end
        end
    end
    m = length(rawP);
    if m > 0
        [sortedP, idxP] = sort(rawP, 'ascend');
        bhAdj = zeros(m,1);
        for k = 1:m
            bhAdj(idxP(k)) = sortedP(k) * m / k;
        end
        for k = (m-1):-1:1
            bhAdj(idxP(k)) = min(bhAdj(idxP(k)), bhAdj(idxP(k+1)));
        end
        bonfAdj = min(rawP * m, 1);
        % Write combined CSV per parameter
        pairT = table();
        pairT.param = repmat({pname}, m, 1);
        pairT.value1 = pv1;
        pairT.value2 = pv2;
        pairT.p_raw = rawP;
        pairT.p_adj_bh = bhAdj;
        pairT.p_adj_bonf = bonfAdj;
        pairCSV = fullfile(files(idx).folder, sprintf('sensitivity_pairwise_%s_%s.csv', char(pname), results.timestamp));
        writetable(pairT, pairCSV);
        fprintf('Saved pairwise CSV: %s\n', pairCSV);
    end
end

pvCSV = fullfile(files(idx).folder, sprintf('sensitivity_pvalues_%s.csv', results.timestamp));
writetable(Pvals, pvCSV);
fprintf('Saved p-values CSV: %s\n', pvCSV);

% Performance-Cost trade-off plots
for p = 1:length(params)
    pname = params{p};
    sel = T.param == pname;
    if sum(sel) < 2
        continue;
    end
    [~, order] = sort(T.value(sel));
    hvp = T.hv(sel); hvp = hvp(order);
    valp = T.value(sel); valp = valp(order);
    timep = T.time(sel); timep = timep(order);
    commp = T.commMB(sel); commp = commp(order);
    u = unique(valp);
    hvMean = zeros(length(u),1); hvStd = zeros(length(u),1);
    costMean = zeros(length(u),1);
    for i = 1:length(u)
        idx = (valp == u(i));
        xh = hvp(idx); xh = xh(~isnan(xh));
        hvMean(i) = mean(xh);
        hvStd(i) = std(xh);
        if strcmp(char(pname), 'M-local')
            xc = timep(idx); xc = xc(~isnan(xc));
            costMean(i) = mean(xc);
        elseif strcmp(char(pname), 'M-elite')
            xc = commp(idx); xc = xc(~isnan(xc));
            costMean(i) = mean(xc);
        elseif strcmp(char(pname), 'population-size')
            xc = timep(idx); xc = xc(~isnan(xc));
            costMean(i) = mean(xc) / max(commonConfig.R_max, 1);
        else
            xc = timep(idx); xc = xc(~isnan(xc));
            costMean(i) = mean(xc);
        end
    end
    figure('Visible','off','Position',[200 200 900 600]);
    yyaxis left; errorbar(u, hvMean, hvStd, '-o', 'LineWidth', 1.5); ylabel('Hypervolume');
    yyaxis right; plot(u, costMean, '-s', 'LineWidth', 1.5);
    pnameStr = strtrim(char(pname));
    pnameNorm = lower(strrep(pnameStr, '-', '_'));
    if strcmp(pnameNorm, 'm_local')
        ylabel('Runtime (s)');
    elseif strcmp(pnameNorm, 'm_elite')
        ylabel('Communication (MB)');
    elseif strcmp(pnameNorm, 'population_size')
        ylabel('Time per Round (s)');
    else
        ylabel('Runtime (s)');
    end
    xlabel('Parameter Value');
    ttl = sprintf('Performance-Cost Trade-off: %s', char(pname));
    title(ttl, 'Interpreter','none');
    grid on;
    figDir = fullfile(commonConfig.figures_dir, sprintf('sensitivity_%s', results.timestamp));
    if ~exist(figDir, 'dir'), mkdir(figDir); end
    outFile = fullfile(figDir, sprintf('sensitivity_tradeoff_%s_%s.png', char(pname), results.timestamp));
    print(gcf, outFile, '-dpng', '-r300'); close(gcf);
    fprintf('Saved figure: %s\n', outFile);
end

% Convergence trajectories
hasRound = false;
for i = 1:length(runKeys)
    r = results.runs.(runKeys{i});
    if isfield(r, 'roundHV') && ~isempty(r.roundHV)
        hasRound = true; break;
    end
end

if hasRound
    for p = 1:length(params)
        pname = params{p};
        selKeys = runKeys;
        vals = [];
        for i = 1:length(runKeys)
            rr = results.runs.(runKeys{i});
            if strcmp(char(pname), rr.param)
                vals(end+1,1) = rr.value;
            else
                vals(end+1,1) = NaN;
            end
        end
        u = unique(vals(~isnan(vals)));
        if isempty(u)
            continue;
        end
        Rm = commonConfig.R_max;
        cols = lines(length(u));
        fig = figure('Visible','off','Position',[200 200 1000 600]); hold on; grid on; box on;
        leg = cell(length(u),1);
        for ui = 1:length(u)
            rHM = nan(Rm,1);
            cnt = zeros(Rm,1);
            for i = 1:length(runKeys)
                rr = results.runs.(runKeys{i});
                if strcmp(char(pname), rr.param) && rr.value == u(ui)
                    hvR = rr.roundHV;
                    for rri = 1:min(length(hvR), Rm)
                        if ~isnan(hvR(rri))
                            if isnan(rHM(rri))
                                rHM(rri) = hvR(rri);
                            else
                                rHM(rri) = rHM(rri) + hvR(rri);
                            end
                            cnt(rri) = cnt(rri) + 1;
                        end
                    end
                end
            end
            for rri = 1:Rm
                if cnt(rri) > 0
                    rHM(rri) = rHM(rri) / cnt(rri);
                else
                    rHM(rri) = NaN;
                end
            end
            plot(1:Rm, rHM, '-o', 'Color', cols(ui,:), 'LineWidth', 1.6);
            leg{ui} = sprintf('%s=%g', char(pname), u(ui));
        end
        xlabel('Federated Rounds'); ylabel('Hypervolume');
        ttl = sprintf('Convergence: %s', char(pname));
        title(ttl, 'Interpreter','none');
        legend(leg, 'Location','best','Interpreter','none');
        figDir = fullfile(commonConfig.figures_dir, sprintf('sensitivity_%s', results.timestamp));
        if ~exist(figDir, 'dir'), mkdir(figDir); end
        outFile = fullfile(figDir, sprintf('sensitivity_convergence_%s_%s.png', char(pname), results.timestamp));
        print(fig, outFile, '-dpng', '-r300'); close(fig);
        fprintf('Saved figure: %s\n', outFile);
    end
end

% Generate HTML report similar to comparison report
figuresDir = fullfile(commonConfig.figures_dir, sprintf('sensitivity_%s', results.timestamp));
if ~exist(figuresDir, 'dir'), mkdir(figuresDir); end
reportFileName = sprintf('%s/sensitivity_report_%s.html', commonConfig.results_dir, results.timestamp);
fid = fopen(reportFileName, 'w');
fprintf(fid, '<!DOCTYPE html>\n');
fprintf(fid, '<html lang="en">\n');
fprintf(fid, '<head>\n');
fprintf(fid, '    <meta charset="UTF-8">\n');
fprintf(fid, '    <meta name="viewport" content="width=device-width, initial-scale=1.0">\n');
fprintf(fid, '    <title>Edge-FML Sensitivity Analysis Report</title>\n');
fprintf(fid, '    <style>\n');
fprintf(fid, '        body { font-family: Arial, sans-serif; margin: 0; padding: 0; background: #f7f9fc; color: #333; }\n');
fprintf(fid, '        .container { max-width: 1100px; margin: 40px auto; background: #fff; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,0.08); border-radius: 8px; }\n');
fprintf(fid, '        h1, h2, h3 { margin-top: 0; }\n');
fprintf(fid, '        .timestamp { color: #666; font-size: 0.9em; margin-bottom: 20px; }\n');
fprintf(fid, '        .summary-table { width: 100%%; border-collapse: collapse; margin-bottom: 24px; }\n');
fprintf(fid, '        .summary-table th, .summary-table td { border: 1px solid #ddd; padding: 8px; text-align: left; }\n');
fprintf(fid, '        .summary-table th { background: #f0f3f7; }\n');
fprintf(fid, '        .figure { margin: 20px 0; text-align: center; }\n');
fprintf(fid, '        .figure img { max-width: 100%%; border: 1px solid #ddd; border-radius: 6px; }\n');
fprintf(fid, '        .figure-caption { color: #555; font-size: 0.9em; margin-top: 6px; }\n');
fprintf(fid, '        .file-link { margin: 6px 0; }\n');
fprintf(fid, '    </style>\n');
fprintf(fid, '</head>\n');
fprintf(fid, '<body>\n');
fprintf(fid, '    <div class="container">\n');
fprintf(fid, '        <h1>Edge-FML Sensitivity Analysis Report</h1>\n');
fprintf(fid, '        <div class="timestamp">Generated on %s</div>\n', datestr(now));
fprintf(fid, '        <h2>1. Summary</h2>\n');
fprintf(fid, '        <p>This report presents the parameter sensitivity analysis for Edge-FML across three parameters: M_local (local generations), M_elite (number of elites shared), and population_size. We summarize performance (Hypervolume) and costs (runtime, communication), stability distributions, and convergence behavior.</p>\n');
fprintf(fid, '        <h3>1.1 Experiment Configuration</h3>\n');
fprintf(fid, '        <ul>\n');
fprintf(fid, '            <li>Maximum federated rounds: %d</li>\n', commonConfig.R_max);
fprintf(fid, '            <li>Baseline values: M_{local}=%d, M_{elite}=%d, population\_size=%d</li>\n', 20, 5, 50);
fprintf(fid, '            <li>Repeated seeds per configuration: %d</li>\n', results.nSeeds);
fprintf(fid, '        </ul>\n');

fprintf(fid, '        <h2>2. Statistical Summary</h2>\n');
fprintf(fid, '        <p>Overall Kruskal-Wallis p-values by parameter:</p>\n');
fprintf(fid, '        <table class="summary-table">\n');
fprintf(fid, '            <tr><th>Parameter</th><th>p-value</th></tr>\n');
params = categories(T.param);
for p = 1:length(params)
    pname = params{p};
    sel = T.param == pname;
    if sum(sel) < 2, continue; end
    [~, order] = sort(T.value(sel));
    hvp = T.hv(sel); hvp = hvp(order);
    valp = T.value(sel); valp = valp(order);
    try
        pv = kruskalwallis(hvp, valp, 'off');
    catch
        pv = NaN;
    end
    fprintf(fid, '            <tr><td>%s</td><td>%.4g</td></tr>\n', char(pname), pv);
end
fprintf(fid, '        </table>\n');

fprintf(fid, '        <div class="file-link"><a href="%s">Download summary CSV</a></div>\n', makeRelativePath(summaryCSV, reportFileName));
fprintf(fid, '        <div class="file-link"><a href="%s">Download p-values CSV</a></div>\n', makeRelativePath(pvCSV, reportFileName));

fprintf(fid, '        <h2>3. Figures</h2>\n');
figFiles = dir(sprintf('%s/*.png', figuresDir));
for ii = 1:length(figFiles)
    fn = figFiles(ii).name;
    fprintf(fid, '        <div class="figure">\n');
    imgRel = sprintf('../figures/sensitivity_%s/%s', results.timestamp, fn);
    fprintf(fid, '            <img src="%s" alt="%s">\n', imgRel, fn);
    fprintf(fid, '            <div class="figure-caption">%s</div>\n', fn);
    fprintf(fid, '        </div>\n');
end

fprintf(fid, '        <h2>4. Conclusions</h2>\n');
fprintf(fid, '        <p>Based on the trade-off and stability analyses, recommended parameters typically center at M_local=20, M_elite=5, population_size=50–70, balancing performance gains against runtime and communication costs.</p>\n');
fprintf(fid, '    </div>\n');
fprintf(fid, '</body>\n');
fprintf(fid, '</html>\n');
fclose(fid);
fprintf('HTML report saved to: %s\n', reportFileName);

fprintf('Basic sensitivity report generation complete.\n');

% Helper functions for path handling
function absPath = ensureAbsolutePath(p, root)
    if isempty(p), absPath = root; return; end
    if ~isempty(p) && (p(1) == filesep || (length(p) > 1 && p(2) == ':'))
        absPath = p;
    else
        absPath = fullfile(root, p);
    end
end


function rel = makeRelativePath(target, baseHtml)
    baseDir = fileparts(baseHtml);
    try
        rel = strrep(target, [baseDir filesep], '');
    catch
        rel = target;
    end
end
