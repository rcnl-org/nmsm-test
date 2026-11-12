% This function regenerates the synthetic known-truth NCP data in
% tests/data/ncp/synthetic, from the true synergy weights and command nodes
% in ncpFixtureValues().synthetic.
%
% True activations are B * commandNodes * weights, with B the cubic
% B-spline matrix NCP builds for 101 frames and 26 nodes. Joint moments
% are what calcMuscleJointMoments gives for those activations with the
% muscle-tendon data in tests/data/ncp/preprocessed and the lengths and
% forces in the tutorial's MTP osimx file (as NCP uses them). Each case is
% a folder with:
%   preprocessed/  tests/data/ncp/preprocessed with the tracked ID moments
%                  replaced by the true moments
%   mtpResults/muscleActivations/gait_1_muscleActivations.sto
%                  the true activations, as if MTP had found them
% Cases:
%   all_tracked/    MTP activations for all nine muscles
%   iliacus_hidden/ MTP activations without iliacus_r, so NCP has to
%                   predict it from the synergies and the moments
%   fixed_weights/  like all_tracked, plus preprocessed/synergyWeights.sto
%                   holding the true weights, for optimize_synergy_vectors
%                   false
%
% The moments come from nmsm-core's own muscle model, so a bug in that
% model is built into the truth; tests/unit/core/MuscleModelTest checks
% the model separately.
%
% Only run this when a fixture or a true value changes on purpose, then
% run NcpSyntheticDataTest and commit the regenerated files.
%
% Usage, with the nmsm-core project open (e.g. after runTests), from the
% nmsm-test folder:
%   addpath("tests/data/ncp/synthetic")
%   generateNcpSyntheticData()
%
% () -> (None)

function generateNcpSyntheticData()
verifyProjectOpened()
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(fullfile(fileparts(fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))))), "helpers"));
fixture = ncpFixtureValues();
inputs = parseTutorialInputs();
[activations, moments] = syntheticActivationsAndMoments(inputs, ...
    fixture.synthetic);
fprintf("True activations range from %.3f to %.3f\n", ...
    min(activations, [], "all"), max(activations, [], "all"));

outputFolder = testDataPath("ncp", "synthetic");
cases = ["all_tracked", "iliacus_hidden", "fixed_weights"];
for caseName = cases
    caseFolder = fullfile(outputFolder, caseName);
    if isfolder(caseFolder)
        rmdir(caseFolder, "s");
    end
    copyfile(testDataPath("ncp", "preprocessed"), fullfile(caseFolder, ...
        "preprocessed"));
    writeMoments(fullfile(caseFolder, "preprocessed", "IDData", ...
        fixture.trialName + ".sto"), inputs.coordinateNames + "_moment", ...
        moments);
    tracked = true(1, length(inputs.muscleNames));
    if caseName == "iliacus_hidden"
        tracked = inputs.muscleNames ~= "iliacus_r";
    end
    mkdir(fullfile(caseFolder, "mtpResults", "muscleActivations"));
    writeToSto(inputs.muscleNames(tracked), inputs.time(1, :), ...
        squeeze(activations(1, tracked, :))', fullfile(caseFolder, ...
        "mtpResults", "muscleActivations", fixture.trialName + ...
        "_muscleActivations.sto"));
    if caseName == "fixed_weights"
        writeToSto(inputs.muscleNames, 1 : size(fixture.synthetic.weights, ...
            1), fixture.synthetic.weights, fullfile(caseFolder, ...
            "preprocessed", "synergyWeights.sto"));
    end
    fprintf("Wrote %s\n", caseFolder);
end
end

% (None) -> (struct)
% Parses settings_tutorial.xml (with the tutorial's MTP results) in a
% temporary folder, giving the muscle-tendon data and the MTP lengths and
% forces NCP uses.
function inputs = parseTutorialInputs()
folder = tempname;
mkdir(folder);
originalFolder = cd(folder);
% One cleanup, so the folder is left before it is removed.
cleanUp = onCleanup(@() leaveAndRemove(originalFolder, folder));
org.opensim.modeling.Logger.removeFileSink();
copyNcpFixtures(folder, "settings_tutorial.xml");
inputs = parseNeuralControlPersonalizationSettingsTree( ...
    xml2struct("settings_tutorial.xml"));
end

function leaveAndRemove(originalFolder, folder)
cd(originalFolder);
rmdir(folder, "s");
end

% (struct, struct) -> (3D array, 3D array)
% Activations (trial x muscle x frame) and the joint moments they give
% (trial x coordinate x frame), as NCP computes them.
function [activations, moments] = syntheticActivationsAndMoments(inputs, ...
    truth)
numFrames = size(inputs.muscleTendonLength, 3);
percent = linspace(0, 100, numFrames)';
B = BSplineMatrices(3, truth.numNodes, numFrames, percent(2) - percent(1));
activations = permute(B * truth.commandNodes * truth.weights, [3, 2, 1]);
[normalizedFiberLengths, normalizedFiberVelocities] = ...
    calcNormalizedMuscleFiberLengthsAndVelocities(inputs, ...
    inputs.optimalFiberLengthScaleFactors, ...
    inputs.tendonSlackLengthScaleFactors);
moments = calcMuscleJointMoments(inputs, activations, ...
    normalizedFiberLengths, normalizedFiberVelocities);
end

% (string, string array, 3D array) -> (None)
% Rewrites the ID file in place, keeping its header and every other
% column, with the named columns replaced by moments(1, i, :).
function writeMoments(fileName, columnsToReplace, moments)
lines = readlines(fileName);
headerEnd = find(startsWith(strtrim(lines), "endheader"), 1);
columnNames = split(strtrim(lines(headerEnd + 1)))';
[data, readNames] = readStoFile(fileName);
assert(isequal(readNames, columnNames))
for i = 1 : length(columnsToReplace)
    column = columnNames == columnsToReplace(i);
    assert(nnz(column) == 1, "No column " + columnsToReplace(i) + ...
        " in " + fileName)
    data(:, column) = squeeze(moments(1, i, :));
end
rows = strings(size(data, 1), 1);
for i = 1 : size(data, 1)
    rows(i) = strjoin(compose("%.17g", data(i, :)), char(9));
end
writelines([lines(1 : headerEnd + 1); rows], fileName);
end
