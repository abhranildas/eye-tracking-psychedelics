function smooth_pursuit_solo_exp
%
% ___________________________________________________________________
%
% Demo implementation of pursuit task
% stimulus: A target moving on a Lissajous curve
% This task demonstrates stimuli presentation with Eyelink and Data Viewer
% integration.
%
% ___________________________________________________________________

% HISTORY
% mm/dd/yy
%
% 01/28/11  NJ  created
% 12/20/13  LJ  changed isoctave to IsOctave, case sensitive for the latest matlab
%                fixed issue with non integer arguments for Eyelink('message' ...) and Eyelink('command' ...)
%



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
        
curve_params=[freqs phases];

trial_duration = 30; % in sec

dot_radius=5;

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
    screenNumber=1; %max(Screen('Screens'));
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % skip sync tests
    
    [window, ~]=Screen('OpenWindow', screenNumber, 0,[],32,2); %#ok<*NASGU>
    Screen(window,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    [winWidth, winHeight] = WindowSize(window);
    
    % define sine function
    sine_plot_x = winWidth/2;
    sine_plot_y = winHeight/2;
    amplitudeX = winWidth/3;
    amplitudeY = winHeight/3;
    
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
    el.backgroundcolour = 0*[1 1 1];
    el.msgfontcolour = 255;
    el.calibrationtargetcolour= 255*[1 1 1];
    target_colour=255*[1 1 1];
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
    
    Eyelink('command', 'add_file_preamble_text ''Recorded by EyelinkToolbox demo-experiment''');
    % Setting the proper recording resolution, proper calibration type,
    % as well as the data file content;
    
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
    
    
    % Now starts running individual trials
    % You can keep the rest of the code except for the implementation
    % of graphics and event monitoring
    % Each trial should have a pair of "StartRecording" and "StopRecording"
    % calls as well integration messages to the data file (message to mark
    % the time of critical events and the image/interest area/condition
    % information for the trial)
    
    for iTrial=1:size(curve_params,1)
        
        % STEP 7.1
        % Sending a 'TRIALID' message to mark the start of a trial in Data
        % Viewer.  This is different than the start of recording message
        % START that is logged when the trial recording begins. The viewer
        % will not parse any messages, events, or samples, that exist in
        % the data file prior to this message.
        Eyelink('Message', 'TRIALID %d', iTrial);
        
        % This supplies the title at the bottom of the eyetracker display
        Eyelink('command', 'record_status_message "TRIAL %d"', iTrial);
        % Before recording, we place reference graphics on the host display
        % Must be in offline mode to transfer image to Host PC
        Eyelink('Command', 'set_idle_mode');
        % clear tracker display and draw box at center
        Eyelink('Command', 'clear_screen %d', 0);
        
        % calculate locations of target peripheries so that we can draw
        % matching lines and boxes on host pc
        %         Eyelink('command', 'draw_filled_box %d %d %d %d 2' ,floor(winWidth/2-amplitudeX)-20, floor(winHeight/2-20), floor(winWidth/2-amplitudeX)+20, floor(winHeight/2+20));
        %         Eyelink('command', 'draw_line %d %d %d %d 2' ,floor(winWidth/2-amplitudeX), floor(winHeight/2), floor(winWidth/2+amplitudeX), floor(winHeight/2));
        %         Eyelink('command', 'draw_filled_box %d %d %d %d 2' ,floor(winWidth/2+amplitudeX)-20, floor(winHeight/2-20), floor(winWidth/2+amplitudeX)+20, floor(winHeight/2+20));
        %         Eyelink('command', 'draw_filled_box %d %d %d %d 2' ,floor(winWidth/2-20), floor((winHeight/2-amplitudeY)-20), floor(winWidth/2+20), floor(winHeight/2-amplitudeY)+20);
        %         Eyelink('command', 'draw_line %d %d %d %d 2' ,floor(winWidth/2), floor(winHeight/2-amplitudeY), floor(winWidth/2), floor(winHeight/2+amplitudeY));
        %         Eyelink('command', 'draw_filled_box %d %d %d %d 2' ,floor(winWidth/2-20), floor(winHeight/2+amplitudeY)-20, floor(winWidth/2+20), floor(winHeight/2+amplitudeY)+20);
        phaseX = curve_params(iTrial,3);
        phaseY = 0; %trials(iTrial,4);
        x =  sine_plot_x + amplitudeX*sin(phaseX);
        y =  sine_plot_y + amplitudeY*sin(phaseY);
        target_pos([1 3]) = x+dot_radius*[-1 1];
        target_pos([2 4]) = y+dot_radius*[-1 1];
        
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
        
        trialTime = GetSecs + trial_duration;
        sttime = GetSecs;
        while GetSecs < trialTime
            
            % STEP 7.4
            % Prepare and show the screen.
            % Enable alpha blending with proper blend-function. We need it
            % for drawing of smoothed points:
%             Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
%             Screen('FillRect', window, el.backgroundcolour);
            Screen('FillOval', window,target_colour, target_pos);
            Screen('Flip', window);
            Eyelink('Message', 'SYNCTIME');
            % STEP 7.5
            % send the location of the target at each iteration so that
            % target can be displayed in Dataviewer
            Eyelink('message', '!V TARGET_POS TARG1 (%d, %d) 1 0',floor(x),floor(y));
            
            
            
            phaseX = curve_params(iTrial,3) + (GetSecs-sttime) * curve_params(iTrial,1);
            phaseY = (GetSecs-sttime) * curve_params(iTrial,2);
            
            x =  sine_plot_x + amplitudeX*sin(phaseX);
            y =  sine_plot_y + amplitudeY*sin(phaseY);
            
            target_pos([1 3]) = x+dot_radius*[-1 1];
            target_pos([2 4]) = y+dot_radius*[-1 1];
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
        
        
        Eyelink('Message', '!V TRIAL_VAR index %d', iTrial);
        
        % a limitation of the currect ETB only accepts ints as input to
        % messages and commands a possible work around is given below
        
        
        msg1 = sprintf('!V TRIAL_VAR freq_x %2.3f ', curve_params(iTrial,1));
        msg2 = sprintf('!V TRIAL_VAR freq_y %2.3f ', curve_params(iTrial,2));
        Eyelink('Message', msg1);
        Eyelink('Message', msg2);
        
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
