function free_view_exp
% FREE_VIEW_EXP  Run one session of the free-viewing (IAPS image) task.
%   free_view_exp
%
%   One session of a free-viewing task, presented with Psychtoolbox and
%   recorded on an EyeLink 1000. Each trial shows a 3x3 grid of nine IAPS
%   images at once, drawn from setup/setup_pre.mat or setup/setup_post.mat
%   depending on which the typed file name asks for.
%
%   The session runs in three phases. First a corner-marking phase: a white
%   dot is shown for 5 s at each of the four screen corners in turn, recorded
%   as trials 0.1 to 0.4, which gives the analysis chain four known screen
%   positions to fit its calibration correction to (lib.preprocess_gaze reads
%   them back as its 'corners' input). Then n_trials task trials: a central
%   fixation dot for fixation_duration, then a 3x3 grid of images for
%   target_duration. Finally the recording is closed, transferred into the
%   data/ subdirectory and renamed.
%
%   Each trial is bracketed by its own StartRecording / StopRecording pair and
%   by TRIALID / TRIAL_RESULT messages for Data Viewer; unlike the other five
%   *_exp.m files, no trial condition variable is sent (the commented-out
%   msg1/msg2 block below TRIAL_VAR index is dead code left over from the
%   saccade template this file was copied from -- there is no target_dir or
%   saccade_type here).
%
% Inputs
%   None as arguments. What the function actually consumes:
%
%   setup.mat  loaded from setup/setup_pre.mat or setup/setup_post.mat,
%              selected by the '_pre'/'_post' suffix of the typed file name.
%              One variable read here, frozen by the shipped artifact
%              (docs/repo-cleanup.md section 4.1.1, zone 3), so neither the
%              load string nor the variable name may change:
%                exp_IAPS_ids  [n_trials x n_pics] IAPS image ID numbers,
%                              DIMENSIONLESS, one row per trial. n_pics = 9,
%                              one per grid cell.
%   keyboard   one command-window prompt, read before any graphics open: the
%              EDF file name to save under, which must match
%              '^[a-z]{3}\d{3}_(pre|post)$' -- three letters, three digits,
%              then _pre or _post -- and must not already exist under data/.
%   hardware   display screen_number = 0, and a live EyeLink host. Unlike the
%              other five *_exp.m files, dummymode is 1 here, but this file
%              is still not to be run: EyelinkInit(1) only simulates the
%              tracker connection, Psychtoolbox graphics calls still need a
%              real display, and the reachable code path is otherwise
%              identical to the other five.
%
%   Timing and geometry are hard-coded at the top of the file and the names do
%   not carry their units:
%     fixation_duration  0.2 SECONDS here. The same name means 1 s in
%                        saccade_exp.m and 300 s in fixate_exp.m, three
%                        orders of magnitude apart under one name, so never
%                        carry a value for it across files.
%     target_duration    10 SECONDS, how long the 3x3 image grid stays on.
%     dot_radius         5 PIXELS, radius of the fixation and corner dots.
%     n_rows, n_cols     3, 3 -- the image grid is 3x3 cells, not quadrants
%                        (section 4.1.1: the old numRows/numCols/quads naming
%                        called these "quadrants", which is wrong for a 3x3
%                        layout).
%
% Output
%   None returned. The side effects are the point:
%     - an EDF recording written on the EyeLink Host PC under the 8-character
%       name held in edf_default ('free'), transferred into data/ (unlike the
%       other five *_exp.m files, which transfer into pwd) and then renamed
%       to the name typed at the prompt.
%     - the Psychtoolbox window and the tracker connection, both closed by
%       the nested cleanup function on every exit path, including the error
%       path.
%
% Known bugs, recorded and deliberately NOT fixed here
%   0.4.7   The file-name pattern below rejects '_post_control', yet
%              fixate/ibo027_post_control.edf exists and
%              free_view_analyze.m:31 handles it explicitly. This file cannot
%              produce a name the analysis side already expects. See the
%              inline NOTE at the pattern.
%   0.4.14  dummymode = 1 (above) makes the
%              "Eyelink('IsConnected')~=1 && ~dummymode" check below
%              unreachable (checkcode UNRCH): the connection check is dead.
%              See the inline NOTE at the site.
%
% See also SACCADE_EXP, SACCADE_LR_EXP, SPEM_EXP, FIXATE_EXP,
%   LIB.PREPROCESS_GAZE, EYELINKINITDEFAULTS

prompt = 'File name: ';
edf_default = 'free';
edf_file = input(prompt, 's');

% NOTE: bug 0.4.7 -- this pattern rejects '_post_control', which
% fixate/ibo027_post_control.edf and free_view_analyze.m:31 both expect.
pattern = '^[a-z]{3}\d{3}_(pre|post)$';

if isempty(regexp(edf_file, pattern, 'once'))
    disp('Incorrect pattern for file name.');
    return
elseif exist(['data/' edf_file '.edf'], 'file')
    disp('The file exists!');
    return
else
    session_phase = regexp(edf_file, pattern, 'tokens');
    session_phase = session_phase{1}{1};
end

