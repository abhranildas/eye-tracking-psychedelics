function [dwell_tot, dwell, pupil, scan] = free_view_measures( ...
    edf_mat, gaze_x, gaze_y, fix_x, fix_y)
% FREE_VIEW_MEASURES  Per-trial gaze measures for one free-viewing recording.
%   [dwell_tot, dwell, pupil, scan] = analyze.free_view_measures( ...
%       edf_mat, gaze_x, gaze_y, fix_x, fix_y)
%
%   Each free-viewing trial shows a 3x3 grid of IAPS images filling the screen.
%   For each of the 73 trials this splits the screen into those 9 cells at the
%   thirds and reduces gaze to four things: how long gaze sat in each cell by
%   raw sample count, how long it sat there by summed fixation duration, how
%   large the pupil was in each cell, and how far the eye travelled between
%   fixations.
%
%   The last 73 trials are used because some recordings begin with 4 extra
%   corner-calibration trials; see the CORNERS input of LIB.PREPROCESS_GAZE.
%
% Inputs
%   edf_mat  Edf2Mat object for one free-viewing recording. Read here:
%            .RawEdf.RECORDINGS(1).sample_rate (Hz), .Samples.time
%            (milliseconds, EyeLink clock), .Samples.pupilSize (arbitrary
%            EyeLink area units), .Events.Start.time and .Events.End.time
%            (milliseconds), .Events.Efix.start and .Events.Efix.duration
%            (milliseconds).
%   gaze_x   [N x 1] horizontal gaze position, pixels, one per tracker sample,
%            NaN during blinks. First output of LIB.PREPROCESS_GAZE, so already
%            homography-corrected into ideal screen coordinates.
%   gaze_y   [N x 1] vertical gaze position, pixels, y growing downward.
%   fix_x    [F x 1] horizontal position of each detected fixation, pixels,
%            homography-corrected. Third output of LIB.PREPROCESS_GAZE.
%   fix_y    [F x 1] vertical position of each detected fixation, pixels.
% Output
%   dwell_tot  [3 x 3 x 73] sample-count dwell time per grid cell, seconds.
%              Divided by the sample rate, then rescaled so each trial's 9 cells
%              sum to exactly 10 s, because the raw window length varies.
%              Rows are vertical position, columns horizontal (the per-trial
%              matrix is transposed on the way in for exactly that reason).
%   dwell      [3 x 3 x 73] fixation-based dwell time per grid cell, seconds --
%              the summed durations of the fixations that landed in the cell.
%              Not rescaled, so it does not sum to 10 s.
%   pupil      [3 x 3 x 73] mean pupil size per grid cell, arbitrary EyeLink
%              area units. NaN for a cell gaze never entered.
%   scan       [1 x 73] scanpath length, pixels -- the sum of the distances
%              between consecutive fixation positions within the trial.
%
%   The caller stores these under the identically named frozen struct fields of
%   free_view/data/free_view_results.mat, so the names here are deliberately
%   left matching the artifact rather than expanded (compare SPEM_MEASURES,
%   where the local ERR had to be renamed to un-shadow a builtin and therefore
%   no longer matches its .err field).
%
%   Known bug, recorded and deliberately not fixed here (0.4.5 in
%   docs/repo-cleanup.md): this function uses two different analysis windows.
%   END_FRAME is computed at line 92 from the trial's true end time, but
%   END_TIME is then overwritten at line 101 with START_TIME + 3000. So
%   DWELL_TOT and PUPIL, which are indexed by START_FRAME:END_FRAME, cover the
%   full ~10.1 s window, while DWELL and SCAN, which are selected by time
%   against END_TIME, cover only the first 3 s. The comment on that line says
%   "first 1.5 s", which matches neither.
%
% See also LIB.PREPROCESS_GAZE, SPEM_MEASURES, FREE_VIEW_ANALYZE

n_trials = 73;

% sampling rate
sample_rate_hz = double(edf_mat.RawEdf.RECORDINGS(1).sample_rate);

% Screen dimensions
screen_width_px  = 1920;
screen_height_px = 1080;

% image border locations: the 3x3 grid splits the screen at the thirds
x_borders = screen_width_px * [1/3 2/3];
y_borders = screen_height_px * [1/3 2/3];

dwell_tot = nan(3, 3, n_trials);
pupil     = nan(3, 3, n_trials);
scan      = nan(1, n_trials);
dwell     = nan(3, 3, n_trials);     % <-- NEW: fixation-based dwell

% for some, 1st 4 are corners, so take last 73 trials
start_times = edf_mat.Events.Start.time(end - n_trials + 1:end);
end_times   = edf_mat.Events.End.time(end - n_trials + 1:end);

% fixation positions and times
fix_pos  = [fix_x fix_y];
fix_time = edf_mat.Events.Efix.start';
fix_dur  = edf_mat.Events.Efix.duration';   % duration in ms

