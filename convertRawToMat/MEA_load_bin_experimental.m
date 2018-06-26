function [header,m,channels] = MEA_load_bin_experimental(binfile,plt)
% THIS IS AN EXPERIMENTAL FORK 
% There is some change this will not work (or worse, output wrong values)
% if the recording duration is not exactly 720 seconds
% This function truly reads the .raw file one channel at a time, which aims
% to reduce the amount of memory required

% note that I (TS) is going to modify this slightly to make it work with
% any number of channels 
% also changed the code so that it saves one giant variable 
% rather than create a subfolder 
% also makes running combineMat.m unncessary 

%form: 
%This function takes txt file output from MC_Datatool (Multichannel
%Systems) and converts it into a matlab matrix.
%

% Instructions 

% Do not run this directly, this is called by MEAbatchConvert.m 
% But a lot of the key steps of the conversion processes are contained here
% The main thing to change is 'convertOption', which you should specify in
% MEAbatchConvert.m, the default is to do 'whole'; the entire grid will be
% saved in one variable 
% the other option is to do electrode by electrode conversion, in which
% case convertOption == 'electrode'

% Last update: 20180626 

% Log
% 20180626: Added option to save each electrode as an individual .mat file 
% (to avoid memory issues on systems with less than 16GB ram / low swap space)


%% initialize

sprintf('MEA_load_bin')

if ~exist('plt','var')
    plt=0;
end;

if ~exist('convertOption', 'var')
    convertOption = 'whole'; 
end 



%% get header
[fid] =fopen(binfile)
[filename, permission, machineformat, encoding] =fopen(fid);
[m,count]=fread(fid,2000,'*char',0,machineformat);
fclose(fid);

%% get key values from header

m=m';
f=findstr(m,'EOH');
newstart=f+4;
header=m(1:f-1)

ADCzerof=findstr(m,'ADC');
ADCz = str2num(m(ADCzerof+11:ADCzerof+16));

fsf=findstr(m,'Sample rate');
fs=str2num(m(fsf+14:fsf+18));

uVf=findstr(m,'�V/AD');
uV = str2num(m(uVf-7:uVf-1));


%% get channels from header

chf=findstr(header,'Streams');
chs = header(chf+11:length(header))
channels=[];
while length(chs)>5
    f=findstr(chs,'_');
    channels=[channels; str2num(chs(f(1)+1:f(1)+2))];
    chs(1:f(1)+2)=[];
end;
channels;
size(channels)

%% get data size and from that, **estimate** the duration of recording

% currently, the estimation works for 720 seconds, but I am not sure if it
% will work for other recording duration, so this is the section that may
% break the code 
[fid] =fopen(binfile);
dataLength = get_file_length(fid);
fclose(fid);

recordDuration = dataLength / length(channels);
% I have no idea why I have to divide by 2... but somehow it works
% probably something to do with the coding of binary values... but I am not
% quite sure...
recordDuration = round(recordDuration / 2, -1); % round to nearest 10^1


%% get data
mkdir(binfile(1:length(binfile)-4))
% start looping through channels here
[fid] =fopen(binfile);
[trash, readCount]=fread(fid,newstart,'*char',0,machineformat);

for i=1:length(channels)
% this (aims to) read the binary file channel by channel


[data, readCount]=fread(fid, recordDuration,'int16',0,machineformat);%change to uint16 for data from older versions of MC_tool


% directly assign channel to m, no need to reshape 
m = data;

%% reshape data

%each row is a different channel
% numChannels = length(channels); 
% m=reshape(data,numChannels,floor(length(data)/numChannels));
% note that I (TS) chaged '60' to numChannels 
% not sure if there will be any consequences... 
% need to check through the logic of this code to make sure


%% convert data to microvolts (see MC_datatool help - search 'binary')
max(m(:));
min(m(:));
% 
m=m-ADCz;
m=m*uV;
dat = m'; % matlab reads tall matrices more efficiently
% tall means number of rows > number of columns
%% plot

% if plt
%     ch=82;
%     figure
%     t=1:size(m,2);
%     t=t/fs;
%     size(m)
%     f=find(channels==ch)
%     plot(t,m(f(1),:),'k')
% end;

%% save
% sprintf('Saving data ...')

% /mkdir(binfile(1:length(binfile)-4))
% the crux to not having folders is here 
% save([binfile(1:length(binfile)-4) filesep binfile(1:length(binfile)-4) '.mat'],'dat','channels','header','uV','ADCz','fs')
% the above line saves to specific subfolders 

% OPTION 1: Save all electrodes as a single file (about 2GB variable), only a good idea if your system has 16GB ram / a lot of swap space
% if strcmp(convertOption, 'whole')
%     save([binfile(1:length(binfile)-4) '.mat'],'dat','channels','header','uV','ADCz','fs', '-v7.3')
% % OPTION 2: For systems with 8GB ram (or less?), save each electrode in a separate file 
% elseif strcmp(convertOption, 'electrode')
%     mkdir(binfile(1:length(binfile)-4))
%     for i=1:length(channels)
%          sprintf('Channel: %d; ',channels(i))
%          dat=m(i,:);
%          save([binfile(1:length(binfile)-4) filesep binfile(1:length(binfile)-4) '_' num2str(channels(i)) '.mat'],'dat','channels','header','uV','ADCz','fs')
%     end 
%     
% end 
dat = m; 
sprintf('Channel: %d; ',channels(i))
save([binfile(1:length(binfile)-4) filesep binfile(1:length(binfile)-4) '_' num2str(channels(i)) '.mat'],'dat','channels','header','uV','ADCz','fs')
end % end looping of all channels 

% close file 
fclose(fid);

end

