% This function regenerates the synthetic known-truth MTP data in
% tests/data/mtp/synthetic:
%
% 1. UF_Subject_3_reduced_muscles_synthetic.osim: the fixture model with
%    the optimal fiber and tendon slack lengths of some muscles adjusted.
%    With the fixture model's own lengths, several muscles reach
%    normalized fiber lengths of 1.45 to 1.53, past the 1.3 MTP allows
%    (calcMuscleTendonNonLinearConstraints), so no truth near MTP's
%    starting values could be found again. Every muscle whose range at the
%    starting values is outside 0.45 to 1.15 gets lengths that center its
%    range on 0.8 and make it at most 0.7 wide.
% 2. emg_scale/ and all/: copies of tests/data/mtp/preprocessed (one gait
%    trial), and two_trials/: a copy of tests/data/mtp/rebuilt/preprocessed
%    (two gait trials). In each, the IDData moments for the tracked
%    coordinates are replaced by the muscle moments MTP's forward model
%    (calcMtpModeledValues) gives for the synthetic model at that case's
%    true parameters. MTP started from its usual starting values should
%    find them again.
% 3. passive/: a copy of tests/data/mtp/passive_moment_data whose IDData
%    moments are replaced by the passive moments Muscle-Tendon Length
%    Initialization's forward model
%    (calcMuscleTendonLengthInitializationModeledValues) gives for the
%    fixture model at the true length scale factors, with maximum
%    isometric force fixed.
%
% The moments come from nmsm-core's own forward models, so a bug in those
% models is built into the truth; the unit tests in tests/unit/core,
% tests/unit/MuscleTendonPersonalization and
% tests/unit/MuscleTendonLengthInitialization check the models separately.
%
% Only run this when the fixture data or a true value changes on purpose,
% then run MtpSyntheticDataTest and commit the regenerated files.
%
% Usage, with the nmsm-core project open (e.g. after runTests), from the
% nmsm-test folder:
%   addpath("tests/data/mtp/synthetic")
%   generateMtpSyntheticData()
%
% () -> (None)

function generateMtpSyntheticData()
verifyProjectOpened()
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(fullfile(fileparts(fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))))), "helpers"));
fixture = mtpFixtureValues();
outputFolder = testDataPath("mtp", "synthetic");
fixtureModel = testDataPath("mtp", fixture.modelFileName);
syntheticModel = fullfile(outputFolder, fixture.synthetic.modelFileName);
oneTrial = testDataPath("mtp", "preprocessed");
twoTrials = testDataPath("mtp", "rebuilt", "preprocessed");

inputs = parseMtpInputs(fixtureModel, oneTrial);
writeSyntheticModel(inputs, fixtureModel, syntheticModel);
fprintf("Wrote %s\n", syntheticModel);

cases = ["emgScale", "emg_scale", oneTrial; "all", "all", oneTrial; ...
    "twoTrials", "two_trials", twoTrials];
for i = 1 : size(cases, 1)
    inputs = parseMtpInputs(syntheticModel, cases(i, 3));
    modeled = calcMtpModeledValues(fixture.synthetic.(cases(i, 1)), ...
        inputs, struct());
    verifyFiberLengthsAreFeasible(modeled, cases(i, 1));
    caseFolder = fullfile(outputFolder, cases(i, 2));
    copyFreshFolder(cases(i, 3), caseFolder);
    for trial = 1 : length(inputs.trialNames)
        writeMoments(fullfile(caseFolder, "IDData", ...
            string(inputs.trialNames{trial}) + ".sto"), ...
            inputs.coordinateNames + "_moment", ...
            modeled.muscleJointMoments(trial, :, :));
    end
    fprintf("Wrote %s\n", caseFolder);
end

inputs = parseMtliInputs(fixtureModel);
modeled = calcMuscleTendonLengthInitializationModeledValues( ...
    fixture.synthetic.passive, inputs);
caseFolder = fullfile(outputFolder, "passive");
copyFreshFolder(testDataPath("mtp", "passive_moment_data"), caseFolder);
for trial = 1 : length(inputs.passivePrefixes)
    writeMoments(fullfile(caseFolder, "IDData", ...
        inputs.passivePrefixes(trial) + ".sto"), ...
        string(inputs.coordinateNames), ...
        modeled.passiveModelMoments(trial, :, :));
end
fprintf("Wrote %s\n", caseFolder);
end

