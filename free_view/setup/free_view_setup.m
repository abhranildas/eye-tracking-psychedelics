% FREE_VIEW_SETUP  Build the pre- and post-session IAPS image trial lists.
%
%   Picks n_screens groups of n_imgs IAPS images each, clustered by arousal
%   rating, for the pre session, then derives a post-session list by
%   shuffling both screen order and within-screen image order. Cell-divided
%   interactive workflow: run section by section by hand, with workspace
%   carryover between sections, not top to bottom in one pass. Six sections,
%   in order: a deprecated binning algorithm (commented out, kept for
%   reference only, never executed); the live image-picking loop; a manual
%   review of the pre-session screens; a (currently dead) save point; the
%   post-session shuffle; and a manual review of the post-session screens.
%
% Inputs
%   None as arguments.
%   Files read: IAPS/IAPS_ratings.mat, holding IAPS_id, arousal_avg,
%     arousal_sd, valence_avg, valence_sd, dominance_avg, dominance_sd (all
%     [n_images x 1], IAPS 1-9 rating scales except IAPS_id). The path is
%     literally 'IAPS/...', so the working directory must be free_view/data
%     for this to resolve (bug 0.4.9) -- it does NOT resolve from
%     free_view/setup/, where this script lives.
%   Working directory: free_view/data (see above).
%   Workspace carryover required for the later sections: "view trials" reads
%     back exp_arousals/exp_valences/exp_IAPS_ids left by "new method...";
%     "shuffle trials for post" reads exp_IAPS_ids/exp_arousals/exp_valences
%     the same way. Both sections also each call `load setup.mat`, but no
%     setup.mat exists in free_view/setup/ -- only setup_pre.mat/
%     setup_post.mat do -- so that load either errors or, if saccade/ is on
%     the path, silently loads the unrelated saccade trial list instead
%     (bug 0.4.8). The workspace variables are what these sections
%     actually depend on, not that load.
%
% Output
%   None returned; nothing is written to disk by the code that actually
%   runs. The "save settings" section's own `save('setup.mat', ...)` is
%   commented out, and the post-session section computes
%   exp_IAPS_ids_post/exp_arousals_post/exp_valences_post but never saves
%   them either (bug 0.4.10) -- so this script cannot currently reproduce
%   either setup_pre.mat or setup_post.mat on disk; both must already exist
%   from an earlier run for FREE_VIEW_EXP to load.
%   Left in the workspace: exp_ids, exp_IAPS_ids, exp_arousals, exp_valences
%     ([n_screens x n_imgs] each, IAPS index/id/arousal/valence per screen
%     position) for the pre list; exp_IAPS_ids_post, exp_arousals_post,
%     exp_valences_post, post_img_idx, post_screen_idx for the post list;
%     and two figure windows opened by the review sections.
%   setup_pre.mat (when saved by hand from the workspace) freezes
%     exp_IAPS_ids, exp_arousals, exp_valences. setup_post.mat additionally
%     freezes post_img_idx and post_screen_idx under those exact names --
%     but NOT exp_IAPS_ids_post/exp_arousals_post/exp_valences_post, which
%     despite looking identical in form are free local names, not present in
%     any .mat (as is exp_ids, throughout). FREE_VIEW_EXP loads exp_IAPS_ids
%     from whichever of the two files matches the running session's phase.
%
% Known bugs, recorded and deliberately NOT fixed here: 0.4.8 (both
% `load setup.mat` calls below load the wrong file, or the saccade
% experiment's trial list, if saccade/ is on the path), 0.4.9 (every
% 'IAPS/...' path below resolves only from free_view/data), 0.4.10 (the
% post-session variables computed below are never saved, so setup_post.mat
% cannot be reproduced by running this script).
%
% See also FREE_VIEW_EXP

%% deprecated way of binning all images in advance

% load('IAPS/IAPS_ratings.mat')
% n_bins=30;
% n_trials=100;
% n_pics=6;
%
% [bin_counts,bin_edges,bin]=histcounts(arousal_avg,n_bins);
%
% binned_ids=cell(n_bins,1);
% binned_arousals=cell(n_bins,1);
% binned_valences=cell(n_bins,1);
% for iBin=1:n_bins
%     ids_thisbin=find(bin==iBin);
%     binned_ids{iBin}=ids_thisbin;
%     binned_arousals{iBin}=arousal_avg(ids_thisbin);
%     binned_valences{iBin}=valence_avg(ids_thisbin);
% end
%
% exp_ids=nan(n_bins,n_pics);
% exp_IAPS_ids=nan(n_bins,n_pics);
% exp_arousals=nan(n_bins,n_pics);
% exp_valences=nan(n_bins,n_pics);
%
% for iTrial=1:n_trials
%     select_bin=randsample(find(bin_counts>=n_pics),1);
%     valences=binned_valences{select_bin};
%     [valences_sorted,sortID]=sort(valences);
%     ids_thisbin=binned_ids{select_bin};
%     select_id=ids_thisbin(sortID([1:3 end-2:end]));
%
%     % randomize the spatial order in each trial
%     select_id=select_id(randperm(length(select_id)));
%
%     exp_ids(iTrial,:)=select_id;
%     exp_IAPS_ids(iTrial,:)=IAPS_id(select_id);
%     exp_arousals(iTrial,:)=arousal_avg(select_id);
%     exp_valences(iTrial,:)=valence_avg(select_id);
%
%     % remove these images from the database
%     bin_counts(select_bin)=bin_counts(select_bin)-n_pics;
%     binned_ids{select_bin}=setdiff(binned_ids{select_bin},select_id);
%     binned_valences{select_bin}=valence_avg(binned_ids{select_bin});
% end

