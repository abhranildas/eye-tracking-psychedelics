function [t, xy] = true_target_traj(edf_mat)
% TRUE_TARGET_TRAJ  Recover the smooth-pursuit target's path from EDF messages.
%   [t, xy] = true_target_traj(edf_mat)
%
%   The spem experiment writes the target's position to the tracker once per
%   display frame as a message of the form
%
%       !V TARGET_POS TARG1 (1591, 578) 1 0
%
%   so the target trajectory is not recorded as samples and has to be parsed
%   back out of the message stream. Messages that do not match are ignored, so
%   the returned vectors are shorter than the full message list and are sampled
%   at the display rate rather than the tracker's sample rate. Use
%   DOWNSAMPLE_TRAJ to put gaze on these same time stamps.
%
% Inputs
%   edf_mat  Edf2Mat object for one recording. Only EDF_MAT.EVENTS.MESSAGES is
%            read: .info, the message text, and .time, the message time stamps
%            in milliseconds on the EyeLink clock.
% Output
%   t   [N x 1] time of each target-position message, milliseconds on the
%       EyeLink clock, in message order.
%   xy  [N x 2] target position at those times, pixels, columns [x y], screen
%       coordinates with y growing downward (1920 x 1080 throughout this repo).
%
%   Returns empty for a recording with no target-position messages, which is
%   every non-spem recording in this repo. Since the Tier B preallocation
%   (docs/repo-cleanup.md item 0.2.1) that empty is now 0x1 and 0x2 rather than
%   the 0x0 and 0x0 the grow-in-place version produced. Both are empty and both
%   index the same way; this is the only behavioural difference the
%   preallocation introduced, and it is on a path no caller in this repo takes.
%
% See also DOWNSAMPLE_TRAJ, SPEM_MEASURES, LIB.PREPROCESS_GAZE, REGEXP

msgs  = edf_mat.Events.Messages.info;   % cell row vector of message strings
times = edf_mat.Events.Messages.time;   % numeric row vector, ms

% Captures the two integer pixel coordinates. TARG1 is the pursuit target; the
% trailing '1 0' fields of the message are the EyeLink visibility flags and are
% not captured.
target_pos_pattern = '!V TARGET_POS TARG1 \((\d+),\s*(\d+)\)';

% Pre-pass: count how many messages match, so the three vectors can be sized
% once rather than grown one element per message. This is pure string matching
% and makes no RNG draws, so it cannot disturb any caller's draw sequence.
is_target_msg = ~cellfun( ...
    @(msg) isempty(regexp(msg, target_pos_pattern, 'once')), msgs);
n_target = nnz(is_target_msg);

t    = zeros(n_target, 1);
x_px = zeros(n_target, 1);
y_px = zeros(n_target, 1);

i_target = 0;
for i_msg = 1:numel(msgs)
    coord_tokens = regexp(msgs{i_msg}, target_pos_pattern, 'tokens', 'once');
    if ~isempty(coord_tokens)
        i_target = i_target + 1;
        x_px(i_target) = str2double(coord_tokens{1});
        y_px(i_target) = str2double(coord_tokens{2});
        t(i_target)    = times(i_msg);
    end
end

xy = [x_px y_px];
end
