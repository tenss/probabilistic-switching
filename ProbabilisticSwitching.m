%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
function ProbabilisticSwitching

% SETUP
% You will need:
% - A Bpod MouseBox (or equivalent) configured with 3 ports.
% > Connect the left port in the box to Bpod Port#1.
% > Connect the center port in the box to Bpod Port#2.
% > Connect the right port in the box to Bpod Port#3.
% > Make sure the liquid calibration tables for ports 1 and 3 have 
%   calibration curves with several points surrounding 3ul.

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    
    S.GUI.RewardAmount = 3; %ul
    S.GUI.RewardProbability = 0.75;
    S.GUI.CueDelay = 0.2; % How long the mouse must poke in the center to activate the goal port
    S.GUI.ResponseTime = 5; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.PunishDelay = 0;
    
    
    S.GUI.TrainingLevel = 2; % Configurable reward condition schemes. 'BothCorrect' rewards either side.
    S.GUIMeta.TrainingLevel.Style = 'popupmenu'; % the GUIMeta field is used by the ParameterGUI plugin to customize UI objects.
    S.GUIMeta.TrainingLevel.String = {'BothCorrect', 'Task'};
        
    S.GUIPanels.Task = {'TrainingLevel', 'RewardAmount', 'RewardProbability'}; % GUIPanels organize the parameters into groups.
    S.GUIPanels.Time = {'CueDelay', 'ResponseTime','PunishDelay'};
    
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);
TotalRewardDisplay('init');

%% Define trials
MaxTrials = 5000;

TrialTypes = nan(1,MaxTrials);
TrialRewarded = nan(1,MaxTrials);

BlockLengthMin = 9;
BlockLengthMax = 23;
i=0; 
while i<MaxTrials

    %block 1 (rewarded port 1)
    aux1 = randi(BlockLengthMax-BlockLengthMin+1)+BlockLengthMin-1;
    TrialTypes(i+1:i+aux1)=1;
    i=i+aux1;
    
    %block 2 (rewarded port 3)
    aux2 = randi(BlockLengthMax-BlockLengthMin+1)+BlockLengthMin-1;
    TrialTypes(i+1:i+aux2)=2;
    i=i+aux2;
end
TrialTypes = TrialTypes(1,1:MaxTrials);

BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
BpodSystem.Data.TrialRewarded = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 300],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);


%% Main trial loop
for currentTrial = 1:MaxTrials
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
        
    
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1 % left port is rewarded 
            if rand<S.GUI.RewardProbability
                LeftActionState = 'Reward';
                TrialRewarded(currentTrial)=1;
            else
                LeftActionState = 'Unrewarded';
                TrialRewarded(currentTrial)=0;
            end
            RightActionState = 'Wrong';
            ValveTime = LeftValveTime;
            ValveState = 1;
        case 2
            if rand<S.GUI.RewardProbability
                RightActionState = 'Reward';
                TrialRewarded(currentTrial)=1;
            else
                RightActionState = 'Unrewarded';
                TrialRewarded(currentTrial)=0;
            end
            LeftActionState = 'Wrong';
            ValveTime = RightValveTime;
            ValveState = 4;
    end
    
    
    sma = NewStateMatrix(); % Assemble state matrix      
    switch S.GUI.TrainingLevel
        
        case 1

            sma = AddState(sma, 'Name', 'WaitForCenterPoke', ...
                'Timer', 0,...
                'StateChangeConditions', {'Port2In', 'CenterDelay'},...
                'OutputActions', {}); 
            sma = AddState(sma, 'Name', 'CenterDelay', ...
                'Timer', S.GUI.CueDelay,...
                'StateChangeConditions', {'Port2Out', 'WaitForCenterPoke', 'Tup', 'WaitForCenterOut'},...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'WaitForCenterOut', ...
                'Timer', 0,...
                'StateChangeConditions', {'Port2Out', 'Reward'},...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'Reward', ...
                'Timer', ValveTime,...
                'StateChangeConditions', {'Tup', 'WaitForResponse'},...
                'OutputActions', {'ValveState', ValveState});             
            sma = AddState(sma, 'Name', 'WaitForResponse', ...
                'Timer', S.GUI.ResponseTime,...
                'StateChangeConditions', {'Port1In', 'Drinking', 'Port3In', 'Drinking', 'Tup', 'exit'},...
                'OutputActions', {}); 
            sma = AddState(sma, 'Name', 'Drinking', ...
                'Timer', 0,...
                'StateChangeConditions', {'Port1Out', 'exit', 'Port3Out', 'exit'},...
                'OutputActions', {});
            
        case 2
            sma = AddState(sma, 'Name', 'WaitForCenterPoke', ...
                'Timer', 0,...
                'StateChangeConditions', {'Port2In', 'CenterDelay'},...
                'OutputActions', {}); 
            sma = AddState(sma, 'Name', 'CenterDelay', ...
                'Timer', S.GUI.CueDelay,...
                'StateChangeConditions', {'Port2Out', 'WaitForCenterPoke', 'Tup', 'WaitForCenterOut'},...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'WaitForCenterOut', ...
                'Timer', 0,...
                'StateChangeConditions', {'Port2Out', 'WaitForResponse'},...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'WaitForResponse', ...
                'Timer', S.GUI.ResponseTime,...
                'StateChangeConditions', {'Port1In', LeftActionState, 'Port3In', RightActionState, 'Tup', 'exit'},...
                'OutputActions', {}); 
            sma = AddState(sma, 'Name', 'Reward', ...
                'Timer', ValveTime,...
                'StateChangeConditions', {'Tup', 'Drinking'},...
                'OutputActions', {'ValveState', ValveState}); 
            sma = AddState(sma, 'Name', 'Unrewarded', ...
                'Timer', 0,...
                'StateChangeConditions', {'Tup', 'exit'},...
                'OutputActions',{}); 
            sma = AddState(sma, 'Name', 'Drinking', ...
                'Timer', 0,...
                'StateChangeConditions', {'Port1Out', 'exit', 'Port3Out', 'exit'},...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'Wrong', ...
                'Timer', S.GUI.PunishDelay,...
                'StateChangeConditions', {'Tup', 'exit'},...
                'OutputActions', {});
    
    end
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        BpodSystem.Data.TrialRewarded(currentTrial) = TrialRewarded(currentTrial); % Adds the trial type of the current trial to data
        
        %Outcome
        switch S.GUI.TrainingLevel
        
            case 1
                
                if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Drinking(1))
                    BpodSystem.Data.Outcomes(currentTrial) = 1;
                elseif ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Wrong(1))
                    BpodSystem.Data.Outcomes(currentTrial) = 0;
                elseif ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Unrewarded(1))
                    BpodSystem.Data.Outcomes(currentTrial) = 2;
                else
                    BpodSystem.Data.Outcomes(currentTrial) = 3;
                end

            case 2
                
                if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Drinking(1))
                    BpodSystem.Data.Outcomes(currentTrial) = 1;
                else
                    BpodSystem.Data.Outcomes(currentTrial) = 3;
                end
        end
        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial);
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end
end

function UpdateSideOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Drinking(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Wrong(1))
        Outcomes(x) = 0;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Unrewarded(1))
        Outcomes(x) = 2;
    else
        Outcomes(x) = 3;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes);

function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
    if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
        TotalRewardDisplay('add', RewardAmount);
    end
