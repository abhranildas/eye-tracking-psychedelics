% FREE_VIEW_ANALYZE  Measure free-viewing dwell, scanpath and pupil, then compare post with pre.
%
%   Cell-divided interactive workflow: run section by section by hand, with
%   workspace carryover between sections. Not a callable function, and not a
%   top-to-bottom run -- almost every section reads variables an earlier one
%   left in the workspace, and several sections are exploratory plots that
%   only make sense once the measurement sections above them have been run.
%   Broadly, sections 1-10 build up the FREE_VIEW_RESULTS struct (index sets,
%   date stamps, per-screen dwell / scanpath / pupil measures, the
%   location-bias correction, the per-image sort, the per-participant pupil
%   normalisation, and the post-minus-pre differences) and every section
%   after that is a figure drawn from what those sections stored.
%
%   THIS FILE CANNOT BE RUN ON THIS MACHINE, for two independent reasons,
%   both of them Tier C items rather than anything this cleanup pass may fix:
%     1. COLORBARPZN is missing. It is called 9 times (a third-party diverging
%        colorbar) and `which colorbarpzn` returns nothing here, so every
%        plotting section that uses it errors out. Tier C item 0.3.9.
%     2. The section at "add date stamps" reads a variable `gap` that is
%        never assigned above it, so it depends on a `gap` left in the
%        workspace by some earlier, unrecorded run -- and the variable of
%        that name later in this file is a different quantity in different
%        units. That is bug 0.4.6, and it means there is no correct
%        top-to-bottom order even with the dependency installed.
%   Verification for this file is therefore CHECK_TIER_A plus reading, with
%   no runtime golden at all (docs/repo-cleanup.md section 4.2).
%
% Inputs
%   None as arguments. What the script actually consumes:
%   Files read:
%     free_view_results.mat  loaded by section 1. Freezes the variable name
%       `free_view_results` and its 22 struct fields `name`, `date_manual`,
%       `date_EL`, `gap`, `corners`, `dwell_tot_raw`, `dwell_raw`,
%       `pupil_raw`, `scan`, `corr_dwell_raw`, `dwell`, `corr_dwell`,
%       `pupil`, `mean_pupil`, `pupil_dil_raw`, `pupil_dil`, `d_dwell`,
%       `d_corr_dwell`, `d_scan`, `d_tot_scan`, `f_pupil_dil`,
%       `f_corr_dwell` (zone 3, docs/repo-cleanup.md section 4.1.1).
%     setup/setup_pre.mat, setup/setup_post.mat  frozen variables
%       `exp_IAPS_ids`, `exp_arousals`, `exp_valences`.
%     <name>.edf  one EyeLink recording per element of FREE_VIEW_RESULTS,
%       named by FREE_VIEW_RESULTS(i).name, read through EDF2MAT.
%   Working directory: must be free_view/data/, since free_view_results.mat
%     and the recordings are opened by bare relative name while the two setup
%     files are opened as 'setup/setup_*.mat'.
%   Path: the repo root must be on the MATLAB path for `lib.preprocess_gaze`,
%     free_view/ for `analyze.free_view_measures`, and COLORBARPZN must be
%     installed. Nothing in this repo puts any of them there -- Tier C items
%     0.3.8 and 0.3.9.
%   Workspace variables required before a section runs: every section after
%     the first needs FREE_VIEW_RESULTS; the plotting sections additionally
%     need AROUSALS and VALENCES from section 1, and the regression and
%     scatter sections need DWELL_PRE, CORR_DWELL_PRE, LOG_F_CORR_DWELL and
%     VALENCES_REP built by the sections above them. The one undocumented
%     requirement, and the one that is a genuine defect rather than ordinary
%     cell-script carryover, is the `gap` read in the date-stamp section --
%     see bug 0.4.6 above and the NOTE at that line.
%   `lib.preprocess_gaze`'s name-value name 'corners' is a zone-2 frozen
%     string literal and is passed unchanged; renaming it is Tier C item
%     0.3.2.
% Output
%   None returned; this is a script. The side effects are the point:
%   Workspace: FREE_VIEW_RESULTS is extended in place, field by field, by the
%     measurement sections; the plotting sections leave their intermediate
%     arrays behind as well.
%   Disk: none. No `save` call exists anywhere in this file, so every field
%     computed here is lost when the workspace is cleared.
%   Figures: roughly two dozen, one per plotting block.
%
%   Units, since almost no name here carries one: `dwell`, `dwell_tot` and
%   everything derived from them are SECONDS; `scan` is a scanpath length in
%   PIXELS (a sum of distances between consecutive fixations); `pupil`,
%   `pupil_raw` and `mean_pupil` are ARBITRARY EYELINK PUPIL-AREA UNITS,
%   neither millimetres nor normalised, which is why `pupil_dil` divides by a
%   per-participant mean and is DIMENSIONLESS; `arousals` and `valences` are
%   IAPS 1-9 rating scales, DIMENSIONLESS; `d_*` is a difference in the
%   parent quantity's own units and `f_*` is a dimensionless fractional
%   change; `gap` is a DURATION where it is read from the struct field and a
%   plain number of DAYS after the `seconds(...)/86400` conversion, which is
%   bug 0.4.6's mechanism.
%
%   Local-versus-frozen-field mismatches, created deliberately and noted here
%   as docs/repo-cleanup.md section 2 requires. Only one was created: the
%   local `gap` of the differencing-and-plotting chain is renamed to
%   `session_gap_days`, while the struct field `.gap` stays frozen, so
%   `session_gap_days = [free_view_results(idx_post_matched).gap]';` reads as
%   a mismatch and is meant to. Only Tier C item 0.3.7, which would migrate
%   free_view_results.mat, could reconcile the two. Note also that
%   `session_gap_days` is an accurate name only after the conversion line --
%   before it the variable still holds durations. That is not sloppiness in
%   the rename; it is bug 0.4.6 showing through, and the NOTE at the
%   conversion says so. The opposite decision was taken for `scan`, `dwell`,
%   `corr_dwell`, `pupil` and `mean_pupil`: each is deliberately NOT renamed,
%   because each is written straight into an identically named frozen field,
%   and matching the artifact is worth more than expanding the name. That
%   matches what tranche 1 decided for the same four names inside
%   ANALYZE.FREE_VIEW_MEASURES.
%
%   Known bugs, recorded and deliberately NOT fixed here:
%     0.4.6   `gap` read with no assignment above it, then reassigned from
%       a duration to a plain number of days further down. Re-running the
%       date-stamp section silently shifts every `date_EL`.
%     0.4.17  `arousals` and `valences` are sorted once by setup_pre.mat's
%       IDs in section 1 and then used against both sessions, while the
%       per-image sort section re-sorts each session by its own IDs. Whether
%       the two orderings agree is never checked. Same section, the
%       `dwell = dwell(sort_idx)` line linear-indexes a matrix with an index
%       built column-major over a differently shaped array.
%     0.4.18  the `eval` in the per-image sort section has a trailing
%       comment naming `idxPre`/`idxPost`, the spelling the other driver used
%       before tranche 6 unified the two. The `eval` itself still resolves
%       correctly -- see the NOTE there.
%     0.4.20  the same `plot(valences_rep, z_res, ...)` call runs twice in
%       a row in the regression section, the first without capturing its
%       handle.
%     0.4.5   ANALYZE.FREE_VIEW_MEASURES, which this script calls, uses
%       two different analysis windows in one function, so `dwell_tot_raw`
%       and `pupil_raw` cover a different span than `dwell_raw` and `scan`.
%       Every number below inherits that.
%
% See also ANALYZE.FREE_VIEW_MEASURES, LIB.PREPROCESS_GAZE, FREE_VIEW_EXP,
%   FREE_VIEW_SETUP, SPEM_ANALYZE, EDF2MAT