% set up trials
load(['setup/setup_' session_phase '.mat'], 'exp_IAPS_ids');

n_trials = size(exp_IAPS_ids, 1);
n_pics = size(exp_IAPS_ids, 2);
fixation_duration = 0.2;         % SECONDS
target_duration = 10;            % SECONDS
dot_radius = 5;                  % PIXELS

if ~IsOctave
    commandwindow;
else
    more off;
end

dummymode = 1;

try
    %%%%%%%%%%
    % STEP 1 %
    %%%%%%%%%%

    % Added a dialog box to set your own EDF file name before opening
    % experiment graphics. Make sure the entered EDF file name is 1 to 8
    % characters in length and only numbers or letters are allowed.

    % if IsOctave
    %     edf_default = 'DEMO';
    % else
    %     prompt = 'File name: ';
    %     edf_default = 'free';
    %     edf_file=input(prompt,'s');
    %
    %     if exist(['data/' edf_file '.edf'],'file')
    %         disp('The file exists!');
    %         return
    %     end
    %
    % end

    %%%%%%%%%%
    % STEP 2 %
    %%%%%%%%%%

    % Open a graphics window on the main screen
    % using the PsychToolbox's Screen function.
    screen_number = 0;
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % skip sync tests

    [window, rect] = Screen('OpenWindow', screen_number, 0, [], 32, 2); %#ok<*NASGU>
    Screen(window, 'BlendFunction', GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    [win_width_px, win_height_px] = WindowSize(window);

    % fixation dot
    fix_pos([1 3]) = win_width_px/2 + dot_radius*[-1 1];
    fix_pos([2 4]) = win_height_px/2 + dot_radius*[-1 1];

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
    % NOTE: bug 0.4.14 -- dummymode = 1 above makes ~dummymode always
    % false, so this whole check is unreachable (checkcode UNRCH).
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

        % start recording eye position (preceded by a short pause so that
        % the tracker can finish the mode transition)
        % The paramerters for the 'StartRecording' call controls the
        % file_samples, file_events, link_samples, link_events availability
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.05);
        Eyelink('StartRecording');

        % show fixation dot
        Screen('FillOval', window, 255*[1 1 1], fix_pos);
        Screen('Flip', window);
        WaitSecs(fixation_duration);

        % send the location of the target at each iteration so that
        % target can be displayed in Dataviewer
        %         Eyelink('message', '!V TARGET_POS TARG1 (%d, %d) 1 0',floor(x_target),floor(y));

        % Do a drift correction at the beginning of each trial
        % Performing drift correction (checking) is optional for
        % EyeLink 1000 eye trackers. Drift correcting at different
        % locations x and y depending on where the ball will start
        % we change the location of the drift correction to match that of
        % the target start position
        % Note drift correction does not accept fractionals in PTB!

        %         EyelinkDoDriftCorrection(el,round(win_width_px/2),round(win_height_px/2));

        %         WaitSecs(0.1);

        % get eye that's tracked
        %         eye_used = Eyelink('EyeAvailable');

        % Load the images
        img_nums = exp_IAPS_ids(i_trial, :);
        imageTextures = cell(1, n_pics);
        for i_pic = 1:n_pics
            imageData = imread(['data/IAPS/' num2str(img_nums(i_pic)) '.jpg']);
            imageTextures{i_pic} = Screen('MakeTexture', window, imageData);
        end

        % Divide the screen into a 3x3 grid of cells. n_rows/n_cols are both
        % 3: these are grid cells, not quadrants (section 4.1.1) -- the old
        % numRows/numCols/quads naming called a 3x3 layout "quadrants", which
        % was wrong.
        screen_width_px = rect(3);
        screen_height_px = rect(4);
        n_cols = 3;
        n_rows = 3;
        cell_width_px = screen_width_px / n_cols;
        cell_height_px = screen_height_px / n_rows;
        cell_rects = cell(n_rows, n_cols);
        for r = 1:n_rows
            for c = 1:n_cols
                cell_rects{r, c} = [(c - 1) * cell_width_px, (r - 1) * cell_height_px, ...
                    c * cell_width_px, r * cell_height_px];
            end
        end

        % Display the images in the grid cells
        for r = 1:n_rows
            for c = 1:n_cols
                Screen('DrawTexture', window, ...
                    imageTextures{(r - 1) * n_cols + c}, [], cell_rects{r, c});
            end
        end

        Screen('Flip', window);

        % Capture a screenshot
        %         screenshot = Screen('GetImage', window);

        % Save the screenshot as an image file (e.g., PNG)
        %         imwrite(screenshot, sprintf('screenshot_%d.png',i_trial));

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

        %         msg1 = sprintf('!V TRIAL_VAR target_dir %d ', target_dir(iTrial));
        %         msg2 = sprintf('!V TRIAL_VAR saccade_type %2.3f ', saccade_type(iTrial));
        %         Eyelink('Message', msg1);
        %         Eyelink('Message', msg2);

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

    % rename file
    if ~strcmp(edf_default, edf_file)
        movefile([edf_default '.edf'], ['data/' edf_file '.edf']);
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
