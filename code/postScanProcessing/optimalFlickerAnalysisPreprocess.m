function [detrendTimeseries,stimParams] = optimalFlickerAnalysisPreprocess(subjectID,subjectDirStem,runNum,runName,retinotopyVars)
% Registration and signal extraction for the optimal flicker analysis
% pipeline. 

% Syntax:
%  [detrendTimeseries,stimParams] = optimalFlickerAnalysisPreprocess(subjectID,subjectDirStem,runNum,runName,retinotopyVars)
%
%
% Dependencies: 
%  Retinotopy data should have been collected and saved to the subjectDir
%  Requires makeMaskFromRetino.m
%
% Description:
%  Will register a retinotopic mask to functional data, then extract the
%  average signal within a visual region of those functional data. 
%	
% Inputs:
%   subjectID             - name of subject (eg TOME_3021)
%   subjectDirStem        - path to subject data; also the path that will
%                           save registered outputs
%   runNum                - number of trials
%   runName               - name of run
%
% Optional   
%   retinotopyVars        - struct with the following fields
%                           areas - integer, specifiying which visual areas
%                             to include the in the mask (default = 1)
%                           eccentricities - 1x2 array, specifying the min
%                             and max eccentricities to include (default =
%                             [0 12])
%                           angles - 1x2 array, specifying the min and max
%                             angles to include (default = [0 360])
% Outputs:
%   detrendTimeseries      - 1xn array that is the extracted signal from
%                            the region of interest after linear and 
%                            constant detrending 
%   stimParams             - the stimulus parameters from this run, if they
%                            have been copied over into the stimulus directory.
%   
% Examples
%{
    
% Enter subject ID here
subjectID = 'TOME_3021';

% Enter run name and numbers here
runNum = 1;
runName = 'tfMRI_CheckFlash_PA_run';
subjectDirStem = '/Users/nfuser/Documents/rtQuest';



%}
%{
    
%}


%% Enter in some initial values

% Set FSL directory
setenv('FSLDIR','/usr/local/fsl');

% Set up paths
subjectDir = fullfile(subjectDirStem,subjectID);
runDirName = horzcat(subjectID,'_run',num2str(runNum));
runDir = fullfile(subjectDir,runDirName);
addpath(runDir);
addpath(subjectDir);

% Handle retinotopy vars 
if nargin < 5
    retinotopyVars.areas = 1; % V1
    retinotopyVars.eccentricities = [0 12];
    retinotopyVars.angles = [0 360];
end


%% Create retinotopy-based V1 mask

% We only need to do this once per subject, since it is calculated on T1
% data, it won't change across runs. 

if ~exist(fullfile(subjectDir,horzcat('mask_area_V',retinotopyVars.areas,'_ecc_',retinotopyVars.eccentricities(1),'_to_',retinotopyVars.eccentricities(2),'.nii')),'file')
    
    % Retintopy data, downloaded from Flywheel from a previous study.
    areasPath = fullfile(subjectDir,horzcat(subjectID,'_native.template_areas.nii.gz'));
    eccenPath = fullfile(subjectDir,horzcat(subjectID,'_native.template_eccen.nii.gz'));
    anglesPath = fullfile(subjectDir,horzcat(subjectID,'_native.template_angle.nii.gz'));
    
    % Read in retinotopic maps with MRIread
    areasMap = MRIread(areasPath);
    eccenMap = MRIread(eccenPath);
    anglesMap = MRIread(anglesPath);
    
    % Create retinotopic mask (in T1w space)
    [maskFullFile] = makeMaskFromRetino(eccenMap,areasMap,anglesMap,retinotopyVars.areas,retinotopyVars.eccentricities,retinotopyVars.angles,subjectDir);
end

%% Register functional data to anatomical data. 
% Where is anatomical and functional data (NOTE, FUNC DATA ARE IN STANDARD SPACE):
T1Path = fullfile(subjectDir,horzcat(subjectID,'_T1.nii.gz'));

funcName = [runName num2str(runNum)];
funcDataPath = fullfile(runDir,'MNINonLinear','Results',funcName,[funcName '.nii.gz']);



% Get scout EPI image.
fprintf('Create scout EPI image\n');
cmd = horzcat('/usr/local/fsl/bin/fslroi ',funcDataPath,' ',runDir,'/scoutEPI.nii.gz 0 91 0 109 0 91 0 1');
system(cmd);



if ~exist(fullfile(subjectDir,'betT1.nii.gz'),'file')
    % Extract brain from T1 
    fprintf('BET\n');
    cmd = horzcat('/usr/local/fsl/bin/bet ',T1Path,' ',subjectDir,'/betT1.nii.gz');
    system(cmd);
    
    % Calculate registration matrix
    fprintf('Calculate registration matrix\n');
    cmd = horzcat('/usr/local/fsl/bin/flirt -ref /usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz -in ',subjectDir,'/betT1.nii.gz -out ',subjectDir,'/T12standard -omat ',subjectDir,'/T12standard.mat ');
    system(cmd);

    % Apply registration to mask
    fprintf('Apply registration matrix to mask\n');
    cmd = horzcat('/usr/local/fsl/bin/flirt -ref /usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz -in ',maskFullFile,' -applyxfm -init ',subjectDir,'/T12standard.mat -out ',subjectDir,'/retinoMask2standard');
    system(cmd);
    
    % Binarize mask, thresholded at .2 to get rid of some noise
    fprintf('Threshold and binarize mask\n');
    cmd = horzcat('/usr/local/fsl/bin/fslmaths ',subjectDir,'/retinoMask2standard -thr .4 -bin ',subjectDir,'/retinoMask2standardBin');
    system(cmd);

end


%% Spot check

% Everything (retino data, functional data) should be in MNI space. Spot
% check that with fsleyes 

cmd = horzcat('/usr/local/fsl/bin/fsleyes ', runDir,'/scoutEPI.nii.gz ',subjectDir,'/retinoMask2standardBin.nii.gz');
system(cmd);

%% Extract V1 timeseries

funcData = MRIread(funcDataPath);
funcData = funcData.vol;

retinoMask = MRIread(horzcat(subjectDir,'/retinoMask2standardBin.nii.gz'));
ROIindex = logical(retinoMask.vol);

v1Timeseries = zeros(1,size(funcData,4));

for i = 1:size(funcData,4)
    tempVol = funcData(:,:,:,i);
    tempVolMasked = tempVol(ROIindex);
    v1Timeseries(i) = mean(tempVolMasked,'all');
end


v1Detrend = detrend(v1Timeseries);

detrendTimeseries = v1Detrend/(max(v1Detrend)-min(v1Detrend));

% Load stim params (if they're in the subjectDir)
try
    stimParams = load(fullfile(runDir,horzcat('stimDataRun',num2str(runNum),'.mat')));
catch
    warning('Stimulus data cannot be found');
    stimParams = [];
end

