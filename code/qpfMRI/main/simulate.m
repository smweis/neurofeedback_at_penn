function [modelResponseStruct,thePacketOut,questData]=simulate(model_type, model_params, control_params, sim_type)
% model_type     -          string
%
% model_params   -          1x5 vector of model parameters:
%                             Sr - ratio of the scale factors of the 
%                                  exponentials
%                             k1, k2 - time constants of the exponentials
%                             beta - maximum amplitude of the response
%                             sigma - Standard deviation of the scaled (0-1) noise
%
% control_params -         1x2 vector of control parameters:
%                             TRmsecs - Scalar. The TR of the BOLD fMRI measurement in 
%                                        msecs. Needed in simulation mode to know how
%                                        much to downsample the simulated signal. 
%                             trialLengthSecs - seconds per trial
%
% sim_type       -         boolean:
%                           true - run simulation without Q+ stimulus presentation
%                           false - run simulation with Q+ stimulus presentation
%
% Example with plotting: 
% model_type='doe';model_params=[0.9998 0.0132 0.7755 1 0];control_params=[800 12];sim_type='false';
% [modelResponseStruct,thePacketOut,questDataFalse]=simulate(model_type, model_params, control_params, sim_type)
%
% model_type='doe';model_params=[0.9998 0.0132 0.7755 1 0];control_params=[800 12];sim_type='true';
% [modelResponseStruct,thePacketOut,questDataTrue]=simulate(model_type, model_params, control_params, sim_type)
% 
% 
% figure; plot(questDataFalse.entropyAfterTrial); hold on; plot(questDataTrue.entropyAfterTrial); legend('random','quest+');
% figure; plot([questDataFalse.trialData.stim],'.'); hold on; plot([questDataTrue.trialData.stim],'.'); legend('random','quest+');
% 
%
%

% Example arguments: 
%       model_type='doe';model_params=[0.9998 0.0132 0.7755 1 0];control_params=[800 12];sim_type='true';


    if strcmp(model_type, 'doe')
        [modelResponseStruct,thePacketOut,questData]=validate_qpDoETFE_simulate(model_params, control_params, sim_type);
    elseif strcmp(model_type, 'wt')
        [modelResponseStruct,thePacketOut,questData]=validate_qpWatsonTFE_simulate(model_params);
    else
        disp('Invalid model')
    end

end

