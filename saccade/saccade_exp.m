function saccade_exp
% SACCADE_EXP  Run one session of the pro-saccade / anti-saccade task.
%   saccade_exp
%
%   One session of the saccade task, presented with Psychtoolbox and recorded
%   on an EyeLink 1000. The trial list is not generated here: it is loaded from
%   setup.mat in the current directory, which saccade_setup.m writes.
%
%   The session runs in three phases. First a corner-marking phase: a white dot
%   is shown for 5 s at each of the four screen corners in turn, recorded as
%   trials 0.1 to 0.4, which gives the analysis chain four known screen
%   positions to fit its calibration correction to (lib.preprocess_gaze reads
%   them back as its 'corners' input). Then n_trials task trials: a central
%   fixation dot for fixation_duration, then a peripheral target on a circle of
%   radius target_circ_radius about the screen centre, at angle
%   target_ang(i_trial), shown for target_duration together with a dim grey
%   anti-target diametrically opposite. A green target means pro-saccade (look
%   at it) and a red one means anti-saccade (look at the grey dot instead); for
%   a colour-blind subject the red dot is replaced by a red cross of the same
%   size, since colour alone would not carry the instruction. Finally the
%   recording is closed, transferred off the Host PC and renamed.
%
%   Each trial is bracketed by its own StartRecording / StopRecording pair and
%   by TRIALID / TRIAL_RESULT messages, and the target position and the two
%   trial variables are written into the message stream for Data Viewer.
%
% Inputs
%   None as arguments. What the function actually consumes:
%
%   setup.mat  loaded from the current directory, so run this file with
%              saccade/ as the working directory. Two variables, both frozen by
%              the shipped artifact (docs/repo-cleanup.md section 4.1.1, zone
%              3), so neither the load string nor the variable names may change:
%                target_ang    [n_trials x 1] angle of the target on the
%                              circle, RADIANS, measured from the +x axis with
%                              y growing downward.
%                saccade_type  [n_trials x 1] logical, DIMENSIONLESS.
%                              true = pro-saccade, false = anti-saccade.
%   keyboard   two command-window prompts, read before any graphics open: the
%              EDF file name to save under (1 to 8 characters, letters and
%              digits only; the run aborts if <name>.edf already exists), and
%              whether the subject is colour-blind, 'y' or 'n'.
%   hardware   display screen_number = 1, and a live EyeLink host. dummymode is
%              0, so there is no simulated-tracker path: without a host this
%              file cannot be run at all, not even as a dry run.
%
%   Timing and geometry are hard-coded at the top of the file and the names do
%   not carry their units:
%     fixation_duration   1 SECOND here. The same name means 0.2 s in
%                         free_view_exp.m and 300 s in fixate_exp.m, three
%                         orders of magnitude apart under one name, so never
%                         carry a value for it across files.
%     target_duration     1 SECOND, how long the target stays on.
%     dot_radius          5 PIXELS, radius of the fixation and target dots.
%     target_circ_radius  win_width_px/4 PIXELS, radius of the circle the
%                         target appears on.
%
% Output
%   None returned. The side effects are the point:
%     - an EDF recording written on the EyeLink Host PC under the 8-character
%       name held in edf_default ('saccade'), transferred into pwd at the end
%       of the session and then renamed to the name typed at the prompt.
%     - the Psychtoolbox window and the tracker connection, both closed by the
%       nested cleanup function on every exit path, including the error path.
%
% Known bugs, recorded and deliberately NOT fixed here
%   0.4.19  target_colour is assigned three times below and never read: all
%              the FillOval and DrawLine calls pass a literal colour vector
%              instead, so the pro/anti colour decision is made twice, once in
%              a dead variable and once in the drawing code. The assignments
%              are left in place; there is an inline NOTE at each site.
%   0.4.4   saccade_setup.m, which produces the setup.mat loaded below,
%              saves only target_ang and so destroys saccade_type. Re-running
%              it silently breaks this file. Do not run it.
%
% See also SACCADE_SETUP, SACCADE_LR_EXP, SPEM_EXP, FIXATE_EXP, FREE_VIEW_EXP,
%   LIB.PREPROCESS_GAZE, EYELINKINITDEFAULTS

