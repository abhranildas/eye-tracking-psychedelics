function [gaze_x, gaze_y, fix_x, fix_y, traj_target, t_target] = preprocess_gaze(edf_mat, varargin)
% PREPROCESS_GAZE  Calibrate, plot and blink-mask the gaze trace of one recording.
%   [gaze_x, gaze_y, fix_x, fix_y, traj_target, t_target] = ...
%       lib.preprocess_gaze(edf_mat, 'exp_type', ..., 'animate', ..., ...
%                           'corners', ..., 'calib_sz', ...)
%
%   Three things happen here, in this order.
%
%   1. A homography is fitted that maps the four corner positions the
%      participant actually looked at onto the four corner positions they were
%      asked to look at, and is applied to every gaze sample and every
%      fixation. This is the calibration correction; with no 'corners' given it
%      is the identity. The four corner-fixation trials are located from the
%      '!V TRIALID 0.' and 'TRIAL_RESULT 0' messages at the head of the
%      recording.
%   2. The corrected trace is plotted -- always, there is no flag to suppress
%      it. Callers that do not want figures set DefaultFigureVisible off.
%      Optionally it is then animated sample by sample.
%   3. Blink samples, padded by 100 ms on each side, are set to NaN in the two
%      returned gaze vectors only. The figures drawn above still show them.
%
% Inputs
%   edf_mat   Edf2Mat object for one recording. Read here: .Samples.time
%             (milliseconds, EyeLink clock), .Samples.posX/.posY (pixels),
%             .Events.Efix.posX/.posY (pixels), .Events.Eblink.start/.end
%             (milliseconds), .Events.Messages.time/.message/.info.
%   Name-value pairs, all optional. These four literals are part of the
%   cross-file contract and are read at free_view_analyze.m:76,
%   spem_analyze.m:9 and pre_process.m:41; they are frozen for this pass and
%   are Tier C item 0.3.2.
%     'exp_type'  'free_view' or 'spem', char, default []. 'free_view' adds the
%                 3x3 grid lines to the plots; 'spem' overlays the pursuit
%                 target during the animation. Compared with STRCMPI, so the
%                 values are frozen too.
%     'animate'   logical or numeric, default false. Draw the second, animated
%                 figure.
%     'corners'   [4 x 2] observed corner positions in pixels, rows ordered
%                 [TL; TR; BR; BL], default NaN(4,2). Any all-NaN row falls
%                 back to that ideal corner, so a partly filled matrix is
%                 allowed. Produced by pre_process.m's manual polygon drag.
%     'calib_sz'  scalar, default 1. Dimensionless -- the fraction of the
%                 screen spanned by the ideal corner square, NOT a length.
%                 pre_process.m:28 and spem_analyze.m:3 both pass 2/3, meaning
%                 the corner targets sat two-thirds of the way out.
% Output
%   gaze_x       [N x 1] horizontal gaze position after calibration, pixels,
%                one per tracker sample, NaN during padded blinks.
%   gaze_y       [N x 1] vertical gaze position, pixels, y growing downward.
%   fix_x        [F x 1] horizontal position of each detected fixation, pixels,
%                calibrated. Not blink-masked.
%   fix_y        [F x 1] vertical fixation position, pixels.
%   traj_target  [M x 2] pursuit target path, pixels, columns [x y]. See the
%                bug note below -- only assigned on one path.
%   t_target     [M x 1] times of those target positions, milliseconds.
%
%   Unit convention throughout: pixels on a fixed 1920 x 1080 screen with the
%   origin at the top left and y growing downward, and milliseconds on the
%   EyeLink tracker clock.
%
%   Known bugs, recorded and deliberately NOT fixed here. All four are in
%   docs/repo-cleanup.md section 0.4 and are Tier C work.
%     0.4.2   The DOWNSAMPLE_TRAJ call below passes every argument after the
%                first shifted one position left relative to that function's
%                signature, so the third output comes back as an [N x 1] blink
%                vector which the next line indexes as (:,2). Errors whenever
%                'animate' is true and 'exp_type' is 'spem'.
%     0.4.3   TRUE_TARGET_TRAJ and DOWNSAMPLE_TRAJ live in spem/, not in
%                +lib/, and nothing in this repo puts spem/ on the path, so
%                both calls fail unless the caller added it.
%     0.4.12  PARSER.FUNCTIONNAME is still set to 'plot_gaze', a function
%                that does not exist, so INPUTPARSER's error messages name the
%                wrong function. That string is code rather than comment, so
%                correcting it is not a Tier A change. Separately, TRAJ_TARGET
%                and T_TARGET are assigned only inside the 'animate' and 'spem'
%                branch, so asking for outputs 5 and 6 on any other path
%                errors.
%     0.4.13  The SET call that would draw the black base trace during the
%                animation is commented out, while BASE_X and BASE_Y are still
%                grown one element per frame. About a quarter of the animation
%                loop's work produces nothing visible.
%
% See also ANALYZE.FREE_VIEW_MEASURES, SPEM_MEASURES, TRUE_TARGET_TRAJ,
% DOWNSAMPLE_TRAJ, SVD

