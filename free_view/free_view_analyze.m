%% initiate
load free_view_results.mat

% load IAPS id's, arousals, and valences
load('setup/setup_pre.mat');
[~,sort_idx]=sort(exp_IAPS_ids(:));
arousals=exp_arousals(:);
arousals=arousals(sort_idx);
valences=exp_valences(:);
valences=valences(sort_idx);

names   = {free_view_results.name};

% find all pre and post indices
isPost  = contains(names,'_post');
isPre   = contains(names,'_pre');

idx_post = find(isPost);
idx_pre  = find(isPre);

% find matched pre and post indices
basePost = regexprep(names(isPost),'_post.*$','');
basePre  = regexprep(names(isPre) ,'_pre.*$' ,''); 

[tf,loc] = ismember(basePost, basePre);

idx_post_matched = idx_post(tf);
idx_pre_matched  = idx_pre(loc(tf));

% find post control indices and matched pre indices
isPost_c   = contains(names,'_post_control');
idx_post_c_matched = find(isPost_c);

basePost_c = regexprep(names(isPost_c),'_post_control.*$','');

[tf,loc] = ismember(basePost_c, basePre);

idx_pre_c_matched  = idx_pre(loc(tf));


% all post-treatment indices (posts that are not control)
isPost_t   = isPost & ~isPost_c;          % post but not post_control
idx_post_t = find(isPost_t);

% all pre-treatment indices = pre that are not control-pre
isPre_c = false(size(names));            % mark which pre's are control
isPre_c(idx_pre_c_matched) = true;       % these pres belong to control
isPre_t = isPre & ~isPre_c;
idx_pre_t = find(isPre_t);

% matched treatment indices (both pre and post_t present)
basePost_t = regexprep(names(isPost_t),'_post.*$','');
[tf_t,loc_t] = ismember(basePost_t, basePre);

idx_post_t_matched = idx_post_t(tf_t);
idx_pre_t_matched  = idx_pre(loc_t(tf_t));

%% add date stamps

% datetime('2024-Nov-22 10:00','InputFormat','yyyy-MMM-dd HH:mm','Format','yyyy-MMM-dd HH:mm')

for idx = 1:numel(free_view_results)
    % name=free_view_results(idx).name
    % edf_mat = Edf2Mat([name '.edf']);
    % date_string=edf_mat.Header.date;
    % free_view_results(idx).date_EL = datetime(date_string,'InputFormat','eee MMM d HH:mm:ss yyyy','Format','yyyy-MMM-dd HH:mm:ss');
    free_view_results(idx).date_EL = free_view_results(idx).date_EL + gap;
    free_view_results(idx).date_manual.Format = 'yyyy-MMM-dd HH:mm';
end

%% compute durations, scan lengths and pupil sizes
for idx=1:numel(free_view_results)
    name=free_view_results(idx).name
    edf_mat = Edf2Mat([name '.edf']);
    corners=free_view_results(idx).corners;
    [gaze_x,gaze_y,fix_x,fix_y] = lib.preprocess_gaze(edf_mat,'corners',corners);
    title(name)

    [dwell_tot_raw,dwell_raw,pupil_raw,scan]=analyze.free_view_measures(edf_mat,gaze_x,gaze_y,fix_x,fix_y);
    free_view_results(idx).dwell_tot_raw=dwell_tot_raw;
    free_view_results(idx).dwell_raw=dwell_raw;
    free_view_results(idx).pupil_raw=pupil_raw;
    free_view_results(idx).scan=scan;
end

%% compute location-based dwell prior
dwell_all=cat(4, free_view_results.dwell_raw);
dwell_avg=squeeze(mean(dwell_all,[3 4],'omitnan'));

figure
imagesc(dwell_avg);
clim([0 max(dwell_avg(:))]);
axis equal tight
colormap(gray);
cb = colorbar; 
cb.Limits = [0 max(dwell_avg(:))];
set(gca,'xtick',[],'ytick',[],'fontsize',13)
title 'location bias of dwell time'
%% compute location-bias-corrected dwell fraction
for idx=1:numel(free_view_results)
    free_view_results(idx).corr_dwell_raw=free_view_results(idx).dwell_raw./dwell_avg;
