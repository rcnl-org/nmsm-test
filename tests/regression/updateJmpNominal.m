% This function regenerates the nominal JMP results in
% tests/data/jmp/nominal by running JointModelPersonalizationTool on each
% regression settings file against the currently checked-out nmsm-core.
%
% Only run this when a change to JMP's results is intentional, and only
% after JointModelPersonalizationRegressionTest/recoversTruthAndChangesNothingElse
% passes, so the new nominal results are still correct. Commit the updated
% files with a message saying why the results changed.
%
% Usage, with the nmsm-core project open (e.g. after runTests):
%   addpath("tests/regression")   % from the nmsm-test folder
%   updateJmpNominal()
%
% () -> (None)

function updateJmpNominal()
verifyProjectOpened()
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(fullfile(fileparts(fileparts(mfilename("fullpath"))), "helpers"));
runs =["settings_translation.xml", "simple_arm_translated_jmp.osim"; ...
    "settings_orientation.xml", "simple_arm_oriented_jmp.osim"];
nominalFolder = testDataPath("jmp", "nominal");
if ~isfolder(nominalFolder)
    mkdir(nominalFolder);
end
startQuietParallelPool();
originalFolder = pwd;
restoreFolder = onCleanup(@() cd(originalFolder));
for i = 1:size(runs, 1)
    workFolder = tempname;
    mkdir(workFolder);
    removeWorkFolder = onCleanup(@() rmdir(workFolder, "s"));
    dataFolder = testDataPath("jmp");
    copyfile(fullfile(dataFolder, "*.osim"), workFolder);
    copyfile(fullfile(dataFolder, "*.trc"), workFolder);
    copyfile(fullfile(dataFolder, "settings", runs(i, 1)), workFolder);
    cd(workFolder);
    evalc("JointModelPersonalizationTool(runs(i, 1))");
    copyfile(fullfile("JMPResults", runs(i, 2)), nominalFolder);
    cd(originalFolder);
    clear removeWorkFolder
    fprintf("Updated %s\n", fullfile(nominalFolder, runs(i, 2)));
end
end
