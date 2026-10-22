% This function returns the known values of the NCP test fixtures in
% tests/data/ncp, so tests share one source of truth instead of repeating
% numbers. NcpFixtureTest checks that the fixture files still match these.
%
% NCP uses the same subject, model and passive data as the MTP fixtures
% (tests/data/mtp), so the shared values come from mtpFixtureValues. The
% NCP-specific data are from nmsm-tutorial/Step-5-Neural-Control-
% Personalization (see tests/data/ncp/README.md).
%
% () -> (struct)

function values = ncpFixtureValues()
mtp = mtpFixtureValues();
values.modelFileName = mtp.modelFileName;
values.coordinateNames = mtp.coordinateNames;
values.muscleNames = mtp.muscleNames;
values.maxIsometricForce = mtp.maxIsometricForce;
values.optimalFiberLength = mtp.optimalFiberLength;
values.tendonSlackLength = mtp.tendonSlackLength;
values.pennationAngle = mtp.pennationAngle;
values.activationGroups = mtp.activationGroups;
values.normalizedFiberLengthGroups = mtp.normalizedFiberLengthGroups;
values.passiveTrialNames = mtp.passiveTrialNames;

% The tutorial's single synergy group: the model ObjectGroup RightLeg,
% whose members are the nine muscles in muscleNames order.
values.synergyGroupName = "RightLeg";
values.numSynergies = 3;

% One gait trial, same time grid as the MTP fixture. The Step 5
% preprocessed data has moment arm files for the three tracked
% coordinates only.
values.trialName = "gait_1";
values.numFrames = 101;
values.timeRange = [0.5, 1.6]; % s
values.numEmgPaddingFrames = 19;

% MTP results the tutorial gives NCP (mtpResults/): activations for all
% nine muscles, and the optimized lengths and forces in the osimx file,
% in muscleNames order.
values.mtpOptimalFiberLength = [0.134594784674751, 0.113887857865955, ...
    0.0607135682355728, 0.185847676390999, 0.113442873367611, ...
    0.0828778939580505, 0.0516264346582315, 0.0721221388221615, ...
    0.101705264113667]; % m
values.mtpTendonSlackLength = [0.296035742385566, 0.128814041217666, ...
    0.420658496878076, 0.0727158252637816, 0.126900174792909, ...
    0.472389769400296, 0.300351997544367, 0.266565235069847, ...
    0.221176735486376]; % m
values.mtpMaxIsometricForce = [2794.97165154896, 971.610300962879, ...
    3845.45568913865, 3696.85050903873, 2422.42281773552, ...
    2768.47760052516, 9067.85368745026, 1980.46336304566, ...
    8331.69765725215]; % N
values.mtpActivationRange = [0, 0.592342]; % over every muscle and frame

% Synthetic known truth (tests/data/ncp/synthetic): three synergies. Each
% row of weights is one synergy over muscleNames (bflh bfsh gasmed glmax2
% iliacus recfem soleus tibant vasmed): loading response (glmax2, vasmed),
% push-off (gasmed, soleus) and swing (iliacus, recfem, tibant, bfsh).
% Each command is a bump on NCP's 26 B-spline nodes, peaking at node 5, 12
% and 20. Activations are B * commandNodes * weights, with B NCP's cubic
% B-spline matrix for 101 frames.
values.synthetic.weights = [ ...
    0.2, 0,   0,   0.6, 0,   0.1, 0.3, 0,   0.8; ...
    0,   0.1, 0.7, 0,   0.2, 0.3, 0.8, 0,   0; ...
    0.4, 0.5, 0,   0,   0.7, 0.5, 0,   0.8, 0.1];
nodes = (1 : 26)';
values.synthetic.commandNodes = 0.05 + 0.45 * exp(-((nodes - [5, 12, 20]) ...
    / 3.5) .^ 2); % (node x synergy)
values.synthetic.numNodes = 26;
end
