function [gaze_x,gaze_y,fix_x,fix_y,traj_target,t_target]=preprocess_gaze(edf_mat, varargin)
% PLOT_GAZE(edf_mat, 'draw_grid', true/false, 'animate', true/false, 'cornerXY', [4x2])
% Optional name-value inputs:
%   'draw_grid' (default: true)
%   'animate'   (default: false)
%   'corners'  (default: NaN(4,2)) as [TL; TR; BR; BL]. Any row all-NaN => keep default (1920x1080).

% ---- parse inputs ----
parser = inputParser; parser.FunctionName = 'plot_gaze';
addRequired(parser, 'edf_mat');
addParameter(parser, 'exp_type', []);
addParameter(parser, 'animate',   false, @(x) islogical(x) || isnumeric(x));
addParameter(parser, 'corners',  NaN(4,2), @(x) (isnumeric(x) && isequal(size(x),[4 2])));
addParameter(parser, 'calib_sz', 1, @isscalar);
parse(parser, edf_mat, varargin{:});
exp_type = parser.Results.exp_type;
animate   = parser.Results.animate;
corners  = parser.Results.corners;
calib_sz  = parser.Results.calib_sz;

% --- parse EDF ---
S   = edf_mat.Samples;

t_gaze = double(S.time);                   % ms
gaze_x = double(S.posX);                   % px
gaze_y = double(S.posY);                   % px
fix_x=edf_mat.Events.Efix.posX';
fix_y=edf_mat.Events.Efix.posY';

% compute blink mask
b_st = double(edf_mat.Events.Eblink.start);
b_en = double(edf_mat.Events.Eblink.end);

blink_pad_ms = 100;                          % small safety pad
b_st = b_st - blink_pad_ms;
b_en = b_en + blink_pad_ms;
blink_mask = false(size(t_gaze));
for k = 1:numel(b_st)
    blink_mask = blink_mask | (t_gaze >= b_st(k) & t_gaze <= b_en(k));
end

% --- Screen & grid (fixed 1920x1080) ---
screen_w = 1920; screen_h = 1080;
x_thirds = (screen_w/3) * (1:2);
y_thirds = (screen_h/3) * (1:2);
drawRect = @() plot([0 screen_w screen_w 0 0],[0 0 screen_h screen_h 0],'-','color',.5*[1 1 1],'LineWidth',.5);

% ---------- Parse corner intervals from EDF messages ----------
cornerIntervals = [];   % Nx2 [start_ms end_ms]
msgT = double(edf_mat.Events.Messages.time(:));
if isfield(edf_mat.Events.Messages,'message')
    msgS = string(edf_mat.Events.Messages.message(:));
elseif isfield(edf_mat.Events.Messages,'info')
    msgS = string(edf_mat.Events.Messages.info(:));
else
    msgS = strings(size(msgT));
end

isCornerStart = startsWith(msgS, "TRIALID 0.");
cornerStartsT = msgT(isCornerStart);

isTrialEnd = startsWith(msgS, "TRIAL_RESULT 0");
trialEndsT  = msgT(isTrialEnd);

cornerStartsT = sort(cornerStartsT);
trialEndsT    = sort(trialEndsT);

for k = 1:min(4, numel(cornerStartsT))
    st = cornerStartsT(k);
    nextEndIdx = find(trialEndsT > st, 1, 'first');
    if ~isempty(nextEndIdx)
        en = trialEndsT(nextEndIdx);
        cornerIntervals(end+1,:) = [st en]; %#ok<AGROW>
    end
end

% map time (ms) to sample indices
cornerIdx = [];  % Nx2 [iStart iEnd]
if ~isempty(cornerIntervals)
    for k = 1:size(cornerIntervals,1)
        st = cornerIntervals(k,1);
        en = cornerIntervals(k,2);
        i1 = find(t_gaze >= st, 1, 'first');
        i2 = find(t_gaze <= en, 1, 'last');
        if ~isempty(i1) && ~isempty(i2) && i2 > i1
            cornerIdx(end+1,:) = [i1 i2]; %#ok<AGROW>
        end
    end
end

% label vector: 0 = base, 1..4 = corner interval id
L = zeros(size(t_gaze));
for k = 1:min(4,size(cornerIdx,1))
    L(cornerIdx(k,1):cornerIdx(k,2)) = k;
end

% colors for the 4 corner intervals
C = [0.7 0.7 0;   % yellow-ish
    0.20 0.60 0.86;   % blue-ish
    0.18 0.80 0.44;   % green-ish
    0.61 0.35 0.71];  % purple-ish