% ---- parse inputs ----
parser = inputParser; parser.FunctionName = 'plot_gaze';
addRequired(parser, 'edf_mat');
addParameter(parser, 'exp_type', []);
addParameter(parser, 'animate',   false, @(x) islogical(x) || isnumeric(x));
addParameter(parser, 'corners',  NaN(4, 2), @(x) (isnumeric(x) && isequal(size(x), [4 2])));
addParameter(parser, 'calib_sz', 1, @isscalar);
parse(parser, edf_mat, varargin{:});
exp_type = parser.Results.exp_type;
animate   = parser.Results.animate;
corners  = parser.Results.corners;
calib_sz  = parser.Results.calib_sz;

% --- parse EDF ---
samples = edf_mat.Samples;

t_gaze = double(samples.time);             % ms
gaze_x = double(samples.posX);             % px
gaze_y = double(samples.posY);             % px
fix_x = edf_mat.Events.Efix.posX';         % px, one per fixation
fix_y = edf_mat.Events.Efix.posY';         % px

% compute blink mask
blink_start_ms = double(edf_mat.Events.Eblink.start);
blink_end_ms   = double(edf_mat.Events.Eblink.end);

blink_pad_ms = 100;                          % small safety pad
blink_start_ms = blink_start_ms - blink_pad_ms;
blink_end_ms   = blink_end_ms + blink_pad_ms;
blink_mask = false(size(t_gaze));
for k = 1:numel(blink_start_ms)
    blink_mask = blink_mask | ...
        (t_gaze >= blink_start_ms(k) & t_gaze <= blink_end_ms(k));
end

% --- Screen & grid (fixed 1920x1080) ---
screen_width_px = 1920; screen_height_px = 1080;
x_thirds = (screen_width_px/3) * (1:2);     % px, the two vertical grid lines
y_thirds = (screen_height_px/3) * (1:2);    % px, the two horizontal grid lines
draw_screen_rect = @() plot( ...
    [0 screen_width_px screen_width_px 0 0], ...
    [0 0 screen_height_px screen_height_px 0], ...
    '-', 'color', .5*[1 1 1], 'LineWidth', .5);

% ---------- Parse corner intervals from EDF messages ----------
corner_intervals_ms = [];   % Nx2 [start_ms end_ms]
msg_time_ms = double(edf_mat.Events.Messages.time(:));
if isfield(edf_mat.Events.Messages, 'message')
    msg_text = string(edf_mat.Events.Messages.message(:));
elseif isfield(edf_mat.Events.Messages, 'info')
    msg_text = string(edf_mat.Events.Messages.info(:));
else
    msg_text = strings(size(msg_time_ms));
end

is_corner_start = startsWith(msg_text, "TRIALID 0.");
corner_start_ms = msg_time_ms(is_corner_start);

is_trial_end = startsWith(msg_text, "TRIAL_RESULT 0");
trial_end_ms = msg_time_ms(is_trial_end);

corner_start_ms = sort(corner_start_ms);
trial_end_ms    = sort(trial_end_ms);

% Pair each corner-trial start with the next trial end. At most four, because
% there are at most four corner-calibration trials.
for k = 1:min(4, numel(corner_start_ms))
    interval_start_ms = corner_start_ms(k);
    next_end_idx = find(trial_end_ms > interval_start_ms, 1, 'first');
    if ~isempty(next_end_idx)
        interval_end_ms = trial_end_ms(next_end_idx);
        corner_intervals_ms(end + 1, :) = ...
            [interval_start_ms interval_end_ms]; %#ok<AGROW>
    end