% set up trials
load('setup.mat', 'target_ang', 'saccade_type');
n_trials = size(target_ang, 1);
fixation_duration = 1;    % SECONDS, central dot before the target appears
target_duration = 1;      % SECONDS, how long the target stays on
dot_radius = 5;           % PIXELS

if ~IsOctave
    commandwindow;
else
    more off;
end

% 0 = require a real EyeLink host. There is no dummy path in this file.
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
        % edf_default is the name the tracker writes on the Host PC; edf_file
        % is the name the transferred recording is renamed to at the end.
        edf_default = 'saccade';
        edf_file = input(prompt, 's');

        if exist([edf_file '.edf'], 'file')
            disp('The file exists!');
            return
        end

    end

    % Colour-blind subjects get a red cross instead of a red dot, because for
    % them the green/red pro/anti distinction carries no information.
    color_blind = '';
    while ~strcmpi(color_blind, 'y') && ~strcmpi(color_blind, 'n')
        color_blind = input('Is the subject colour-blind? y/n: ', 's');
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

    % PIXELS: radius of the circle around which the target will appear
    target_circ_radius = win_width_px/4;

    %     moviePtr = Screen('CreateMovie', window, 'saccade_movie.mp4', [],[],1);

    % fixation dot, as a PIXEL rect [left top right bottom] for FillOval
    fix_center = [win_width_px win_height_px]/2;
    fix_pos([1 3]) = fix_center(1) + dot_radius*[-1 1];
    fix_pos([2 4]) = fix_center(2) + dot_radius*[-1 1];

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

    % -- Define 'X' parameters:
    %    1. Color of the cross
    %    2. Length of each diagonal from the center
    %       (this is half the total length of the line)
    %    3. Line width
    % NOTE: bug 0.4.19 -- target_colour is never read, here or at either of
    % its two reassignments inside the trial loop. Left in place deliberately;
    % it is Tier C, not a Tier B unused-assignment target.
    target_colour = [255 0 0]; % Red
    half_length   = 8;         % PIXELS, centre of the cross to each tip
    line_width_px = 4;         % PIXELS, thickness of the lines

    % Calculate the end coordinates of the two diagonals, as PIXEL offsets from
    % the target centre. x1_1/y1_1 and x1_2/y1_2 are the two ends of diagonal 1,
    % x2_1/y2_1 and x2_2/y2_2 the two ends of diagonal 2.
    % Diagonal 1: top-left to bottom-right
    x1_1 = - half_length;  y1_1 = - half_length;
    x1_2 = half_length;  y1_2 = half_length;

    % Diagonal 2: bottom-left to top-right
    x2_1 = - half_length;  y2_1 = half_length;
    x2_2 = half_length;  y2_2 = - half_length;

    % Now starts running individual trials
    % You can keep the rest of the code except for the implementation
    % of graphics and event monitoring
    % Each trial should have a pair of "StartRecording" and "StopRecording"
    % calls as well integration messages to the data file (message to mark
    % the time of critical events and the image/interest area/condition
    % information for the trial)

    for i_trial = 1:n_trials

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

        % Prepare and show the screen.
        % Enable alpha blending with proper blend-function. We need it
        % for drawing of smoothed points:
        Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        Screen('FillRect', window, el.backgroundcolour);

        % show fixation dot
        Screen('FillOval', window, 255*[1 1 1], fix_pos);
        Screen('Flip', window);
        %         Screen('AddFrameToMovie', window, windowrect, [], moviePtr);
        WaitSecs(fixation_duration);

        % get target and anti-target position, PIXELS. The anti-target sits
        % diametrically opposite the target on the same circle, and is drawn at
        % half the radius so it reads as a dimmer, smaller marker.
        x_target = fix_center(1) + target_circ_radius*cos(target_ang(i_trial));
        y_target = fix_center(2) + target_circ_radius*sin(target_ang(i_trial));

        target_pos([1 3]) = x_target + dot_radius*[-1 1];
        target_pos([2 4]) = y_target + dot_radius*[-1 1];

        x_antitarget = fix_center(1) - target_circ_radius*cos(target_ang(i_trial));
        y_antitarget = fix_center(2) - target_circ_radius*sin(target_ang(i_trial));

        antitarget_pos([1 3]) = x_antitarget + dot_radius/2*[-1 1];
        antitarget_pos([2 4]) = y_antitarget + dot_radius/2*[-1 1];

        % send the location of the target at each iteration so that
        % target can be displayed in Dataviewer
        Eyelink('message', '!V TARGET_POS TARG1 (%d, %d) 1 0', floor(x_target), floor(y_target));

        % NOTE: bug 0.4.19 -- both assignments below are dead. The colours
        % that actually reach the screen are the literals in the FillOval and
        % DrawLine calls further down.
        if saccade_type(i_trial) % if pro-saccade
            target_colour = [0 255 0]; % green
        else
            target_colour = [255 0 0]; % red
        end

        % Do a drift correction at the beginning of each trial
        % Performing drift correction (checking) is optional for
        % EyeLink 1000 eye trackers. Drift correcting at different
        % locations x and y depending on where the ball will start
        % we change the location of the drift correction to match that of
        % the target start position
        % Note drift correction does not accept fractionals in PTB!

        %         EyelinkDoDriftCorrection(el,round(win_width_px/2),round(win_height_px/2));

        WaitSecs(0.1);

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

        if saccade_type(i_trial) % if pro-saccade
            % show green dot
            Screen('FillOval', window, [0 255 0], target_pos);
        else % if anti-saccade
            if strcmpi(color_blind, 'n')
                % show red dot
                Screen('FillOval', window, [255 0 0], target_pos);
            elseif strcmpi(color_blind, 'y')
                % show red cross
                Screen('DrawLine', window, [255 0 0], ...
                    x_target + x1_1, y_target + y1_1, ...
                    x_target + x1_2, y_target + y1_2, line_width_px);
                Screen('DrawLine', window, [255 0 0], ...
                    x_target + x2_1, y_target + y2_1, ...
                    x_target + x2_2, y_target + y2_2, line_width_px);
            end
        end

        % show grey dot across from red dot
        Screen('FillOval', window, 30*[1 1 1], antitarget_pos);

        Screen('Flip', window);

        %         % Capture a screenshot
        %         screenshot = Screen('GetImage', window);
        %
        %         % Save the screenshot as an image file (e.g., PNG)
        %         imwrite(screenshot, sprintf('screenshot_%d.png',i_trial));

        %         Screen('AddFrameToMovie', window, windowrect, [], moviePtr);

        WaitSecs(target_duration);
        %             Eyelink('Message', 'SYNCTIME');

        % add 100 msec of data to catch final events and blank display
        WaitSecs(0.1);
        Eyelink('StopRecording');

        Screen('FillRect', window, el.backgroundcolour);
        Screen('Flip', window);

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

        % The two trial variables Data Viewer will show, built as strings
        % first because Eyelink('Message', fmt, ...) takes only integers.
        % target_ang is in RADIANS, saccade_type is a logical printed as a
        % float. Both names match the frozen setup.mat variables, so the
        % message text must not be reworded.
        msg_target_ang = sprintf('!V TRIAL_VAR target_ang %.1f ', target_ang(i_trial));
        msg_saccade_type = sprintf('!V TRIAL_VAR saccade_type %2.3f ', saccade_type(i_trial));
        Eyelink('Message', msg_target_ang);
        Eyelink('Message', msg_saccade_type);

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

    %     Screen('FinalizeMovie', moviePtr);

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
        % Close the tracker connection and every Psychtoolbox window. Nested,
        % so it is reachable from the try block and from the catch.
        % Shutdown Eyelink:
        Eyelink('Shutdown');
        Screen('CloseAll');
    end

end