%% initiate
load free_view_results.mat

% load IAPS id's, arousals, and valences
load('setup/setup_pre.mat');
[~, sort_idx] = sort(exp_IAPS_ids(:));
arousals = exp_arousals(:);
arousals = arousals(sort_idx);
valences = exp_valences(:);
valences = valences(sort_idx);

names = {free_view_results.name};

% find all pre and post indices
is_post = contains(names, '_post');
is_pre  = contains(names, '_pre');

idx_post = find(is_post);
idx_pre  = find(is_pre);

% find matched pre and post indices
base_post = regexprep(names(is_post), '_post.*$', '');
base_pre  = regexprep(names(is_pre), '_pre.*$', '');

[has_match, match_idx] = ismember(base_post, base_pre);

idx_post_matched = idx_post(has_match);
idx_pre_matched  = idx_pre(match_idx(has_match));

% find post control indices and matched pre indices
is_post_control = contains(names, '_post_control');
idx_post_c_matched = find(is_post_control);

base_post_control = regexprep(names(is_post_control), '_post_control.*$', '');

[has_match, match_idx] = ismember(base_post_control, base_pre);

idx_pre_c_matched = idx_pre(match_idx(has_match));

% all post-treatment indices (posts that are not control)
is_post_treatment = is_post & ~is_post_control;   % post but not post_control
idx_post_t = find(is_post_treatment);

% all pre-treatment indices = pre that are not control-pre
is_pre_control = false(size(names));         % mark which pre's are control
is_pre_control(idx_pre_c_matched) = true;    % these pres belong to control
is_pre_treatment = is_pre & ~is_pre_control;
idx_pre_t = find(is_pre_treatment);

% matched treatment indices (both pre and post_t present)
base_post_treatment = regexprep(names(is_post_treatment), '_post.*$', '');
[has_match_treatment, match_idx_treatment] = ismember(base_post_treatment, base_pre);

idx_post_t_matched = idx_post_t(has_match_treatment);
idx_pre_t_matched  = idx_pre(match_idx_treatment(has_match_treatment));

%% add date stamps

% datetime('2024-Nov-22 10:00','InputFormat','yyyy-MMM-dd HH:mm','Format','yyyy-MMM-dd HH:mm')

