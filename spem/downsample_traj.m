function [t_ds, traj_target_ds, traj_gaze_ds, blink_gaze_ds] = downsample_traj( ...
    t_target, traj_target, t_gaze, traj_gaze, blink_gaze)
% DOWNSAMPLE_TRAJ  Align a gaze trajectory to the target's sample times.
%   [t_ds, traj_target_ds, traj_gaze_ds, blink_gaze_ds] = downsample_traj( ...
%       t_target, traj_target, t_gaze, traj_gaze, blink_gaze)
%
%   Keeps only the time stamps present in BOTH clocks, in target order, and
%   selects the matching rows of each trajectory. There is no interpolation, so
%   every returned sample is an original measurement: the target trajectory is
%   sampled once per '!V TARGET_POS' message (about 60 Hz) while gaze is sampled
%   at the tracker rate (1000 Hz here), and this throws away the gaze samples
%   that have no target counterpart. Any target time with no matching gaze time
%   is dropped too, with a warning.
%
% Inputs
%   t_target     [M x 1] target time stamps, milliseconds on the EyeLink clock.
%   traj_target  [M x 2] target positions, pixels, columns [x y], screen
%                coordinates with y growing downward.
%   t_gaze       [N x 1] gaze time stamps, milliseconds on the same clock.
%   traj_gaze    [N x 2] gaze positions, pixels, columns [x y].
%   blink_gaze   [N x 1] optional logical blink mask over the gaze samples,
%                dimensionless. Pass [] or omit to get an empty fourth output.
% Output
%   t_ds            [K x 1] the common time stamps, milliseconds, in target
%                   order. K <= min(M, N).
%   traj_target_ds  [K x 2] target positions at those times, pixels.
%   traj_gaze_ds    [K x 2] gaze positions at those times, pixels.
%   blink_gaze_ds   [K x 1] blink mask at those times, dimensionless, or [] if
%                   BLINK_GAZE was omitted or empty.
%
%   Callers: spem/spem_measures.m:13 (four arguments, no blink mask) and
%   +lib/preprocess_gaze.m:230. The second passes every argument after the first
%   shifted one position left, so it errors on a reachable path; that is bug
%   0.4.2 in docs/repo-cleanup.md and is deliberately not fixed here.
%
% See also TRUE_TARGET_TRAJ, SPEM_MEASURES, LIB.PREPROCESS_GAZE, INTERSECT

% Common times, keeping the target's ordering rather than sorting.
[t_ds, i_target, i_gaze] = intersect(t_target, t_gaze, 'stable');

% Trajectories restricted to those times.
traj_target_ds = traj_target(i_target, :);
traj_gaze_ds   = traj_gaze(i_gaze, :);

% Blink mask is optional: absent when the caller only wants the trajectories.
if nargin > 4 && ~isempty(blink_gaze)
    blink_gaze_ds = blink_gaze(i_gaze);
else
    blink_gaze_ds = [];
end

% A dropped target sample means the recording has a gap where the target was
% drawn but no gaze sample landed on that exact millisecond.
if numel(t_ds) < numel(t_target)
    warning('Some target times had no matching gaze time.');
end
end
