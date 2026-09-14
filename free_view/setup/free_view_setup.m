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

load('IAPS/IAPS_ratings.mat')
n_screens=73;
n_imgs=9;

exp_ids=nan(n_screens,n_imgs);
exp_IAPS_ids=nan(n_screens,n_imgs);
exp_arousals=nan(n_screens,n_imgs);
exp_valences=nan(n_screens,n_imgs);

for iScreen=1:n_screens
    % pick a random point
    firstid=randsample(length(IAPS_id),1);
    [~,idx] = sort(abs(arousal_avg-arousal_avg(firstid)));
    ids_thistrial=idx(1:n_imgs);


    % randomize the spatial order in each trial
    ids_thistrial=ids_thistrial(randperm(length(ids_thistrial)));

    exp_ids(iScreen,:)=ids_thistrial;
    exp_IAPS_ids(iScreen,:)=IAPS_id(ids_thistrial);
    exp_arousals(iScreen,:)=arousal_avg(ids_thistrial);
    exp_valences(iScreen,:)=valence_avg(ids_thistrial);

    % remove these images from the database
    IAPS_id(ids_thistrial)=[];
    arousal_avg(ids_thistrial)=[];
    valence_avg(ids_thistrial)=[];
end

% randomize trial order
randorder=randperm(n_screens);
exp_ids=exp_ids(randorder,:);
exp_IAPS_ids=exp_IAPS_ids(randorder,:);
exp_arousals=exp_arousals(randorder,:);
exp_valences=exp_valences(randorder,:);

%% view trials
load('IAPS/IAPS_ratings.mat')
load setup.mat
n_screens=73;
n_imgs=9;
figure(1); hold on
plot(arousal_avg,valence_avg,'.','color',.7*[1 1 1]);
xlabel 'arousal'; ylabel 'valence'

for iScreen=1:n_screens
    figure(1)
    plot(exp_arousals(iScreen,:),exp_valences(iScreen,:),'.r')
    waitforbuttonpress;
    plot(exp_arousals(iScreen,:),exp_valences(iScreen,:),'.k')
    figure(2);
    for iPic=1:n_imgs
        img=imread(['IAPS/' num2str(exp_IAPS_ids(iScreen,iPic)) '.jpg']);
        subplot(3,3,iPic);
        imshow(img)
    end
    waitforbuttonpress;
end

%% save settings
% save('setup.mat','exp_IAPS_ids','exp_valences','exp_arousals')

%% shuffle trials for post
load setup.mat
n_screens=size(exp_IAPS_ids,1);
n_imgs=size(exp_IAPS_ids,2);

post_screen_idx=randperm(n_screens)';
exp_IAPS_ids_post=nan(size(exp_IAPS_ids));
exp_arousals_post=nan(size(exp_arousals));
exp_valences_post=nan(size(exp_valences));

post_img_idx=nan(n_screens,n_imgs);
for iScreen=1:n_screens
    post_img_idx(iScreen,:)=randperm(n_imgs);
    exp_IAPS_ids_post(iScreen,:)=exp_IAPS_ids(post_screen_idx(iScreen),post_img_idx(iScreen,:));
    exp_arousals_post(iScreen,:)=exp_arousals(post_screen_idx(iScreen),post_img_idx(iScreen,:));
    exp_valences_post(iScreen,:)=exp_valences(post_screen_idx(iScreen),post_img_idx(iScreen,:));
end

%% view post trials
load setup_post.mat
load('IAPS/IAPS_ratings.mat')
figure(1); hold on
plot(arousal_avg,valence_avg,'.','color',.7*[1 1 1]);
xlabel 'arousal'; ylabel 'valence'

for iScreen=1:n_screens
    figure(1)
    plot(exp_arousals(iScreen,:),exp_valences(iScreen,:),'.r')
    waitforbuttonpress;
    plot(exp_arousals(iScreen,:),exp_valences(iScreen,:),'.k')
    figure(2);
    for iPic=1:n_imgs
        img=imread(['IAPS/' num2str(exp_IAPS_ids(iScreen,iPic)) '.jpg']);
        subplot(3,3,iPic);
        imshow(img)
    end
    waitforbuttonpress;
end