end

%% sort dwells/pupil sizes by IAPS ID

sess = {'pre','post'};
for i = [1 2]
    sess_this=sess{i};

    load(['setup/setup_' sess_this '.mat'],'exp_IAPS_ids');
    [sorted_IAPS_ids,sort_idx]=sort(exp_IAPS_ids(:));

    idxVec = eval(['idx_' sess_this]);   % grabs idxPre or idxPost

    for k = idxVec(:).'
        dwell_raw = free_view_results(k).dwell_raw;
        corr_dwell_raw = free_view_results(k).corr_dwell_raw;
        pupil_raw = free_view_results(k).pupil_raw;

        dwell = reshape(permute(dwell_raw,[2 1 3]), 9, []).';
        corr_dwell = reshape(permute(corr_dwell_raw,[2 1 3]), 9, []).';
        pupil = reshape(permute(pupil_raw,[2 1 3]), 9, []).';

        dwell = dwell(sort_idx);
        corr_dwell = corr_dwell(sort_idx);
        pupil = pupil(sort_idx);

        free_view_results(k).dwell = dwell;
        free_view_results(k).corr_dwell = corr_dwell;
        free_view_results(k).pupil = pupil;
    end
end

%% check that total dwell per screen is ~10s for each subject
% for idx=1:numel(free_view_results)
%     dwell_raw=free_view_results(idx).dwell_raw;
%     figure
%     plot(squeeze(sum(dwell_raw,[1 2])))
%     % ylim([0 10])
%     title(free_view_results(idx).name)
% end

%% compute mean pupil size per participant

% first fill in mean pupil size per session
for idx=1:numel(free_view_results)
    free_view_results(idx).mean_pupil=mean(free_view_results(idx).pupil,'omitnan');
end

% now average pre/post for each participant that has both
mean_pupil_both=mean([[free_view_results(idx_pre_matched).mean_pupil];
                    [free_view_results(idx_post_matched).mean_pupil]]);

% fill in for both pre/post
c = num2cell(mean_pupil_both);
[free_view_results(idx_pre_matched).mean_pupil] = c{:};
[free_view_results(idx_post_matched).mean_pupil] = c{:};

%% compute pupil dilations/contractions as fractions of mean pupil size
for idx=1:numel(free_view_results)
    free_view_results(idx).pupil_dil_raw=free_view_results(idx).pupil_raw./free_view_results(idx).mean_pupil;
    free_view_results(idx).pupil_dil=free_view_results(idx).pupil./free_view_results(idx).mean_pupil;
end

%% compute post-pre delta in date/dwell/pupil dilation/mean valence/scan lengths

for k = 1:numel(idx_pre_matched)
    ipre  = idx_pre_matched(k);
    ipost = idx_post_matched(k);
    free_view_results(ipost).d_dwell=free_view_results(ipost).dwell-free_view_results(ipre).dwell;
    free_view_results(ipost).d_corr_dwell=free_view_results(ipost).corr_dwell-free_view_results(ipre).corr_dwell;
    free_view_results(ipost).f_corr_dwell=free_view_results(ipost).corr_dwell./free_view_results(ipre).corr_dwell-1;
    % free_view_results(ipost).d_valence=free_view_results(ipost).mean_valence-free_view_results(ipre).mean_valence;
    free_view_results(ipost).d_scan=free_view_results(ipost).scan-free_view_results(ipre).scan;
    free_view_results(ipost).d_tot_scan=sum(free_view_results(ipost).scan)-sum(free_view_results(ipre).scan);
    free_view_results(ipost).gap=free_view_results(ipost).date_EL-free_view_results(ipre).date_EL;
    % fractional change in pupil dilation:
    free_view_results(ipost).f_pupil_dil=free_view_results(ipost).pupil_dil./free_view_results(ipre).pupil_dil-1;
end

%% plot post vs pre absolute (un-location-uncorrected) dwell times

