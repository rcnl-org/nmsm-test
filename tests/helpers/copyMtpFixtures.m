% This function copies the MTP fixture model, the preprocessed and passive
% data folders, the synthetic model and data (into synthetic/), and the
% given settings files into a folder, so MTP can be parsed or run there.
% setUpMtpWorkingFolder uses it for a test's temporary folder; tests that
% run several MTP cases use it to give each case its own folder.
%
% Example: copyMtpFixtures("tutorialRun", "settings_tutorial.xml")
%
% (string, string array) -> (None)

function copyMtpFixtures(folder, settingsFileNames)
if ~isfolder(folder)
    mkdir(folder);
end
dataFolder = testDataPath("mtp");
copyfile(fullfile(dataFolder, "*.osim"), folder);
copyfile(fullfile(dataFolder, "preprocessed"), ...
    fullfile(folder, "preprocessed"));
copyfile(fullfile(dataFolder, "passive_moment_data"), ...
    fullfile(folder, "passive_moment_data"));
% Synthetic model and data, without the generator script
mkdir(fullfile(folder, "synthetic"));
copyfile(fullfile(dataFolder, "synthetic", "*.osim"), ...
    fullfile(folder, "synthetic"));
for caseFolder = ["emg_scale", "all", "two_trials", "passive"]
    copyfile(fullfile(dataFolder, "synthetic", caseFolder), ...
        fullfile(folder, "synthetic", caseFolder));
end
for name = settingsFileNames
    copyfile(fullfile(dataFolder, "settings", name), folder);
end
end
