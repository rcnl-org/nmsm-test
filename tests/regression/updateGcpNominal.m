% This function regenerates the nominal GCP results in
% tests/data/gcp/nominal by running GroundContactPersonalizationTool on
% each regression settings file that has nominal results against the
% currently checked-out nmsm-core. For each case it keeps
% <case>_bodyModel_gcp.osimx and
% <case>_bodyModel_Foot_1_optimizedGroundReactions.sto. Cases that fail to
% run are reported and skipped.
%
% Only run this when a change to GCP's results is intentional, and only
% after the other GroundContactPersonalizationRegressionTest tests pass,
% so the new nominal results are still correct. Commit the updated files
% with a message saying why the results changed.
%
% Usage, with the nmsm-core project open (e.g. after runTests):
%   addpath("tests/regression")   % from the nmsm-test folder
%   updateGcpNominal()
%
% () -> (None)

function updateGcpNominal()
verifyProjectOpened()
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(fullfile(fileparts(fileparts(mfilename("fullpath"))), "helpers"));
runs = ["globals", "settings_synthetic_globals.xml", "GCPResults"; ...
    "springs", "settings_synthetic_springs.xml", "GCPResults"; ...
    "tutorial", "settings_tutorial.xml", "GCPResultsV1"];
nominalFolder = testDataPath("gcp", "nominal");
if isfolder(nominalFolder)
    rmdir(nominalFolder, "s");
end
mkdir(nominalFolder);
startQuietParallelPool();
originalFolder = pwd;
restoreFolder = onCleanup(@() cd(originalFolder));
for i = 1 : size(runs, 1)
    workFolder = tempname;
    copyGcpFixtures(workFolder, runs(i, 2));
    cd(workFolder);
    try
        evalc("GroundContactPersonalizationTool(runs(i, 2))");
    catch exception
        % A failed run leaves its log open, which would block rmdir.
        diary off
        fprintf("Skipped %s: %s\n", runs(i, 1), exception.message);
    end
    results = fullfile(workFolder, runs(i, 3));
    if isfolder(results)
        for file = ["bodyModel_gcp.osimx", ...
                "bodyModel_Foot_1_optimizedGroundReactions.sto"]
            copyfile(fullfile(results, file), fullfile(nominalFolder, ...
                runs(i, 1) + "_" + file));
        end
        fprintf("Updated %s nominal results\n", runs(i, 1));
    end
    cd(originalFolder);
    clearGcpMexFiles(workFolder);
    rmdir(workFolder, "s");
end
end