for i_session = 1:numel(free_view_results)
    % name=free_view_results(i_session).name
    % edf_mat = Edf2Mat([name '.edf']);
    % date_string=edf_mat.Header.date;
    % free_view_results(i_session).date_EL = datetime(date_string, ...
    %     'InputFormat','eee MMM d HH:mm:ss yyyy','Format','yyyy-MMM-dd HH:mm:ss');

    % NOTE: bug 0.4.6. `gap` is read here and assigned nowhere above, so
    % this section only works when a `gap` is already sitting in the
    % workspace -- and the `gap` this file itself produces further down is a
    % different quantity (a per-pair post-minus-pre interval, later converted
    % to days). Running this section twice, or after that conversion, shifts
    % every date_EL again. Left exactly as is; the fix is Tier D.
    free_view_results(i_session).date_EL = free_view_results(i_session).date_EL + gap;
    free_view_results(i_session).date_manual.Format = 'yyyy-MMM-dd HH:mm';
end

%% compute durations, scan lengths and pupil sizes
for i_session = 1:numel(free_view_results)
    name = free_view_results(i_session).name   % NOTE: deliberately
                                     % unsuppressed (item 0.2.4) -- this is
                                     % the script's only way to show which
                                     % subject is being processed during the
                                     % long re-parsing loop.
    edf_mat = Edf2Mat([name '.edf']);
    corners = free_view_results(i_session).corners;
    [gaze_x, gaze_y, fix_x, fix_y] = lib.preprocess_gaze(edf_mat, 'corners', corners);
    title(name)

    % dwell_tot_raw / dwell_raw / pupil_raw / scan keep the names of the
    % frozen fields they are written into -- see the header's mismatch note.
    [dwell_tot_raw, dwell_raw, pupil_raw, scan] = ...
        analyze.free_view_measures(edf_mat, gaze_x, gaze_y, fix_x, fix_y);
    free_view_results(i_session).dwell_tot_raw = dwell_tot_raw;
    free_view_results(i_session).dwell_raw = dwell_raw;
    free_view_results(i_session).pupil_raw = pupil_raw;
    free_view_results(i_session).scan = scan;
end

%% compute location-based dwell prior
dwell_all = cat(4, free_view_results.dwell_raw);
dwell_avg = squeeze(mean(dwell_all, [3 4], 'omitnan'));

figure
imagesc(dwell_avg);
clim([0 max(dwell_avg(:))]);
axis equal tight
colormap(gray);
h_colorbar = colorbar;
h_colorbar.Limits = [0 max(dwell_avg(:))];
set(gca, 'xtick', [], 'ytick', [], 'fontsize', 13)
title 'location bias of dwell time'
%% compute location-bias-corrected dwell fraction
for i_session = 1:numel(free_view_results)
    free_view_results(i_session).corr_dwell_raw = ...
        free_view_results(i_session).dwell_raw ./ dwell_avg;
end

%% sort dwells/pupil sizes by IAPS ID

sess = {'pre', 'post'};
for i_phase = [1 2]
    sess_this = sess{i_phase};

    load(['setup/setup_' sess_this '.mat'], 'exp_IAPS_ids');
    [sorted_IAPS_ids, sort_idx] = sort(exp_IAPS_ids(:));

    % NOTE: bug 0.4.18. The trailing comment below names idxPre/idxPost,
    % the spelling spem_analyze.m used before tranche 6 unified both drivers
    % onto idx_pre/idx_post; no variable of either old name exists anywhere
    % in the repo now. The eval itself is unaffected and still resolves: it
    % builds 'idx_pre' / 'idx_post' from sess_this, and those are exactly the
    % live variable names assigned in the "initiate" section above. Rewriting
    % the eval into something safer is Tier C, not this pass.
    session_idx = eval(['idx_' sess_this]);   % grabs idxPre or idxPost

    % NOTE: `k` keeps its name here on purpose. It labels two unrelated loops
    % in this file -- this one over the sessions of one phase, and the
    % matched-pair loop further down -- and the rename map allows only one
    % row per old name per file, so only the pair loop becomes i_pair.
    for k = session_idx(:).'
        dwell_raw = free_view_results(k).dwell_raw;
        corr_dwell_raw = free_view_results(k).corr_dwell_raw;
        pupil_raw = free_view_results(k).pupil_raw;

        % dwell / corr_dwell / pupil keep the names of the frozen fields they
        % are written into at the bottom of this loop.
        dwell = reshape(permute(dwell_raw, [2 1 3]), 9, []).';
        corr_dwell = reshape(permute(corr_dwell_raw, [2 1 3]), 9, []).';
        pupil = reshape(permute(pupil_raw, [2 1 3]), 9, []).';

        % NOTE: bug 0.4.17. sort_idx is built column-major over the
        % session's own ID array, and is used here to linear-index a matrix
        % of a different shape; and arousals/valences above were sorted once
        % by setup_pre.mat's IDs and are used against both sessions.
        dwell = dwell(sort_idx);
        corr_dwell = corr_dwell(sort_idx);
        pupil = pupil(sort_idx);

        free_view_results(k).dwell = dwell;
        free_view_results(k).corr_dwell = corr_dwell;
        free_view_results(k).pupil = pupil;
    end
end

%% check that total dwell per screen is ~10s for each subject
% for i_session=1:numel(free_view_results)
%     dwell_raw=free_view_results(i_session).dwell_raw;
%     figure
%     plot(squeeze(sum(dwell_raw,[1 2])))
%     % ylim([0 10])
%     title(free_view_results(i_session).name)
% end

