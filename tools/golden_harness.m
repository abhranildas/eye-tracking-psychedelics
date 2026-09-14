function golden = golden_harness(mode, golden_file)
% GOLDEN_HARNESS  Capture or replay golden outputs for Tier-B readability checks.
%   golden = golden_harness('capture', golden_file)
%   golden = golden_harness('replay',  golden_file)
%
%   Calls this repo's three runnable entry points directly -- never through
%   free_view_analyze.m or spem_analyze.m, which are cell scripts that re-parse
%   every subject -- and either saves their reduced outputs to GOLDEN_FILE
%   ('capture') or reloads GOLDEN_FILE and asserts isequal against a fresh run
%   ('replay').
%
%   Entry points, by tranche (docs/repo-cleanup.md sections 2 and 4.2):
%     tranche 1   lib.preprocess_gaze                            (fixate/ibo031_pre.edf)
%     tranche 1   lib.preprocess_gaze + analyze.free_view_measures
%                                                    (free_view/data/gss005_pre.edf)
%     tranche 1   lib.preprocess_gaze + spem_measures            (spem/gss004_pre.edf)
%   The third exercises spem/true_target_traj.m and spem/downsample_traj.m
%   internally, which is how those two get runtime coverage.
%
%   Not covered, by decision recorded in section 4.2: the six *_exp.m files
%   (need Psychtoolbox plus a live EyeLink host), free_view_analyze.m (missing
%   colorbarpzn), spem_analyze.m (10 minutes of disk I/O), free_view_setup.m and
%   saccade_setup.m (unseeded RNG that overwrites shipped .mat artifacts),
%   pre_process.m and +lib/animate_trial.m (no callable entry point), and
%   movie_test.m (aborts by design). Tier-B edits in those are verified by
%   pattern check only.
%
% Inputs
%   mode         'capture' or 'replay', char/string
%   golden_file  path to a .mat file to write to / read from, char/string
% Output
%   golden  struct of reduced entry-point outputs (as captured or as freshly
%           computed, depending on mode). Checksums are sums over all elements
%           with NaNs omitted; sizes are size vectors.
%
% Nothing on these paths draws from the RNG (verified: rand/randn/randi/randperm
% appear only in the two setup scripts), but each block is seeded anyway so the
% harness stays valid once Tier C item 0.3.10 adds seeds.
%
% Requires MATLAB R2024b Update 6 (24.2.0.2923080) and the Edf2Mat add-on. The
% .edf recordings are not in version control; if they or Edf2Mat are missing the
% affected block warns and stores [] rather than erroring.
%
% See also CANON, CHECK_TIER_A, RENAMES

repo = fileparts(fileparts(mfilename('fullpath')));
addpath(repo, fullfile(repo, 'spem'), fullfile(repo, 'free_view'));

seed = 0;   % this repo has no config file; the harness owns the seed

fig_state = get(0, 'DefaultFigureVisible');
set(0, 'DefaultFigureVisible', 'off');
cleanup = onCleanup(@() set(0, 'DefaultFigureVisible', fig_state));  %#ok<NASGU>

have_edf2mat = exist('Edf2Mat', 'class') == 8 || exist('Edf2Mat', 'file') == 2;

% -------------------------------------------------------------------------
% Entry point 1: lib.preprocess_gaze on a fixate recording, no corners.
% -------------------------------------------------------------------------
rec = fullfile(repo, 'fixate', 'ibo031_pre.edf');
if have_edf2mat && isfile(rec)
    rng(seed);
    edf_mat = Edf2Mat(rec);
    [gaze_x, gaze_y, fix_x, fix_y] = lib.preprocess_gaze(edf_mat);
    golden.fixate_gaze_checksum = sum(gaze_x, 'all', 'omitnan') ...
        + sum(gaze_y, 'all', 'omitnan');
    golden.fixate_gaze_size = size(gaze_x);
    golden.fixate_fix_checksum = sum(fix_x, 'all', 'omitnan') ...
        + sum(fix_y, 'all', 'omitnan');
    golden.fixate_fix_size = size(fix_x);
