function [dwell_tot,dwell,pupil,scan]=free_view_measures(edf_mat,gaze_x,gaze_y,fix_x,fix_y)

n_trials=73;

% sampling rate
samp_rate=double(edf_mat.RawEdf.RECORDINGS(1).sample_rate);

% Screen dimensions
screen_width = 1920;
screen_height = 1080;

% image border locations
x_borders=screen_width*[1/3 2/3];
y_borders=screen_height*[1/3 2/3];

dwell_tot=nan(3,3,n_trials);
pupil=nan(3,3,n_trials);
scan=nan(1,n_trials);
dwell=nan(3,3,n_trials);     % <-- NEW: fixation-based dwell

% for some, 1st 4 are corners, so take last 73 trials
start_times=edf_mat.Events.Start.time(end-n_trials+1:end); 
end_times=edf_mat.Events.End.time(end-n_trials+1:end); 

% fixation positions and times
fix_pos=[fix_x fix_y];
fix_time=edf_mat.Events.Efix.start';
fix_dur = edf_mat.Events.Efix.duration';   % duration in ms

for iTrial=1:n_trials
    % find frames of the trial    
    end_time=end_times(iTrial)-1;
    end_frame=find(edf_mat.Samples.time==end_time);

    trial_start_time=start_times(iTrial); 
    
    % take viewing start time to be 10s before end time (ignoring fixation time and
    % picture loading delays)

    start_time=end_time-(10.1)*1e3;

    end_time=start_time+3000; % take only first 1.5 s

    if start_time<=trial_start_time
        error('trial time was <10s')
    end
    start_frame=find(edf_mat.Samples.time==start_time);

    % gaze coordinates over the trial
    gaze_x_this=gaze_x(start_frame:end_frame);
    gaze_y_this=gaze_y(start_frame:end_frame);

    % pupil size over the trial
    pupil_this=edf_mat.Samples.pupilSize(start_frame:end_frame);

    % segment gaze x and y coordinates into 3 bins
    % these inequalities automatically drop nans, i.e. blinks
    gaze_x_bin=false([length(gaze_x_this) 3]);
    gaze_x_bin(:,1)=gaze_x_this<=x_borders(1);
    gaze_x_bin(:,3)=gaze_x_this>=x_borders(2);
    gaze_x_bin(:,2)=(gaze_x_this>x_borders(1))&(gaze_x_this<x_borders(2));

    gaze_y_bin=false([length(gaze_y_this) 3]);
    gaze_y_bin(:,1)=gaze_y_this<=y_borders(1);
    gaze_y_bin(:,3)=gaze_y_this>=y_borders(2);
    gaze_y_bin(:,2)=(gaze_y_this>y_borders(1))&(gaze_y_this<y_borders(2));

    % compute duration and avg. pupil size in each image region
    dwell_this=nan(3,3);
    pupil_sz_this =nan(3,3);
    for x=1:3
        for y=1:3
            mask = (gaze_x_bin(:,x) & gaze_y_bin(:,y));
            dwell_this(x,y)=nnz(mask);
            if any(mask)
                % compute only over samples inside this rectangle
                pupil_sz_this(x,y)=mean(pupil_this(mask), 'omitnan');
            end
        end
    end

    % we need to transpose because x/y index rows/columns, but they should
    % mean horizontal/vertical coordinates instead
    dwell_tot(:,:,iTrial) = dwell_this';
    pupil(:,:,iTrial)  = pupil_sz_this';

    %% scan-path length
    % select fixations within this trial
    fix_this=(fix_time>=start_time)&(fix_time<=end_time);
    fix_pos_this=fix_pos(fix_this,:);
    fix_dur_this=fix_dur(fix_this);   % durations (ms) for this trial

    % consecutive deltas
    fix_diff=diff(fix_pos_this);

    scan(iTrial)=sum(vecnorm(fix_diff,2,2));

    %% fixation-based dwell time per image (in seconds)
    dwell_fix_this = zeros(3,3);
    if ~isempty(fix_pos_this)
        fix_x = fix_pos_this(:,1);
        fix_y = fix_pos_this(:,2);

        % bin fixation positions into 3x3 grid
        fix_x_bin = false(size(fix_x,1),3);
        fix_x_bin(:,1) = fix_x <= x_borders(1);
        fix_x_bin(:,3) = fix_x >= x_borders(2);
        fix_x_bin(:,2) = (fix_x > x_borders(1)) & (fix_x < x_borders(2));

        fix_y_bin = false(size(fix_y,1),3);
        fix_y_bin(:,1) = fix_y <= y_borders(1);
        fix_y_bin(:,3) = fix_y >= y_borders(2);
        fix_y_bin(:,2) = (fix_y > y_borders(1)) & (fix_y < y_borders(2));

        for x=1:3
            for y=1:3
                mask = fix_x_bin(:,x) & fix_y_bin(:,y);
                if any(mask)
                    % sum fixation durations in this region, convert ms -> s
                    dwell_fix_this(x,y) = sum(fix_dur_this(mask))/1000;
                end
            end
        end
    end

    % transpose to keep same convention as dwell
    dwell(:,:,iTrial) = dwell_fix_this';

end

% divide dwell by sample rate to get in units of time (seconds)
dwell_tot=dwell_tot/samp_rate;

% normalize total dwell time per screen to 10s (because it varies)
dwell_tot=dwell_tot./sum(dwell_tot,[1 2])*10;

end