%% --------- CALIBRATE: use a homography so cornerXY -> ideal screen corners exactly ---------
% Ideal/default (target) corners (TL, TR, BR, BL)
% src = [0 0; screen_w 0; screen_w screen_h; 0 screen_h];
src=[screen_w screen_h]/2 + ...\
    [-[screen_w screen_h]; [screen_w -screen_h]; [screen_w screen_h]; [-screen_w screen_h]]/2*calib_sz;

% Observed corners from manual overrides, falling back to defaults on NaN rows
obs = src;
if ~isempty(corners) && isequal(size(corners),[4 2])
    for r = 1:4
        if all(isfinite(corners(r,:)))
            obs(r,:) = corners(r,:);
        end
    end
end

valid = all(isfinite(obs),2) & all(isfinite(src),2);

if sum(valid) >= 4
    % --- Direct Linear Transform (DLT) for homography (obs -> src) ---
    U = obs(valid,:);   % observed points (x,y)
    V = src(valid,:);   % ideal targets (u,v)

    % Build A * h = 0
    % For each correspondence (x,y) -> (u,v):
    % [ -x -y -1  0  0  0  u*x  u*y  u ]
    % [  0  0  0 -x -y -1  v*x  v*y  v ]
    n = size(U,1);
    A = zeros(2*n, 9);
    for i = 1:n
        x_h = U(i,1); y_h = U(i,2);
        u_h = V(i,1); v_h = V(i,2);
        A(2*i-1,:) = [-x_h, -y_h, -1,  0,  0,  0,  u_h*x_h, u_h*y_h, u_h];
        A(2*i  ,:) = [ 0,  0,  0, -x_h, -y_h, -1,  v_h*x_h, v_h*y_h, v_h];
    end
    [~,~,VV] = svd(A,0);
    hvec = VV(:,end);           % was: h = VV(:,end);
    H    = reshape(hvec,[3,3])';% was: H = reshape(h,[3,3])';
else
    % Fallback: identity (or keep your earlier affine fallback if you like)
    H = eye(3);
end

% Apply homography to the full gaze trajectory (homogeneous coords)
P   = [gaze_x, gaze_y, ones(size(gaze_x))]';   % 3 x N
Pp  = H * P;
gaze_x = (Pp(1,:)./Pp(3,:))';
gaze_y = (Pp(2,:)./Pp(3,:))';

% Apply homography to the fixation points
P   = [fix_x, fix_y, ones(size(fix_x))]';   % 3 x N
Pp  = H * P;
fix_x = (Pp(1,:)./Pp(3,:))';
fix_y = (Pp(2,:)./Pp(3,:))';

% --- Auto bounds to minimally fit the whole (transformed) trajectory ---
pad = 50;
xmin = min(gaze_x) - pad;  ymin = min(gaze_y) - pad;
xmax = max(gaze_x) + pad;  ymax = max(gaze_y) + pad;

%% --------- (1) Static density-style trajectory ----------
figure
ax1 = axes; hold(ax1,'on'); set(ax1,'YDir','reverse'); axis equal; box on;
xlim([xmin xmax]); ylim([ymin ymax]);

% --- base-only black trajectory (exclude corner intervals) ---
xb = gaze_x; yb = gaze_y;
maskCorner = (L ~= 0);
xb(maskCorner) = NaN;
yb(maskCorner) = NaN;

% NEW: split base into non-blink (black) and blink (grey)
xb_nb = xb; yb_nb = yb;                 % non-blink
xb_nb(blink_mask) = NaN; yb_nb(blink_mask) = NaN;
plot(xb_nb, yb_nb, '.r', 'MarkerSize',1);

xb_bk = xb; yb_bk = yb;                 % blink
nb = ~blink_mask;
xb_bk(nb) = NaN; yb_bk(nb) = NaN;
plot(xb_bk, yb_bk, '.', 'Color', 'k', 'MarkerSize',1);

% plot fixation points
plot(fix_x, fix_y, '.b', 'MarkerSize',1);

% Screen rectangle (+ optional grid) -- stays in default coordinates
drawRect();
if strcmpi(exp_type,'free_view')
    for xx = x_thirds, plot([xx xx],[0 screen_h],'-','color',.5*[1 1 1],'LineWidth',.5); end
    for yy = y_thirds, plot([0 screen_w],[yy yy],'-','color',.5*[1 1 1],'LineWidth',.5); end
end

% Colored overlays for the corner intervals
for k = 1:min(4, size(cornerIdx,1))
    idx1 = cornerIdx(k,1); idx2 = cornerIdx(k,2);
    scatter(gaze_x(idx1:idx2), gaze_y(idx1:idx2),8,'o','MarkerFaceColor',C(k,:),'MarkerFaceAlpha', 0.05,'MarkerEdgeAlpha',0);
