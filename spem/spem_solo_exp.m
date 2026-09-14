function smooth_pursuit_solo_exp
% SMOOTH_PURSUIT_SOLO_EXP  Run one session of the smooth-pursuit task, target only.
%   smooth_pursuit_solo_exp
%
%   One session of the smooth-pursuit task, presented with Psychtoolbox and
%   recorded on an EyeLink 1000. A single target moves on a Lissajous curve;
%   unlike spem_exp, this file draws no distractors. The trial list is not
%   loaded from a .mat file: it is generated in code, hard-coded at the top of
%   this file (see Inputs below).
%
%   The session runs in three phases. First a corner-marking phase: a white dot
%   is shown for 5 s at each of the four screen corners in turn, recorded as
%   trials 0.1 to 0.4, which gives the analysis chain four known screen
%   positions to fit its calibration correction to (lib.preprocess_gaze reads
%   them back as its 'corners' input). Then one trial per row of curve_params,
%   each trial_duration long: the target moves continuously on its Lissajous
%   curve. Finally the recording is closed, transferred off the Host PC and
%   renamed.
%
%   Each trial is bracketed by its own StartRecording / StopRecording pair and
%   by TRIALID / TRIAL_RESULT messages, and the target's per-trial frequencies
%   are written into the message stream for Data Viewer.
%
% Inputs
%   None as arguments. What the function actually consumes:
%
%   setup.mat  none. Unlike the saccade pair, this file loads no trial list
%              from disk -- the curve parameters are generated in code, right
%              below the function line:
%                freqs         [5x2] CYCLES PER TRIAL (not Hz), one row per
%                              trial, columns [freq_x freq_y].
%                phases        [5x1] RADIANS, initial phase of the target on
%                              its Lissajous curve, one per trial.
%                curve_params  [5x3] = [freqs phases], one row per trial; this
%                              is what the trial loop actually indexes.
%   keyboard   one command-window prompt, read before any graphics open: the
%              EDF file name to save under (1 to 8 characters, letters and
%              digits only; the run aborts if <name>.edf already exists).
%   hardware   display screen_number = 1, and a live EyeLink host. dummymode is
%              0, so there is no simulated-tracker path: without a host this
%              file cannot be run at all, not even as a dry run.
%
%   Timing and geometry are hard-coded at the top of the file and the names do
%   not carry their units:
%     trial_duration   30 SECONDS, how long each trial's motion runs.
%     dot_radius       5 PIXELS, radius of the corner-marking dot and the
%                      moving target.
%
% Output
%   None returned. The side effects are the point:
%     - an EDF recording written on the EyeLink Host PC under the 8-character
%       name held in edf_default ('smooth'), transferred into pwd at the end
%       of the session and then renamed to the name typed at the prompt.
%     - the Psychtoolbox window and the tracker connection, both closed by the
%       nested cleanup function on every exit path, including the error path.
%
% Known bugs, recorded and deliberately NOT fixed here
%   0.4.11  This file is named spem_solo_exp.m but declares
%              function smooth_pursuit_solo_exp (checkcode FNDEF). Renaming
%              the function to match the file is a real AST change and is
%              Tier C, not this pass.
%
% See also SPEM_EXP, SACCADE_EXP, SACCADE_LR_EXP, FIXATE_EXP, FREE_VIEW_EXP,
%   LIB.PREPROCESS_GAZE, EYELINKINITDEFAULTS

% HISTORY
% mm/dd/yy
%
% 01/28/11  NJ  created
% 12/20/13  LJ  changed isoctave to IsOctave, case sensitive for the latest
%               matlab; fixed issue with non integer arguments for
%               Eyelink('message' ...) and Eyelink('command' ...)

% freq_x freq_y
freqs = [   3   2;
            5   4;
            1   3;
            2   3;
            4   5]/2;

% phase_x phase_y
phases = [  pi/2;
            pi/2;
            3*pi/4;
            3*pi/4;
            pi];

curve_params = [freqs phases];

trial_duration = 30; % in sec

