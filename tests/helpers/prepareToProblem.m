% This function prepares a Treatment Optimization problem from a settings
% file in the current folder exactly as the tool named in it does on
% candidate-1.5.4, up to the point where GPOPS-II solves it:
%   parse (parseToSettingsFile), normalizeSynergyData,
%   setupMuscleSynergies, setupTorqueControls (Verification and Design
%   only), makeTreatmentOptimizationInputs, convertToGpopsInputs,
% the sequence in <Tool>OptimizationTool and solveOptimalControlProblem.
% If a tool's sequence changes, change it here too.
%
% Needs GPOPS-II: makeTreatmentOptimizationInputs and convertToGpopsInputs
% call gpops2 to find the collocation times. Clears Treatment
% Optimization's persistent caches first (clearToCaches).
%
% Example: [setup, inputs, params] = prepareToProblem("settings_tracking_torque_tutorial.xml")
%
% (string) -> (struct, struct, struct)

function [setup, inputs, params] = prepareToProblem(fileName)
clearToCaches();
[inputs, params] = parseToSettingsFile(fileName);
inputs = normalizeSynergyData(inputs);
inputs = setupMuscleSynergies(inputs);
if inputs.toolName ~= "TrackingOptimization"
    inputs = setupTorqueControls(inputs);
end
inputs = makeTreatmentOptimizationInputs(inputs, params);
[setup, inputs] = convertToGpopsInputs(inputs, params);
setup.auxdata = inputs;
end
