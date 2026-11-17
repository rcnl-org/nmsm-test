% This function copies the GCP fixtures into a folder, so GCP can be parsed
% or run there: the body model and GRF data (tests/data/gcp), the IK data
% shared with MTP (tests/data/mtp), the synthetic GCP cases (into
% synthetic/, if they exist), and the given settings files.
%
% GCP writes footModel_<n>.osim and copies a pointKinematics MEX file into
% the current folder, so each run needs a folder of its own.
%
% Example: copyGcpFixtures("tutorialRun", "settings_tutorial.xml")
%
% (string, string array) -> (None)

function copyGcpFixtures(folder, settingsFileNames)
if ~isfolder(folder)
    mkdir(folder);
end
gcpFolder = testDataPath("gcp");
copyfile(fullfile(gcpFolder, "*.osim"), folder);
copyfile(fullfile(gcpFolder, "preprocessed"), fullfile(folder, ...
    "preprocessed"));
copyfile(testDataPath("mtp", "preprocessed", "IKData"), fullfile(folder, ...
    "preprocessed", "IKData"));
synthetic = dir(fullfile(gcpFolder, "synthetic"));
synthetic = synthetic([synthetic.isdir] & ~startsWith({synthetic.name}, "."));
for caseFolder = string({synthetic.name})
    copyfile(fullfile(gcpFolder, "synthetic", caseFolder), ...
        fullfile(folder, "synthetic", caseFolder));
end
for name = settingsFileNames
    copyfile(fullfile(gcpFolder, "settings", name), folder);
end
end
