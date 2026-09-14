% SACCADE_SETUP  Generate a random pro-/anti-saccade trial list and save it.
%
%   Draws N_TRIALS random target angles and writes them to setup.mat for
%   SACCADE_EXP to load. Runs top to bottom in one pass; not a cell-divided
%   workflow.
%
% Inputs
%   None as arguments. Reads nothing from disk. Assumes the working directory
%   is saccade/, since that is where SACCADE_EXP looks for setup.mat.
% Output
%   setup.mat, written to the working directory. Holds TARGET_ANG ([n_trials
%   x 1] double, radians, uniform on [0, 2*pi)) -- a zone-3 frozen name,
%   loaded by SACCADE_EXP. The commented-out lines below would also generate
%   and save TARGET_DIR and SACCADE_TYPE ([n_trials x 1] logical each,
%   dimensionless), but are dead code, left exactly as found.
%
% Known bugs, recorded and deliberately NOT fixed here: 0.4.4 -- the SAVE
% below writes ONLY target_ang to setup.mat, which currently also holds
% saccade_type. SACCADE_EXP.m:10 loads both. Running this script overwrites
% that file and silently destroys saccade_type. Do not run it.
%
% See also SACCADE_EXP, SACCADE_LR_EXP

n_trials = 100;

% target_dir=logical(randi([0 1],[n_trials 1])); % target to right or left
% saccade_type=logical(randi([0 1],[n_trials 1])); % pro- or anti-saccade
%
% save('setup.mat','target_dir','saccade_type')

target_ang = 2*pi*rand(n_trials, 1);
% NOTE: bug 0.4.4 -- overwrites setup.mat, destroying the saccade_type
% field that SACCADE_EXP.m:10 also loads from this same file.
save('setup.mat', 'target_ang')
