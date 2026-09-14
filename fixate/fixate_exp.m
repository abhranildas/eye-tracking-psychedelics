function fixate_exp
%
% ___________________________________________________________________
%
% Pro-saccade and anti-saccade task
%
% ___________________________________________________________________

% set up trials
fixation_duration=300; % in sec
dot_radius=5; % corner calibration dots
target_radius=1; % fixation target
target_colour=100*[1 1 1];

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
        edf_default = 'saccade';
        edf_file=input(prompt,'s');

        if exist([edf_file '.edf'],'file')
            disp('The file exists!');
            return
        end

    end

    %%%%%%%%%%
    % STEP 2 %
    %%%%%%%%%%

    % Open a graphics window on the main screen
    % using the PsychToolbox's Screen function.
    screenNumber=1;
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % skip sync tests

    [window,~]=Screen('OpenWindow', screenNumber, 0,[],32,2); %#ok<*NASGU>
    % [window, windowrect] = PsychImaging('OpenWindow', screenNumber);
    Screen(window,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    [winWidth, winHeight] = WindowSize(window);

    %     moviePtr = Screen('CreateMovie', window, 'saccade_movie.mp4', [],[],1);

    % fixation dot
    fix_pos([1 3]) = winWidth/2+target_radius*[-1 1];
    fix_pos([2 4]) = winHeight/2+target_radius*[-1 1];

    %%%%%%%%%%
    % STEP 3 %
    %%%%%%%%%%

    % Provide Eyelink with details about the graphics environment
    % and perform some initializations. The information is returned
    % in a structure that also contains useful defaults
    % and control codes (e.g. tracker state bit and Eyelink key values).

    el=EyelinkInitDefaults(window);

    % We are changing calibration to match task background and target
    % this eliminates affects of changes in luminosity between screens
    % no sound and smaller targets
    %     el.targetbeep = 0;
    el.backgroundcolour = [0 0 0];
    el.msgfontcolour = 255;
    el.calibrationtargetcolour= 255*[1 1 1];
    % for lower resolutions you might have to play around with these values
    % a little. If you would like to draw larger targets on lower res
    % settings please edit PsychEyelinkDispatchCallback.m and see comments
    % in the EyelinkDrawCalibrationTarget function
    el.calibrationtargetsize= 1;
    el.calibrationtargetwidth=0.5;
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

    % open file to record data to
    res = Eyelink('Openfile', edf_default);
    if res~=0
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
    Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', 0, 0, winWidth-1, winHeight-1);
    Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, winWidth-1, winHeight-1);
    % set calibration type.
    Eyelink('command', 'calibration_type = HV9');
    Eyelink('command', 'generate_default_targets = YES');

    % STEP 5.1 retrieve tracker version and tracker software version
    [v,vs] = Eyelink('GetTrackerVersion');
    fprintf('Running experiment on a ''%s'' tracker.\n', vs );
    vsn = regexp(vs,'\d','match');

    if v == 3 && str2double(vsn{1}) == 4 % if EL 1000 and tracker version 4.xx

        % remote mode possible add HTARGET ( head target)
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT,HTARGET');
        % set link data (used for gaze cursor)
        Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,FIXUPDATE,INPUT');
        Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT,HTARGET');
    else
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT');
        % set link data (used for gaze cursor)
        Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,FIXUPDATE,INPUT');
        Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
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
    corners=[0 0;
        0 winHeight-2*dot_radius;
        winWidth-2*dot_radius winHeight-2*dot_radius;
        winWidth-2*dot_radius 0];

    for iCorner=1:4

        % Sending a 'TRIALID' message to mark the start of a trial in Data
        % Viewer.  This is different than the start of recording message
        % START that is logged when the trial recording begins. The viewer
        % will not parse any messages, events, or samples, that exist in
        % the data file prior to this message.
        Eyelink('Message', 'TRIALID 0.%d', iCorner);

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
        corner_pos([1 2])=corners(iCorner,:);
        corner_pos([3 4])=corners(iCorner,:)+2*dot_radius;
        Screen('FillOval', window,255*[1 1 1], corner_pos);
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

    % Now starts running trial
    % You can keep the rest of the code except for the implementation
    % of graphics and event monitoring
    % Each trial should have a pair of "StartRecording" and "StopRecording"
    % calls as well integration messages to the data file (message to mark
    % the time of critical events and the image/interest area/condition
    % information for the trial)


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
    Screen('FillOval', window,target_colour, fix_pos);
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
        status=Eyelink('ReceiveFile');
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
        movefile([edf_default '.edf'],[edf_file '.edf']);
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
