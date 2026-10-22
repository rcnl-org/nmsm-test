% This function regenerates the nominal NCP results in
% tests/data/ncp/nominal by running NeuralControlPersonalizationTool on
% each regression settings file against the currently checked-out
% nmsm-core. For each case it keeps <case>_synergyWeights.sto,
% <case>_gait_1_synergyCommands.sto and <case>_gait_1_modeledMomentsNcp.sto.
% Cases that fail to run (iliacusHidden and mtli on candidate-1.5.4) are
% reported and skipped.
%
% Only run this when a change to NCP's results is intentional, and only
% after the other NeuralControlPersonalizationRegressionTest tests pass,
% so the new nominal results are still correct. Commit the updated files
% with a message saying why the results changed.
%
% Usage, with the nmsm-core project open (e.g. after runTests):
%   addpath("tests/regression")   % from the nmsm-test folder
%   updateNcpNominal()
%
% () -> (None)

function updateNcpNominal()
verifyProjectOpened()
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(fullfile(fileparts(fileparts(mfilename("fullpath"))), "helpers"));
runs = ["allTracked", "settings_synthetic_all_tracked.xml", "NCPResults"; ...
    "fixedWeights", "settings_synthetic_fixed_weights.xml", "NCPResults"; ...
    "sum", "settings_synthetic_sum.xml", "NCPResults"; ...
    "iliacusHidden", "settings_synthetic_iliacus_hidden.xml", "NCPResults"; ...
    "mtli", "settings_synthetic_mtli.xml", "NCPResults"; ...
    "tutorial", "settings_tutorial.xml", "NCPResultsV1"];
nominalFolder = testDataPath("ncp", "nominal");
if isfolder(nominalFolder)
    rmdir(nominalFolder, "s");
end
mkdir(nominalFolder);
startQuietParallelPool();
originalFolder = pwd;
restoreFolder = onCleanup(@() cd(originalFolder));
for i = 1 : size(runs, 1)
    workFolder = tempname;
    copyNcpFixtures(workFolder, runs(i, 2));
    cd(workFolder);
    try
        evalc("NeuralControlPersonalizationTool(runs(i, 2))");
    catch exception
        % A failed run leaves its log open, which would block rmdir.
        diary off
        cd(originalFolder);
        rmdir(workFolder, "s");
        fprintf("Skipped %s: %s\n", runs(i, 1), exception.message);
        continue
    end
    results = fullfile(workFolder, runs(i, 3));
    for file = ["synergyWeights.sto", "gait_1_synergyCommands.sto", ...
            fullfile("modelMoments", "gait_1_modeledMomentsNcp.sto")]
        [~, name, extension] = fileparts(file);
        copyfile(fullfile(results, file), fullfile(nominalFolder, ...
            runs(i, 1) + "_" + name + extension));
    end
    cd(originalFolder);
    rmdir(workFolder, "s");
    fprintf("Updated %s nominal results\n", runs(i, 1));
end
end
