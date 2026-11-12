% This function reads a Treatment Optimization solution from a results
% folder: time, states ([positions, velocities] of the states
% coordinates), accelerations, and controls (torque controls and synergy
% commands, whichever were written), plus the modeled inverse dynamics
% loads.
%
% Example: solution = readToSolution(run.resultsDirectory, "drive_kick1")
%
% (string, string) -> (struct)

function solution = readToSolution(folder, trialName)
[states, names] = readStoFile(fullfile(folder, trialName + "_states.sto"));
solution.time = states(:, 1);
solution.states = states(:, 2 : end);
solution.stateNames = names(2 : end);
accelerations = readStoFile(fullfile(folder, trialName + ...
    "_accelerations.sto"));
solution.accelerations = accelerations(:, 2 : end);
solution.torqueControls = [];
solution.torqueNames = strings(1, 0);
torqueFile = fullfile(folder, trialName + "_torqueControls.sto");
if isfile(torqueFile)
    [torques, names] = readStoFile(torqueFile);
    solution.torqueControls = torques(:, 2 : end);
    solution.torqueNames = names(2 : end);
end
solution.synergyCommands = [];
synergyFile = fullfile(folder, trialName + "_synergyCommands.sto");
if isfile(synergyFile)
    commands = readStoFile(synergyFile);
    solution.synergyCommands = commands(:, 2 : end);
end
[loads, names] = readStoFile(fullfile(folder, "IDData", trialName + ".sto"));
solution.inverseDynamics = loads(:, 2 : end);
solution.inverseDynamicsNames = names(2 : end);
end