end

% map time (ms) to sample indices
corner_sample_idx = [];  % Nx2 [iStart iEnd]
if ~isempty(corner_intervals_ms)
    for k = 1:size(corner_intervals_ms, 1)
        interval_start_ms = corner_intervals_ms(k, 1);
        interval_end_ms   = corner_intervals_ms(k, 2);
        i_first = find(t_gaze >= interval_start_ms, 1, 'first');
        i_last  = find(t_gaze <= interval_end_ms, 1, 'last');
        if ~isempty(i_first) && ~isempty(i_last) && i_last > i_first
            corner_sample_idx(end + 1, :) = [i_first i_last]; %#ok<AGROW>
        end
    end
end

% label vector: 0 = base, 1..4 = corner interval id
corner_label = zeros(size(t_gaze));
for k = 1:min(4, size(corner_sample_idx, 1))
    corner_label(corner_sample_idx(k, 1):corner_sample_idx(k, 2)) = k;
end

% colors for the 4 corner intervals, 4x3 RGB
corner_colors = [0.7 0.7 0;   % yellow-ish
    0.20 0.60 0.86;   % blue-ish
    0.18 0.80 0.44;   % green-ish
    0.61 0.35 0.71];  % purple-ish

%% --------- CALIBRATE: use a homography so cornerXY -> ideal screen corners exactly ---------
% Ideal/default (target) corners (TL, TR, BR, BL), px. calib_sz shrinks the
% square towards the screen centre: 1 puts the corners at the screen corners.
% src = [0 0; screen_w 0; screen_w screen_h; 0 screen_h];
ideal_corners_px = [screen_width_px screen_height_px]/2 + ...
    [-[screen_width_px  screen_height_px]; ...
      [screen_width_px -screen_height_px]; ...
      [screen_width_px  screen_height_px]; ...
     [-screen_width_px  screen_height_px]]/2*calib_sz;

% Observed corners from manual overrides, falling back to defaults on NaN rows
observed_corners_px = ideal_corners_px;
if ~isempty(corners) && isequal(size(corners), [4 2])
    for i_row = 1:4
        if all(isfinite(corners(i_row, :)))
            observed_corners_px(i_row, :) = corners(i_row, :);
        end
    end
end

is_valid = all(isfinite(observed_corners_px), 2) & ...
    all(isfinite(ideal_corners_px), 2);

if sum(is_valid) >= 4
    % --- Direct Linear Transform (DLT) for homography (obs -> src) ---
    observed_px = observed_corners_px(is_valid, :);   % observed points (x,y)
    ideal_px    = ideal_corners_px(is_valid, :);      % ideal targets (u,v)

    % Build A * h = 0
    % For each correspondence (x,y) -> (u,v):
    % [ -x -y -1  0  0  0  u*x  u*y  u ]
    % [  0  0  0 -x -y -1  v*x  v*y  v ]
    n_points = size(observed_px, 1);
    dlt_matrix = zeros(2*n_points, 9);
    for i_point = 1:n_points
        x_obs = observed_px(i_point, 1); y_obs = observed_px(i_point, 2);
        x_ideal = ideal_px(i_point, 1);  y_ideal = ideal_px(i_point, 2);
        dlt_matrix(2*i_point - 1, :) = ...
            [-x_obs, -y_obs, -1,  0,  0,  0,  x_ideal*x_obs, x_ideal*y_obs, x_ideal];
        dlt_matrix(2*i_point, :) = ...
            [ 0,  0,  0, -x_obs, -y_obs, -1,  y_ideal*x_obs, y_ideal*y_obs, y_ideal];
    end
    % The homography is the null vector of the DLT system, i.e. the right
    % singular vector with the smallest singular value.
    [~, ~, dlt_null_basis] = svd(dlt_matrix, 0);
    homography_vec = dlt_null_basis(:, end);
    homography     = reshape(homography_vec, [3, 3])';
else
    % Fallback: identity (or keep your earlier affine fallback if you like)
    homography = eye(3);
end