%% compute mean pupil size per participant

% first fill in mean pupil size per session
for i_session = 1:numel(free_view_results)
    free_view_results(i_session).mean_pupil = ...
        mean(free_view_results(i_session).pupil, 'omitnan');
end

% now average pre/post for each participant that has both
mean_pupil_both = mean([[free_view_results(idx_pre_matched).mean_pupil];
                        [free_view_results(idx_post_matched).mean_pupil]]);

% fill in for both pre/post
mean_pupil_cells = num2cell(mean_pupil_both);
[free_view_results(idx_pre_matched).mean_pupil] = mean_pupil_cells{:};
[free_view_results(idx_post_matched).mean_pupil] = mean_pupil_cells{:};

%% compute pupil dilations/contractions as fractions of mean pupil size
for i_session = 1:numel(free_view_results)
    free_view_results(i_session).pupil_dil_raw = ...
        free_view_results(i_session).pupil_raw ./ free_view_results(i_session).mean_pupil;
    free_view_results(i_session).pupil_dil = ...
        free_view_results(i_session).pupil ./ free_view_results(i_session).mean_pupil;
end

%% compute post-pre delta in date/dwell/pupil dilation/mean valence/scan lengths

for i_pair = 1:numel(idx_pre_matched)
    i_session_pre  = idx_pre_matched(i_pair);
    i_session_post = idx_post_matched(i_pair);
    free_view_results(i_session_post).d_dwell = ...
        free_view_results(i_session_post).dwell - free_view_results(i_session_pre).dwell;
    free_view_results(i_session_post).d_corr_dwell = ...
        free_view_results(i_session_post).corr_dwell - ...
        free_view_results(i_session_pre).corr_dwell;
    free_view_results(i_session_post).f_corr_dwell = ...
        free_view_results(i_session_post).corr_dwell ./ ...
        free_view_results(i_session_pre).corr_dwell - 1;
    % free_view_results(i_session_post).d_valence = ...
    %     free_view_results(i_session_post).mean_valence - ...
    %     free_view_results(i_session_pre).mean_valence;
    free_view_results(i_session_post).d_scan = ...
        free_view_results(i_session_post).scan - free_view_results(i_session_pre).scan;
    free_view_results(i_session_post).d_tot_scan = ...
        sum(free_view_results(i_session_post).scan) - ...
        sum(free_view_results(i_session_pre).scan);
    free_view_results(i_session_post).gap = ...
        free_view_results(i_session_post).date_EL - free_view_results(i_session_pre).date_EL;
    % fractional change in pupil dilation:
    free_view_results(i_session_post).f_pupil_dil = ...
        free_view_results(i_session_post).pupil_dil ./ ...
        free_view_results(i_session_pre).pupil_dil - 1;
end

%% plot post vs pre absolute (un-location-uncorrected) dwell times

% Concatenate dwell across all matched IDs (all images)
dwell_pre = [free_view_results(idx_pre_matched).dwell];
dwell_post = [free_view_results(idx_post_matched).dwell];

x = dwell_pre(dwell_pre > 0 & dwell_post > 0);
y = dwell_post(dwell_pre > 0 & dwell_post > 0);

% handle zeros separately
x0 = dwell_pre(dwell_pre == 0 | dwell_post == 0);
y0 = dwell_post(dwell_pre == 0 | dwell_post == 0);
x0(~x0) = 5e-3;
y0(~y0) = 5e-3;

figure; hold on
plot(x, y, '.b', 'MarkerSize', .5);
plot(x0, y0, '.k', 'MarkerSize', 1);

axis([3e-3 20 3e-3 20])
set(gca, 'xscale', 'log', 'yscale', 'log', ...
    'xtick', [1e-3 1e-1 1e1], 'ytick', [1e-3 1e-1 1e1], 'fontsize', 13)
xlabel('pre'); ylabel('post');
title('durations (sec)')

% correlation over nonzeros only
mask = dwell_pre > 0 & dwell_post > 0;
r = corr(log10(dwell_pre(mask)), log10(dwell_post(mask)), 'rows', 'complete');
ax = gca;
text(ax, 0.02, 0.98, sprintf('r = %.2f', r), ...
    'Units', 'normalized', 'Color', 'b', 'FontSize', 12);

% histograms of marginals
figure
histogram(log10([x; x0]), 'EdgeColor', 'none')
xlim(log10([3e-3 20]))
set(gca, 'xtick', [], 'ytick', [])
box off

figure
histogram(log10([y; y0]), 'EdgeColor', 'none')
xlim(log10([3e-3 20]))
set(gca, 'xtick', [], 'ytick', [])
box off

% linear histogram of all (pre+post)
% compute log-normal parameters of non-zero dwells
% NOTE: std returns the SD first and the mean second, hence the order here.
[log_dwell_sd, log_dwell_mean] = std(log([x; y]));

dwell_all = [dwell_pre; dwell_post];

figure; hold on
histogram(dwell_all, 'binedges', [0 linspace(.07, 5, 2e2)], ...
    'normalization', 'pdf', 'EdgeColor', 'none')
