% This function returns the known values of the Treatment Optimization
% test fixtures in tests/data/to, so tests share one source of truth
% instead of repeating numbers. TreatmentOptimizationFixtureTest checks that
% the fixture files still match these.
%
% The fixtures are the nmsm-tutorial kick problems: Step 6 (torque driven,
% tests/data/to/torque) and Step 8 (synergy driven, tests/data/to/synergy),
% which share their IK and ID data (tests/data/to/preprocessed). See
% tests/data/to/README.md.
%
% () -> (struct)

function values = toFixtureValues()
values.trialName = "drive_kick1";
values.modelFileName = "KickingModel.osim";
values.numFrames = 63;
values.timeRange = [0, 0.31]; % s, 200 Hz
values.numIkCoordinates = 41;
values.numIdLoads = 41;
% The coordinates both tutorial problems optimize (GPOPS states), each also
% torque controlled in the torque problem.
values.statesCoordinates = ["hip_flexion_r", "knee_angle_r", ...
    "ankle_angle_r"];
values.loads = values.statesCoordinates + "_moment";

% Torque problem (tutorial Step 6). The model has 86 muscles, which
% Treatment Optimization disables for a torque-driven run.
values.torque.numModelMuscles = 86;
% Published results used as starting points: Verification starts from
% TorqueTOResultsV1 and Design from TorqueVOResultsV2. Both solved on
% 25 intervals x 4 collocation points.
values.torque.publishedFrames = 101;

% Synergy problem (tutorial Step 8). The model has only the nine right-leg
% muscles, in this order, which is also the order of synergyWeights.sto.
values.synergy.muscleNames = ["bflh_r", "bfsh_r", "gasmed_r", ...
    "glmax2_r", "iliacus_r", "recfem_r", "soleus_r", "tibant_r", ...
    "vasmed_r"];
values.synergy.synergyGroup = "RightLeg";
values.synergy.numSynergies = 4;
values.synergy.surrogateCoordinates = ["hip_flexion_r", ...
    "hip_adduction_r", "hip_rotation_r", "knee_angle_r", ...
    "ankle_angle_r", "subtalar_angle_r"];
values.synergy.surrogateSamplesPerFrame = 25;
% SynergyTOResultsV1 and SynergyVOResultsV2: 1 interval x 50 points.
values.synergy.publishedFrames = 51;
end
