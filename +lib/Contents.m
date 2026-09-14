% LIB  Shared helpers used by every experiment and analysis in this repo.
%
% Call these as lib.<name>, e.g. lib.preprocess_gaze(edf_mat). The +lib folder
% sits at the repo root, so the repo root has to be on the MATLAB path.
%
% Gaze preprocessing
%   preprocess_gaze  - Calibrate, plot and blink-mask the gaze trace of one
%                      recording. Fits a homography from the four observed
%                      corner fixations onto the four ideal corner positions,
%                      applies it to every gaze sample and every fixation,
%                      plots the result, and returns the trace with blinks
%                      (padded 100 ms each side) set to NaN. All positions are
%                      pixels on a 1920 x 1080 screen with y growing downward;
%                      all times are milliseconds on the EyeLink clock. Feeds
%                      spem_measures and analyze.free_view_measures.
%
% Scratch
%   animate_trial    - Script, not a function: replays one trial's gaze as an
%                      animation. Needs an EDF2MAT object named edf already in
%                      the caller's workspace, and its trial number and frame
%                      arithmetic do not match any recording in this repo
%                      (bug 0.3.14.16 in docs/repo-cleanup.md).
%
% Note on dependencies: preprocess_gaze calls true_target_traj and
% downsample_traj, which live in spem/ rather than here, so spem/ must also be
% on the path for its 'spem' animation branch to run. That layout is recorded
% as bug 0.3.14.3 and is not fixed in the Tier A/B pass.
%
% See also SPEM_MEASURES, ANALYZE.FREE_VIEW_MEASURES, TRUE_TARGET_TRAJ,
% DOWNSAMPLE_TRAJ
