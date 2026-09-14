% ANIMATE_TRIAL  Play back one trial's raw gaze trace, frame by frame.
%
%   Cell-divided interactive workflow: a single MATLAB section, run by hand
%   after EDF has been loaded in the caller's workspace. Not a callable
%   function -- there is no signature and it takes no arguments.
%
% Inputs
%   None as arguments. Requires a workspace variable EDF to already exist
%     before this section is run: an Edf2Mat object for the recording to
%     animate, read via EDF.Samples.gx/.gy (pixels, screen coordinates with y
%     growing downward, 1920 x 1080 in this repo) and EDF.timeline/
%     EDF.Events.Start.time (milliseconds on the EyeLink clock). This script
%     never loads or constructs EDF itself.
%   TRIAL_NUM (hard-coded below, currently 70) selects which trial's samples
%     to animate, counting Start events.
%
% Output
%   None returned. Opens a figure and animates a red circle marker over
%   EDF.Samples.gx/.gy for the frame range of trial TRIAL_NUM, one call to
%   DRAWNOW per sample, with the plot title showing elapsed time in seconds.
%   Nothing is written to disk and nothing is left in the workspace beyond
%   the plotted figure.
%
% Known bugs, recorded and deliberately NOT fixed here: 0.4.16 --
% TRIAL_NUM = 70 exceeds the trial count of every spem and fixate recording
% in this repo, and the frame-index arithmetic below uses EDF.timeline, whose
% length does not match EDF.Samples.gx, so the indexing is wrong regardless
% of which trial is picked. This script also depends on the undocumented EDF
% workspace variable described above.
%
% See also LIB.PREPROCESS_GAZE

%% animate
figure;
axis image; axis([0 1920 0 1080])
set(gca, 'ydir', 'reverse')
hold on;

point = plot(edf.Samples.gx(1, 1), edf.Samples.gy(1, 1), 'ro');

% NOTE: bug 0.4.16 -- exceeds every recording's trial count in this repo.
trial_num = 70;

exp_start_time = edf.timeline(1);
% NOTE: bug 0.4.16 -- edf.timeline's length does not match Samples.gx, so
% this frame arithmetic is wrong regardless of trial_num.
start_frame = edf.Events.Start.time(trial_num) - exp_start_time + 1;
end_frame = edf.Events.Start.time(trial_num + 1) - exp_start_time + 1;

frame_rate_hz = 1e3;   % Frames per second (adjust as needed)
for frame = start_frame:end_frame

    % Update the position of the point
    set(point, 'XData', edf.Samples.gx(frame, 1), 'YData', edf.Samples.gy(frame, 1));

    % Pause to control the frame rate
    pause(1/frame_rate_hz);

    % show time
    title(sprintf('%.1f', (frame - start_frame)/1e3));

    % Refresh the plot
    drawnow;
end