scale_factor = numel([x; y]) / numel(dwell_all);
fplot(@(x) lognpdf(x, log_dwell_mean, log_dwell_sd) * scale_factor, [0 5], '-k')
legend('data', 'log-normal fit to non-zero durations')
legend box off
xlabel 'total fixation time (s)'
set(gca, 'ytick', [], 'fontsize', 13)

%% fractional change in corrected (intentional) dwell times vs absolute pre-dwell times
% variable x is absolute dwell, because that's what determines memory impact

[~, idx_t_in_all] = ismember(idx_pre_t_matched, idx_pre_matched);
[~, idx_c_in_all] = ismember(idx_pre_c_matched, idx_pre_matched);

corr_dwell_pre = [free_view_results(idx_pre_matched).corr_dwell];
corr_dwell_post = [free_view_results(idx_post_matched).corr_dwell];

% The local is session_gap_days while the frozen field stays .gap -- see the
% header's mismatch note. Until the conversion further down it still holds
% durations, not days; that discrepancy is bug 0.4.6.
session_gap_days = [free_view_results(idx_post_matched).gap]';

f_corr_dwell = corr_dwell_post ./ corr_dwell_pre;

% replace +/- inf with max value:
log_f_corr_dwell = log10(f_corr_dwell);
log_f_corr_dwell(isinf(log_f_corr_dwell)) = nan;

clim_upper = max(log_f_corr_dwell(isfinite(log_f_corr_dwell)));
clim_lower = min(log_f_corr_dwell(isfinite(log_f_corr_dwell)));

valences_rep = repmat(valences, [1 size(corr_dwell_pre, 2)]);

% plot all views (3D plot)
figure
plot3(dwell_pre(:), valences_rep(:), log_f_corr_dwell(:), '.k', 'MarkerSize', 1);
xlabel 'absolute pre dwell (s)'
ylabel 'valences'
zlabel 'log 10 (post corr. dwell / pre corr. dwell)'
set(gca, 'xscale', 'log', 'fontsize', 13)
grid on

% plot all views (colour plot)
figure
scatter(dwell_pre(:), valences_rep(:), 3, log_f_corr_dwell(:), ...
    'filled', 'MarkerEdgeColor', 'none');
xlabel 'absolute pre dwell (s)'
ylabel 'valences'
title 'log 10 (post corr. dwell / pre corr. dwell)'
colorbarpzn(clim_lower, clim_upper, 'colorP', [1 0 0], 'colorN', [0 0 0]);
set(gca, 'xscale', 'log', 'fontsize', 13)

% average across subjects (this favours dependence on valence by removing fluctuation, and
% disfavours dependence on pre-dwell by washing out the dependence function)
% clim_upper=max(mean(log_f_corr_dwell,2,'omitnan'));
% clim_lower=min(mean(log_f_corr_dwell,2,'omitnan'));
% figure
% scatter(mean(dwell_pre,2), valences,10, ...
%     mean(log_f_corr_dwell,2,'omitnan'),'filled','MarkerEdgeColor','none');
% xlabel 'absolute pre dwell (s)'
% ylabel 'valences'
% title 'log 10 (post corr. dwell / pre corr. dwell)'
% h_colorbar_pzn=colorbarpzn(clim_lower,clim_upper,'colorP',[1 0 0],'colorN',[0 0 0]);
% set(gca,'xscale','log','fontsize',13)

% figure
% r=corr(dwell_pre(:), log_f_corr_dwell(:), 'rows', 'complete');
% plot(dwell_pre, f_corr_dwell,'.k','MarkerSize',1)
% ax = gca;
% text(ax, 0.02, 0.98, sprintf('r = %.2f', r), ...
%     'Units','normalized','FontSize',12);
% set(gca,'xscale','log','YScale','log','fontsize',13)
% yline(1)
% xlabel 'absolute pre dwell (s)'
% ylabel 'post corr. dwell / pre corr. dwell'
% title 'dwell change vs pre-dwell (memory effect)'

figure; hold on
r = corr(dwell_pre(:), log_f_corr_dwell(:), 'rows', 'complete');

