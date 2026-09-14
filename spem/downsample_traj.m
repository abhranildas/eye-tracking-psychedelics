function [t_ds, traj_target_ds, traj_gaze_ds, blink_gaze_ds] = downsample_traj( ...
    t_target, traj_target, t_gaze, traj_gaze, blink_gaze)
% Downsample both target and gaze to the exact common time points (no interpolation).

% Common times (keep target order)
[t_ds, ia, ib] = intersect(t_target, t_gaze, 'stable');

% Downsampled trajectories aligned to t_ds
traj_target_ds = traj_target(ia, :);
traj_gaze_ds   = traj_gaze(ib, :);

% Optional blink vector (from gaze)
if nargin > 4 && ~isempty(blink_gaze)
    blink_gaze_ds = blink_gaze(ib);
else
    blink_gaze_ds = [];
end

% (Optional) quick warnings on dropped samples
if numel(t_ds) < numel(t_target), warning('Some target times had no matching gaze time.'); end
end
