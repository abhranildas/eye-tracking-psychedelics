% Clear the workspace
clear all;
close all;

% Cue to do movie or not
doMovie = 1;

% This changes either default for rect for add frame or specified
% (1) Gives a captured movie showing only the bottom left
% (2) Gives a captured movie showing only the top left
mType = 2;

% For dmeo only
thfgfgg



Screen('Preference', 'SkipSyncTests', 2);

% Setup and open screen
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'UseRetinaResolution');
PsychImaging('FinalizeConfiguration');

screenid = max(Screen('Screens'));

[window, windowRect] = PsychImaging('OpenWindow', screenid);

% Start the movie now if requested
if doMovie == 1
moviePtr = Screen('CreateMovie', window, ['exampleMovieType' num2str(mType) '.mp4']);
end

% Draw dots in the corners of the screen

bottom = windowRect(4);
top = 0;
left = 0;
right = windowRect(3);
middleX = windowRect(3) / 2;
middleY = windowRect(4) / 2;

xyPos = [left top; right top; left bottom; right bottom;...
middleX top; middleX bottom; left middleY; right middleY;...
windowRect(3) / 2 windowRect(4) / 2]';
colors = [255 0 0; 0 255 0; 0 0 255; 0 0 0;...
128 128 128; 128 128 128; 128 128 128; 128 128 128; 255 255 0]';

% Drawing loop
while ~KbCheck
Screen('DrawDots', window, xyPos, 15, colors, [0 0], 2)
Screen('Flip', window)
if doMovie == 1

    if mType == 1
        Screen('AddFrameToMovie', window, [], [], moviePtr);
    elseif mType == 2
        Screen('AddFrameToMovie', window, windowRect, [], moviePtr);
    end

end
end

% Clean up and leave the building
Screen('FinalizeMovie', moviePtr);
sca

