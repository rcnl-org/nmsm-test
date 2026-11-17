% This function regenerates the nominal Treatment Optimization results in
% tests/data/to/nominal: for each case in toSetupCases, the prepared
% problem's deterministic quantities (evaluateToProblem) as
% setup_<case>.mat, against the currently checked-out nmsm-core. Full runs
% have no nominal results: IPOPT's solutions differ between computers.
%
% Only run this when a change to Treatment Optimization's setup is
% intentional, and only after the other
% TreatmentOptimizationSetupRegressionTest tests pass. Commit the updated
% files with a message saying why the results changed. Needs GPOPS-II.
%
% Usage, with the nmsm-core project open (e.g. after runTests):
%   addpath("tests/regression")   % from the nmsm-test folder
%   updateToNominal()
%
% () -> (None)

function updateToNominal()
verifyProjectOpened()
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(fullfile(fileparts(fileparts(mfilename("fullpath"))), "helpers"));
assert(gpopsIsLicensed(), "GPOPS-II is not licensed on this computer.")
nominalFolder = testDataPath("to", "nominal");
if isfolder(nominalFolder)
    rmdir(nominalFolder, "s");
end
mkdir(nominalFolder);
originalFolder = pwd;
restoreFolder = onCleanup(@() cd(originalFolder));
cases = toSetupCases();
for name = string(fieldnames(cases))'
    workFolder = tempname;
    copyToFixtures(workFolder, cases.(name).problem, cases.(name).settings);
    cd(workFolder);
    [~, setup] = evalc("prepareToProblem(cases.(name).settings)");
    result = evaluateToProblem(setup); %#ok<NASGU>
    save(fullfile(nominalFolder, "setup_" + name + ".mat"), "result");
    cd(originalFolder);
    clearToCaches();
    rmdir(workFolder, "s");
    fprintf("Updated %s nominal results\n", name);
end
clearToCaches();
end