% Apply homography to the full gaze trajectory (homogeneous coords)
pts_homog        = [gaze_x, gaze_y, ones(size(gaze_x))]';   % 3 x N
pts_homog_mapped = homography * pts_homog;
gaze_x = (pts_homog_mapped(1, :)./pts_homog_mapped(3, :))';
gaze_y = (pts_homog_mapped(2, :)./pts_homog_mapped(3, :))';

% Apply homography to the fixation points
pts_homog        = [fix_x, fix_y, ones(size(fix_x))]';   % 3 x N
pts_homog_mapped = homography * pts_homog;
fix_x = (pts_homog_mapped(1, :)./pts_homog_mapped(3, :))';
fix_y = (pts_homog_mapped(2, :)./pts_homog_mapped(3, :))';

% --- Auto bounds to minimally fit the whole (transformed) trajectory ---
plot_pad_px = 50;
xmin = min(gaze_x) - plot_pad_px;  ymin = min(gaze_y) - plot_pad_px;
xmax = max(gaze_x) + plot_pad_px;  ymax = max(gaze_y) + plot_pad_px;

%% --------- (1) Static density-style trajectory ----------
figure
ax_static = axes; hold(ax_static, 'on'); set(ax_static, 'YDir', 'reverse');
axis equal; box on;
xlim([xmin xmax]); ylim([ymin ymax]);

% --- base-only black trajectory (exclude corner intervals) ---
gaze_x_base = gaze_x; gaze_y_base = gaze_y;
is_corner_sample = (corner_label ~= 0);
gaze_x_base(is_corner_sample) = NaN;
gaze_y_base(is_corner_sample) = NaN;

% NEW: split base into non-blink (black) and blink (grey)
gaze_x_base_noblink = gaze_x_base; gaze_y_base_noblink = gaze_y_base;
gaze_x_base_noblink(blink_mask) = NaN;
gaze_y_base_noblink(blink_mask) = NaN;
plot(gaze_x_base_noblink, gaze_y_base_noblink, '.r', 'MarkerSize', 1);

gaze_x_base_blink = gaze_x_base; gaze_y_base_blink = gaze_y_base;
not_blink = ~blink_mask;
gaze_x_base_blink(not_blink) = NaN;
gaze_y_base_blink(not_blink) = NaN;
plot(gaze_x_base_blink, gaze_y_base_blink, '.', 'Color', 'k', 'MarkerSize', 1);

% plot fixation points
plot(fix_x, fix_y, '.b', 'MarkerSize', 1);

% Screen rectangle (+ optional grid) -- stays in default coordinates
draw_screen_rect();
if strcmpi(exp_type, 'free_view')
    for x_grid_line = x_thirds
        plot([x_grid_line x_grid_line], [0 screen_height_px], ...
            '-', 'color', .5*[1 1 1], 'LineWidth', .5);
    end
    for y_grid_line = y_thirds
        plot([0 screen_width_px], [y_grid_line y_grid_line], ...
            '-', 'color', .5*[1 1 1], 'LineWidth', .5);
    end
end

% Colored overlays for the corner intervals
for k = 1:min(4, size(corner_sample_idx, 1))
    i_corner_first = corner_sample_idx(k, 1);
    i_corner_last  = corner_sample_idx(k, 2);
    scatter(gaze_x(i_corner_first:i_corner_last), ...
        gaze_y(i_corner_first:i_corner_last), ...
        8, 'o', 'MarkerFaceColor', corner_colors(k, :), ...
        'MarkerFaceAlpha', 0.05, 'MarkerEdgeAlpha', 0);
end