%% new method of picking closest neighbours

% NOTE: bug 0.4.9 -- resolves only when the working directory is
% free_view/data.
load('IAPS/IAPS_ratings.mat')
n_screens = 73;
n_imgs = 9;

exp_ids = nan(n_screens, n_imgs);
exp_IAPS_ids = nan(n_screens, n_imgs);
exp_arousals = nan(n_screens, n_imgs);
exp_valences = nan(n_screens, n_imgs);

for i_screen = 1:n_screens
    % pick a random point
    firstid = randsample(length(IAPS_id), 1);
    [~, idx] = sort(abs(arousal_avg - arousal_avg(firstid)));
    ids_thistrial = idx(1:n_imgs);

    % randomize the spatial order in each trial
    ids_thistrial = ids_thistrial(randperm(length(ids_thistrial)));

    exp_ids(i_screen, :) = ids_thistrial;
    exp_IAPS_ids(i_screen, :) = IAPS_id(ids_thistrial);
    exp_arousals(i_screen, :) = arousal_avg(ids_thistrial);
    exp_valences(i_screen, :) = valence_avg(ids_thistrial);

    % remove these images from the database
    % NOTE: this is element deletion, not growth, and it is coupled to the
    % RNG draws above through ids_thistrial -- leave the indexing as is.
    IAPS_id(ids_thistrial) = [];
    arousal_avg(ids_thistrial) = [];
    valence_avg(ids_thistrial) = [];
end

% randomize trial order
randorder = randperm(n_screens);
exp_ids = exp_ids(randorder, :);
exp_IAPS_ids = exp_IAPS_ids(randorder, :);
exp_arousals = exp_arousals(randorder, :);
exp_valences = exp_valences(randorder, :);

%% view trials
load('IAPS/IAPS_ratings.mat')
% NOTE: bug 0.4.8 -- no setup.mat exists in this directory; this either
% errors or, if saccade/ is on the path, loads the saccade trial list.
load setup.mat
n_screens = 73;
n_imgs = 9;
figure(1); hold on
plot(arousal_avg, valence_avg, '.', 'color', .7*[1 1 1]);
xlabel 'arousal'; ylabel 'valence'

for i_screen = 1:n_screens
    figure(1)
    plot(exp_arousals(i_screen, :), exp_valences(i_screen, :), '.r')
    waitforbuttonpress;
    plot(exp_arousals(i_screen, :), exp_valences(i_screen, :), '.k')
    figure(2);
    for i_pic = 1:n_imgs
        img = imread(['IAPS/' num2str(exp_IAPS_ids(i_screen, i_pic)) '.jpg']);
        subplot(3, 3, i_pic);
        imshow(img)
    end
    waitforbuttonpress;
end

%% save settings
% save('setup.mat','exp_IAPS_ids','exp_valences','exp_arousals')

%% shuffle trials for post
% NOTE: bug 0.4.8, same as above.
load setup.mat
n_screens = size(exp_IAPS_ids, 1);
n_imgs = size(exp_IAPS_ids, 2);

post_screen_idx = randperm(n_screens)';
exp_IAPS_ids_post = nan(size(exp_IAPS_ids));
exp_arousals_post = nan(size(exp_arousals));
exp_valences_post = nan(size(exp_valences));

post_img_idx = nan(n_screens, n_imgs);
for i_screen = 1:n_screens
    post_img_idx(i_screen, :) = randperm(n_imgs);
    exp_IAPS_ids_post(i_screen, :) = ...
        exp_IAPS_ids(post_screen_idx(i_screen), post_img_idx(i_screen, :));
    exp_arousals_post(i_screen, :) = ...
        exp_arousals(post_screen_idx(i_screen), post_img_idx(i_screen, :));
    exp_valences_post(i_screen, :) = ...
        exp_valences(post_screen_idx(i_screen), post_img_idx(i_screen, :));
end
% NOTE: bug 0.4.10 -- exp_IAPS_ids_post/exp_arousals_post/
% exp_valences_post computed above are never saved, so setup_post.mat
% cannot be reproduced by running this script.

%% view post trials
load setup_post.mat
load('IAPS/IAPS_ratings.mat')
figure(1); hold on
plot(arousal_avg, valence_avg, '.', 'color', .7*[1 1 1]);
xlabel 'arousal'; ylabel 'valence'

for i_screen = 1:n_screens
    figure(1)
    plot(exp_arousals(i_screen, :), exp_valences(i_screen, :), '.r')
    waitforbuttonpress;
    plot(exp_arousals(i_screen, :), exp_valences(i_screen, :), '.k')
    figure(2);
    for i_pic = 1:n_imgs
        img = imread(['IAPS/' num2str(exp_IAPS_ids(i_screen, i_pic)) '.jpg']);
        subplot(3, 3, i_pic);
        imshow(img)
    end
    waitforbuttonpress;
end
