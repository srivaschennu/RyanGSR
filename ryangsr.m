function lacWin

close all;
fclose all;
clear; clc;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Load materials - sequences, word list and sounds
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
enable_pp   = 1;                   % 1 to enable parallel port
port_number = xlsread('port.xls'); % reads the parallel port from file
load index_stimuli_TwoNotes;
load audio_vars2;

% index_stimuli contains the following:
% 1. audio matrix for each stimulus sequence
% 2. Type of sequence (0 = non-aversive, 1 = aversive, 3 = surprise aversive)
% 3. Stimulus lengths for each sequence
% There are 10 blocks of 8 trials with the first two being training
% sequences and hence containing just predictable events. The subsequent 8
% blocks contain 6 non-aversive, 1 aversive, and 1 surprise aversive each.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% nshost = '10.0.0.42';
% nsport = 55513;
% fprintf('Connecting to Net Station.\n');
% [nsstatus, nserror] = NetStation('Connect',nshost,nsport);
% if nsstatus ~= 0
%     error('Could not connect to NetStation host %s:%d.\n%s\n', ...
%         nshost, nsport, nserror);
% end
% NetStation('Synchronize');

f_sample = 44100;
fprintf('Initialising audio.\n');

InitializePsychSound

if PsychPortAudio('GetOpenDeviceCount') == 1
    PsychPortAudio('Close',0);
end

%DMX
audiodevices = PsychPortAudio('GetDevices',3);
outdevice = strcmp('DMX 6Fire USB ASIO Driver',{audiodevices.DeviceName});

%Windows
% audiodevices = PsychPortAudio('GetDevices',2);
% outdevice = strcmp('Microsoft Sound Mapper - Output',{audiodevices.DeviceName});

mb_handle = msgbox({'Ensure that:','','-  Inset earphone jack is connected to the Terratec box, NOT the laptop','',...
    '- "Waveplay 1/2" volume in the panel below is set to -4dB',''},'ryangsr','warn');
boxpos = get(mb_handle,'Position');
set(mb_handle,'Position',[boxpos(1) boxpos(2)+125 boxpos(3) boxpos(4)]);
system('C:\Program Files\TerraTec\DMX6FireUSB\DMX6FireUSB.exe');
if ishandle(mb_handle)
    uiwait(mb_handle);
end

pahandle = PsychPortAudio('Open',audiodevices(outdevice).DeviceIndex,1,1,f_sample,2);

% Create left and right aversive and non-aversive stimuli
tada_right  = [zeros(length(tada_audio),1) tada_audio(:,1)];
noise_right = [zeros(length(noise_audio),1) noise_audio];
tada_left  = [tada_audio(:,1) zeros(length(tada_audio),1)];
noise_left = [noise_audio zeros(length(noise_audio),1)];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set program parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
practice_trials = 40;                   % hard coded based on sequences
stim_duration=1000;                     % stimulus duration
initial_delay=5000;                     % blank time from task start
antic_pause_trials = 2000;              % pause between pattern and stimuli in experimental trials
antic_pause_practice_trials = 1000;     % pause between pattern and stimuli in practice trials
pause_between_trials=14000;             % gap between experimental trials
pause_between_practice_trails = 2500;   % gap between the first half of practice trials
pause_rampup_practice_trials = 6000;    % gap between trials by the end of the practice trials
pause_between_training_blocks = 10000;  % after every 5th training trial pause
pause_after_training = 300000;          % delay after training trials to reduce habituation to noise
restartWarningDuration = 60000;         % delay between warning about restart and trials restarting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Build index of events
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
index_events={};