for i_trial = 1:n_trials
    % find frames of the trial
    end_time  = end_times(i_trial) - 1;
    end_frame = find(edf_mat.Samples.time == end_time);

    trial_start_time = start_times(i_trial);

    % take viewing start time to be 10s before end time (ignoring fixation time and
    % picture loading delays)

    start_time = end_time - (10.1)*1e3;

    end_time = start_time + 3000; % take only first 1.5 s

    if start_time <= trial_start_time
        error('trial time was <10s')
    end
    start_frame = find(edf_mat.Samples.time == start_time);

    % gaze coordinates over the trial
    gaze_x_this = gaze_x(start_frame:end_frame);
    gaze_y_this = gaze_y(start_frame:end_frame);

    % pupil size over the trial
    pupil_this = edf_mat.Samples.pupilSize(start_frame:end_frame);

    % segment gaze x and y coordinates into 3 bins
    % these inequalities automatically drop nans, i.e. blinks
    gaze_x_bin = false([length(gaze_x_this) 3]);
    gaze_x_bin(:, 1) = gaze_x_this <= x_borders(1);
    gaze_x_bin(:, 3) = gaze_x_this >= x_borders(2);
    gaze_x_bin(:, 2) = (gaze_x_this > x_borders(1)) & (gaze_x_this < x_borders(2));

    gaze_y_bin = false([length(gaze_y_this) 3]);
    gaze_y_bin(:, 1) = gaze_y_this <= y_borders(1);
    gaze_y_bin(:, 3) = gaze_y_this >= y_borders(2);
    gaze_y_bin(:, 2) = (gaze_y_this > y_borders(1)) & (gaze_y_this < y_borders(2));

    % compute duration and avg. pupil size in each image region
    dwell_this    = nan(3, 3);
    pupil_sz_this = nan(3, 3);
    for i_x_bin = 1:3
        for i_y_bin = 1:3
            mask = (gaze_x_bin(:, i_x_bin) & gaze_y_bin(:, i_y_bin));
            dwell_this(i_x_bin, i_y_bin) = nnz(mask);
            if any(mask)
                % compute only over samples inside this rectangle
                pupil_sz_this(i_x_bin, i_y_bin) = mean(pupil_this(mask), 'omitnan');
            end
        end
    end

    % we need to transpose because x/y index rows/columns, but they should
    % mean horizontal/vertical coordinates instead
    dwell_tot(:, :, i_trial) = dwell_this';
    pupil(:, :, i_trial)     = pupil_sz_this';

    %% scan-path length
    % select fixations within this trial
    fix_this     = (fix_time >= start_time) & (fix_time <= end_time);
    fix_pos_this = fix_pos(fix_this, :);
    fix_dur_this = fix_dur(fix_this);   % durations (ms) for this trial

    % consecutive deltas
    fix_diff = diff(fix_pos_this);

    scan(i_trial) = sum(vecnorm(fix_diff, 2, 2));

    %% fixation-based dwell time per image (in seconds)
    dwell_fix_this = zeros(3, 3);
    if ~isempty(fix_pos_this)
        % per-trial locals, NOT the FIX_X/FIX_Y inputs -- those are only needed
        % to build FIX_POS above, and are renamed here so the shadowing is
        % visible rather than silent
        fix_x_this = fix_pos_this(:, 1);
        fix_y_this = fix_pos_this(:, 2);

        % bin fixation positions into 3x3 grid
        fix_x_bin = false(size(fix_x_this, 1), 3);
        fix_x_bin(:, 1) = fix_x_this <= x_borders(1);
        fix_x_bin(:, 3) = fix_x_this >= x_borders(2);
        fix_x_bin(:, 2) = (fix_x_this > x_borders(1)) & (fix_x_this < x_borders(2));

        fix_y_bin = false(size(fix_y_this, 1), 3);
        fix_y_bin(:, 1) = fix_y_this <= y_borders(1);
        fix_y_bin(:, 3) = fix_y_this >= y_borders(2);
        fix_y_bin(:, 2) = (fix_y_this > y_borders(1)) & (fix_y_this < y_borders(2));

        for i_x_bin = 1:3
            for i_y_bin = 1:3
                mask = fix_x_bin(:, i_x_bin) & fix_y_bin(:, i_y_bin);
                if any(mask)
                    % sum fixation durations in this region, convert ms -> s
                    dwell_fix_this(i_x_bin, i_y_bin) = sum(fix_dur_this(mask))/1000;
                end
            end
        end
    end

    % transpose to keep same convention as dwell
    dwell(:, :, i_trial) = dwell_fix_this';

end

% divide dwell by sample rate to get in units of time (seconds)
dwell_tot = dwell_tot/sample_rate_hz;

% normalize total dwell time per screen to 10s (because it varies)
dwell_tot = dwell_tot./sum(dwell_tot, [1 2])*10;

end
