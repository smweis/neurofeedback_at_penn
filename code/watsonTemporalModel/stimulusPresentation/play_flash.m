function play_flash(runNumber,stimFreq,blockDur,scanDur,tChar,display,subjectPath,allFreqs)

%% Displays a black/white full-field flicker
%
%   Usage:
%   play_flash(runNumber,stimFreq,blockDur,scanDur,tChar,display,subjectPath,allFreqs,debug))
%
%   Required inputs:
%   runNumber           - which run. To determine save data. 
%
%   Defaults:
%   stimFreq            - stimulus flicker frequency    (default = 16   [hertz])
%   blockDur            - duration of stimulus blocks   (default = 12   [seconds])
%   scanDur             - duration of total run (default = 336 seconds)
%   tChar               - {'t'}; % character(s) to signal a scanner trigger
%   display.distance    - 106.5; % distance from screen (cm) - (UPenn - SC3T);
%   display.width       - 69.7347; % width of screen (cm) - (UPenn - SC3T);
%   display.height      - 39.2257; % height of screen (cm) - (UPenn - SC3T);
%   subjectPath         - passed from default for
%                           tbUseProject('neurofeedback') (default - test subject)
%   allFreqs            - the domain of possible frequencies to present
%                          
%                           


%   Stimulus will flicker at 'stimFreq', occilating between flicker and
%   grey screen based on 'blockDur'
%
%   Written by Andrew S Bock Jul 2016
%   Modified by Steven M Weisberg Jan 2019

%% Set defaults

% stimulus frequency
if ~exist('stimFreq','var')
    stimFreq = 16; % seconds
end

% block duration
if ~exist('blockDur','var')
    blockDur = 12; % seconds
end

% run duration
if ~exist('scanDur','var')
    scanDur = 336;
end

% scanner trigger
if ~exist('tChar','var') || isempty(tChar)
    tChar = {'t'};
end

% display parameters
if ~exist('display','var') || isempty(display)
    display.distance = 106.5; % distance from screen (cm) - (UPenn - SC3T);
    display.width = 69.7347; % width of screen (cm) - (UPenn - SC3T);
    display.height = 39.2257; % height of screen (cm) - (UPenn - SC3T);
end

if ~exist('subjectPath','var') || isempty(subjectPath)
    [subjectPath] = getPaths('TOME_3040_TEST');
end

if ~exist('allFreqs','var') || isempty(allFreqs)
    allFreqs = [2,4,8,16,32,64];
end

%% Debugging
debug = 0;
stimWindow = [];

if debug
    stimWindow = [10 10 20 20];
end



%% Save input variables
params.stimFreq         = nan(1,scanDur/blockDur);
params.trialTypeStrings = cell(1,length(params.stimFreq));
params.allFreqs         = allFreqs;


%% Set up actualStimuli.txt
% A text file that will serve as a record for all stimuli frequencies
% presented

fid = fopen(fullfile(subjectPath,'actualStimuli.txt'),'w');
fclose(fid);

%% Initial settings
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 2); % Skip sync tests
screens = Screen('Screens'); % get the number of screens
screenid = max(screens); % draw to the external screen

%% For Trigger
a = cd;
if a(1)=='/' % mac or linux
    a = PsychHID('Devices');
    for i = 1:length(a)
        d(i) = strcmp(a(i).usageName, 'Keyboard');
    end
    keybs = find(d);
else % windows
    keybs = [];
end


%% Define black and white
black = BlackIndex(screenid);
white = WhiteIndex(screenid);
grey = white/2;


%% Screen params
res = Screen('Resolution',max(Screen('screens')));
display.resolution = [res.width res.height];
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'UseRetinaResolution');
[winPtr, windowRect]            = PsychImaging('OpenWindow', screenid, grey, stimWindow);
[mint,~,~] = Screen('GetFlipInterval',winPtr,200);
display.frameRate = 1/mint; % 1/monitor flip interval = framerate (Hz)
display.screenAngle = pix2angle( display, display.resolution );
[center(1), center(2)]          = RectCenter(windowRect); % Get the center coordinate of the window
fix_dot                         = angle2pix(display,0.25); % For fixation cross (0.25 degree)


