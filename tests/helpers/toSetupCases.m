% This function lists the Treatment Optimization cases whose prepared
% problems (prepareToProblem, evaluateToProblem) are compared with nominal
% results: each case's fixture problem and settings file. Shared by
% TreatmentOptimizationSetupRegressionTest and updateToNominal.
%
% () -> (struct)

function cases = toSetupCases()
cases.trackingTorque = struct("problem", "torque", "settings", ...
    "settings_tracking_torque_tutorial.xml");
cases.trackingSynergy = struct("problem", "synergy", "settings", ...
    "settings_tracking_synergy_tutorial.xml");
cases.verificationTorque = struct("problem", "torque", "settings", ...
    "settings_verification_torque_tutorial.xml");
cases.designTorqueV3 = struct("problem", "torque", "settings", ...
    "settings_design_torque_tutorial_v3.xml");
cases.designTorqueV5 = struct("problem", "torque", "settings", ...
    "settings_design_torque_tutorial_v5.xml");
cases.designSynergy = struct("problem", "synergy", "settings", ...
    "settings_design_synergy_tutorial.xml");
end
