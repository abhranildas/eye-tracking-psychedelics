%% compute mean errors and pupil sizes
load spem_results.mat
calib_sz=2/3;

for idx=1:numel(results)
    name=results(idx).name
    edf_mat = Edf2Mat([name '.edf']);
    corners=results(idx).corners;
    [gaze_x,gaze_y] = lib.preprocess_gaze(edf_mat,'exp_type','spem','corners',corners,'calib_sz',calib_sz,'animate',false);

    [err,pupil_sz_mean]=spem_measures(edf_mat,gaze_x,gaze_y);
    axis([0 1920 0 1080])
    title(sprintf('%s: %.1f',name,mean(err)))

    % append to the struct
    results(idx).err=err;
    results(idx).pupil_sz_mean=pupil_sz_mean;
end

% save 'spem_results.mat' results

%% compute post-pre delta in errors and pupil size

names   = {results.name};

% Match anywhere, not just at the end
isPost  = contains(names,'_post');
isPre   = contains(names,'_pre');

idxPost = find(isPost);
idxPre  = find(isPre);

% Strip everything from the marker onward
basePost = regexprep(names(isPost),'_post.*$','');
basePre  = regexprep(names(isPre) ,'_pre.*$' ,''); 

[tf,loc] = ismember(basePost, basePre);

for k = find(tf').'
    ipost = idxPost(k);
    ipre  = idxPre(loc(k));
    results(ipost).d_err=results(ipost).err-results(ipre).err;
    results(ipost).d_pupil_sz_mean=results(ipost).pupil_sz_mean-results(ipre).pupil_sz_mean;
    % fractional change in pupil size:
    results(ipost).f_pupil_sz_mean=results(ipost).pupil_sz_mean./results(ipre).pupil_sz_mean-1;
end

%% plote change in error
d_err=[results.d_err];
histogram(d_err(:))
avg_d_err=mean(d_err(:));
text(40, 80, sprintf('avg. \\Deltaerror = %.2f',avg_d_err),'FontSize',13)
xlabel('\Deltaerror')
set(gca,'ytick',[],'ylim',[0 90],'fontsize',13)
box off