else
    [golden.fixate_gaze_checksum, golden.fixate_gaze_size, ...
        golden.fixate_fix_checksum, golden.fixate_fix_size] = deal([]);
    warning('golden_harness:noInput', ...
        'Edf2Mat or %s not found -- fixate entry point skipped.', rec);
end

% -------------------------------------------------------------------------
% Entry point 2: lib.preprocess_gaze + analyze.free_view_measures.
% -------------------------------------------------------------------------
rec = fullfile(repo, 'free_view', 'data', 'gss005_pre.edf');
results_file = fullfile(repo, 'free_view', 'data', 'free_view_results.mat');
if have_edf2mat && isfile(rec) && isfile(results_file)
    rng(seed);
    loaded = load(results_file, 'free_view_results');
    corners = loaded.free_view_results(1).corners;
    assert(strcmp(loaded.free_view_results(1).name, 'gss005_pre'), ...
        'golden_harness:wrongSubject', ...
        'free_view_results(1) is %s, not the gss005_pre this golden was captured on', ...
        loaded.free_view_results(1).name);
    edf_mat = Edf2Mat(rec);
    [gaze_x, gaze_y, fix_x, fix_y] = lib.preprocess_gaze(edf_mat, 'corners', corners);
    [dwell_tot, dwell, pupil, scan] = ...
        analyze.free_view_measures(edf_mat, gaze_x, gaze_y, fix_x, fix_y);
    golden.free_view_dwell_tot_checksum = sum(dwell_tot, 'all', 'omitnan');
    golden.free_view_dwell_checksum = sum(dwell, 'all', 'omitnan');
    golden.free_view_pupil_checksum = sum(pupil, 'all', 'omitnan');
    golden.free_view_scan_checksum = sum(scan, 'all', 'omitnan');
    golden.free_view_sizes = [size(dwell_tot); size(dwell); size(pupil); ...
        size(scan, 1) size(scan, 2) 1];
else
    [golden.free_view_dwell_tot_checksum, golden.free_view_dwell_checksum, ...
        golden.free_view_pupil_checksum, golden.free_view_scan_checksum, ...
        golden.free_view_sizes] = deal([]);
    warning('golden_harness:noInput', ...
        'Edf2Mat or %s not found -- free_view entry point skipped.', rec);
end

% -------------------------------------------------------------------------
% Entry point 3: lib.preprocess_gaze + spem_measures. Exercises
% true_target_traj.m and downsample_traj.m internally.
% -------------------------------------------------------------------------
rec = fullfile(repo, 'spem', 'gss004_pre.edf');
results_file = fullfile(repo, 'spem', 'spem_results.mat');
if have_edf2mat && isfile(rec) && isfile(results_file)
    rng(seed);
    loaded = load(results_file, 'results');
    corners = loaded.results(1).corners;
    assert(strcmp(loaded.results(1).name, 'gss004_pre'), ...
        'golden_harness:wrongSubject', ...
        'results(1) is %s, not the gss004_pre this golden was captured on', ...
        loaded.results(1).name);
    edf_mat = Edf2Mat(rec);
    [gaze_x, gaze_y] = lib.preprocess_gaze(edf_mat, 'exp_type', 'spem', ...
        'corners', corners, 'calib_sz', 2/3, 'animate', false);
    [err, pupil_sz_mean] = spem_measures(edf_mat, gaze_x, gaze_y);
    golden.spem_err = err(:).';                      % 5 trials, kept whole
    golden.spem_pupil_sz_mean = pupil_sz_mean(:).';  % 5 trials, kept whole
else
    [golden.spem_err, golden.spem_pupil_sz_mean] = deal([]);
    warning('golden_harness:noInput', ...
        'Edf2Mat or %s not found -- spem entry point skipped.', rec);
end

% -------------------------------------------------------------------------

if strcmp(mode, 'capture')
    save(golden_file, 'golden');
elseif strcmp(mode, 'replay')
    ref = load(golden_file, 'golden');
    assert(isequal(ref.golden, golden), 'golden_harness:mismatch', ...
        'golden output changed -- this edit is not behaviour-preserving');
else
    error('golden_harness:mode', 'mode must be ''capture'' or ''replay''');
end
end
