% This function copies one Treatment Optimization problem's fixtures into a
% folder, so Treatment Optimization can be parsed or run there: the
% problem's model and starting data (tests/data/to/torque or
% tests/data/to/synergy), the shared IK and ID data (preprocessed/), the
% user-defined term functions (userFunctions/, on the path from the current
% folder), every GPOPS solver settings file (gpops_*.xml), and the given
% settings files.
%
% Treatment Optimization writes its log, the surrogate model and a copy of
% the model with muscles disabled next to the files it reads, so each parse
% or run needs a folder of its own.
%
% Example: copyToFixtures("torqueRun", "torque", "settings_tracking_torque_run.xml")
%
% (string, string, string array) -> (None)

function copyToFixtures(folder, problem, settingsFileNames)
arguments
    folder (1, 1) string
    problem (1, 1) string {mustBeMember(problem, ["torque", "synergy"])}
    settingsFileNames (1, :) string = strings(1, 0)
end
if ~isfolder(folder)
    mkdir(folder);
end
toFolder = testDataPath("to");
copyfile(fullfile(toFolder, problem, "*"), folder);
copyfile(fullfile(toFolder, "preprocessed"), fullfile(folder, "preprocessed"));
copyfile(fullfile(toFolder, "userFunctions", "*.m"), folder);
solverSettings = dir(fullfile(toFolder, "settings", "gpops_*.xml"));
for file = string({solverSettings.name})
    copyfile(fullfile(toFolder, "settings", file), folder);
end
for name = settingsFileNames
    copyfile(fullfile(toFolder, "settings", name), folder);
end
end
