function [t, xy] = true_target_traj(edf_mat)
% Extract times and [x y] from messages like:
% '!V TARGET_POS TARG1 (1591, 578) 1 0'
% Returns:
%   t  - [N x 1] times (same units as edf_mat.Events.Messages.time)
%   xy - [N x 2] coordinates, columns = [x y]

msgs  = edf_mat.Events.Messages.info;   % cell row vector of strings
times = edf_mat.Events.Messages.time;   % numeric row vector

pat = '!V TARGET_POS TARG1 \((\d+),\s*(\d+)\)';

% preallocate growing vectors (simple, clear)
t  = [];
xv = [];
yv = [];

for i = 1:numel(msgs)
    tok = regexp(msgs{i}, pat, 'tokens', 'once');
    if ~isempty(tok)
        xv(end+1,1) = str2double(tok{1}); %#ok<AGROW>
        yv(end+1,1) = str2double(tok{2}); %#ok<AGROW>
        t (end+1,1) = times(i);           %#ok<AGROW>
    end
end

xy = [xv yv];
end
