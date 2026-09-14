function [err,pupil_sz_mean]=spem_measures(edf_mat,gaze_x,gaze_y)

n_trials=5;

t_gaze = double(edf_mat.Samples.time);                   % ms

% spem target trajectory
[t_target, traj_target] = true_target_traj(edf_mat);

% downsample gaze trajectory to match target trajectory samples
traj_gaze=[gaze_x gaze_y];
% [t_gaze,traj_gaze] = downsample_traj(t_target,traj_target,t_gaze,traj_gaze);
[t_ds, traj_target_ds, traj_gaze_ds] = downsample_traj( ...
    t_target, traj_target, t_gaze, traj_gaze);

pupil_sz_mean =nan(n_trials,1);
err =nan(n_trials,1);

% for some, 1st 4 are corners, so take last 5 trials
start_times=edf_mat.Events.Start.time(end-n_trials+1:end);
end_times=edf_mat.Events.End.time(end-n_trials+1:end);

for iTrial=1:n_trials
    % extract target and gaze trajectories for the trial
    start_time=start_times(iTrial);
    end_time=end_times(iTrial)-1;

    start_frame=find(t_ds>=start_time,1);
    end_frame=find(t_ds<=end_time,1,'last');

    traj_target_this=traj_target_ds(start_frame:end_frame,:);
    traj_gaze_this=traj_gaze_ds(start_frame:end_frame,:);

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
    % compute error (distance) between target and gaze
    err_this=vecnorm(traj_target_this-traj_gaze_this,2,2);

    % mean of error over the trial
    err(iTrial)=mean(err_this,'omitnan');

    % pupil size over the trial
    pupil_this=edf_mat.Samples.pupilSize(start_frame:end_frame);

    % compute avg. pupil size over the trial
    pupil_sz_mean(iTrial)=mean(pupil_this,'omitnan');
end

