nTrials=100;

% target_dir=logical(randi([0 1],[nTrials 1])); % target to right or left
% saccade_type=logical(randi([0 1],[nTrials 1])); % pro- or anti-saccade
% 
% save('setup.mat','target_dir','saccade_type')

target_ang=2*pi*rand(nTrials,1);
save('setup.mat','target_ang')