% Concatenate dwell across all matched IDs (all images)
dwell_pre=[free_view_results(idx_pre_matched).dwell];
dwell_post=[free_view_results(idx_post_matched).dwell];

x=dwell_pre(dwell_pre>0 & dwell_post>0); y=dwell_post(dwell_pre>0 & dwell_post>0);

% handle zeros separately
x0=dwell_pre(dwell_pre==0|dwell_post==0);
y0=dwell_post(dwell_pre==0|dwell_post==0);
x0(~x0)=5e-3; y0(~y0)=5e-3;

figure; hold on
plot(x,y, '.b','MarkerSize',.5); 
plot(x0,y0, '.k','MarkerSize',1);

axis([3e-3 20 3e-3 20])
set(gca,'xscale','log','yscale','log',...
    'xtick',[1e-3 1e-1 1e1], 'ytick',[1e-3 1e-1 1e1], 'fontsize',13)
xlabel('pre'); ylabel('post');
title('durations (sec)')

% correlation over nonzeros only
mask = dwell_pre>0 & dwell_post>0;
r = corr(log10(dwell_pre(mask)), log10(dwell_post(mask)), 'rows','complete');
ax = gca;
text(ax, 0.02, 0.98, sprintf('r = %.2f', r), ...
    'Units','normalized', 'Color','b', 'FontSize',12);

% histograms of marginals
figure
histogram(log10([x; x0]),'EdgeColor','none')
xlim(log10([3e-3 20]))
set(gca,'xtick',[],'ytick',[])
box off

figure
histogram(log10([y; y0]),'EdgeColor','none')
xlim(log10([3e-3 20]))
set(gca,'xtick',[],'ytick',[])
box off

% linear histogram of all (pre+post)
% compute log-normal parameters of non-zero dwells

[s,m]=std(log([x;y]));

dwell_all=[dwell_pre;dwell_post];

figure; hold on
histogram(dwell_all,'binedges',[0 linspace(.07,5,2e2)],'normalization','pdf','EdgeColor','none')
scale_factor=numel([x;y])/numel(dwell_all);
fplot(@(x) lognpdf(x,m,s)*scale_factor,[0 5],'-k')
legend('data','log-normal fit to non-zero durations')
legend box off
xlabel 'total fixation time (s)'
set(gca,'ytick',[],'fontsize',13)

%% fractional change in corrected (intentional) dwell times vs absolute pre-dwell times
% variable x is absolute dwell, because that's what determines memory impact

[~, idx_t_in_all] = ismember(idx_pre_t_matched, idx_pre_matched);
[~, idx_c_in_all] = ismember(idx_pre_c_matched, idx_pre_matched);

corr_dwell_pre=[free_view_results(idx_pre_matched).corr_dwell];
corr_dwell_post=[free_view_results(idx_post_matched).corr_dwell];
gap=[free_view_results(idx_post_matched).gap]';

f_corr_dwell=corr_dwell_post./corr_dwell_pre;

% replace +/- inf with max value:
log_f_corr_dwell=log10(f_corr_dwell);
log_f_corr_dwell(isinf(log_f_corr_dwell))=nan;

ulim=max(log_f_corr_dwell(isfinite(log_f_corr_dwell)));
llim=min(log_f_corr_dwell(isfinite(log_f_corr_dwell)));

valences_rep=repmat(valences,[1 size(corr_dwell_pre,2)]);

% plot all views (3D plot)
figure
plot3(dwell_pre(:), valences_rep(:),log_f_corr_dwell(:),'.k','MarkerSize',1);
xlabel 'absolute pre dwell (s)'
ylabel 'valences'
zlabel 'log 10 (post corr. dwell / pre corr. dwell)'
set(gca,'xscale','log','fontsize',13)
grid on

% plot all views (colour plot)
figure
scatter(dwell_pre(:), valences_rep(:),3,log_f_corr_dwell(:),'filled','MarkerEdgeColor','none');
xlabel 'absolute pre dwell (s)'
ylabel 'valences'
title 'log 10 (post corr. dwell / pre corr. dwell)'
colorbarpzn(llim,ulim,'colorP',[1 0 0],'colorN',[0 0 0]);
set(gca,'xscale','log','fontsize',13)

