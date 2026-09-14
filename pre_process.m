% results=struct;

%% calibrate files manually
% list files not yet calibrated
% load spem_results.mat

edfFiles  = dir('*.edf');
allNames  = erase({edfFiles.name}, '.edf');
doneNames = {results.name};
todoNames = setdiff(allNames, doneNames, 'stable');

% calibrate each file
i_todo = 1;
idx  = numel(results) + 1;
name = todoNames{i_todo}
edf_mat = Edf2Mat([name '.edf']);

% check that sampling rate was 1 KHz throughout
if unique([edf_mat.RawEdf.RECORDINGS.sample_rate])~=1000
    warning('sampling rate not 1KHz')
end

lib.preprocess_gaze(edf_mat);
title(name)

% Initial rectangle (screen coords; y grows downward)
screen_w = 1920; screen_h = 1080;
calib_sz=2/3;
initPos=[screen_w screen_h]/2 + ...\
    [-[screen_w screen_h]; [screen_w -screen_h]; [screen_w screen_h]; [-screen_w screen_h]]/2*calib_sz;


roi = drawpolygon('Parent', gca, ...
    'Position', initPos, ...
    'FaceAlpha', 0.05, 'LineWidth', 1.5, ...
    'InteractionsAllowed','reshape');  % allow dragging vertices

%% after manual clicking, store corners
corners = roi.Position;
% calibrate and return corrected trajectory (blinks removed)
[gaze_x,gaze_y] = lib.preprocess_gaze(edf_mat,'corners',corners,'calib_sz',calib_sz);
axis([0 1920 0 1080])
title(name)

% store calibration in struct
results(idx).name    = name;
results(idx).corners = corners;

% save 'spem_results.mat' results

%% sort the struct by name
% Build sortable keys
names = string({results.name})';

grp   = regexp(names,'^(gss|ibo|aya)','match','once');            % gss/ibo/aya
[~, grpRank] = ismember(grp, ["gss","ibo","aya"]);                % gss=1, ibo=2, aya=3
grpRank(grpRank==0) = 99;                                         % (fallback)

numID = str2double(regexp(names,'(?<=^[a-z]+)\d+','match','once'));% number after prefix

phaseRank = 2*ones(numel(names),1);                               % default: post=2
phaseRank(endsWith(names,'_pre'))           = 1;                   % pre first
phaseRank(endsWith(names,'_post_control'))  = 3;                   % post_control after post

% Sort by: group → number → phase
[~, ord] = sortrows([grpRank(:), numID(:), phaseRank(:)]);
results = results(ord);