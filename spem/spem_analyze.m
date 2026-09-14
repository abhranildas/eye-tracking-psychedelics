% SPEM_ANALYZE  Measure smooth-pursuit tracking error and pupil size, then compare post with pre.
%
%   Cell-divided interactive workflow: run section by section by hand, with
%   workspace carryover between sections. Not a callable function, and not a
%   top-to-bottom run -- each section depends on the workspace the previous
%   one leaves behind. Three sections, in order: re-parse every recording
%   named in the results struct and fill in its per-trial tracking error and
%   mean pupil size; then match each post session to its pre session by
%   subject name and store the post-minus-pre differences; then plot the
%   distribution of the change in tracking error.
%
%   Section 1 is slow and destructive of nothing but time: it runs EDF2MAT
%   over all 102 recordings, roughly 10 minutes of disk I/O, and writes back
%   into RESULTS. Do not run it as a verification step (docs/repo-cleanup.md
%   section 4.2).
%
% Inputs
%   None as arguments. What the script actually consumes:
%   Files read:
%     spem_results.mat  loaded by section 1. Freezes the variable name
%       `results` and its 7 struct fields `name`, `corners`, `err`,
%       `pupil_sz_mean`, `d_err`, `d_pupil_sz_mean`, `f_pupil_sz_mean`
%       (zone 3, docs/repo-cleanup.md section 4.1.1). The bare local
%       `results` that holds it is free; the load/save string is not.
%     <name>.edf  one EyeLink recording per element of RESULTS, named by
%       RESULTS(i).name, read through EDF2MAT.
%   Working directory: must be spem/, since both the .mat and every .edf are
%     opened by bare relative name.
%   Path: the repo root must be on the MATLAB path for `lib.preprocess_gaze`,
%     and spem/ for SPEM_MEASURES. Nothing in this repo puts them there --
%     Tier C item 0.3.8.
%   Workspace variables required before a section runs: sections 2 and 3 both
%     need the RESULTS produced (or extended) by section 1; section 3 needs
%     the `d_err` fields section 2 writes.
%   Hard-coded constant, whose name does not carry its unit:
%     calib_sz  2/3, DIMENSIONLESS -- the fraction of the screen spanned by
%       the ideal calibration-corner square, NOT a length.
%   `lib.preprocess_gaze`'s name-value names 'exp_type', 'corners',
%     'calib_sz', 'animate' and the value 'spem' are zone-2 frozen string
%     literals and are passed unchanged in section 1; renaming them is
%     Tier C item 0.3.2.
% Output
%   None returned; this is a script. The side effects are the point:
%   Workspace: RESULTS gains `err` and `pupil_sz_mean` (section 1),
%     `d_err`, `d_pupil_sz_mean` and `f_pupil_sz_mean` (section 2), and
%     section 3 leaves `d_err` and `avg_d_err` behind.
%   Disk: none. The `save 'spem_results.mat' results` line after section 1 is
%     commented out, so nothing is persisted automatically.
%   Figures: section 1 redraws the calibrated gaze trace per subject;
%     section 3 draws a histogram of the change in tracking error.
%
%   Units, since no name here carries one: `err` / `tracking_err_px` is
%   pixels (RMS distance between gaze and the true target trajectory, one
%   value per trial); `pupil_sz_mean` is arbitrary EyeLink pupil-area units,
%   neither millimetres nor normalised; `d_*` is a difference in those same
%   units and `f_*` is a dimensionless fractional change.
%
%   Local-versus-frozen-field mismatch, created deliberately and noted here
%   as docs/repo-cleanup.md section 2 requires: the local `err` is renamed to
%   `tracking_err_px` to un-shadow the builtin `err` and to match
%   SPEM_MEASURES' output name after tranche 1, while the struct field
%   `.err` stays frozen. So `results(i_session).err = tracking_err_px;`
%   reads as a mismatch and is meant to. Only Tier C item 0.3.7, which would
%   migrate spem_results.mat, could reconcile the two. The locals `d_err`
%   and `pupil_sz_mean` are deliberately NOT renamed, for the opposite
%   reason: each is written straight into an identically named frozen field,
%   and matching the artifact is worth more there than expanding the name.
%
%   Known bugs, recorded and deliberately NOT fixed here:
%     0.4.1  SPEM_MEASURES indexes the raw pupil-size array with indices
%       computed against the downsampled time base, so every one of the 102
%       `pupil_sz_mean` values this script stores and then differences is
%       computed from the wrong samples. Everything section 2 derives from
%       `pupil_sz_mean` inherits that error.
%     0.4.3  `lib.preprocess_gaze` calls helpers that live in spem/, so
%       section 1 works only because this script is itself run from spem/.
%
% See also SPEM_MEASURES, LIB.PREPROCESS_GAZE, PRE_PROCESS, SPEM_EXP,
%   TRUE_TARGET_TRAJ, EDF2MAT

%% compute mean errors and pupil sizes
load spem_results.mat
calib_sz = 2/3;

for i_session = 1:numel(results)
    name = results(i_session).name   % NOTE: deliberately unsuppressed (item
                                     % 0.2.4) -- this is the script's only
                                     % way to show which subject is being
                                     % processed during the ~10 minute loop.
    edf_mat = Edf2Mat([name '.edf']);
    corners = results(i_session).corners;
    [gaze_x, gaze_y] = lib.preprocess_gaze(edf_mat, ...
        'exp_type', 'spem', 'corners', corners, ...
        'calib_sz', calib_sz, 'animate', false);

    [tracking_err_px, pupil_sz_mean] = spem_measures(edf_mat, gaze_x, gaze_y);
    axis([0 1920 0 1080])
    title(sprintf('%s: %.1f', name, mean(tracking_err_px)))

    % append to the struct. The frozen field .err keeps its name while the
    % local is tracking_err_px -- see the header's mismatch note.
    results(i_session).err = tracking_err_px;
    results(i_session).pupil_sz_mean = pupil_sz_mean;
end

% save 'spem_results.mat' results

%% compute post-pre delta in errors and pupil size

names = {results.name};

% Match anywhere, not just at the end
is_post = contains(names, '_post');
is_pre  = contains(names, '_pre');

idx_post = find(is_post);
idx_pre  = find(is_pre);

% Strip everything from the marker onward
base_post = regexprep(names(is_post), '_post.*$', '');
base_pre  = regexprep(names(is_pre), '_pre.*$', '');

[has_match, match_idx] = ismember(base_post, base_pre);

for i_pair = find(has_match').'
    i_session_post = idx_post(i_pair);
    i_session_pre  = idx_pre(match_idx(i_pair));
    results(i_session_post).d_err = ...
        results(i_session_post).err - results(i_session_pre).err;
    results(i_session_post).d_pupil_sz_mean = ...
        results(i_session_post).pupil_sz_mean - results(i_session_pre).pupil_sz_mean;
    % fractional change in pupil size:
    results(i_session_post).f_pupil_sz_mean = ...
        results(i_session_post).pupil_sz_mean ./ results(i_session_pre).pupil_sz_mean - 1;
end

%% plote change in error
d_err = [results.d_err];
histogram(d_err(:))
avg_d_err = mean(d_err(:));
text(40, 80, sprintf('avg. \\Deltaerror = %.2f', avg_d_err), 'FontSize', 13)
xlabel('\Deltaerror')
set(gca, 'ytick', [], 'ylim', [0 90], 'fontsize', 13)
box off
