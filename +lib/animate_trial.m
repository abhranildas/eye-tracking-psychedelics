%% animate
figure;
axis image; axis([0 1920 0 1080])
set(gca,'ydir','reverse')
hold on;

point=plot(edf.Samples.gx(1,1),edf.Samples.gy(1,1),'ro');

trial_num=70;

exp_start_time=edf.timeline(1);
start_frame=edf.Events.Start.time(trial_num)-exp_start_time+1;
end_frame=edf.Events.Start.time(trial_num+1)-exp_start_time+1;

frameRate = 1e3;   % Frames per second (adjust as needed)
for frame = start_frame:end_frame
    
    % Update the position of the point
    set(point, 'XData', edf.Samples.gx(frame,1), 'YData', edf.Samples.gy(frame,1));
    
    % Pause to control the frame rate
    pause(1/frameRate);

    % show time
    title(sprintf('%.1f',(frame-start_frame)/1e3));
    
    % Refresh the plot
    drawnow;
end