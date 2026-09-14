function [tracking_err_px, pupil_sz_mean] = spem_measures(edf_mat, gaze_x, gaze_y)
% SPEM_MEASURES  Per-trial pursuit error and pupil size for one spem recording.
%   [tracking_err_px, pupil_sz_mean] = spem_measures(edf_mat, gaze_x, gaze_y)
%
%   Reconstructs the pursuit target's path from the EDF messages, puts gaze on
%   the target's time stamps, and reduces each of the last 5 trials to two
%   numbers: how far gaze sat from the target on average, and how large the
%   pupil was on average.
%
%   The last 5 trials are used because some recordings begin with 4 extra
%   corner-calibration trials; see the CORNERS input of LIB.PREPROCESS_GAZE.
%
% Inputs
%   edf_mat  Edf2Mat object for one spem recording. Read here:
%            .Samples.time (milliseconds, EyeLink clock), .Samples.pupilSize
%            (arbitrary EyeLink area units, not mm and not normalised),
%            .Events.Start.time and .Events.End.time (milliseconds), and, via
%            TRUE_TARGET_TRAJ, .Events.Messages.
%   gaze_x   [N x 1] horizontal gaze position, pixels, one per tracker sample,
%            NaN during blinks. The homography-corrected first output of
%            LIB.PREPROCESS_GAZE, so it is already in ideal screen coordinates.
%   gaze_y   [N x 1] vertical gaze position, pixels, y growing downward.
% Output
%   tracking_err_px  [5 x 1] mean distance between gaze and target over each
%                    trial, pixels. NaN samples are omitted from the mean.
%   pupil_sz_mean    [5 x 1] mean pupil size over each trial, arbitrary EyeLink
%                    area units.
%
%   Name mismatch worth knowing about: the caller stores these as the frozen
%   struct fields RESULTS(k).err and RESULTS(k).pupil_sz_mean of
%   spem/spem_results.mat. The local was renamed to TRACKING_ERR_PX because a
%   bare ERR shadows the builtin; the .err field cannot be renamed without a
%   migration of the shipped artifact (Tier C item 0.3.7), so the two names
%   differ on purpose.
%
%   Known bug, recorded and deliberately not fixed here (0.4.1 in
%   docs/repo-cleanup.md): line 106 indexes the raw .Samples.pupilSize array with
%   START_FRAME and END_FRAME, which were computed against the downsampled T_DS.
%   The raw array has 151246 samples where T_DS has 9007, so every PUPIL_SZ_MEAN
%   below is the mean of roughly 1.8 s of the wrong samples instead of 30 s of
%   the right ones. TRACKING_ERR_PX is unaffected -- it indexes the downsampled
%   trajectories, which is what those frames are indices into.
%
% See also TRUE_TARGET_TRAJ, DOWNSAMPLE_TRAJ, LIB.PREPROCESS_GAZE,
% ANALYZE.FREE_VIEW_MEASURES

n_trials = 5;

t_gaze = double(edf_mat.Samples.time);   % ms

% spem target trajectory, parsed back out of the EDF messages
[t_target, traj_target] = true_target_traj(edf_mat);

% downsample gaze trajectory to match target trajectory samples
traj_gaze = [gaze_x gaze_y];
% [t_gaze,traj_gaze] = downsample_traj(t_target,traj_target,t_gaze,traj_gaze);
[t_ds, traj_target_ds, traj_gaze_ds] = downsample_traj( ...
    t_target, traj_target, t_gaze, traj_gaze);

pupil_sz_mean   = nan(n_trials, 1);
tracking_err_px = nan(n_trials, 1);

% for some, 1st 4 are corners, so take last 5 trials
start_times = edf_mat.Events.Start.time(end - n_trials + 1:end);
end_times   = edf_mat.Events.End.time(end - n_trials + 1:end);

for i_trial = 1:n_trials
    % extract target and gaze trajectories for the trial
    start_time = start_times(i_trial);
    end_time   = end_times(i_trial) - 1;

    % frame indices into the DOWNSAMPLED time base, not into .Samples
    start_frame = find(t_ds >= start_time, 1);
    end_frame   = find(t_ds <= end_time, 1, 'last');

    traj_target_this = traj_target_ds(start_frame:end_frame, :);
    traj_gaze_this   = traj_gaze_ds(start_frame:end_frame, :);

    %% animate the target and gaze points
    % N = min(size(traj_target_this,1), size(traj_gaze_this,1));
    % traj_target_this = traj_target_this(1:N,:);
    % traj_gaze_this   = traj_gaze_this(1:N,:);
    %
    % figure('Color','w'); axis equal; hold on
    % xy = [traj_target_this; traj_gaze_this];
    % xlim([min(xy(:,1)) max(xy(:,1))]); ylim([min(xy(:,2)) max(xy(:,2))]);
    %
    % h1 = plot(traj_target_this(1,1), traj_target_this(1,2), 'or', 'MarkerFaceColor','r');
    % h2 = plot(traj_gaze_this(1,1),   traj_gaze_this(1,2),   'ob', 'MarkerFaceColor','b');
    %
    % for k = 2:N
    %     set(h1,'XData',traj_target_this(k,1),'YData',traj_target_this(k,2));
    %     set(h2,'XData',traj_gaze_this(k,1)  ,'YData',traj_gaze_this(k,2));
    %     drawnow
    % end

    %%
    % per-sample distance between target and gaze, px
    tracking_err_px_this = vecnorm(traj_target_this - traj_gaze_this, 2, 2);

    % mean of error over the trial
    tracking_err_px(i_trial) = mean(tracking_err_px_this, 'omitnan');

    % pupil size over the trial -- see the header: these are indices into the
    % downsampled time base being used on the raw sample array (bug 0.4.1)
    pupil_this = edf_mat.Samples.pupilSize(start_frame:end_frame);

    % compute avg. pupil size over the trial
    pupil_sz_mean(i_trial) = mean(pupil_this, 'omitnan');
end

end
