function predictedProportions = qpWatsonTemporalModel(frequency, params)
% Express the returned value from the Watson model as amplitude proportions
%
% Syntax:
%  predictedProportions = watsonToProportions(nCategories)
%
% Description:
%	Given a number of categories, the parameters of a Watson temporal model
%
%
% Examples:
%{
    figure; hold on;
    i = 0;
    bins = 5;
    colorm = rand(bins,3);
    for freq = 0:0.1:64
        i = i + 1;
        predictedProportions = watsonToProportions(freq, [0 64], bins, [0.004 2 1 1]);
        maxProbabilityMiss(i) = abs(sum(predictedProportions)) - 1;
       

        for j = 1:bins
            semilogx(freq,predictedProportions(j),'.','color',colorm(j,:));
        end
    end
    max(maxProbabilityMiss)
%}


freqRange=[0 64];
nCategories=21;

% Obtain the Watson model for these params across the frequency range at a
% high resolution

%defaults

freqSupport = freqRange(1):0.01:freqRange(2);
y = watsonTemporalModel(freqSupport, params);

% Where is the passed frequency value in frequence support
predictedProportions = zeros(length(frequency),nCategories);

for jj = 1:length(frequency)
    [~,freqIdxInSupport] = min(abs(freqSupport-frequency(jj)));

% Scale the Watson model to have unit amplitude
    y = y - min(y);
    if max(y) ~= 0
        y = y ./ max(y);
    end
% Loop over the categories and report the proportion value for the
% specified frequency in each amplitude category
    catBinSize = 1 / nCategories;
    for ii = 1:nCategories
    
        categoryCenter = (ii-1)*catBinSize + catBinSize/2;
        distFromCatCenter = y(freqIdxInSupport) - categoryCenter;
        if ii == 1
            if distFromCatCenter < 0 
                predictedProportions(jj,ii) = 1;
            else
                predictedProportions(jj,ii) = (1 - abs(distFromCatCenter)/catBinSize); 
            end
        elseif ii == nCategories
            if distFromCatCenter > 0
                predictedProportions(jj,ii) = 1;
            else
                predictedProportions(jj,ii) = (1 - abs(distFromCatCenter)/catBinSize);
            end
        else
            predictedProportions(jj,ii) = (1 - abs(distFromCatCenter)/catBinSize);
        end
    
    end
end


predictedProportions(predictedProportions<0)=0;

end