% NOTE: bug 0.4.6's unit change happens on the next line -- the variable
% goes from a duration to a plain number of days here, and only from here on
% does its name describe it.
session_gap_days = seconds(session_gap_days) / 86400;
session_gap_days_rep = repmat(session_gap_days(:).', size(dwell_pre, 1), 1);

% colour gradient scatter of treatment folks
scatter(reshape(dwell_pre(:, idx_t_in_all), [], 1), ...
    reshape(f_corr_dwell(:, idx_t_in_all), [], 1), 30, ...
    reshape(session_gap_days_rep(:, idx_t_in_all), [], 1), '.');

% flat colour scatter of control folks
plot(reshape(dwell_pre(:, idx_c_in_all), [], 1), ...
    reshape(f_corr_dwell(:, idx_c_in_all), [], 1), '.w', 'markersize', 4);

% --- custom red-to-blue colormap ---
n_colors = 256;
red_to_blue = [linspace(1, 0, n_colors)', ...   % R: 1 -> 0
    zeros(n_colors, 1), ...                     % G: 0
    linspace(0, 1, n_colors)'];                 % B: 0 -> 1
colormap(gca, red_to_blue);                     % apply to current axes
% -----------------------------------

ax = gca;
ax.Color = .7*[1 1 1];
text(ax, 0.02, 0.98, sprintf('r = %.2f', r), ...
    'Units', 'normalized', 'FontSize', 12);
set(gca, 'XScale', 'log', 'YScale', 'log', 'FontSize', 13)
yline(1)
xlabel 'absolute pre dwell (s)'
ylabel 'post corr. dwell / pre corr. dwell'
title 'dwell change vs pre-dwell (memory effect)'

h_colorbar = colorbar;
clim([min(session_gap_days(idx_t_in_all)) max(session_gap_days(idx_t_in_all))])
ylabel(h_colorbar, 'gap (days)')

%% plot average dwell and its change

% average corrected dwell (pre) vs arousal and valence
corr_dwell_pre = mean([free_view_results(idx_pre).corr_dwell], 2);
clim_upper = max(corr_dwell_pre(:));
clim_lower = min(corr_dwell_pre(:));
figure
scatter(arousals, valences, [], corr_dwell_pre, ...
    'filled', 'MarkerEdgeColor', .5*[1 1 1]);
% NOTE: the handle is deliberately not captured (Tier B item 0.2.3 -- it was
% assigned and never read). Re-capturing it is what the two lines below need.
colorbarpzn(clim_lower, clim_upper, ...
    'colorP', [1 0 0], 'colorN', [0 0 0], 'full', 1);
% h_colorbar_pzn.Limits=[0 2.3];
% h_colorbar_pzn.Ticks=[0 1 2];
xlabel 'arousal'
ylabel 'valence'
title 'location-corrected dwell factor (pre)'
set(gca, 'fontsize', 13)

% average corrected dwell (post) vs arousal and valence
corr_dwell_post = mean([free_view_results(idx_post).corr_dwell], 2);
clim_upper = max(corr_dwell_post(:));
clim_lower = min(corr_dwell_post(:));
figure
scatter(arousals, valences, [], corr_dwell_post, ...
    'filled', 'MarkerEdgeColor', .5*[1 1 1]);
% NOTE: handle deliberately not captured, as above (Tier B item 0.2.3).
colorbarpzn(clim_lower, clim_upper, ...
    'colorP', [1 0 0], 'colorN', [0 0 0], 'full', 1);
% h_colorbar_pzn.Limits=[0 2.3];
% h_colorbar_pzn.Ticks=[0 1 2];
xlabel 'arousal'
ylabel 'valence'
title 'location-corrected dwell factor (post)'
set(gca, 'fontsize', 13)

% average location-corrected dwell change vs arousal and valence
d_corr_dwell_avg = mean([free_view_results.d_corr_dwell], 2, 'omitnan');
clim_upper = max(d_corr_dwell_avg(:));
clim_lower = min(d_corr_dwell_avg(:));
figure
scatter(arousals, valences, [], d_corr_dwell_avg, ...
    'filled', 'MarkerEdgeColor', .5*[1 1 1]);
xlabel 'arousal'
ylabel 'valence'
title 'avg. change in location-corrected dwell factor'
% NOTE: handle deliberately not captured (Tier B item 0.2.3).
colorbarpzn(clim_lower, clim_upper, ...
    'colorP', [1 0 0], 'colorN', [0 0 0]);
% h_colorbar_pzn.Ticks=[-1 0 1];
set(gca, 'fontsize', 13)

% dwell change against only valence
figure; hold on
h1 = plot(valences_rep, log_f_corr_dwell, '.k', 'MarkerSize', 1);
h2 = plot(valences, mean(log_f_corr_dwell, 2, 'omitnan'), '.r', 'MarkerSize', 6);
r = corr(valences_rep(:), log_f_corr_dwell(:), 'rows', 'complete');
ax = gca;
text(ax, 0.02, 0.98, sprintf('r = %.4f', r), ...
    'Units', 'normalized', 'FontSize', 12);
xlabel 'valence'
ylabel 'log 10 (post corr. dwell / pre corr. dwell)'
title 'dwell change vs valence'
legend([h1(1) h2], {'all views', 'avg across subjects'});
legend boxoff
set(gca, 'fontsize', 13)

%% multiple linear regression to see the effect of valence vs memory

% Treat these as x, y, z
x = valences_rep(:);
y = log10(dwell_pre(:));
z = log_f_corr_dwell(:);

% Keep only rows where all three are finite (removing nans)
mask = isfinite(x) & isfinite(y) & isfinite(z);
x = x(mask);
y = y(mask);
z = z(mask);

% compute each pairwise correlation coeff:
r_xy = corr(x, y);
r_xz = corr(x, z);
r_yz = corr(y, z);

% Standardize each variable (z-scoring)
x_std = (x - mean(x)) ./ std(x);
y_std = (y - mean(y)) ./ std(y);
z_std = (z - mean(z)) ./ std(z);

% Design matrix: standardized x and y (no intercept because all variables
% are standardized)
design_std = [x_std y_std];

% Multiple regression: z_std ~ x_std + y_std
beta_std = design_std \ z_std;    % OLS solution

% NOTE: the next four statements are deliberately unsuppressed (item 0.2.4).
% They are the only way to read the regression results when the section is
% run interactively, and the comment below asks the reader to compare them.
beta_x_std = beta_std(1)   % standardized beta for x (valences_rep)
beta_y_std = beta_std(2)   % standardized beta for y (dwell_pre)

% check that betas match the formulas based on correlation coefficients:
beta_corr(1) = (r_xz - r_xy*r_yz) / (1 - r_xy^2)
beta_corr(2) = (r_yz - r_xz*r_xy) / (1 - r_xy^2)

% % (Optional) Get R^2 (proportion of variance explained by model)
% z_hat = design_std * beta_std;
% R2 = 1 - sum((z_std - z_hat).^2) / sum((z_std - mean(z_std)).^2);

% regress dwell change on memory
design_mem = [ones(numel(y), 1) y];   % new design matrix
beta_mem = design_mem \ z;
z_hat = design_mem * beta_mem;

% plot the regression
figure; hold on
plot3(x, y, z, '.k', 'MarkerSize', 1);
plot3(x, y, z_hat, '.r', 'MarkerSize', 1);
xlabel 'valences'
ylabel 'absolute pre dwell (s)'
zlabel 'log 10 (post corr. dwell / pre corr. dwell)'
set(gca, 'fontsize', 13)
grid on

% remove memory-dependence
z_hat = log10(dwell_pre)*beta_mem(2) + beta_mem(1);
z_res = log_f_corr_dwell - z_hat;

figure; hold on
% NOTE: bug 0.4.20. The next two lines draw the identical plot twice, the
% first without capturing its handle. Left as is; the fix is Tier D.
plot(valences_rep, z_res, '.k', 'MarkerSize', 1)
h1 = plot(valences_rep, z_res, '.k', 'MarkerSize', 1);
h2 = plot(valences, mean(z_res, 2, 'omitnan'), '.r', 'MarkerSize', 6);
r = corr(valences_rep(:), z_res(:), 'rows', 'complete');
ax = gca;
text(ax, 0.02, 0.98, sprintf('r = %.4f', r), ...
    'Units', 'normalized', 'FontSize', 12);
xlabel 'valence'
ylabel 'memory-corrected dwell change'
title 'memory-corrected dwell change vs valence'
legend([h1(1) h2], {'all views', 'avg across subjects'});
legend boxoff
set(gca, 'fontsize', 13)
ylim([-3 3])

%% scanpath length

% for i_session=1:numel(free_view_results)
%     figure
%     plot(free_view_results(i_session).scan_len,'-o')
%     ylim([0 2.5e4])
% end

% plot scan-lengths vs avg. arousal per screen

% pre
load('setup/setup_pre.mat', 'exp_arousals');
arousal_screen_pre = mean(exp_arousals, 2);
scan_pre = vertcat(free_view_results(idx_pre).scan);

figure
plot(arousal_screen_pre, scan_pre, '.k', 'MarkerSize', 1)
ylim([0 2.5e4])
xlabel 'avg. arousal of the screen'
ylabel 'scanpath length'
title pre

% post
load('setup/setup_post.mat', 'exp_arousals');
arousal_screen_post = mean(exp_arousals, 2);
scan_post = vertcat(free_view_results(idx_post).scan);

figure
plot(arousal_screen_post, scan_post, '.k', 'MarkerSize', 1)
ylim([0 2.5e4])
xlabel 'avg. arousal of the screen'
ylabel 'scanpath length'
title post

% deltas in scanpath
figure
histogram([free_view_results.d_scan])
xlabel 'delta scanpath length'
xline(0)
set(gca, 'ytick', [], 'fontsize', 13)

% overall pre and post distributions
figure; hold on
histogram(scan_pre, 'Normalization', 'pdf', 'EdgeColor', 'none')
histogram(scan_post, 'Normalization', 'pdf', 'EdgeColor', 'none')
xlabel 'scanpath length'
legend('pre', 'post')
set(gca, 'ytick', [], 'fontsize', 13)

% correlation between pupil dilation and scanpath length

pupil_dil_all = cat(4, free_view_results.pupil_dil_raw);
pupil_dil_all = squeeze(mean(pupil_dil_all, [1 2], 'omitnan'))';

scan_all = vertcat(free_view_results.scan);
figure
plot(pupil_dil_all(:), scan_all(:), '.k', 'markersize', 1)
xlabel 'avg. pupil dilation per screen'
ylabel 'scanpath length'

%% plot of dwell delta against valence and participant
delta = [free_view_results.d_corr_dwell];

n_subj = size(delta, 2);

% Create grids for participant number (x) and valence (y)
[participant_grid, valence_grid] = meshgrid(1:n_subj, valences);

% Scatter plot
figure;
scatter(participant_grid(:), valence_grid(:), 10, delta(:), 'filled');

xlabel('Participant');
ylabel('Valence');
clim_upper = max(delta(:));
clim_lower = min(delta(:));
colorbarpzn(clim_lower, clim_upper, 'colorP', [1 0 0], 'colorN', [0 0 0]);
title('Dwell time change');

%% plot post vs pre pupil dilations
% Collect matched indices
% iposts = idx_post(has_match);
% ipres  = idx_pre(match_idx(has_match));
%
% % mean pupil size
%
% % Concatenate pupil dilations across all matched IDs (all images)
% preC  = arrayfun(@(i) free_view_results(i).pupil_dil(:), ipres,  'uni', 0);
% postC = arrayfun(@(i) free_view_results(i).pupil_dil(:), iposts, 'uni', 0);
% pre_all  = vertcat(preC{:});
% post_all = vertcat(postC{:});
%
% r=corrcoef(pre_all,post_all,'Rows', 'complete'); r=r(1,2);
%
% % Plot: post vs pre (one dot per image per subject)
% figure; plot(pre_all, post_all, '.k','MarkerSize',1); hold on
% axis equal
% refline(1,0)
% xlabel('pre'); ylabel('post');
% title(sprintf('pupil dilations, r=%f',r))

%% plot pupil vs participant and location

% absolute pupil size
pupil_all = cat(4, free_view_results.pupil_raw);
pupil_avg = squeeze(mean(pupil_all, 3, 'omitnan'));
pupil_avg = reshape(permute(pupil_avg, [2 1 3]), 9, [])';
figure
imagesc(pupil_avg)
colorbar
xlabel 'screen location'
ylabel 'participant'
title 'pupil size'
set(gca, 'fontsize', 13)

% pupil dilation
pupil_all = cat(4, free_view_results.pupil_dil_raw);
pupil_avg = squeeze(mean(pupil_all, 3, 'omitnan'));
pupil_avg = reshape(permute(pupil_avg, [2 1 3]), 9, [])';
figure
h_image = imagesc(pupil_avg);
clim_lower = min(pupil_avg(:));
clim_upper = max(pupil_avg(:));
% NOTE: handle deliberately not captured (Tier B item 0.2.3).
colorbarpzn(clim_lower, clim_upper, ...
    'colorP', [0 0 1], 'colorN', [1 0 0], 'full', 1);

% make nans black
set(h_image, 'AlphaData', ~isnan(pupil_avg));
set(gca, 'Color', [0 0 0]);

xlabel 'screen location'
ylabel 'participant'
title 'pupil dilation'
set(gca, 'fontsize', 13)

% location-based pupil-dilation prior
pupil_loc_avg = squeeze(mean(pupil_all, [3 4], 'omitnan'));

figure
imagesc(pupil_loc_avg);
clim([0 max(pupil_loc_avg(:))]);
axis equal tight
colormap(gray);
h_colorbar = colorbar;
% h_colorbar.Limits = [0 max(pupil_loc_avg(:))];
set(gca, 'xtick', [], 'ytick', [], 'fontsize', 13)
title 'location-based mean pupil dilation'

%% plot pupil vs participant and image

% absolute pupil size
pupil_all = [free_view_results.pupil]';
figure
imagesc(pupil_all)
colorbar
xlabel 'image'
ylabel 'participant'
title 'pupil size'
set(gca, 'fontsize', 13)

% pupil dilation
pupil_all = [free_view_results.pupil_dil]';
figure
h_image = imagesc(pupil_all);
clim_lower = min(pupil_all(:));
clim_upper = max(pupil_all(:));
% NOTE: handle deliberately not captured (Tier B item 0.2.3).
colorbarpzn(clim_lower, clim_upper, ...
    'colorP', [0 0 1], 'colorN', [1 0 0], 'full', 1);

% make nans black
set(h_image, 'AlphaData', ~isnan(pupil_all));
set(gca, 'Color', [0 0 0]);

xlabel 'image'
ylabel 'participant'
title 'pupil dilation'
set(gca, 'fontsize', 13)

%% plot average pupil dilation and its change

% average across both pre and post
pupil_dil_mean = mean([free_view_results.pupil_dil], 2, 'omitnan');
figure
scatter(arousals, valences, [], pupil_dil_mean, ...
    'filled', 'MarkerEdgeColor', .5*[1 1 1]);
clim_lower = min(pupil_dil_mean);
clim_upper = max(pupil_dil_mean);
% NOTE: handle deliberately not captured (Tier B item 0.2.3).
colorbarpzn(clim_lower, clim_upper, ...
    'colorP', [1 0 0], 'colorN', [0 0 0], 'full', 1);
% h_colorbar_pzn.Ticks=[1000 1200];
xlabel 'arousal'
ylabel 'valence'
title 'avg. pupil dilation'
set(gca, 'fontsize', 13)

figure
f_pupil_dil_avg = 100*mean([free_view_results.f_pupil_dil], 2, 'omitnan');
scatter(arousals, valences, [], f_pupil_dil_avg, ...
    'filled', 'MarkerEdgeColor', .5*[1 1 1]);
clim_lower = min(f_pupil_dil_avg);
clim_upper = max(f_pupil_dil_avg);
xlabel 'arousal'
ylabel 'valence'
title 'avg. change in pupil dilation'
h_colorbar_pzn = colorbarpzn(clim_lower, clim_upper, ...
    'colorP', [1 0 0], 'colorN', [0 0 0], 'full', 0);
h_colorbar_pzn.Ticks = -20:10:10;
h_colorbar_pzn.TickLabels = {'-20%', '-10%', '0', '+10%'};
set(gca, 'fontsize', 13)