%% --------- (2) Animation ----------
if animate
    figure
    ax_animation = axes; hold(ax_animation, 'on');
    set(ax_animation, 'YDir', 'reverse'); axis equal; box on;
    xlim([xmin xmax]); ylim([ymin ymax]);

    % Screen rectangle (+ optional grid)
    draw_screen_rect();
    if strcmpi(exp_type, 'free_view')
        for x_grid_line = x_thirds
            plot([x_grid_line x_grid_line], [0 screen_height_px], ...
                '-', 'color', .5*[1 1 1], 'LineWidth', .5);
        end
        for y_grid_line = y_thirds
            plot([0 screen_width_px], [y_grid_line y_grid_line], ...
                '-', 'color', .5*[1 1 1], 'LineWidth', .5);
        end
    end

    % Prepare line objects: base + 4 corner-colored traces
    h_base  = plot(NaN, NaN, '-', 'Color', 'r', 'LineWidth', .5);
    h_blink = plot(NaN, NaN, '-', 'Color', 'k', 'LineWidth', .5);   % <-- ADDED (red for blinks)
    h_seg   = gobjects(1, 4);
    for k = 1:4
        h_seg(k) = scatter(NaN, NaN, 8, 'o', ...
            'MarkerFaceColor', corner_colors(k, :), ...
            'MarkerFaceAlpha', 0.05, 'MarkerEdgeAlpha', 0);
    end
    % Gaze dot
    h_gaze = plot(NaN, NaN, 'o', 'MarkerSize', 5, ...
        'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'none');

    if strcmpi(exp_type, 'spem')
        % spem target trajectory
        [t_target, traj_target] = true_target_traj(edf_mat);
        h_target = plot(NaN, NaN, 'o', 'MarkerSize', 5, ...
            'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'none');

        % downsample gaze trajectory to match target trajectory samples
        % NOTE: arguments are shifted one position left -- bug 0.4.2
        traj_gaze = [gaze_x gaze_y];
        [t_gaze, traj_gaze, blink_mask] = ...
            downsample_traj(t_target, t_gaze, traj_gaze, blink_mask);
        gaze_x = traj_gaze(:, 1);
        gaze_y = traj_gaze(:, 2);
    end

    % Clock via title
    title('t = 0.0 s');

    % Stream points; treat blinks as their own class (5) so they draw in red.
    % Every 4th sample, i.e. 250 Hz out of the 1000 Hz recording.
    label_eff_prev = NaN;
    for i = 1:4:numel(t_gaze)
        label = corner_label(i);            % 0 = base, 1..4 = corner id
        is_blink = blink_mask(i);
        label_eff = label;
        if label==0 && is_blink, label_eff = 5; end   % <-- ADDED: route base+blink to red trace

        % Update the dot (black during blink)
        set(h_gaze, 'XData', gaze_x(i), 'YData', gaze_y(i));
        if is_blink
            set(h_gaze, 'MarkerFaceColor', 'k');
        else
            set(h_gaze, 'MarkerFaceColor', 'r');
        end

        if strcmpi(exp_type, 'spem')
            % Update original spem trajectory dot
            set(h_target, 'XData', traj_target(i, 1), 'YData', traj_target(i, 2));
        end

        % Update clock (seconds from start, 1 decimal)
        title(sprintf('t = %.1f s', (t_gaze(i) - t_gaze(1))/1000));

        if label_eff==0
            % NOTE: the set() below is commented out, so this whole branch
            % grows two vectors that are never drawn -- bug 0.4.13
            base_x = get(h_base, 'XData'); base_y = get(h_base, 'YData');
            if ~isequal(label_eff_prev, label_eff) && ~isempty(base_x)
                base_x(end + 1) = NaN; base_y(end + 1) = NaN;
            end
            base_x(end + 1) = gaze_x(i); base_y(end + 1) = gaze_y(i);
            % set(hBase,'XData',xB,'YData',yB);

        elseif label_eff==5   % <-- ADDED: blink trace (red)
            blink_x = get(h_blink, 'XData'); blink_y = get(h_blink, 'YData');
            if ~isequal(label_eff_prev, label_eff) && ~isempty(blink_x)
                blink_x(end + 1) = NaN; blink_y(end + 1) = NaN;
            end
            blink_x(end + 1) = gaze_x(i); blink_y(end + 1) = gaze_y(i);
            set(h_blink, 'XData', blink_x, 'YData', blink_y);

        else
            seg_x = get(h_seg(label_eff), 'XData');
            seg_y = get(h_seg(label_eff), 'YData');
            if ~isequal(label_eff_prev, label_eff) && ~isempty(seg_x)
                seg_x(end + 1) = NaN; seg_y(end + 1) = NaN;
            end
            seg_x(end + 1) = gaze_x(i); seg_y(end + 1) = gaze_y(i);
            set(h_seg(label_eff), 'XData', seg_x, 'YData', seg_y);
        end

        label_eff_prev = label_eff;
        drawnow;
    end
end

%% remove blinks

% only for returned outputs (plots above remain unchanged)
gaze_x(blink_mask) = NaN;
gaze_y(blink_mask) = NaN;