% (string, string) -> (struct)
% Parses settings_minimal.xml (no synergy extrapolation or MTLI) with the
% given model and data folder in a temporary folder, giving the EMG,
% muscle-tendon and model inputs MTP's forward model needs.
function inputs = parseMtpInputs(modelFile, dataFolder)
fixture = mtpFixtureValues();
[folder, cleanUp] = enterTemporaryFolder(); %#ok<ASGLU>
copyfile(modelFile, fullfile(folder, fixture.modelFileName));
copyfile(dataFolder, fullfile(folder, "preprocessed"));
copyfile(testDataPath("mtp", "settings", "settings_minimal.xml"), folder);
inputs = parseMuscleTendonPersonalizationSettingsTree( ...
    xml2struct("settings_minimal.xml"));
end

% (string) -> (struct)
% Parses the MTLI section of edge_mtli_enabled.xml (fixture passive data)
% with the given model, with maximum isometric force fixed as in
% settings_synthetic_passive.xml.
function inputs = parseMtliInputs(modelFile)
fixture = mtpFixtureValues();
[folder, cleanUp] = enterTemporaryFolder(); %#ok<ASGLU>
copyfile(modelFile, fullfile(folder, fixture.modelFileName));
copyfile(testDataPath("mtp", "preprocessed"), fullfile(folder, ...
    "preprocessed"));
copyfile(testDataPath("mtp", "passive_moment_data"), fullfile(folder, ...
    "passive_moment_data"));
copyfile(testDataPath("mtp", "settings", "edge_mtli_enabled.xml"), folder);
inputs = parseMuscleTendonLengthInitializationSettingsTree( ...
    xml2struct("edge_mtli_enabled.xml"));
inputs.optimizeIsometricMaxForce = false;
end

function [folder, cleanUp] = enterTemporaryFolder()
folder = tempname;
mkdir(folder);
originalFolder = cd(folder);
% One cleanup, so the folder is left before it is removed.
cleanUp = onCleanup(@() leaveAndRemove(originalFolder, folder));
org.opensim.modeling.Logger.removeFileSink();
end

function leaveAndRemove(originalFolder, folder)
cd(originalFolder);
rmdir(folder, "s");
end

function copyFreshFolder(source, target)
if isfolder(target)
    rmdir(target, "s");
end
copyfile(source, target);
end

% (struct, string, string) -> (None)
% Normalized fiber length is (muscle-tendon length - slack length) /
% (optimal length * cos(pennation)), so for a muscle whose muscle-tendon
% length spans [a, b], optimal length (b - a) / (0.7 cos) and slack length
% (a + b) / 2 - 0.8 * optimal length * cos give the range [0.45, 1.15].
function writeSyntheticModel(inputs, sourceFile, outputFile)
model = Model(sourceFile);
lengths = calcNormalizedMuscleFiberLengthsAndVelocities(inputs, ...
    ones(1, 9), ones(1, 9));
for i = 1 : length(inputs.muscleNames)
    muscleLength = squeeze(inputs.muscleTendonLength(1, i, :));
    fiberLength = squeeze(lengths(1, i, :));
    if min(fiberLength) >= 0.45 && max(fiberLength) <= 1.15
        continue
    end
    cosine = cos(inputs.pennationAngle(i));
    range = [min(muscleLength), max(muscleLength)];
    optimalLength = max(inputs.optimalFiberLength(i), ...
        diff(range) / (0.7 * cosine));
    slackLength = mean(range) - 0.8 * optimalLength * cosine;
    muscle = model.getMuscles().get(char(inputs.muscleNames(i)));
    muscle.setOptimalFiberLength(optimalLength);
    muscle.setTendonSlackLength(slackLength);
    fprintf("  %s: optimal fiber length %.6f -> %.6f, tendon slack " + ...
        "length %.6f -> %.6f\n", inputs.muscleNames(i), ...
        inputs.optimalFiberLength(i), optimalLength, ...
        inputs.tendonSlackLength(i), slackLength);
end
model.print(char(outputFile));
end

% (struct, string) -> (None)
% MTP keeps normalized fiber lengths between 0.3 and 1.3, so a truth near
% those limits could not reliably be found again.
function verifyFiberLengthsAreFeasible(modeled, caseName)
lengths = modeled.normalizedFiberLength;
assert(all(lengths > 0.35 & lengths < 1.25, "all"), caseName + ...
    ": true normalized fiber lengths range from " + min(lengths, [], ...
    "all") + " to " + max(lengths, [], "all") + ", too close to " + ...
    "MTP's 0.3 to 1.3 limits.")
fprintf("  %s: true normalized fiber lengths %.3f to %.3f\n", caseName, ...
    min(lengths, [], "all"), max(lengths, [], "all"));
end

% (string, string array, 3D array) -> (None)
% Rewrites one trial's ID file in place, keeping its header and every
% other column, with the named columns replaced by moments(1, i, :).
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
