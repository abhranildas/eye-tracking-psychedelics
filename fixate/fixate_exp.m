function fixate_exp
% FIXATE_EXP  Run one session of the sustained-fixation task.
%   fixate_exp
%
%   One session of a 5-minute central-fixation task, presented with
%   Psychtoolbox and recorded on an EyeLink 1000. Unlike the other five
%   *_exp.m files, there is no per-trial list: after the four-corner
%   calibration phase there is exactly one long fixation trial, so nothing
%   is loaded from a setup script.
%
%   The session runs in two phases. First a corner-marking phase: a white dot
%   is shown for 5 s at each of the four screen corners in turn, recorded as
%   trials 0.1 to 0.4, which gives the analysis chain four known screen
%   positions to fit its calibration correction to (lib.preprocess_gaze reads
%   them back as its 'corners' input). Then one continuous trial: a single
%   central dot of target_radius is shown and recorded for fixation_duration,
%   with no target motion and no trial variables to log. Finally the
%   recording is closed, transferred off the Host PC and renamed.
%
%   Each phase is bracketed by its own StartRecording / StopRecording pair
%   and by TRIALID / TRIAL_RESULT messages for Data Viewer.
%
% Inputs
%   None as arguments. What the function actually consumes:
%
%   setup.mat  none. Unlike saccade_exp.m, this file loads no .mat file at
%              all: there is no trial list to generate, since the whole
%              session is a single fixation trial with a hard-coded duration.
%   keyboard   one command-window prompt, read before any graphics open: the
%              EDF file name to save under (1 to 8 characters, letters and
%              digits only; the run aborts if <name>.edf already exists).
%   hardware   display screen_number = 1, and a live EyeLink host. dummymode
%              is 0, so there is no simulated-tracker path: without a host
%              this file cannot be run at all, not even as a dry run.
%
%   Timing and geometry are hard-coded at the top of the file and the names do
%   not carry their units:
%     fixation_duration  300 SECONDS here (5 minutes). The same name means
%                         1 s in saccade_exp.m and 0.2 s in free_view_exp.m,
%                         three orders of magnitude apart under one name, so
%                         never carry a value for it across files.
%     dot_radius          5 PIXELS, radius of the four corner-calibration
%                         dots.
%     target_radius       1 PIXEL, radius of the central fixation dot.
%
% Output
%   None returned. The side effects are the point:
%     - an EDF recording written on the EyeLink Host PC under the 8-character
%       name held in edf_default, transferred into pwd at the end of the
%       session and then renamed to the name typed at the prompt.
%     - the Psychtoolbox window and the tracker connection, both closed by
%       the nested cleanup function on every exit path, including the error
%       path.
%
% Known bugs, recorded and deliberately NOT fixed here
%   0.4.22  edf_default is 'saccade' here (below), not a name describing
%              this task -- a copy-paste leftover from the file this one was
%              cloned from. It is the 8-character name the Host PC writes the
%              recording under before it is transferred and renamed, so it
%              only matters if a fixate_exp.m session and a saccade_exp.m (or
%              saccade_lr_exp.m) session run back to back on the same Host PC
%              without the first file being cleared, in which case the second
%              Openfile call could collide with the first. Left as is; see
%              the inline NOTE below.
%
% See also SACCADE_EXP, SACCADE_LR_EXP, SPEM_EXP, FREE_VIEW_EXP,
%   LIB.PREPROCESS_GAZE, EYELINKINITDEFAULTS

% set up trials
fixation_duration = 300;         % SECONDS (5 minutes), the one long trial
dot_radius = 5;                  % PIXELS, corner calibration dots
target_radius = 1;               % PIXELS, central fixation dot
target_colour = 100*[1 1 1];

if ~IsOctave
    commandwindow;
else
    more off;
end

dummymode = 0;

