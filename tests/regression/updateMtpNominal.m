% This function regenerates the nominal MTP results in
% tests/data/mtp/nominal by running MuscleTendonPersonalizationTool on each
% regression settings file against the currently checked-out nmsm-core.
% For each case it keeps <case>_muscleModelParameters.sto and, per trial,
% <case>_<trial>_modelJointMoments.sto.
%
% Only run this when a change to MTP's results is intentional, and only
% after the other MuscleTendonPersonalizationRegressionTest tests pass, so
% the new nominal results are still correct. Commit the updated files with
% a message saying why the results changed.
%
% Usage, with the nmsm-core project open (e.g. after runTests):
%   addpath("tests/regression")   % from the nmsm-test folder
%   updateMtpNominal()
%
% () -> (None)

function updateMtpNominal()
verifyProjectOpened()
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(fullfile(fileparts(fileparts(mfilename("fullpath"))), "helpers"));
runs = ["emgScale", "settings_synthetic_emg_scale.xml", "MTPResults"; ...
    "all", "settings_synthetic_all.xml", "MTPResults"; ...
    "twoTrials", "settings_synthetic_two_trials.xml", "MTPResults"; ...
    "passive", "settings_synthetic_passive.xml", "MTPResults"; ...
    "tutorial", "settings_tutorial.xml", "MTPResultsV1"];
nominalFolder = testDataPath("mtp", "nominal");
if isfolder(nominalFolder)
    rmdir(nominalFolder, "s");
end
mkdir(nominalFolder);
startQuietParallelPool();
originalFolder = pwd;
restoreFolder = onCleanup(@() cd(originalFolder));
for i = 1 : size(runs, 1)
    workFolder = tempname;
    copyMtpFixtures(workFolder, runs(i, 2));
    cd(workFolder);
    evalc("MuscleTendonPersonalizationTool(runs(i, 2))");
    analysis = fullfile(workFolder, runs(i, 3), "Analysis");
    copyfile(fullfile(analysis, "muscleModelParameters", ...
        "muscleModelParameters.sto"), fullfile(nominalFolder, ...
        runs(i, 1) + "_muscleModelParameters.sto"));
    for moments = dir(fullfile(analysis, "modelJointMoments", "*.sto"))'
        copyfile(fullfile(moments.folder, moments.name), ...
            fullfile(nominalFolder, runs(i, 1) + "_" + moments.name));
    end
    cd(originalFolder);
    rmdir(workFolder, "s");
    fprintf("Updated %s nominal results\n", runs(i, 1));
end
end