% average across subjects (this favours dependence on valence by removing fluctuation, and
% disfavours dependence on pre-dwell by washing out the dependence function)
% ulim=max(mean(log_f_corr_dwell,2,'omitnan'));
% llim=min(mean(log_f_corr_dwell,2,'omitnan'));
% figure
% scatter(mean(dwell_pre,2), valences,10,mean(log_f_corr_dwell,2,'omitnan'),'filled','MarkerEdgeColor','none');
% xlabel 'absolute pre dwell (s)'
% ylabel 'valences'
% title 'log 10 (post corr. dwell / pre corr. dwell)'
% hcb=colorbarpzn(llim,ulim,'colorP',[1 0 0],'colorN',[0 0 0]);
% set(gca,'xscale','log','fontsize',13)

% figure
% r=corr(dwell_pre(:), log_f_corr_dwell(:), 'rows', 'complete');
% plot(dwell_pre, f_corr_dwell,'.k','MarkerSize',1)
% ax = gca;
% text(ax, 0.02, 0.98, sprintf('r = %.2f', r), ...
%     'Units','normalized','FontSize',12);
% set(gca,'xscale','log','YScale','log','fontsize',13)
% yline(1)
% xlabel 'absolute pre dwell (s)'
% ylabel 'post corr. dwell / pre corr. dwell'
% title 'dwell change vs pre-dwell (memory effect)'

figure; hold on
r = corr(dwell_pre(:), log_f_corr_dwell(:), 'rows', 'complete');