try
    %%%%%%%%%%
    % STEP 1 %
    %%%%%%%%%%

    % Added a dialog box to set your own EDF file name before opening
    % experiment graphics. Make sure the entered EDF file name is 1 to 8
    % characters in length and only numbers or letters are allowed.

    if IsOctave
        edf_default = 'DEMO';
    else
        prompt = 'File name: ';
        % NOTE: bug 0.4.22 -- edf_default is 'saccade', a leftover from the
        % file this one was copied from, not a name describing this task.
        edf_default = 'saccade';
        edf_file = input(prompt, 's');

        if exist([edf_file '.edf'], 'file')
            disp('The file exists!');
            return
        end

    end

    %%%%%%%%%%
    % STEP 2 %
    %%%%%%%%%%

    % Open a graphics window on the main screen
    % using the PsychToolbox's Screen function.
    screen_number = 1;
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % skip sync tests

    [window, ~] = Screen('OpenWindow', screen_number, 0, [], 32, 2); %#ok<*NASGU>
    % [window, windowrect] = PsychImaging('OpenWindow', screen_number);
    Screen(window, 'BlendFunction', GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    [win_width_px, win_height_px] = WindowSize(window);

    %     moviePtr = Screen('CreateMovie', window, 'saccade_movie.mp4', [],[],1);

    % fixation dot, as a PIXEL rect [left top right bottom] for FillOval
    fix_pos([1 3]) = win_width_px/2 + target_radius*[-1 1];
    fix_pos([2 4]) = win_height_px/2 + target_radius*[-1 1];

    %%%%%%%%%%
    % STEP 3 %
    %%%%%%%%%%

    % Provide Eyelink with details about the graphics environment
    % and perform some initializations. The information is returned
    % in a structure that also contains useful defaults
    % and control codes (e.g. tracker state bit and Eyelink key values).

    el = EyelinkInitDefaults(window);

    % We are changing calibration to match task background and target
    % this eliminates affects of changes in luminosity between screens
    % no sound and smaller targets
    %     el.targetbeep = 0;
    el.backgroundcolour = [0 0 0];
    el.msgfontcolour = 255;
    el.calibrationtargetcolour = 255*[1 1 1];
    % for lower resolutions you might have to play around with these values
    % a little. If you would like to draw larger targets on lower res
    % settings please edit PsychEyelinkDispatchCallback.m and see comments
    % in the EyelinkDrawCalibrationTarget function
    el.calibrationtargetsize = 1;
    el.calibrationtargetwidth = 0.5;
    % call this function for changes to the el calibration structure to take
    % affect
    EyelinkUpdateDefaults(el);

    %%%%%%%%%%
    % STEP 4 %
    %%%%%%%%%%

    % Initialization of the connection with the Eyelink tracker
    % exit program if this fails.

    if ~EyelinkInit(dummymode)
        fprintf('Eyelink Init aborted.\n');
        cleanup;  % cleanup function
        return;
    end

    % open file to record data to. open_file_status is 0 on success.
    open_file_status = Eyelink('Openfile', edf_default);
    if open_file_status~=0
        fprintf('Cannot create EDF file ''%s'' ', edf_default);
        cleanup;
        return;
    end

    % make sure we're still connected.
    if Eyelink('IsConnected')~=1 && ~dummymode
        cleanup;
        return;
    end

    %%%%%%%%%%
    % STEP 5 %
    %%%%%%%%%%

    % SET UP TRACKER CONFIGURATION

    % Setting the proper recording resolution, proper calibration type,
    % as well as the data file content;
    % record monitor distance, resolution and PPD:

    % This command is crucial to map the gaze positions from the tracker to
    % screen pixel positions to determine fixation
    Eyelink('command', 'screen_pixel_coords = %ld %ld %ld %ld', ...
        0, 0, win_width_px - 1, win_height_px - 1);
    Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', ...
        0, 0, win_width_px - 1, win_height_px - 1);
    % set calibration type.
    Eyelink('command', 'calibration_type = HV9');
    Eyelink('command', 'generate_default_targets = YES');

    % STEP 5.1 retrieve tracker version and tracker software version
    % tracker_version: integer model code, 3 = EyeLink 1000.
    % tracker_version_str: the host's version banner.
    % tracker_version_digits: its digits, one per cell, so {1} is the software
    % major version.
    [tracker_version, tracker_version_str] = Eyelink('GetTrackerVersion');
    fprintf('Running experiment on a ''%s'' tracker.\n', tracker_version_str );
    tracker_version_digits = regexp(tracker_version_str, '\d', 'match');

    % Which samples and events the tracker writes to the EDF file and sends
    % over the link. The two branches differ only in HTARGET, the head-target
    % data that only a 1000 in remote mode produces.
    % if EL 1000 and tracker version 4.xx
    if tracker_version == 3 && str2double(tracker_version_digits{1}) == 4

        % remote mode possible add HTARGET ( head target)
        Eyelink('command', ...
            'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('command', ...
            'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT,HTARGET');
        % set link data (used for gaze cursor)
        Eyelink('command', ...
            'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,FIXUPDATE,INPUT');
        Eyelink('command', ...
            'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT,HTARGET');
    else
        Eyelink('command', ...
            'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('command', ...
            'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT');
        % set link data (used for gaze cursor)
        Eyelink('command', ...
            'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,FIXUPDATE,INPUT');
        Eyelink('command', ...
            'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
    end

    % allow to use the big button on the eyelink gamepad to accept the
    % calibration/drift correction target
    Eyelink('command', 'button_function 5 "accept_target_fixation"');

    %%%%%%%%%%
    % STEP 6 %
    %%%%%%%%%%

    % Hide the mouse cursor
    %     Screen('HideCursorHelper', window);
    % enter Eyetracker camera setup mode, calibration and validation
    EyelinkDoTrackerSetup(el);

    %%%%%%%%%%
    % STEP 7 %
    %%%%%%%%%%

    % show dots at the four corners so that we have reference for
    % correction later. Recorded as trials 0.1 to 0.4; lib.preprocess_gaze
    % reads these four intervals back to fit its calibration correction.
    % PIXELS, one row per corner, [x y] of the dot's top-left, screen
    % coordinates with y growing downward.
    corners = [0 0;
        0 win_height_px - 2*dot_radius;
        win_width_px - 2*dot_radius win_height_px - 2*dot_radius;
        win_width_px - 2*dot_radius 0];

    for i_corner = 1:4

        % Sending a 'TRIALID' message to mark the start of a trial in Data
        % Viewer.  This is different than the start of recording message
        % START that is logged when the trial recording begins. The viewer
        % will not parse any messages, events, or samples, that exist in
        % the data file prior to this message.
        Eyelink('Message', 'TRIALID 0.%d', i_corner);

        % This supplies the title at the bottom of the eyetracker display
        Eyelink('command', 'record_status_message "mark corners"');

        % Before recording, we place reference graphics on the host display
        % Must be in offline mode to transfer image to Host PC
        Eyelink('Command', 'set_idle_mode');

        % clear tracker display and draw box at center
        Eyelink('Command', 'clear_screen %d', 0);

        % Prepare and show the screen.
        % Enable alpha blending with proper blend-function. We need it
        % for drawing of smoothed points:
        Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        Screen('FillRect', window, el.backgroundcolour);

        % start recording eye position (preceded by a short pause so that
        % the tracker can finish the mode transition)
        % The paramerters for the 'StartRecording' call controls the
        % file_samples, file_events, link_samples, link_events availability
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.05);
        Eyelink('StartRecording');

        % show corner dot, as a PIXEL rect [left top right bottom]
        corner_pos([1 2]) = corners(i_corner, :);
        corner_pos([3 4]) = corners(i_corner, :) + 2*dot_radius;
        Screen('FillOval', window, 255*[1 1 1], corner_pos);
        Screen('Flip', window);
        WaitSecs(5);

        % add 100 msec of data to catch final events and blank display
        WaitSecs(0.1);
        Eyelink('StopRecording');

        % Sending a 'TRIAL_RESULT' message to mark the end of a trial in
        % Data Viewer. This is different than the end of recording message
        % END that is logged when the trial recording ends. The viewer will
        % not parse any messages, events, or samples that exist in the data
        % file after this message.
        Eyelink('Message', 'TRIAL_RESULT 0');
    end

    % Now starts the single fixation trial. There is no per-trial loop and no
    % trial condition variable to send, since the whole session is one long
    % continuous recording of a static central dot.

    % Before recording, we place reference graphics on the host display
    % Must be in offline mode to transfer image to Host PC
    Eyelink('Command', 'set_idle_mode');

    % clear tracker display and draw box at center
    Eyelink('Command', 'clear_screen %d', 0);

    % Prepare and show the screen.
    % Enable alpha blending with proper blend-function. We need it
    % for drawing of smoothed points:
    Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('FillRect', window, el.backgroundcolour);

    % show fixation dot
    Screen('FillOval', window, target_colour, fix_pos);
    Screen('Flip', window);

    % start recording eye position (preceded by a short pause so that
    % the tracker can finish the mode transition)
    % The paramerters for the 'StartRecording' call controls the
    % file_samples, file_events, link_samples, link_events availability
    Eyelink('Command', 'set_idle_mode');
    WaitSecs(0.05);
    Eyelink('StartRecording');
    % record a few samples before we actually start displaying
    % otherwise you may lose a few msec of data
    WaitSecs(0.1);

    WaitSecs(fixation_duration);

    % add 100 msec of data to catch final events and blank display
    WaitSecs(0.1);
    Eyelink('StopRecording');

    % Sending a 'TRIAL_RESULT' message to mark the end of a trial in
    % Data Viewer. This is different than the end of recording message
    % END that is logged when the trial recording ends. The viewer will
    % not parse any messages, events, or samples that exist in the data
    % file after this message.
    Eyelink('Message', 'TRIAL_RESULT 0');

    %%%%%%%%%%
    % STEP 8 %
    %%%%%%%%%%

    % End of Experiment; close the file first
    % close graphics window, close data file and shut down tracker
    Eyelink('Command', 'set_idle_mode');
    WaitSecs(0.5);
    Eyelink('CloseFile');

    try
        fprintf('Receiving data file ''%s''\n', edf_default );
        status = Eyelink('ReceiveFile');
        if status > 0
            fprintf('ReceiveFile status %d\n', status);
        end
        if 2==exist(edf_default, 'file')
            fprintf('Data file ''%s'' can be found in ''%s''\n', edf_default, pwd );
        end
    catch %#ok<*CTCH>
        fprintf('Problem receiving data file ''%s''\n', edf_default );
    end

    % rename file
    if ~strcmp(edf_default, edf_file)
        movefile([edf_default '.edf'], [edf_file '.edf']);
    end

    %%%%%%%%%%
    % STEP 9 %
    %%%%%%%%%%

    % run cleanup function (close the eye tracker and window).
    cleanup;

catch
    cleanup;
    fprintf('%s: some error occured\n', mfilename);
    psychrethrow(lasterror); %#ok<*LERR>

end

    function cleanup
        % Shutdown Eyelink:
        Eyelink('Shutdown');
        Screen('CloseAll');
    end

end