% col 1 -> latency from task start in milliseconds
% col 2 -> event type ('pattern_stim', 'play_stimulus',
%          'display_distractor', 'blank_screen', 'send_sync_pulse',
%          'display_rest_msg', 'display_restart_msg'
% col 3 -> argument1
%   for 'pattern_stim' has an index number associated with it.
%   for 'play_stimulus' can be 'aversive_right', 'aversive_left',
%       'non-aversive_right', or 'non-aversive_left'
%   for 'display_distractor' number 1,2,3 or 4 indicating '|' left, '|'
%       right, '_' left, or '_' right.
%   for 'send_sync_pulse' can be 'aversive', 'non-aversive', or 'unpred_aversive'

ev_ptr=1;
restStart = 0;
current_latency=initial_delay;
for i=1:length(index_stimuli)
    
    % Pattern stimuli
    index_events{ev_ptr,1}=current_latency;
    index_events{ev_ptr,2}='pattern_stim';
    index_events{ev_ptr,3}=i;
    current_latency = current_latency + index_stimuli{i,3} + 50;
    ev_ptr=ev_ptr+1;
    
    % Aversive or non-aversive sync pulse
    switch index_stimuli{i,2}
        case 0
            index_events{ev_ptr,1}=current_latency;
            index_events{ev_ptr,2}='send_sync_pulse';
            index_events{ev_ptr,3}='non-aversive_right';
            current_latency=current_latency+50;
            ev_ptr=ev_ptr+1;
        case 1
            index_events{ev_ptr,1}=current_latency;
            index_events{ev_ptr,2}='send_sync_pulse';
            index_events{ev_ptr,3}='aversive_right';
            current_latency=current_latency+50;
            ev_ptr=ev_ptr+1;
        case 3
            index_events{ev_ptr,1}=current_latency;
            index_events{ev_ptr,2}='send_sync_pulse';
            index_events{ev_ptr,3}='unpred_aversive';
            current_latency=current_latency+50;
            ev_ptr=ev_ptr+1;
        otherwise
            error('internal error');
    end
    
    % Aversive or non-aversive stimulus
    if i <= (practice_trials/2) % First half of practice trials have short delay before stimululs
        current_latency = current_latency + antic_pause_practice_trials;
        increasing_pause = antic_pause_practice_trials;
    elseif i <= practice_trials % Second half of practice trials ramp up to full delay before stimulus
        increasing_pause = increasing_pause + ((antic_pause_trials - antic_pause_practice_trials)/ (practice_trials/2));
        current_latency = current_latency + increasing_pause;
    else                        % No longer practice trials so have full delay before stimulus
        current_latency = current_latency + antic_pause_trials;
    end
    
    switch index_stimuli{i,2}
        case 0
            index_events{ev_ptr,1}=current_latency;
            index_events{ev_ptr,2}='play_stimulus';
            if i <= 20 || (i > 40 && i <= 72)
                index_events{ev_ptr,3}='non-aversive_right';
            else
                index_events{ev_ptr,3}='non-aversive_left';
            end
            current_latency=current_latency+floor(stim_duration*1.1);
            ev_ptr=ev_ptr+1;
        case 1
            index_events{ev_ptr,1}=current_latency;
            index_events{ev_ptr,2}='play_stimulus';
            if i <= 20 || (i > 40 && i <= 72)
                index_events{ev_ptr,3}='aversive_right';
            else
                index_events{ev_ptr,3}='aversive_left';
            end
            current_latency=current_latency+floor(stim_duration*1.1);
            ev_ptr=ev_ptr+1;
        case 3
            index_events{ev_ptr,1}=current_latency;
            index_events{ev_ptr,2}='play_stimulus';
            if i <= 20 || (i > 40 && i <= 72)
                index_events{ev_ptr,3}='aversive_right';
            else
                index_events{ev_ptr,3}='aversive_left';
            end
            current_latency=current_latency+floor(stim_duration*1.1);
            ev_ptr=ev_ptr+1;
        otherwise
            index_stimuli{i,2}
            error('internal error');
    end
    
    % Insert appropriate pauses between trials
    if i==10 || i ==15 || i==20 || i==25 || i==30 || i==35 % During training pause for 10 s after every different block
        current_latency=current_latency+pause_between_training_blocks;
    elseif i <= 20 % First half of practice trials have short delay between trials
        current_latency=current_latency+pause_between_practice_trails;
        increasing_interTrialPause = pause_between_practice_trails;
    elseif i < practice_trials % After simple blocks ramp up delay to specified level
        increasing_interTrialPause = increasing_interTrialPause + ((pause_rampup_practice_trials - pause_between_practice_trails)/ (practice_trials/2));
        current_latency = current_latency + increasing_interTrialPause;
    elseif i == practice_trials % Long pause at end of training trials with messages to rest and restart
        restStart = 1;
        index_events{ev_ptr,1}=current_latency;
        startRest = current_latency;
        index_events{ev_ptr,2}='display_rest_msg';
        current_latency = current_latency + pause_after_training - restartWarningDuration;
        ev_ptr=ev_ptr+1;
        index_events{ev_ptr,1}=current_latency;
        index_events{ev_ptr,2}='display_restart_msg';
        current_latency = current_latency + restartWarningDuration;
        ev_ptr=ev_ptr+1;
        index_events{ev_ptr,1}=current_latency;
        index_events{ev_ptr,2}='display_testing_msg';
        ev_ptr=ev_ptr+1;
    else                        % No longer practice trials so have full delay between trials
        current_latency = current_latency + pause_between_trials;
    end
    
end
task_duration=current_latency;

% Put the index_events into event order i.e. latency time.
[b,ix]=sort(cell2mat(index_events(:,1)));
index_events=index_events(ix,:);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Capture participant data and test stimuli
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
config_results();
% config_display( 0, 2, [0 0 0], [1 1 1], 'Arial', 25, 1, 8, 0)
% config_keyboard(100, 5, 'nonexclusive' );
start_cogent;

% Initialize the inpout32 low-level I/O driver
config_io;

% Verify that the inpout32 driver was successfully installed
global cogent;
if (cogent.io.status ~= 0)
    error('inp/outp installation failed');
    return;
end

% Set enable_pp to 1 to enable parallel port
if enable_pp
    outp(port_number,0);
end

% Test the sync pulse
clc;
response = [];
while isempty(response)
    response = input('Enter 1 to test sync pulse, 2 for next: ', 's');
    if ~isempty(response)
        if str2double(response) == 1    % if 1 test sync pulse
            if enable_pp
                outp(port_number,255);
                wait(20);
                outp(port_number,0);
                disp('Sent sync pulse.');
                response = [];
            else
                disp('Parallel port disabled.');
                response = [];
            end
        elseif str2double(response) == 2 % if 2 then continue
            response = 2;
        else                             % if neither then loop
            response = [];
        end
    end
end

% Test pattern stimuli
clc;
response = [];
while isempty(response)
    response = input('Enter 1 to test pattern stimuli, 2 for next: ', 's');
    if ~isempty(response)
        if str2double(response) == 1    % if 1 test pattern stimuli
            %wavplay(.1*index_stimuli{1,1},44100);
            PsychPortAudio('FillBuffer',pahandle, .1*index_stimuli{1,1}');
            PsychPortAudio('Start',pahandle);
            
            disp('Played pattern stimuli.');
            response = [];
        elseif str2double(response) == 2 % if 2 then continue
            response = 2;
        else                             % if neither then loop
            response = [];
        end
    end
end

% Test non-aversive stimuli
clc;
response = [];
while isempty(response)
    response = input('Enter 1 to test non-aversive stimuli, 2 for next: ', 's');
    if ~isempty(response)
        if str2double(response) == 1    % if 1 test non-aversive stimuli
            %           wavplay(.1*tada_right,44100);
            PsychPortAudio('FillBuffer',pahandle, .1*tada_right');
            PsychPortAudio('Start',pahandle);
            disp('Played non-aversive stimuli.');
            response = [];
        elseif str2double(response) == 2 % if 2 then continue
            response = 2;
        else                             % if neither then loop
            response = [];
        end
    end
end

% Test aversive stimuli
clc;
response = [];
while isempty(response)
    response = input('Enter 1 to test aversive stimuli, 2 for next: ', 's');
    if ~isempty(response)
        if str2double(response) == 1    % if 1 test aversive stimuli
            %wavplay(noise_right,44100);
            PsychPortAudio('FillBuffer',pahandle, noise_right');
            PsychPortAudio('Start',pahandle);
            disp('Played aversive stimuli.');
            response = [];
        elseif str2double(response) == 2 % if 2 then continue
            response = 2;
        else                             % if neither then loop
            response = [];
        end
    end
end


% Start or abort
clc;
response = [];
while isempty(response)
    response = input('Enter 1 to start, 2 to abort: ', 's');
    if ~isempty(response)
        if str2double(response) == 1    % if 1 start training
            clc;
            disp('Running training phase.');
        elseif str2double(response) == 2 % if 2 return for abort
            return;
        else                             % if neither then loop
            response = [];
        end
    end
end
if str2double(response) == 2
    return;
end

NetStation('StartRecording');
pause(1);
NetStation('Event','STRT');

% Record start time and send start indicating sync pulse
start_time=time;
if enable_pp
    outp(port_number, 255); % Start of experiment sync pulse
end
wait(1000);
if enable_pp
    outp(port_number, 0);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Run through the index of events
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:length(index_events)
    
    if time-start_time>index_events{i,1}+50
        warning(sprintf('Warning: negative slack at event %d, %d milliseconds',i,time-start_time-index_events{i,1}));
    else
        while time-start_time<index_events{i,1}; end;
    end
    
    % Play the pattern stimuli
    if strcmp(index_events{i,2},'pattern_stim')
        %        wavplay(.1*index_stimuli{index_events{i,3},1},44100,'async');
        PsychPortAudio('FillBuffer',pahandle,.1*index_stimuli{index_events{i,3},1}');
        PsychPortAudio('Start',pahandle);
        
        % Play the aversive or non-aversive stimulus
    elseif strcmp(index_events{i,2},'play_stimulus')
        if strcmp(index_events{i,3},'aversive_right')
            %            wavplay(noise_right,44100,'async');
            PsychPortAudio('FillBuffer',pahandle,noise_right');
            PsychPortAudio('Start',pahandle);
        elseif strcmp(index_events{i,3},'aversive_left')
            %             wavplay(noise_left,44100,'async');
            PsychPortAudio('FillBuffer',pahandle,noise_left');
            PsychPortAudio('Start',pahandle);
        elseif strcmp(index_events{i,3},'non-aversive_right')
            %             wavplay(.1*tada_right,44100,'async');
            PsychPortAudio('FillBuffer',pahandle,.1*tada_right');
            PsychPortAudio('Start',pahandle);
        elseif strcmp(index_events{i,3},'non-aversive_left')
            %             wavplay(.1*tada_left,44100,'async');
            PsychPortAudio('FillBuffer',pahandle,.1*tada_left');
            PsychPortAudio('Start',pahandle);
        else
            error(sprintf('Unknown argument at %d',i));
        end
        
        % Display rest and restart messages
    elseif strcmp(index_events{i,2},'display_rest_msg')
        clc;
        disp('Silent rest phase (lasts 5 minutes)');
    elseif strcmp(index_events{i,2},'display_restart_msg')
        clc;
        disp('Prepare to restart in 1 minute!');
    elseif strcmp(index_events{i,2},'display_testing_msg')
        clc;
        disp('Running test phase');
        
        % Send sync pulse
    elseif strcmp(index_events{i,2},'send_sync_pulse')
        if strcmp(index_events{i,3},'aversive_left') || strcmp(index_events{i,3},'aversive_right')
            if enable_pp
                outp(port_number, 255);
                wait(10);
                outp(port_number, 0);
            end
            NetStation('Event','PAVE');
            
        elseif strcmp(index_events{i,3},'non-aversive_left') || strcmp(index_events{i,3},'non-aversive_right')
            if enable_pp
                outp(port_number, 255);
                wait(20);
                outp(port_number, 0);
            end
            NetStation('Event','NAVE');
            
        elseif strcmp(index_events{i,3},'unpred_aversive')
            if enable_pp
                outp(port_number, 255);
                wait(30);
                outp(port_number, 0);
                NetStation('Event','UAVE');
            end
        else
            error(sprintf('Unknown argument at %d',i));
        end
    else
        error(sprintf('Unknown command at %d',i));
    end
end
wait(10000); % Because there are no more 'events' after the last trial there
% is no delay after it. We therefore need a delay here before
% the end of experiment sync pulse below.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Wrap-up and end program
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if enable_pp
    outp(port_number, 0);
    outp(port_number, 255);    % End of experiment sync pulse
    wait(1000);
    outp(port_number, 0);
end

NetStation('Event','STOP');
pause(1);
NetStation('StopRecording');

PsychPortAudio('Close',pahandle);

clc;
disp('Program complete.');

stop_cogent;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%