gap = seconds(gap)/86400;
gap_rep = repmat(gap(:).', size(dwell_pre,1), 1); 

% colour gradient scatter of treatment folks
scatter(reshape(dwell_pre(:,idx_t_in_all),[],1), reshape(f_corr_dwell(:,idx_t_in_all),[],1), 30, reshape(gap_rep(:,idx_t_in_all),[],1), '.');

% flat colour scatter of control folks
plot(reshape(dwell_pre(:,idx_c_in_all),[],1), reshape(f_corr_dwell(:,idx_c_in_all),[],1), '.w','markersize',4);

% --- custom red-to-blue colormap ---
nColors = 256;
cmap = [linspace(1,0,nColors)', ...   % R: 1 -> 0
        zeros(nColors,1), ...         % G: 0
        linspace(0,1,nColors)'];      % B: 0 -> 1
colormap(gca, cmap);                  % apply to current axes
% -----------------------------------

ax = gca;
ax.Color  = .7*[1 1 1];
text(ax, 0.02, 0.98, sprintf('r = %.2f', r), ...
    'Units','normalized','FontSize',12);
set(gca,'XScale','log','YScale','log','FontSize',13)
yline(1)
xlabel 'absolute pre dwell (s)'
ylabel 'post corr. dwell / pre corr. dwell'
title 'dwell change vs pre-dwell (memory effect)'

cb = colorbar;
clim([min(gap(idx_t_in_all)) max(gap(idx_t_in_all))])
ylabel(cb,'gap (days)')


%% plot average dwell and its change

% average corrected dwell (pre) vs arousal and valence
corr_dwell_pre=mean([free_view_results(idx_pre).corr_dwell],2);
ulim=max(corr_dwell_pre(:));
llim=min(corr_dwell_pre(:));
figure
scatter(arousals,valences,[],corr_dwell_pre,'filled','MarkerEdgeColor',.5*[1 1 1]);
hcb=colorbarpzn(llim,ulim,'colorP',[1 0 0],'colorN',[0 0 0],'full',1);
% hcb.Limits=[0 2.3];
% hcb.Ticks=[0 1 2];
xlabel 'arousal'
ylabel 'valence'
title 'location-corrected dwell factor (pre)'
set(gca,'fontsize',13)

% average corrected dwell (post) vs arousal and valence
corr_dwell_post=mean([free_view_results(idx_post).corr_dwell],2);
ulim=max(corr_dwell_post(:));
llim=min(corr_dwell_post(:));
figure
scatter(arousals,valences,[],corr_dwell_post,'filled','MarkerEdgeColor',.5*[1 1 1]);
hcb=colorbarpzn(llim,ulim,'colorP',[1 0 0],'colorN',[0 0 0],'full',1);
% hcb.Limits=[0 2.3];
% hcb.Ticks=[0 1 2];
xlabel 'arousal'
ylabel 'valence'
title 'location-corrected dwell factor (post)'
set(gca,'fontsize',13)

% average location-corrected dwell change vs arousal and valence
d_corr_dwell_avg=mean([free_view_results.d_corr_dwell],2,'omitnan');
ulim=max(d_corr_dwell_avg(:));
llim=min(d_corr_dwell_avg(:));
figure
scatter(arousals,valences,[],d_corr_dwell_avg,'filled','MarkerEdgeColor',.5*[1 1 1]);
xlabel 'arousal'
ylabel 'valence'
title 'avg. change in location-corrected dwell factor'
hcb=colorbarpzn(llim,ulim,'colorP',[1 0 0],'colorN',[0 0 0]);
% hcb.Ticks=[-1 0 1];
set(gca,'fontsize',13)

% dwell change against only valence
figure; hold on
h1=plot(valences_rep,log_f_corr_dwell,'.k','MarkerSize',1);
h2=plot(valences, mean(log_f_corr_dwell,2,'omitnan'),'.r','MarkerSize',6);
r=corr(valences_rep(:), log_f_corr_dwell(:), 'rows', 'complete');
ax = gca;
text(ax, 0.02, 0.98, sprintf('r = %.4f', r), ...
    'Units','normalized','FontSize',12);
xlabel 'valence'
ylabel 'log 10 (post corr. dwell / pre corr. dwell)'
title 'dwell change vs valence'
legend([h1(1) h2], {'all views','avg across subjects'});
legend boxoff
set(gca,'fontsize',13)

%% multiple linear regression to see the effect of valence vs memory

% Treat these as x, y, z
x = valences_rep(:);        
y = log10(dwell_pre(:));           
z = log_f_corr_dwell(:);

% Keep only rows where all three are finite (removing nans)
mask = isfinite(x) & isfinite(y) & isfinite(z);
x = x(mask);
y = y(mask);
z = z(mask);

% compute each pairwise correlation coeff:
r_xy=corr(x,y);
r_xz=corr(x,z);
r_yz=corr(y,z);

% Standardize each variable (z-scoring)
x_std = (x - mean(x)) ./ std(x);
y_std = (y - mean(y)) ./ std(y);
z_std = (z - mean(z)) ./ std(z);

% Design matrix: standardized x and y (no intercept because all variables
% are standardized)
X = [x_std y_std];

% Multiple regression: z_std ~ x_std + y_std
beta = X \ z_std;    % OLS solution

beta_x_std = beta(1)   % standardized beta for x (valences_rep)
beta_y_std = beta(2)   % standardized beta for y (dwell_pre)

% check that betas match the formulas based on correlation coefficients:
beta_corr(1)=(r_xz-r_xy*r_yz)/(1-r_xy^2)
beta_corr(2)=(r_yz-r_xz*r_xy)/(1-r_xy^2)

% % (Optional) Get R^2 (proportion of variance explained by model)
% z_hat = X * beta;
% R2 = 1 - sum((z_std - z_hat).^2) / sum((z_std - mean(z_std)).^2);

% regress dwell change on memory
Y=[ones(numel(y),1) y]; % new design matrix
beta_mem= Y\z;
z_hat=Y*beta_mem;

% plot the regression
figure; hold on
plot3(x, y,z,'.k','MarkerSize',1);
plot3(x, y,z_hat,'.r','MarkerSize',1);
xlabel 'valences'
ylabel 'absolute pre dwell (s)'
zlabel 'log 10 (post corr. dwell / pre corr. dwell)'
set(gca,'fontsize',13)
grid on

% remove memory-dependence
z_hat=log10(dwell_pre)*beta_mem(2)+beta_mem(1);
z_res=log_f_corr_dwell-z_hat;

figure; hold on
plot(valences_rep,z_res,'.k','MarkerSize',1)
h1=plot(valences_rep,z_res,'.k','MarkerSize',1);
h2=plot(valences, mean(z_res,2,'omitnan'),'.r','MarkerSize',6);
r=corr(valences_rep(:), z_res(:), 'rows', 'complete');
ax = gca;
text(ax, 0.02, 0.98, sprintf('r = %.4f', r), ...
    'Units','normalized','FontSize',12);
xlabel 'valence'
ylabel 'memory-corrected dwell change'
title 'memory-corrected dwell change vs valence'
legend([h1(1) h2], {'all views','avg across subjects'});
legend boxoff
set(gca,'fontsize',13)
ylim([-3 3])


%% scanpath length

% for idx=1:numel(free_view_results)
%     figure
%     plot(free_view_results(idx).scan_len,'-o')
%     ylim([0 2.5e4])
% end

% plot scan-lengths vs avg. arousal per screen

% pre
load('setup/setup_pre.mat','exp_arousals');
arousal_screen_pre=mean(exp_arousals,2);
scan_pre=vertcat(free_view_results(idx_pre).scan);

figure
plot(arousal_screen_pre,scan_pre,'.k','MarkerSize',1)
ylim([0 2.5e4])
xlabel 'avg. arousal of the screen'
ylabel 'scanpath length'
title pre

% post
load('setup/setup_post.mat','exp_arousals');
arousal_screen_post=mean(exp_arousals,2);
scan_post=vertcat(free_view_results(idx_post).scan);

figure
plot(arousal_screen_post,scan_post,'.k','MarkerSize',1)
ylim([0 2.5e4])
xlabel 'avg. arousal of the screen'
ylabel 'scanpath length'
title post

% deltas in scanpath
figure
histogram([free_view_results.d_scan])
xlabel 'delta scanpath length'
xline(0)
set(gca,'ytick',[],'fontsize',13)

% overall pre and post distributions
figure; hold on
histogram(scan_pre,'Normalization','pdf','EdgeColor','none')
histogram(scan_post,'Normalization','pdf','EdgeColor','none')
xlabel 'scanpath length'
legend('pre','post')
set(gca,'ytick',[],'fontsize',13)

% correlation between pupil dilation and scanpath length

pupil_dil_all=cat(4,free_view_results.pupil_dil_raw);
pupil_dil_all=squeeze(mean(pupil_dil_all,[1 2],'omitnan'))';

scan_all=vertcat(free_view_results.scan);
figure
plot(pupil_dil_all(:),scan_all(:),'.k','markersize',1)
xlabel 'avg. pupil dilation per screen'
ylabel 'scanpath length'

%% plot of dwell delta against valence and participant
delta=[free_view_results.d_corr_dwell];

n_subj = size(delta,2);

% Create grids for participant number (x) and valence (y)
[participantGrid, valenceGrid] = meshgrid(1:n_subj, valences);  

% Scatter plot
figure;
scatter(participantGrid(:), valenceGrid(:), 10, delta(:), 'filled');

xlabel('Participant');
ylabel('Valence');
ulim=max(delta(:));
llim=min(delta(:));
colorbarpzn(llim,ulim,'colorP',[1 0 0],'colorN',[0 0 0]);
title('Dwell time change');

%% plot post vs pre pupil dilations
% Collect matched indices
% iposts = idx_post(tf);
% ipres  = idx_pre(loc(tf));
% 
% % mean pupil size
% 
% % Concatenate pupil dilations across all matched IDs (all images)
% preC  = arrayfun(@(i) free_view_results(i).pupil_dil(:), ipres,  'uni', 0);
% postC = arrayfun(@(i) free_view_results(i).pupil_dil(:), iposts, 'uni', 0);
% pre_all  = vertcat(preC{:});
% post_all = vertcat(postC{:});
% 
% r=corrcoef(pre_all,post_all,'Rows', 'complete'); r=r(1,2);
% 
% % Plot: post vs pre (one dot per image per subject)
% figure; plot(pre_all, post_all, '.k','MarkerSize',1); hold on
% axis equal
% refline(1,0)
% xlabel('pre'); ylabel('post');
% title(sprintf('pupil dilations, r=%f',r))

%% plot pupil vs participant and location

% absolute pupil size
pupil_all=cat(4, free_view_results.pupil_raw);
pupil_avg=squeeze(mean(pupil_all,3,'omitnan'));
pupil_avg = reshape(permute(pupil_avg, [2 1 3]), 9, [])';
figure
imagesc(pupil_avg)
colorbar
xlabel 'screen location'
ylabel 'participant'
title 'pupil size'
set(gca,'fontsize',13)

% pupil dilation
pupil_all=cat(4, free_view_results.pupil_dil_raw);
pupil_avg=squeeze(mean(pupil_all,3,'omitnan'));
pupil_avg = reshape(permute(pupil_avg, [2 1 3]), 9, [])';
figure
hImg=imagesc(pupil_avg);
llim=min(pupil_avg(:));
ulim=max(pupil_avg(:));
hcb=colorbarpzn(llim,ulim,'colorP',[0 0 1],'colorN',[1 0 0],'full',1);

% make nans black
set(hImg, 'AlphaData', ~isnan(pupil_avg)); 
set(gca, 'Color', [0 0 0]); 

xlabel 'screen location'
ylabel 'participant'
title 'pupil dilation'
set(gca,'fontsize',13)

% location-based pupil-dilation prior
pupil_loc_avg=squeeze(mean(pupil_all,[3 4],'omitnan'));

figure
imagesc(pupil_loc_avg);
clim([0 max(pupil_loc_avg(:))]);
axis equal tight
colormap(gray);
cb = colorbar; 
% cb.Limits = [0 max(pupil_loc_avg(:))];
set(gca,'xtick',[],'ytick',[],'fontsize',13)
title 'location-based mean pupil dilation'

%% plot pupil vs participant and image

% absolute pupil size
pupil_all=[free_view_results.pupil]';
figure
imagesc(pupil_all)
colorbar
xlabel 'image'
ylabel 'participant'
title 'pupil size'
set(gca,'fontsize',13)

% pupil dilation
pupil_all=[free_view_results.pupil_dil]';
figure
hImg=imagesc(pupil_all);
llim=min(pupil_all(:));
ulim=max(pupil_all(:));
hcb=colorbarpzn(llim,ulim,'colorP',[0 0 1],'colorN',[1 0 0],'full',1);

% make nans black
set(hImg, 'AlphaData', ~isnan(pupil_all)); 
set(gca, 'Color', [0 0 0]); 

xlabel 'image'
ylabel 'participant'
title 'pupil dilation'
set(gca,'fontsize',13)

%% plot average pupil dilation and its change

% average across both pre and post
pupil_dil_mean=mean([free_view_results.pupil_dil],2,'omitnan');
figure
scatter(arousals,valences,[],pupil_dil_mean,'filled','MarkerEdgeColor',.5*[1 1 1]);
llim=min(pupil_dil_mean);
ulim=max(pupil_dil_mean);
hcb=colorbarpzn(llim,ulim,'colorP',[1 0 0],'colorN',[0 0 0],'full',1);
% hcb.Ticks=[1000 1200];
xlabel 'arousal'
ylabel 'valence'
title 'avg. pupil dilation'
set(gca,'fontsize',13)

figure
f_pupil_dil_avg=100*mean([free_view_results.f_pupil_dil],2,'omitnan');
scatter(arousals,valences,[],f_pupil_dil_avg,'filled','MarkerEdgeColor',.5*[1 1 1]);
llim=min(f_pupil_dil_avg);
ulim=max(f_pupil_dil_avg);
xlabel 'arousal'
ylabel 'valence'
title 'avg. change in pupil dilation'
hcb=colorbarpzn(llim,ulim,'colorP',[1 0 0],'colorN',[0 0 0],'full',0);
hcb.Ticks=-20:10:10;
hcb.TickLabels={'-20%','-10%','0','+10%'};
set(gca,'fontsize',13)