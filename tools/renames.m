function map = renames(file)
% RENAMES  The repo-wide zone-1 rename map, scoped to one file.
%   map = renames(file)
%
% Inputs
%   file  path or bare filename of the .m file about to be checked, char/string.
%         Only the basename is used, so a full path or 'spem_exp.m' both work.
% Output
%   map  Nx2 cell array, {new_name, old_name}, holding exactly the rows that
%        apply to FILE. Ready to pass straight to CHECK_TIER_A. Returns a 0x2
%        cell for a file with no renames.
%
% Usage, and the reason it takes a file:
%
%   check_tier_a(old_file, new_file, renames(new_file))
%
% The map is deliberately NOT repo-wide-flat. CHECK_TIER_A reverse-substitutes
% every NEW name found in canon(new_file) back to its old name, so a row is
% unsafe in any file where its new name already exists as a different
% identifier. This repo has live instances: n_trials is the new name for
% nTrials in saccade_exp.m but is already a distinct variable in spem_exp.m and
% spem_measures.m; phase_x is the new name for phaseX in spem_solo_exp.m but is
% already a variable in spem_exp.m; idx_pre is the new name for idxPre in
% spem_analyze.m but already exists in free_view_analyze.m; screen_width_px is
% the new name for three different old spellings in three different files. A
% flat map would turn those into false check failures. Scoping by file is what
% makes the four-spellings-into-one merges expressible at all.
%
% Two rules the map's shape enforces, binding on every tranche:
%   1. Within one file, at most one row per old name. Where an old name means
%      two different things in one file (i at preprocess_gaze.m:132 vs :240,
%      k at free_view_analyze.m:115 vs :167, gap at free_view_analyze.m:67 vs
%      :248-335), only ONE cluster of sites is renamed and the other keeps the
%      old name. Reverse substitution then still reconstructs the original
%      exactly. Adding a second row for the same old name trips
%      ASSERT_RENAME_BIJECTION -- that is the check working, not a nuisance.
%   2. Within one file, at most one row per new name. Two old names cannot
%      merge into one new name in the same file (hcb and cb -- see below).
%
% Scope: zone 1 only (file-local variables). Nothing from zone 2 (the
% preprocess_gaze name-value string literals, deferred to Tier C item 0.3.2) or
% zone 3 (the frozen save/load names, Tier C item 0.3.7) appears here. Struct
% fields are excluded by CHECK_TIER_A's own negative lookbehind, so a local
% variable may be renamed while a frozen field of the same name stays.
%
% Source: docs/repo-cleanup.md section 4.1.1, zone 1 table, transcribed with the
% four deviations recorded in that document's section 4.1.3 tranche-0 entry.
%
% See also CHECK_TIER_A, ASSERT_RENAME_BIJECTION, CANON

narginchk(1, 1);
[~, stem, ext] = fileparts(char(file));
base = [stem ext];

exp_files = {'fixate_exp.m', 'free_view_exp.m', 'saccade_exp.m', ...
    'saccade_lr_exp.m', 'spem_exp.m', 'spem_solo_exp.m'};
spem_pair = {'spem_exp.m', 'spem_solo_exp.m'};
analyzers = {'free_view_analyze.m', 'spem_analyze.m'};
measures  = {'free_view_measures.m', 'spem_measures.m'};

pg  = {'preprocess_gaze.m'};
fva = {'free_view_analyze.m'};
sa  = {'spem_analyze.m'};
fve = {'free_view_exp.m'};
fvs = {'free_view_setup.m'};
fvm = {'free_view_measures.m'};
sm  = {'spem_measures.m'};
dt  = {'downsample_traj.m'};
ttt = {'true_target_traj.m'};
pp  = {'pre_process.m'};
mt  = {'movie_test.m'};
sse = {'spem_solo_exp.m'};
at  = {'animate_trial.m'};

