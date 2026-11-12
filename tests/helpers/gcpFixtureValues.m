% This function returns the known values of the GCP test fixtures in
% tests/data/gcp, so tests share one source of truth instead of repeating
% numbers. GcpFixtureTest checks that the fixture files still match these.
%
% The fixtures are the nmsm-tutorial Step 2 (Ground Contact
% Personalization) problem; see tests/data/gcp/README.md. The IK file is
% byte-identical to the MTP fixture's and is copied from tests/data/mtp.
%
% () -> (struct)

function values = gcpFixtureValues()
values.modelFileName = "bodyModel.osim";
values.trialName = "gait_1";
values.numFrames = 101;
values.timeRange = [0.5, 1.6]; % s, IK and GRF

% The right foot, modeled by the tutorial: a two-segment foot (calcn_r and
% toes_r, joined by the pin joint mtp_r) on force plate 2.
values.hindfootBody = "calcn_r";
values.toesBody = "toes_r";
values.toesJoint = "mtp_r";
values.toesCoordinate = "mtp_angle_r";
values.markers = struct("toe", "R_Toe", "medial", "R_Toe_Medial", ...
    "lateral", "R_Toe_Lateral", "heel", "R_Heel", ...
    "midfootSuperior", "R_Midfoot_Superior");
values.markerBodies = struct("toe", "toes_r", "medial", "calcn_r", ...
    "lateral", "calcn_r", "heel", "calcn_r", "midfootSuperior", "calcn_r");
values.forceColumns = ["ground_force_2_vx", "ground_force_2_vy", ...
    "ground_force_2_vz"];
values.momentColumns = ["ground_moment_2_mx", "ground_moment_2_my", ...
    "ground_moment_2_mz"];
values.electricalCenterColumns = ["ground_force_2_px", ...
    "ground_force_2_py", "ground_force_2_pz"];
values.beltSpeed = 1.4; % m/s, tutorial treadmill

% Synthetic known truth (tests/data/gcp/synthetic). GCP's starting values
% in those settings files (the same for both cases), and the true values
% each case's ground reactions were computed with. Every spring has the
% same spring constant in both cases:
% - globals: the starting spring constant, with damping, dynamic friction
%   and resting length different from the start;
% - springs: a different spring constant, with everything else at the
%   start.
% Spring constants varying from spring to spring were tried and are not
% recoverable: springs that never touch the ground do not affect the cost,
% and lsqnonlin stalls on the rest (see tests/data/gcp/README.md).
values.synthetic.gridWidth = 5;
values.synthetic.gridHeight = 11;
values.synthetic.numSprings = 37; % grid points inside the foot outline
values.synthetic.start = struct("springConstant", 2500, ...
    "dampingFactor", 1, "dynamicFrictionCoefficient", 0.5, ...
    "viscousFrictionCoefficient", 0, "restingSpringLength", 0.05);
values.synthetic.globals = struct("springConstant", 2500, ...
    "dampingFactor", 1.5, "dynamicFrictionCoefficient", 0.7, ...
    "viscousFrictionCoefficient", 0, "restingSpringLength", 0.045);
values.synthetic.springs = struct("springConstant", 3000, ...
    "dampingFactor", 1, "dynamicFrictionCoefficient", 0.5, ...
    "viscousFrictionCoefficient", 0, "restingSpringLength", 0.05);
% rotation: the globals truth, measured by a force plate turned by
% forcePlateRotation (rad) about the vertical axis. Its settings start at
% the globals truth and optimize only the rotation, from 0.
values.synthetic.rotation = values.synthetic.globals;
values.synthetic.rotation.forcePlateRotation = 0.05;
end
