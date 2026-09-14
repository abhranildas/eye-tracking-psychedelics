% PRE_PROCESS  Manually calibrate spem recordings and sort the results struct.
%
%   Cell-divided interactive workflow: run section by section by hand, with
%   workspace carryover between sections. Not a callable function. Three
%   sections, in order: pick the next uncalibrated recording and open the
%   draggable calibration polygon; after the corners are dragged by hand,
%   read them back and re-run the calibration; then, once every recording is
%   done, sort the accumulated results struct into a canonical subject order.
%
% Inputs
%   None as arguments.
%   Workspace variable required before the first section runs: RESULTS, a
%     struct array already holding every previously-calibrated subject (each
%     element has at least a .name field). Ordinarily produced by
%     `load spem_results.mat` (commented out at the top of this file) or, for
%     a first run with nothing calibrated yet, `results = struct;` (also
%     commented out). RESULTS is a bare local that holds the contents of the
%     zone-3 frozen `results` variable in spem/spem_results.mat -- the local
%     name is free to use, the load/save string is not.
%   Files read: every `*.edf` recording in the working directory, which must
%     therefore be spem/ (or wherever the recordings to calibrate live).
%   Interactive input: section 1 opens a `drawpolygon` on the plotted gaze
%     trace and the four corner vertices must be dragged by hand into place
%     before moving to section 2.
%   `lib.preprocess_gaze`'s name-value arguments 'corners' and 'calib_sz' are
%     zone-2 frozen literals (docs/repo-cleanup.md section 4.1.1) and are
%     passed unchanged at line 41.
% Output
%   None returned; this is a script. Side effects, by section: section 1
%     plots the recording's gaze trace and opens the draggable polygon;
%     section 2 re-runs LIB.PREPROCESS_GAZE with the dragged corners and
%     writes RESULTS(idx).name / .corners into the workspace struct (the
%     `save 'spem_results.mat' results` line that would persist it is
%     commented out, so nothing reaches disk automatically -- see Tier B
%     item 0.2.4 for why line 15 stays unsuppressed rather than being
%     "fixed"); section 3 reorders RESULTS in place by subject group, number
%     and session phase, with no disk write either.
%
% See also LIB.PREPROCESS_GAZE, SPEM_ANALYZE

% results=struct;

%% calibrate files manually
% list files not yet calibrated
% load spem_results.mat

edf_files = dir('*.edf');
all_names = erase({edf_files.name}, '.edf');
done_names = {results.name};
todo_names = setdiff(all_names, done_names, 'stable');

% calibrate each file
i_todo = 1;
idx = numel(results) + 1;
name = todo_names{i_todo}   % NOTE: deliberately unsuppressed (item 0.2.4) --
                             % this is the script's only way to show which
                             % subject is next while run interactively.
edf_mat = Edf2Mat([name '.edf']);

% check that sampling rate was 1 KHz throughout
if unique([edf_mat.RawEdf.RECORDINGS.sample_rate]) ~= 1000
    warning('sampling rate not 1KHz')
end

lib.preprocess_gaze(edf_mat);
title(name)

% Initial rectangle (screen coords; y grows downward)
screen_width_px = 1920; screen_height_px = 1080;
calib_sz = 2/3;
init_pos_px = [screen_width_px screen_height_px]/2 + ...
    [-[screen_width_px screen_height_px]; [screen_width_px -screen_height_px]; ...
    [screen_width_px screen_height_px]; [-screen_width_px screen_height_px]]/2*calib_sz;

roi = drawpolygon('Parent', gca, ...
    'Position', init_pos_px, ...
    'FaceAlpha', 0.05, 'LineWidth', 1.5, ...
    'InteractionsAllowed', 'reshape');  % allow dragging vertices

%% after manual clicking, store corners
corners = roi.Position;
% calibrate and return corrected trajectory (blinks removed)
[gaze_x, gaze_y] = lib.preprocess_gaze(edf_mat, 'corners', corners, ...
    'calib_sz', calib_sz);
axis([0 1920 0 1080])
title(name)

% store calibration in struct
results(idx).name = name;
results(idx).corners = corners;

% save 'spem_results.mat' results

%% sort the struct by name
% Build sortable keys
names = string({results.name})';

group = regexp(names, '^(gss|ibo|aya)', 'match', 'once');          % gss/ibo/aya
[~, group_rank] = ismember(group, ["gss", "ibo", "aya"]);           % gss=1, ibo=2, aya=3
group_rank(group_rank == 0) = 99;                                    % (fallback)

subject_num = str2double(regexp(names, '(?<=^[a-z]+)\d+', 'match', 'once'));
                                                                 % number after prefix

phase_rank = 2*ones(numel(names), 1);              % default: post=2
phase_rank(endsWith(names, '_pre')) = 1;           % pre first
phase_rank(endsWith(names, '_post_control')) = 3;  % post_control after post

% Sort by: group → number → phase
[~, sort_order] = sortrows([group_rank(:), subject_num(:), phase_rank(:)]);
results = results(sort_order);
