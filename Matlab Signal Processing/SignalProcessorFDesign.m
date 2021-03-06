clear variables
close all

%% Configuration Details
fileNum = 2;      %2-5
numSecondsBeginning = 5; %Number of seconds to eliminate from beginning of signal
numSecondsEnd = 5;       %Number of seconds to eliminate from end of signal
cutoffFreq = 5;          %Highest Frequency to display (Hz)
fPassResp = .2;          %Beginning of passband for respiration rate (Hz)
fStopResp = .9;          %End of passpand for respiration rate (Hz)
fPassHeart = 1;          %Beginning of passband for heart rate (Hz)
fStopHeart = 2;          %End of passband for heart rate (Hz)
combWidth = .05;         %width of band to cancel in comb filter
numHarmonics = 5;        %number of harmonics to cancel in comb filter

%% Read in raw data and save as time, I, and Q channels
fileName = ['tek000' num2str(fileNum) 'ALL.csv'];
rawData = csvread(fileName,21);
t = rawData(:,1);
iChannel = rawData(:,3);
qChannel = rawData(:,4);
combinedSignals = iChannel + 1j.*qChannel;
Fs = 1/(t(2) - t(1));   %Sampling Frequency
L = length(iChannel);   %Length of signals
NFFT = 2^nextpow2(L);   %Length of FFT

%% Eliminate numSecondsBeginning of bad data at beginning
numSamplesBeginning = round(numSecondsBeginning*Fs);
t(1:numSamplesBeginning) = [];
iChannel(1:numSamplesBeginning) = [];
qChannel(1:numSamplesBeginning) = [];
combinedSignals(1:numSamplesBeginning) = [];

%% Eliminate numSecondsEnd of bad data at end
numSamplesEnd = round(numSecondsEnd*Fs);
t(end:-1:(end-numSamplesEnd)) = [];
iChannel(end:-1:(end-numSamplesEnd)) = [];
qChannel(end:-1:(end-numSamplesEnd)) = [];
combinedSignals(end:-1:(end-numSamplesEnd)) = [];

%% Take one sided FFT
fftI = fft(iChannel,NFFT)/L;                %FFT of I channel
fftQ = fft(qChannel,NFFT)/L;                %FFT of Q channel
fftCombined = fft(combinedSignals,NFFT)/L;  %FFT of Q channel
f = Fs/2*linspace(0,1,NFFT/2+1);            %Frequency Range
oneSidedIDFT = 2*abs(fftI(1:NFFT/2+1));
oneSidedQDFT = 2*abs(fftQ(1:NFFT/2+1));
oneSidedCombinedDFT = 2*abs(fftCombined(1:NFFT/2+1));

%% Only display frequencies greater than the cutoff frequency
maskCutoff = f>cutoffFreq;
f(maskCutoff) = [];
oneSidedIDFT(maskCutoff) = [];
oneSidedQDFT(maskCutoff) = [];
oneSidedCombinedDFT(maskCutoff) = [];

fNorm = Fs/2;
respBandpassDesign = fdesign.bandpass('N,F3dB1,F3dB2',...
    2,.1/fNorm, .9/fNorm);
respBandpass = design(respBandpassDesign);
iChannelResp = filter(respBandpass,iChannel);

%% Determine Respiration Rate
[maxIResp , iRespLoc] = max(iChannelRespDFT);
[maxQResp , qRespLoc] = max(qChannelRespDFT);
[maxCombinedResp , combinedRespLoc] = max(combinedRespDFT);

respirationRate = f(combinedRespLoc);
respChoice = 'Combined Channel';

if(maxIResp > maxQResp && maxIResp > maxCombinedResp)
    respirationRate = f(iRespLoc);
    respChoice = 'I channel';
end
if(maxQResp > maxIResp && maxQResp > maxCombinedResp)
    respirationRate = f(qRespLoc);
    respChoice = 'Q channel';
end

%% Bandpass filter for heart rate
heartMask = f>fPassHeart & f<fStopHeart;
iChannelHeartDFT = oneSidedIDFT;
qChannelHeartDFT = oneSidedQDFT;
combinedHeartDFT = oneSidedQDFT;
iChannelHeartDFT(~heartMask) = 0;
qChannelHeartDFT(~heartMask) = 0;
combinedHeartDFT(~heartMask) = 0;

