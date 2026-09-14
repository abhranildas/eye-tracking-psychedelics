% MOVIE_TEST  Psychtoolbox demo: draw dots in the screen corners and record
%             the display to an .mp4, optionally cropped to one quadrant.
%
%   Runs top to bottom in one pass -- not a cell-divided workflow, and not a
%   callable function. As currently written it never gets past line 14 (see
%   the known bug below), so nothing past that point actually executes.
%
% Inputs
%   None as arguments. Clears the entire workspace and closes all figures on
%   entry (`clear all; close all;`), so nothing needs to pre-exist. DO_MOVIE
%   and MOVIE_TYPE (hard-coded below) select whether a movie is recorded and
%   which crop rect is used for it.
%
% Output
%   None returned. Opens a full-screen Psychtoolbox window, draws dots in the
%   screen corners/edge midpoints/centre until any key is pressed, and, if
%   DO_MOVIE, writes the capture to exampleMovieType<N>.mp4 in the working
%   directory, where N is MOVIE_TYPE -- 1 crops to the default AddFrameToMovie
%   rect (bottom-left in practice), 2 crops to WINDOW_RECT (the whole window,
%   i.e. no effective crop).
%
% Known bugs, recorded and deliberately NOT fixed here: 0.4.15 -- line 14
% is a bare `thfgfgg`, an undefined identifier, which aborts the script
% immediately; the comment above it ("For dmeo only") suggests it was left in
% deliberately to stop this demo running unattended. Resolving the abort and
% the dead MOVIE_TYPE == 1 branch is Tier C item 0.3.13, not this pass.
%
% See also LIB.ANIMATE_TRIAL

% Clear the workspace
clear all;
close all;

% Cue to do movie or not
do_movie = 1;

% This changes either default for rect for add frame or specified
% (1) Gives a captured movie showing only the bottom left
% (2) Gives a captured movie showing only the top left
movie_type = 2;

% For dmeo only
% NOTE: bug 0.4.15 -- undefined identifier, aborts the script here.
thfgfgg

Screen('Preference', 'SkipSyncTests', 2);

% Setup and open screen
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'UseRetinaResolution');
PsychImaging('FinalizeConfiguration');

screenid = max(Screen('Screens'));

[window, window_rect] = PsychImaging('OpenWindow', screenid);

% Start the movie now if requested
if do_movie == 1
    movie_ptr = Screen('CreateMovie', window, ...
        ['exampleMovieType' num2str(movie_type) '.mp4']);
end

% Draw dots in the corners of the screen

bottom = window_rect(4);
top = 0;
left = 0;
right = window_rect(3);
middle_x_px = window_rect(3) / 2;
middle_y_px = window_rect(4) / 2;

xy_pos_px = [left top; right top; left bottom; right bottom; ...
    middle_x_px top; middle_x_px bottom; left middle_y_px; right middle_y_px; ...
    window_rect(3) / 2 window_rect(4) / 2]';
colors = [255 0 0; 0 255 0; 0 0 255; 0 0 0; ...
    128 128 128; 128 128 128; 128 128 128; 128 128 128; 255 255 0]';

% Drawing loop
while ~KbCheck
    Screen('DrawDots', window, xy_pos_px, 15, colors, [0 0], 2)
    Screen('Flip', window)
    if do_movie == 1

        if movie_type == 1
            Screen('AddFrameToMovie', window, [], [], movie_ptr);
        elseif movie_type == 2
            Screen('AddFrameToMovie', window, window_rect, [], movie_ptr);
        end

    end
end

% Clean up and leave the building
Screen('FinalizeMovie', movie_ptr);
sca