dot_radius = 5;

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
        edf_default = 'smooth';
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
    screen_number = 1; %max(Screen('Screens'));
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % skip sync tests

    [window, ~] = Screen('OpenWindow', screen_number, 0, [], 32, 2); %#ok<*NASGU>
    Screen(window, 'BlendFunction', GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    [win_width_px, win_height_px] = WindowSize(window);

    % define sine function, PIXELS
    sine_plot_x_px = win_width_px/2;
    sine_plot_y_px = win_height_px/2;
    amplitude_x_px = win_width_px/3;
    amplitude_y_px = win_height_px/3;

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
    el.backgroundcolour = 0*[1 1 1];
    el.msgfontcolour = 255;
    el.calibrationtargetcolour = 255*[1 1 1];
    target_colour = 255*[1 1 1];
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

    Eyelink('command', 'add_file_preamble_text ''Recorded by EyelinkToolbox demo-experiment''');
    % Setting the proper recording resolution, proper calibration type,
    % as well as the data file content;

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
    % correction later
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

        % show corner dot
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

    % Now starts running individual trials
    % You can keep the rest of the code except for the implementation
    % of graphics and event monitoring
    % Each trial should have a pair of "StartRecording" and "StopRecording"
    % calls as well integration messages to the data file (message to mark
    % the time of critical events and the image/interest area/condition
    % information for the trial)

    for i_trial = 1:size(curve_params, 1)

        % STEP 7.1
        % Sending a 'TRIALID' message to mark the start of a trial in Data
        % Viewer.  This is different than the start of recording message
        % START that is logged when the trial recording begins. The viewer
        % will not parse any messages, events, or samples, that exist in
        % the data file prior to this message.
        Eyelink('Message', 'TRIALID %d', i_trial);

        % This supplies the title at the bottom of the eyetracker display
        Eyelink('command', 'record_status_message "TRIAL %d"', i_trial);
        % Before recording, we place reference graphics on the host display
        % Must be in offline mode to transfer image to Host PC
        Eyelink('Command', 'set_idle_mode');
        % clear tracker display and draw box at center
        Eyelink('Command', 'clear_screen %d', 0);

        % calculate locations of target peripheries so that we can draw
        % matching lines and boxes on host pc
        %         Eyelink('command', 'draw_filled_box %d %d %d %d 2', ...
        %             floor(win_width_px/2-amplitude_x_px)-20, floor(win_height_px/2-20), ...
        %             floor(win_width_px/2-amplitude_x_px)+20, floor(win_height_px/2+20));
        %         Eyelink('command', 'draw_line %d %d %d %d 2', ...
        %             floor(win_width_px/2-amplitude_x_px), floor(win_height_px/2), ...
        %             floor(win_width_px/2+amplitude_x_px), floor(win_height_px/2));
        %         Eyelink('command', 'draw_filled_box %d %d %d %d 2', ...
        %             floor(win_width_px/2+amplitude_x_px)-20, floor(win_height_px/2-20), ...
        %             floor(win_width_px/2+amplitude_x_px)+20, floor(win_height_px/2+20));
        %         Eyelink('command', 'draw_filled_box %d %d %d %d 2', ...
        %             floor(win_width_px/2-20), floor((win_height_px/2-amplitude_y_px)-20), ...
        %             floor(win_width_px/2+20), floor(win_height_px/2-amplitude_y_px)+20);
        %         Eyelink('command', 'draw_line %d %d %d %d 2', ...
        %             floor(win_width_px/2), floor(win_height_px/2-amplitude_y_px), ...
        %             floor(win_width_px/2), floor(win_height_px/2+amplitude_y_px));
        %         Eyelink('command', 'draw_filled_box %d %d %d %d 2', ...
        %             floor(win_width_px/2-20), floor(win_height_px/2+amplitude_y_px)-20, ...
        %             floor(win_width_px/2+20), floor(win_height_px/2+amplitude_y_px)+20);
        phase_x = curve_params(i_trial, 3);
        phase_y = 0; %trials(i_trial,4);
        x =  sine_plot_x_px + amplitude_x_px*sin(phase_x);
        y =  sine_plot_y_px + amplitude_y_px*sin(phase_y);
        target_pos([1 3]) = x + dot_radius*[-1 1];
        target_pos([2 4]) = y + dot_radius*[-1 1];

        WaitSecs(0.1);
        % STEP 7.2
        % Do a drift correction at the beginning of each trial
        % Performing drift correction (checking) is optional for
        % EyeLink 1000 eye trackers. Drift correcting at different
        % locations x and y depending on where the ball will start
        % we change the location of the drift correction to match that of
        % the target start position
        % Note drift correction does not accept fractionals in PTB!
        % EyelinkDoDriftCorrection(el,round(x),round(y));

        % STEP 7.3
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

        % get eye that's tracked
        %         eye_used = Eyelink('EyeAvailable');

        trial_end_time = GetSecs + trial_duration;
        trial_start_time = GetSecs;
        while GetSecs < trial_end_time

            % STEP 7.4
            % Prepare and show the screen.
            % Enable alpha blending with proper blend-function. We need it
            % for drawing of smoothed points:
            %             Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            %             Screen('FillRect', window, el.backgroundcolour);
            Screen('FillOval', window, target_colour, target_pos);
            Screen('Flip', window);
            Eyelink('Message', 'SYNCTIME');
            % STEP 7.5
            % send the location of the target at each iteration so that
            % target can be displayed in Dataviewer
            Eyelink('message', '!V TARGET_POS TARG1 (%d, %d) 1 0', floor(x), floor(y));

            phase_x = curve_params(i_trial, 3) + ...
                (GetSecs - trial_start_time) * curve_params(i_trial, 1);
            phase_y = (GetSecs - trial_start_time) * curve_params(i_trial, 2);

            x =  sine_plot_x_px + amplitude_x_px*sin(phase_x);
            y =  sine_plot_y_px + amplitude_y_px*sin(phase_y);

            target_pos([1 3]) = x + dot_radius*[-1 1];
            target_pos([2 4]) = y + dot_radius*[-1 1];
        end

        Screen('Flip', window, [], 1)

        % STEP 7.6
        % add 100 msec of data to catch final events and blank display
        WaitSecs(0.1);
        Eyelink('StopRecording');

        Screen('FillRect', window, el.backgroundcolour);
        Screen('Flip', window);

        % STEP 7.7
        % Send out necessary integration messages for data analysis
        % See "Protocol for EyeLink Data to Viewer Integration-> Interest
        % Area Commands" section of the EyeLink Data Viewer User Manual
        % IMPORTANT! Don't send too many messages in a very short period of
        % time or the EyeLink tracker may not be able to write them all
        % to the EDF file.
        % Consider adding a short delay every few messages.
        WaitSecs(0.001);
        % Send messages to report trial condition information
        % Each message may be a pair of trial condition variable and its
        % corresponding value follwing the '!V TRIAL_VAR' token message
        % See "Protocol for EyeLink Data to Viewer Integration-> Trial
        % Message Commands" section of the EyeLink Data Viewer User Manual
        WaitSecs(0.001);

        Eyelink('Message', '!V TRIAL_VAR index %d', i_trial);

        % a limitation of the currect ETB only accepts ints as input to
        % messages and commands a possible work around is given below

        msg_freq_x = sprintf('!V TRIAL_VAR freq_x %2.3f ', curve_params(i_trial, 1));
        msg_freq_y = sprintf('!V TRIAL_VAR freq_y %2.3f ', curve_params(i_trial, 2));
        Eyelink('Message', msg_freq_x);
        Eyelink('Message', msg_freq_y);

        % STEP 7.8
        % Sending a 'TRIAL_RESULT' message to mark the end of a trial in
        % Data Viewer. This is different than the end of recording message
        % END that is logged when the trial recording ends. The viewer will
        % not parse any messages, events, or samples that exist in the data
        % file after this message.
        Eyelink('Message', 'TRIAL_RESULT 0');

    end

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

    % rename the transferred file from the Host PC name to the name typed at
    % the prompt in STEP 1
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
