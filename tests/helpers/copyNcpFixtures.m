% This function copies the NCP fixtures into a folder, so NCP can be parsed
% or run there: the model and passive data shared with MTP
% (tests/data/mtp), NCP's preprocessed data and MTP results
% (tests/data/ncp), the synthetic NCP cases (into synthetic/, if they
% exist), and the given settings files.
%
% Example: copyNcpFixtures("tutorialRun", "settings_tutorial.xml")
%
% (string, string array) -> (None)

function copyNcpFixtures(folder, settingsFileNames)
if ~isfolder(folder)
    mkdir(folder);
end
mtpFolder = testDataPath("mtp");
ncpFolder = testDataPath("ncp");
copyfile(fullfile(mtpFolder, "*.osim"), folder);
copyfile(fullfile(mtpFolder, "passive_moment_data"), ...
    fullfile(folder, "passive_moment_data"));
copyfile(fullfile(ncpFolder, "preprocessed"), ...
    fullfile(folder, "preprocessed"));
copyfile(fullfile(ncpFolder, "mtpResults"), fullfile(folder, "mtpResults"));
copyfile(fullfile(ncpFolder, "osimx"), fullfile(folder, "osimx"));
synthetic = dir(fullfile(ncpFolder, "synthetic"));
synthetic = synthetic([synthetic.isdir] & ~startsWith({synthetic.name}, "."));
for caseFolder = string({synthetic.name})
    copyfile(fullfile(ncpFolder, "synthetic", caseFolder), ...
        fullfile(folder, "synthetic", caseFolder));
end
for name = settingsFileNames
    copyfile(fullfile(ncpFolder, "settings", name), folder);
end
end
