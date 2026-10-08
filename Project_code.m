%----------------------Distance and geometric analysis-------------------
% ---------------------PART 1----------------------------
clc 
close all
clear all

startTime = datetime("today","TimeZone","local"); 
stopTime = startTime + days(1); 
sampleTime = 60; 
sc = satelliteScenario(startTime,stopTime,sampleTime); 
Re=earthRadius; 

Table= readtable('satellite_loc_orbit.xlsx'); %reading sattelites parameter table%
semiMajorAxis = Table.altitude+Re; 
eccentricity = Table.Eccen; 
inclination = Table.Inc; 
rightAscensionOfAscendingNode =Table.RAAN; 
argumentOfPeriapsis =Table.ArgPeri; 
trueAnomaly = Table.TA;         
sattelite_num=Table.sat_number;
for i=1:height(Table)
sat (i) = satellite(sc,semiMajorAxis(i),eccentricity(i),inclination (i), ... 
    rightAscensionOfAscendingNode (i),argumentOfPeriapsis (i),trueAnomaly(i), ...
    'Name',string(sattelite_num(i))); 
end
satelliteScenarioViewer(sc,'Dimension','3D')

%% ----------------Part 2----------------------------
gs = groundStation(sc,-37.808229,144.964321,'Name','RMIT');
ac=access(sat(1,:),gs);
satelliteScenarioViewer(sc,'Dimension','3D')
intvls = accessIntervals(ac);

%% -----------------Part 3-------------------------
status=accessStatus(ac,sc.StartTime);
idxAbove_A   = find(status(:) > 0);        
namesAbove_A = arrayfun(@(x)x.Name, sat(idxAbove_A));  % arrayfun(@(x) mean(x.f1),S)
list = table(idxAbove_A, string(namesAbove_A)','VariableNames', {'Sat_Num','Sat_Name'})

%% -----------------------------Part 4---------------------------
[az,el,range]=aer(gs,sat,sc.StartTime);
az(el<0)=nan;
el(el<0)=nan;
                    
idxAbove = find(el > 0); % satellites above the local horizon %array funtion to store sat data%
namesAbove = arrayfun(@(s)s.Name, sat(idxAbove), 'UniformOutput', false);
azAbove    = mod(az(idxAbove), 360);
elAbove    = el(idxAbove);
range_km   = range(idxAbove) / 1000;

result = table(idxAbove, string(namesAbove)', azAbove, elAbove, range_km, ...
    'VariableNames', {'Sat_Num','Sat_Name','Azimuth_deg','Elevation_deg','Range_km'}); %result in table%

result = sortrows(result, 'Range_km', 'ascend') % Sorted by closest satellite %

%% ---------------------------Part 5------------------------------
figure
skyplot(az,el,sat.Name, MarkerSizeData=100 )

%% ---------------------Link performance analysis----------------------------
% -----------------------------Part 1--------------------------------------------
if isempty(result)
    warning('No satellites are above the local horizon at %s.', string(sc.StartTime));
else
    closest = result(1,:);
    fprintf('Closest satellite at %s: %s (index %d) — %.1f km (Az=%.1f°, El=%.1f°)\n', ...
        string(sc.StartTime), closest.Sat_Name, closest.Sat_Num, closest.Range_km, ...
        closest.Azimuth_deg, closest.Elevation_deg);
end

%% ------------------------Part 2------------------------------
dis= closest {1,5}*10^3		%distance from table's 1st row column 5
freq= 19.100e9;                    % freq 
fspl=20*log10(dis)+20*log10(freq)-147.55
 
P_tx=10*log10(1); %in dBW
L_tx=1.6; 		% Given parameters in the question %
L_rx=1.8; 
D_tx=0.4; 
D_rx=0.3; 
other_loss= 2.1;
G_tx=10*log10((pi*D_tx*freq/3e8)^2* 0.6) 
G_rx=10*log10((pi*D_rx*freq/3e8)^2* 0.45)
Received_Power_GS = P_tx + 30 - L_tx + G_tx - fspl- other_loss + G_rx - L_rx % in dBm

%% ----------------------------Part 3 ------------------------------------ 
k = 1.379e-23;              % Boltzman constant given 
T = 250;                    % Noise temperature given  
No = 10*log10(k*T)+ 30      % in dBm

%% ---------------------Part 4 --------------------------------------
Rb    = 24e6; % bit rate
S_No  = Received_Power_GS - No
Eb_No = S_No -10*log10(Rb)

%% ------------------------------Part 5------------------------------------
bpS     = 2;                    % bits per symbol 
M       = 2^bpS;                % QPSK  
Ber_4PSK = berawgn(Eb_No,'psk',M,'nondiff');           %ber theoritical 

M2       = 16;               % QAM
Ber_16QAM = berawgn(Eb_No,'qam',M2,'nondiff');          %ber theoritical 

list2 = table(Received_Power_GS, No,S_No,Eb_No)
list3 = table(Ber_4PSK,Ber_16QAM)

%% -----------------------PART 6---------------------
EbNo_arr= (Eb_No-5):(Eb_No+5);      % array to run loop
bpS     = 2;        % bits per symbol 
M       = 2^bpS;    %QPSK 
Ber_theo_arr_4psk = zeros(1, length(EbNo_arr)); 
Ber_theo_arr_16qam = zeros(1, length(EbNo_arr)); 
for i=1:length(EbNo_arr) 
Ber_theo_arr_4psk(i) = berawgn(EbNo_arr(i),'psk',M,'nondiff'); %ber theoritical 4psk
Ber_theo_arr_16qam(i) = berawgn(EbNo_arr(i),'qam',16,'nondiff'); %ber theoritical 16 psk
end 
figure 
semilogy(Ber_theo_arr_4psk,'X-', LineWidth=2 ) 
hold on
semilogy(Ber_theo_arr_16qam,'X-', LineWidth=2) 
grid on 
xlabel('Eb/No [db]') 
ylabel('BER') 
legend('4PSK BER',' 16QAM BER') 
title('BER Performance for Eb/No (-5+ Eb/No) dB to (+5+ Eb/No) dB')
