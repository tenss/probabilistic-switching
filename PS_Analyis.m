TrialTypes = SessionData.TrialTypes-1; %0: rewarded port 1, %1: rewarded port 3
nTrial=size(TrialTypes,2);

%Outcome: Drinking 1; Wrong 0, Unrewarded 2, Else 3 
Outcomes = SessionData.Outcomes;

Side = nan(1,nTrial); %0:left, 1:right
Side(Outcomes==1 | Outcomes==2)=TrialTypes(Outcomes==1 | Outcomes==2);
Side(Outcomes==0) = ~TrialTypes(Outcomes==0);

% Fraction left vs distance to switch

FirstBlockChange = [0 diff(TrialTypes)];
ind_FirstBlockChange= find(FirstBlockChange);
t_p=2;t_f=2;
if nTrial-ind_FirstBlockChange(end)<t_f;
    Side=[Side nan(1,nTrial-ind_FirstBlockChange(end)<t_f)];
end

for i=-t_p:+t_f
    p(i+t_p+1) = nanmean(Side(find(FirstBlockChange)+i));
end