end

%% --------- (2) Animation ----------
if animate
    figure
    ax2 = axes; hold(ax2,'on'); set(ax2,'YDir','reverse'); axis equal; box on;
    xlim([xmin xmax]); ylim([ymin ymax]);

    % Screen rectangle (+ optional grid)
    drawRect();
    if strcmpi(exp_type,'free_view')
        for xx = x_thirds, plot([xx xx],[0 screen_h],'-','color',.5*[1 1 1],'LineWidth',.5); end
        for yy = y_thirds, plot([0 screen_w],[yy yy],'-','color',.5*[1 1 1],'LineWidth',.5); end
    end

    % Prepare line objects: base + 4 corner-colored traces
    hBase  = plot(NaN,NaN,'-','Color','r','LineWidth',.5);
    hBlink = plot(NaN,NaN,'-','Color','k','LineWidth',.5);   % <-- ADDED (red for blinks)
    hSeg   = gobjects(1,4);
    for k = 1:4
        hSeg(k) = scatter(NaN,NaN,8,'o','MarkerFaceColor',C(k,:),'MarkerFaceAlpha', 0.05,'MarkerEdgeAlpha',0);
    end
    % Gaze dot
    hGaze = plot(NaN,NaN,'o','MarkerSize',5,'MarkerFaceColor','r','MarkerEdgeColor','none');

    if strcmpi(exp_type,'spem')
        % spem target trajectory
        [t_target, traj_target] = true_target_traj(edf_mat);
        hTrue = plot(NaN,NaN,'o','MarkerSize',5,'MarkerFaceColor','b','MarkerEdgeColor','none');

        % downsample gaze trajectory to match target trajectory samples
        traj_gaze=[gaze_x gaze_y];
        [t_gaze,traj_gaze,blink_mask] = downsample_traj(t_target,t_gaze,traj_gaze,blink_mask);
        gaze_x=traj_gaze(:,1);
        gaze_y=traj_gaze(:,2);
    end

    % Clock via title
    title('t = 0.0 s');

    % Stream points; treat blinks as their own class (5) so they draw in red
    prevLabEff = NaN;
    for i = 1:4:numel(t_gaze)
        lab = L(i);                         % 0 = base, 1..4 = corner id
        isBlink = blink_mask(i);
        labEff  = lab;
        if lab==0 && isBlink, labEff = 5; end   % <-- ADDED: route base+blink to red trace

        % Update the dot (black during blink)
        set(hGaze,'XData',gaze_x(i),'YData',gaze_y(i));
        if isBlink, set(hGaze,'MarkerFaceColor','k'); else, set(hGaze,'MarkerFaceColor','r'); end

        if strcmpi(exp_type,'spem')
            % Update original spem trajectory dot
            set(hTrue,'XData',traj_target(i,1),'YData',traj_target(i,2));
        end

        % Update clock (seconds from start, 1 decimal)
        title(sprintf('t = %.1f s', (t_gaze(i)-t_gaze(1))/1000));

        if labEff==0
            xB = get(hBase,'XData'); yB = get(hBase,'YData');
            if ~isequal(prevLabEff,labEff) && ~isempty(xB)
                xB(end+1) = NaN; yB(end+1) = NaN;
            end
            xB(end+1) = gaze_x(i); yB(end+1) = gaze_y(i);
            % set(hBase,'XData',xB,'YData',yB);

        elseif labEff==5   % <-- ADDED: blink trace (red)
            xR = get(hBlink,'XData'); yR = get(hBlink,'YData');
            if ~isequal(prevLabEff,labEff) && ~isempty(xR)
                xR(end+1) = NaN; yR(end+1) = NaN;
            end
            xR(end+1) = gaze_x(i); yR(end+1) = gaze_y(i);
            set(hBlink,'XData',xR,'YData',yR);

        else
            xK = get(hSeg(labEff),'XData'); yK = get(hSeg(labEff),'YData');
            if ~isequal(prevLabEff,labEff) && ~isempty(xK)
                xK(end+1) = NaN; yK(end+1) = NaN;
            end
            xK(end+1) = gaze_x(i); yK(end+1) = gaze_y(i);
            set(hSeg(labEff),'XData',xK,'YData',yK);
        end

        prevLabEff = labEff;
        drawnow;
    end
end


%% remove blinks

% only for returned outputs (plots above remain unchanged)
gaze_x(blink_mask) = NaN;
gaze_y(blink_mask) = NaN;