% {new_name, old_name, files the row applies to}
T = {
% --- +lib/preprocess_gaze.m: the densest single-capital naming in the repo ---
    'samples',              'S',                pg
    'corner_label',         'L',                pg
    'corner_colors',        'C',                pg
    'observed_px',          'U',                pg
    'ideal_px',             'V',                pg
    'dlt_matrix',           'A',                pg
    'dlt_null_basis',       'VV',               pg
    'homography_vec',       'hvec',             pg
    'homography',           'H',                pg
    'pts_homog',            'P',                pg
    'pts_homog_mapped',     'Pp',               pg
    'blink_start_ms',       'b_st',             pg
    'blink_end_ms',         'b_en',             pg
    'not_blink',            'nb',               pg
    'gaze_x_base',          'xb',               pg
    'gaze_y_base',          'yb',               pg
    'gaze_x_base_noblink',  'xb_nb',            pg
    'gaze_y_base_noblink',  'yb_nb',            pg
    'gaze_x_base_blink',    'xb_bk',            pg
    'gaze_y_base_blink',    'yb_bk',            pg
    'msg_time_ms',          'msgT',             pg
    'msg_text',             'msgS',             pg
    'label',                'lab',              pg
    'label_eff',            'labEff',           pg
    'label_eff_prev',       'prevLabEff',       pg
    'base_x',               'xB',               pg
    'base_y',               'yB',               pg
    'blink_x',              'xR',               pg
    'blink_y',              'yR',               pg
    'seg_x',                'xK',               pg
    'seg_y',                'yK',               pg
    'corner_intervals_ms',  'cornerIntervals',  pg
    'corner_sample_idx',    'cornerIdx',        pg
    'corner_start_ms',      'cornerStartsT',    pg
    'trial_end_ms',         'trialEndsT',       pg
    'is_corner_start',      'isCornerStart',    pg
    'is_trial_end',         'isTrialEnd',       pg
    'next_end_idx',         'nextEndIdx',       pg
    'is_corner_sample',     'maskCorner',       pg
    'i_point',              'i',                pg   % the :132 correspondence loop only
% --- +lib/preprocess_gaze.m, added in tranche 1: the camelCase leftovers and
%     the one- to three-character locals the section 4.1.1 table did not cover.
%     k is deliberately absent: it labels six unrelated loops in this one file
%     (:38, :68, :80, :93, :195, :217), and rule 1 allows only one row per old
%     name per file, so it keeps its name everywhere. ---
    'draw_screen_rect',     'drawRect',         pg
    'is_blink',             'isBlink',          pg
    'h_base',               'hBase',            pg
    'h_blink',              'hBlink',           pg
    'h_seg',                'hSeg',             pg
    'h_gaze',               'hGaze',            pg
    'h_target',             'hTrue',            pg
    'interval_start_ms',    'st',               pg
    'interval_end_ms',      'en',               pg
    'i_first',              'i1',               pg
    'i_last',               'i2',               pg
    'i_corner_first',       'idx1',             pg
    'i_corner_last',        'idx2',             pg
    'i_row',                'r',                pg
    'n_points',             'n',                pg
    'x_obs',                'x_h',              pg
    'y_obs',                'y_h',              pg
    'x_ideal',              'u_h',              pg
    'y_ideal',              'v_h',              pg
    'x_grid_line',          'xx',               pg
    'y_grid_line',          'yy',               pg
    'is_valid',             'valid',            pg
    'observed_corners_px',  'obs',              pg
    'ideal_corners_px',     'src',              pg
    'plot_pad_px',          'pad',              pg
    'ax_static',            'ax1',              pg
    'ax_animation',         'ax2',              pg
% --- free_view/free_view_analyze.m ---
    'clim_upper',           'ulim',             fva
    'clim_lower',           'llim',             fva
    'h_colorbar_pzn',       'hcb',              fva
    'h_colorbar',           'cb',               fva
    'h_image',              'hImg',             fva
    'i_session',            'idx',              fva
    'i_phase',              'i',                fva
    'i_pair',               'k',                fva   % the :167 pair loop only
    'session_idx',          'idxVec',           fva
    'session_gap_days',     'gap',              fva   % the :248-335 chain only
    'beta_std',             'beta',             fva
    'design_mem',           'Y',                fva
    'design_std',           'X',                fva
    'participant_grid',     'participantGrid',  fva
    'valence_grid',         'valenceGrid',      fva
    'n_colors',             'nColors',          fva
    'red_to_blue',          'cmap',             fva
    'is_pre_control',       'isPre_c',          fva
    'is_post_control',      'isPost_c',         fva
    'is_pre_treatment',     'isPre_t',          fva
    'is_post_treatment',    'isPost_t',         fva
    'base_post_control',    'basePost_c',       fva
    'base_post_treatment',  'basePost_t',       fva
    'has_match_treatment',  'tf_t',             fva
    'match_idx_treatment',  'loc_t',            fva
% --- spem/spem_analyze.m: the pre/post vocabulary, unified onto the
%     free_view_analyze.m spelling (which already uses idx_pre/idx_post) ---
    'idx_pre',              'idxPre',           sa
    'idx_post',             'idxPost',          sa
    'i_session',            'idx',              sa
    'i_pair',               'k',                sa
% --- shared by both analysis drivers ---
    'base_pre',             'basePre',          analyzers
    'base_post',            'basePost',         analyzers
    'is_pre',               'isPre',            analyzers
    'is_post',              'isPost',           analyzers
    'has_match',            'tf',               analyzers
    'match_idx',            'loc',              analyzers
% --- added in tranche 6. ipre/ipost are the two struct indices of one
%     matched pre/post pair and are spelled identically in both drivers, so
%     they unify alongside base_pre/base_post/is_pre/is_post above. The names
%     are i_session_pre / i_session_post rather than i_pre / i_post so they
%     read as variants of i_session (the new name for idx, which indexes the
%     same struct) and cannot be mistaken for idx_pre / idx_post, which are
%     the whole index VECTORS. ---
    'i_session_pre',        'ipre',             analyzers
    'i_session_post',       'ipost',            analyzers
% --- free_view/free_view_analyze.m, added in tranche 6. gap_rep follows gap
%     into the session_gap_days chain (:248-335) so the pair does not end up
%     half-renamed; s/m/c are the file's last one-character locals, each
%     confined to a single cluster, so rule 1 permits a row for each. Note
%     [s, m] = std(...) returns the SD first and the mean second, which is
%     exactly the confusion the rename removes. ---
    'session_gap_days_rep', 'gap_rep',          fva
    'log_dwell_sd',         's',                fva
    'log_dwell_mean',       'm',                fva
    'mean_pupil_cells',     'c',                fva
% --- the two measures functions ---
    'tracking_err_px',      'err',              [sm, sa]
    'screen_width_px',      'screen_width',     fvm
    'screen_height_px',     'screen_height',    fvm
% --- the analysis chain, added in tranche 1. The zone-2 output contract of
%     lib.preprocess_gaze (gaze_x/gaze_y/fix_x/fix_y) and edf_mat are kept, by
%     the section 4.1.1 recommendation; the fix_x/fix_y rows below rename only
%     free_view_measures.m's per-trial LOCALS at :101-113, which shadow the
%     inputs of the same name from the first loop iteration onward. The inputs
%     themselves (:1, :26) keep their contract names. ---
    'tracking_err_px_this', 'err_this',         sm
    'sample_rate_hz',       'samp_rate',        fvm
    'fix_x_this',           'fix_x',            fvm
    'fix_y_this',           'fix_y',            fvm
    'i_x_bin',              'x',                fvm
    'i_y_bin',              'y',                fvm
    'i_target',             'ia',               dt
    'i_gaze',               'ib',               dt
    'i_msg',                'i',                ttt
    'target_pos_pattern',   'pat',              ttt
    'coord_tokens',         'tok',              ttt
    'x_px',                 'xv',               ttt
    'y_px',                 'yv',               ttt
% --- the six *_exp.m files ---
    'tracker_version',      'v',                exp_files
    'tracker_version_str',  'vs',               exp_files
    'tracker_version_digits', 'vsn',            exp_files
    'open_file_status',     'res',              exp_files
    'win_width_px',         'winWidth',         exp_files
    'win_height_px',        'winHeight',        exp_files
    'i_corner',             'iCorner',          exp_files
    'i_trial',              'iTrial',           [exp_files, measures]
    'screen_number',        'screenNumber',     exp_files
    'n_trials',             'nTrials',          {'saccade_exp.m', ...
                                                 'saccade_lr_exp.m', ...
                                                 'free_view_exp.m', ...
                                                 'saccade_setup.m'}
% --- the saccade pair, added in tranche 2. msg1/msg2 are renamed after the
%     trial variable each one carries, so the row is necessarily per-file:
%     saccade_lr_exp.m needs msg_target_dir and the spem pair need msg_freq_x
%     and msg_freq_y. Tranches 3 and 4 add those rows themselves. ---
    'line_width_px',        'lineWidth',        {'saccade_exp.m', ...
                                                 'saccade_lr_exp.m'}
    'msg_target_ang',       'msg1',             {'saccade_exp.m'}
    'msg_saccade_type',     'msg2',             {'saccade_exp.m', ...
                                                 'saccade_lr_exp.m'}
% --- added in tranche 3: saccade_lr_exp.m's own msg1, and the spem pair's
%     msg1/msg2, named after the trial variable each carries, per the rule
%     above ---
    'msg_target_dir',       'msg1',             {'saccade_lr_exp.m'}
    'msg_freq_x',           'msg1',             spem_pair
    'msg_freq_y',           'msg2',             spem_pair
% --- free_view/free_view_exp.m ---
    'session_phase',        'type',             fve
    'screen_width_px',      'screenWidth',      fve
    'screen_height_px',     'screenHeight',     fve
    'n_rows',               'numRows',          fve
    'n_cols',               'numCols',          fve
    'cell_width_px',        'quadWidth',        fve
    'cell_height_px',       'quadHeight',       fve
    'cell_rects',           'quads',            fve
    'i_pic',                'i',                fve
% --- free_view/setup/free_view_setup.m ---
    'i_screen',             'iScreen',          fvs
    'i_pic',                'iPic',             fvs
% --- spem/spem_exp.m and spem/spem_solo_exp.m ---
    'trial_end_time',       'trialTime',        spem_pair
    'trial_start_time',     'sttime',           spem_pair
    'amplitude_x_px',       'amplitudeX',       spem_pair
    'amplitude_y_px',       'amplitudeY',       spem_pair
    'phase_x',              'phaseX',           sse
    'phase_y',              'phaseY',           sse
    'sine_plot_x_px',       'sine_plot_x',      sse
    'sine_plot_y_px',       'sine_plot_y',      sse
% --- pre_process.m ---
    'edf_files',            'edfFiles',         pp
    'all_names',            'allNames',         pp
    'done_names',           'doneNames',        pp
    'todo_names',           'todoNames',        pp
    'init_pos_px',          'initPos',          pp
    'group',                'grp',              pp
    'group_rank',           'grpRank',          pp
    'subject_num',          'numID',            pp
    'phase_rank',           'phaseRank',        pp
    'sort_order',           'ord',              pp
% --- screen dimensions, four spellings collapsed onto two names ---
    'screen_width_px',      'screen_w',         [pg, pp]
    'screen_height_px',     'screen_h',         [pg, pp]
% --- +lib/animate_trial.m: the one camelCase leftover, added in tranche 5.
%     Confirmed as the sole gap in what was otherwise recorded (tranche 0) as
%     an empty map for this file; every other identifier in it was already
%     snake_case. ---
    'frame_rate_hz',        'frameRate',        at
% --- movie_test.m ---
    'do_movie',             'doMovie',          mt
    'movie_type',           'mType',            mt
    'movie_ptr',            'moviePtr',         mt
    'window_rect',          'windowRect',       mt
    'xy_pos_px',            'xyPos',            mt
    'middle_x_px',          'middleX',          mt
    'middle_y_px',          'middleY',          mt
    };

applies = cellfun(@(scope) any(strcmp(base, scope)), T(:, 3));
map = T(applies, 1:2);
if ~isempty(map)
    assert_rename_bijection(map);
end
end