%% Comb filter to eliminate respiration Harmonics
for n = 1:numHarmonics
    combMask = (f < (n*respirationRate + combWidth)) & ...
               (f > (n*respirationRate - combWidth));
    iChannelHeartDFT(combMask) = 0;
    qChannelHeartDFT(combMask) = 0;
    combinedHeartDFT(combMask) = 0;
end

%% Determine Heart Rate
[maxIHeart , iHeartLoc] = max(iChannelHeartDFT);
[maxQHeart , qHeartLoc] = max(qChannelHeartDFT);
[maxCombinedHeart , combinedHeartLoc] = max(combinedHeartDFT);

heartRate = f(combinedHeartLoc);
heartChoice = 'Combined Channel';

if(maxIHeart > maxQHeart && maxIHeart > maxCombinedHeart)
    heartRate = f(iHeartLoc);
    heartChoice = 'I channel';
end
if(maxQHeart > maxIHeart && maxQHeart > maxCombinedHeart)
    heartRate = f(qHeartLoc);
    heartChoice = 'Q channel';
end
if(maxCombinedHeart > maxIHeart && maxCombinedHeart > maxQHeart)
    heartRate = f(combinedHeartLoc);
    heartChoice = 'Combined channels';
end

%% Plot I and Q
figure
subplot(3,1,1)
plot(t,iChannel)
xlabel('Time (s)')
ylabel('|i(t)|')
title('I Channel in Time Domain')
subplot(3,1,2)
plot(t,qChannel)
xlabel('Time (s)')
ylabel('|q(t)|')
title('Q Channel in Time Domain')
subplot(3,1,3)
plot(t,abs(combinedSignals))
xlabel('Time (s)')
ylabel('|c(t)|')
title('Combined Signals in Time Domain')

figure
subplot(3,1,1)
plot(f,oneSidedIDFT) 
title('Single-Sided Amplitude Spectrum of I channel FFT')
xlabel('Frequency (Hz)')
ylabel('|I(f)|')
subplot(3,1,2)
plot(f,oneSidedQDFT) 
title('Single-Sided Amplitude Spectrum of Q channel FFT')
xlabel('Frequency (Hz)')
ylabel('|Q(f)|')
subplot(3,1,3)
plot(f,oneSidedCombinedDFT) 
title('Single-Sided Amplitude Spectrum of Combined channels FFT')
xlabel('Frequency (Hz)')
ylabel('|C(f)|')

figure
subplot(3,1,1)
plot(f,iChannelRespDFT) 
title('I Channel Bandpass for Respiration Rate')
xlabel('Frequency (Hz)')
ylabel('|I(f)|')
subplot(3,1,2)
plot(f,qChannelRespDFT) 
title('Q Channel Bandpass for Respiration Rate')
xlabel('Frequency (Hz)')
ylabel('|Q(f)|')
subplot(3,1,3)
plot(f,combinedRespDFT) 
title('Combined Channels Bandpass for Respiration Rate')
xlabel('Frequency (Hz)')
ylabel('|C(f)|')

figure
subplot(3,1,1)
plot(f,iChannelHeartDFT) 
title('I Channel Bandpass for Heart Rate')
xlabel('Frequency (Hz)')
ylabel('|I(f)|')
subplot(3,1,2)
plot(f,qChannelHeartDFT) 
title('Q Channel Bandpass for Heart Rate')
xlabel('Frequency (Hz)')
ylabel('|Q(f)|')
subplot(3,1,3)
plot(f,combinedHeartDFT) 
title('Combined Channels Bandpass for Heart Rate')
xlabel('Frequency (Hz)')
ylabel('|C(f)|')

%% Print out heart and respiration rates
endMessage1 = ['Heart Rate is ' num2str(heartRate) ...
    ' beats per second using the ' heartChoice];
endMessage2 = ['Respiration Rate is ' num2str(respirationRate) ...
    ' breaths per second using the ' respChoice];
disp(endMessage1);
disp(endMessage2);

