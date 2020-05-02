function [psiParamsFit]=doeSimulate(Sr_m, k1_m, k2_m, beta_m, sigma_m, TR, trialLength, qpPres, outNum)
%% A simulation script to be compiled and run at speed for the DOE temporal model
%
% Syntax:
%  [psiParamsFit]=validate_qpDoETFE_simulate(Sr_m, k1_m, k2_m, beta_m, sigma_m, TR, trialLength, qpPres, outNum)
%
% Description:
%	Takes in simulated parameters for the model, the control (TR, trial
%	length), and whether or not Q+ is in control of things, plus a debug
%	flag. 
%
% Inputs:
%   Sr_m           - 
%   k1_m           -
%   k2_m           -
%   beta_m         -
%   sigma_m        -
%   TR             -
%   trialLength    -
%   qpPres         - Logical. 1 for Q+, 0 for random.
%   outNum         - String. Label for the output CSV file
% 
% Outputs:
%   psiParamsFit   - 1x5 vector. The results of the BADS fit for the best
%                    fitting model parameters.
%
% Example: 
%{
[psiParamsFit] = doeSimulate('1.05', '.01', '.06', '1.00', '.4','800','12','1','false1');

%}
% 
% We'll need to do some sanity checking our input. For now, we can handle
% things this way: 
model_params = [str2num(Sr_m) str2num(k1_m) str2num(k2_m) str2num(beta_m) str2num(sigma_m)]; 

trialLength = str2num(trialLength);
TR = str2num(TR);

%% Are we simulating old fashioned constant stimuli?
assert(islogical(str2num(qpPres)),'Need to say whether Q+ is being used or not (make sure qpPres is logical.');
simulateConstantStimuli = logical(str2num(qpPres)); 


%% Model general values
simulatedPsiParams = model_params;

% Some information about the trials?
nTrials = 30; % how many trials
trialLengthSecs = trialLength; % seconds per trial (12)
stimulusStructDeltaT = 100; % the resolution of the stimulus struct in msecs

% True size of the BOLD response
maxBOLDSimulated = 1.6;

% Initial guess for the max size of the evoked BOLD response
maxBOLD = 1.0;

% Which stimulus (in freq Hz) is the "baseline" stimulus? This stimulus
% should be selected with the expectation that the neural response to this
% stimulus will be minimal as compared to all other stimuli.
baselineStimulus = 0;



%% Model specific values
% Get the default Q+ params
myQpParams = qpParams;

% Add the stimulus domain. ~Log spaced frequencies between 0 and 30 Hz
myQpParams.stimParamsDomainList = {[baselineStimulus,1.875,3.75,7.5,15,30,60]};
nStims = length(myQpParams.stimParamsDomainList{1});

% The number of outcome categories.
myQpParams.nOutcomes = 51;

% The headroom is the proportion of outcomes that are reserved above and
% below the min and max output of the DoE model to account for noise
headroom = 0.1;

% Create an anonymous function from qpDoETemporalModel in which we
% specify the number of outcomes for the y-axis response
myQpParams.qpPF = @(f,p) qpDoETemporalModel(f,p,myQpParams.nOutcomes,headroom);
Sr = 0.899:0.025:1.099;
k1 = 0.001:0.0005:0.01;
k2 = 0.001:0.01:.2;
beta = 0.4:0.2:2; % Amplitude of the scaled response; should converge to unity
sigma = 0.3:0.2:1;	% Standard deviation of the scaled (0-1) noise

% Beta will converge to 1 as maxBOLD gets closer and closer to the
% simulated maxBOLD. As a result, when simulating data, beta should always
% be set to 1. And, Q+ should always be able to incorporate 1 in its
% domain. Assert these conditions are true. 
assert(simulatedPsiParams(4)==1,'Simulated Beta should always be 1.');
assert(ismember(1,beta),'The domain for beta should always include 1.');


myQpParams.psiParamsDomainList = {Sr, k1, k2, beta, sigma};

% Pick some random params to simulate if none provided (but set the neural
% noise to zero)
if isempty(simulatedPsiParams)
    simulatedPsiParams = [randsample(Sr,1) randsample(k1,1) randsample(k2,1) randsample(beta,1) 0];
end

% Derive some lower and upper bounds from the parameter ranges. This is
% used later in maximum likelihood fitting
lowerBounds = [Sr(1) k1(1) k2(1) beta(1) sigma(1)];
upperBounds = [Sr(end) k1(end) k2(end) beta(end) sigma(end)];

% Create a simulated observer with binned output
myQpParams.qpOutcomeF = @(f) qpSimulatedObserver(f,myQpParams.qpPF,simulatedPsiParams);

% Initialize Q+
questData = qpInitialize(myQpParams);

% Tack on a continuous output simulated observer to myQpParams
myQpParams.continuousPF = @(f) doeTemporalModel(f,simulatedPsiParams);