%% Make imagesd
greyScreen = grey*ones(fliplr(display.resolution));
blackScreen = black*ones(fliplr(display.resolution));
whiteScreen = white*ones(fliplr(display.resolution));
Texture(1) = Screen('MakeTexture', winPtr, blackScreen);
Texture(2) = Screen('MakeTexture', winPtr, whiteScreen);
Texture(3) = Screen('MakeTexture', winPtr, greyScreen);

%% Display Text, wait for Trigger

commandwindow;
Screen('FillRect',winPtr, grey);
Screen('DrawDots', winPtr, [0;0], fix_dot,black, center, 1);
Screen('Flip',winPtr);
ListenChar(2);
HideCursor;
disp('Ready, waiting for trigger...');

startTime = wait4T(tChar);  %wait for 't' from scanner.

%% Drawing Loop
breakIt = 0;
frameCt = 0;

curFrame = 0;
params.startDateTime    = datestr(now);
params.endDateTime      = datestr(now); % this is updated below
elapsedTime = 0;
disp(['Trigger received - ' params.startDateTime]);
blockNum = 0;
try
    while elapsedTime < scanDur && ~breakIt  %loop until 'esc' pressed or time runs out
        thisBlock = ceil(elapsedTime/blockDur);
        
        
        % stim frequency selection and recording
        if thisBlock > blockNum
            blockNum = thisBlock;

            if mod(blockNum,6) == 0 % every sixth block, display steady screen
                trialTypeString = 'baseline';
                stimFreq = 0;
                
            elseif ~isempty(dir(fullfile(subjectPath,'stimLog','nextStim*')))
                
                d = dir(fullfile(subjectPath,'stimLog','nextStim*'));
                [~,idx] = max([d.datenum]);
                filename = d(idx).name;
                nextStimNum = sscanf(filename,'nextStimuli%d');
                trialTypeString = ['quest recommendation - ' num2str(nextStimNum)];
                readFid = fopen(fullfile(subjectPath,'stimLog',filename),'r');
                stimFreq = fscanf(readFid,'%d');
                fclose(readFid);

            
            else % if no QUEST+ stim yet, randomly pick a frequency
                trialTypeString = 'random';
                whichFreq = randi(6);
                stimFreq = allFreqs(whichFreq);
            end
            
            fid = fopen(fullfile(subjectPath,'actualStimuli.txt'),'a');
            fprintf(fid,'%d\n',stimFreq);
            fclose(fid);
            
            disp(['Trial Type - ' trialTypeString]);
            disp(['Trial Number - ' num2str(blockNum) '; Frequency - ' num2str(stimFreq)]);
            
            
            
            params.stimFreq(thisBlock) = stimFreq;
            params.trialTypeStrings{thisBlock} = trialTypeString;
            
        end
        
     
        % display 
        if stimFreq ~= 0 % flicker
            if (elapsedTime - curFrame) > (1/(stimFreq*2))
                frameCt = frameCt + 1;
                Screen( 'DrawTexture', winPtr, Texture( mod(frameCt,2) + 1 )); % current frame
                % Flip to the screen
                Screen('Flip', winPtr);
                curFrame = GetSecs - startTime;
            end
        else % black screen
            Screen( 'DrawTexture', winPtr, Texture( 3 )); % grey screen
            % Flip to the screen
            Screen('Flip', winPtr);
        end
        
        
        
        % update timers
        elapsedTime = GetSecs-startTime;
        params.endDateTime = datestr(now);
        % check to see if the "esc" button was pressed
        breakIt = escPressed(keybs);
        WaitSecs(0.001);
        
    end
    
    sca;
    save(fullfile(subjectPath,strcat('stimFreqData_Run',num2str(runNumber))),'params');
    disp(['elapsedTime = ' num2str(elapsedTime)]);
    ListenChar(1);
    ShowCursor;
    Screen('CloseAll');
    
catch ME
    Screen('CloseAll');
    ListenChar;
    ShowCursor;
    rethrow(ME);
end
