
TrialTypes = SessionData.TrialTypes-1; %0: rewarded port 1, %1: rewarded port 3
nTrial=size(TrialTypes,2);

%Outcome: Drinking 1; Wrong 0, Unrewarded 2, Else 3 
Outcomes = SessionData.Outcomes;

Side = nan(1,nTrial); %0:left, 1:right
Side(Outcomes==1 | Outcomes==2)=TrialTypes(Outcomes==1 | Outcomes==2);
Side(Outcomes==0) = ~TrialTypes(Outcomes==0);

% Fraction left vs distance to left right switch
FirstBlockChange = [0 diff(TrialTypes)];

ind_LR_BlockChange= find(FirstBlockChange==-1);
ind_RL_BlockChange= find(FirstBlockChange==1);

t_p=9;t_f=9;
if nTrial-ind_LR_BlockChange(end)<t_f
    Side=[Side nan(1,nTrial-ind_LR_BlockChange(end)+1)];
end
if nTrial-ind_RL_BlockChange(end)<t_f
    Side=[Side nan(1,nTrial-ind_RL_BlockChange(end)+1)];
end

pLR=nan(1,t_p+t_f+1);%fraction of right
pRL=nan(1,t_p+t_f+1);%fraction of right
for i=-t_p:+t_f
    pLR(i+t_p+1) = nanmean(Side(ind_LR_BlockChange+i));
    pRL(i+t_p+1) = nanmean(Side(ind_RL_BlockChange+i));
end

figure
plot(-t_p:t_f,1-pLR);hold on
plot(-t_p:t_f,1-pRL)
ylabel('fraction of left')
legend('L-R','R-L'); legend boxoff