% Create a full length packet
thePacket = createPacket('nTrials',nTrials,...,
    'trialLengthSecs',trialLengthSecs,...,
    'stimulusStructDeltaT',stimulusStructDeltaT);
 
% Create and save an rng seed to use for this simulation
rngSeed = rng();

% Create a copy of Q+
questDataUntrained = questData;

% Create a stimulusVec to hold the trial across the loops
stimulusVec = nan(1,nTrials);

%% Run simulated trials
for tt = 1:nTrials
    
    % Ask QP to supply our next stimulus. If it is the first two trials
    % we force a baseline event
    if tt<=2
        stimulusVec(tt) = baselineStimulus;
        fprintf('Initial baseline stimulus: %f',stimulusVec(tt));
    else
        if simulateConstantStimuli
            % get random stimulus
            stimulusVec(tt) = questData.stimParamsDomain(randi(questData.nStimParamsDomain));
            fprintf('Stimuli chosen randomly: %f',stimulusVec(tt));
        else
            % get next stimulus from Q+
            stimulusVec(tt) = qpQuery(questData);
            fprintf('Stimuli chosen by Q+: %f',stimulusVec(tt));
        end
    end
    
    % Update maxBOLD with our best guess at the maximum BOLD fMRI response
    % that could be evoked by a stimulus (relative to the baseline
    % stimulus), which is the beta value of the model
    try % Try fitting with BADS
        psiParamsFit = qpFitBads(questData.trialData,questData.qpPF,psiParamsQuest,questData.nOutcomes,...
    'lowerBounds', lowerBounds,'upperBounds',upperBounds,...
    'plausibleLowerBounds',lowerBounds,'plausibleUpperBounds',upperBounds)
        maxBOLD = maxBOLD.*psiParamsFit(4)
        fprintf('Using the BADS fit to generate maxBOLD.\n');
    catch e% If not, fit with the best fitting parameters from Q+ 
        psiParamsIndex = qpListMaxArg(questData.posterior);
        psiParamsQuest = questData.psiParamsDomain(psiParamsIndex,:)
        maxBOLD = maxBOLD.*psiParamsQuest(4)
        fprintf('Using the Q+ fit to generate maxBOLD.\n');
        fprintf('qpFitBads did not execute with the following error: \n%s',e.message);
        fprintf('%s',e.stack.file);
        fprintf('%s',e.stack.name);
        fprintf('%s',e.stack.line);
    end
    
    % Create a packet
    thePacket = createPacket('nTrials',tt,...,
        'trialLengthSecs',trialLengthSecs,...,
        'stimulusStructDeltaT',stimulusStructDeltaT);

    % Obtain outcomes from tfeUpdate 
    [outcomes] = ...
        tfeUpdate(thePacket, myQpParams, stimulusVec, baselineStimulus, ...
        'maxBOLDSimulated',maxBOLDSimulated,...
        'rngSeed',rngSeed,...,
        'maxBOLD',maxBOLD,...,
        'TRmsecs', TR);
   
    % Grab a naive copy of questData
    questData = questDataUntrained;

    % Update quest data structure. This is the slow step in the simulation.
    for yy = 1:tt
        questData = qpUpdate(questData,stimulusVec(yy),outcomes(yy));
    end
       
    
end

%% Find out QUEST+'s estimate of the stimulus parameters, obtained
% on the gridded parameter domain.
psiParamsIndex = qpListMaxArg(questData.posterior);
psiParamsQuest = questData.psiParamsDomain(psiParamsIndex,:);
fprintf('Simulated parameters:              %0.3f, %0.3f, %0.3f, %0.3f, %0.3f \n', ...
    simulatedPsiParams(1),simulatedPsiParams(2),simulatedPsiParams(3),simulatedPsiParams(4),simulatedPsiParams(5));
fprintf('Max posterior QUEST+ parameters:   %0.3f, %0.3f, %0.3f, %0.3f, %0.3f \n', ...
    psiParamsQuest(1),psiParamsQuest(2),psiParamsQuest(3),psiParamsQuest(4),psiParamsQuest(5));

%% Find maximum likelihood fit. Use psiParams from QUEST+ as the starting
% parameter for the search, and impose as parameter bounds the range
% provided to QUEST+.
psiParamsFit = qpFitBads(questData.trialData,questData.qpPF,psiParamsQuest,questData.nOutcomes,...
    'lowerBounds', lowerBounds,'upperBounds',upperBounds,...
    'plausibleLowerBounds',lowerBounds,'plausibleUpperBounds',upperBounds);

outfilename = horzcat('doe_',outNum,'.csv');
%save(outfilename,psiParamsFit);
csvwrite(outfilename, psiParamsFit);

fprintf('Maximum likelihood fit parameters: %0.3f, %0.3f, %0.3f, %0.3f, %0.3f \n', ...
    psiParamsFit(1),psiParamsFit(2),psiParamsFit(3),psiParamsFit(4),psiParamsFit(5));

end
