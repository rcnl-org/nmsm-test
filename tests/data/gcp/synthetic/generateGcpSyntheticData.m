% This function regenerates the synthetic known-truth GCP data in
% tests/data/gcp/synthetic, from the true values in
% gcpFixtureValues().synthetic.(case).
%
% For each case it runs GCP's own input preparation on the fixtures (foot
% model with its spring grid, foot kinematics, B-splines), computes the
% ground reactions GCP's contact model gives at the true spring
% parameters, with the foot moving as GCP fits it to the experimental IK
% (kinematic B-spline coefficients 1), and writes them into a copy of the
% GRF file as the right foot's plate 2 data:
% - forces: the modeled forces;
% - electrical center: the floor point under the experimental midfoot
%   superior marker, which GCP moves the measured moments to anyway;
% - moments: the modeled moments minus (0, -L, 0) x F, which GCP adds back
%   for the resting spring length L before comparing.
% With those choices, GCP's ground reaction cost terms are exactly zero at
% the true parameters.
%
% Cases (each a folder with IKData/ and GRFData/):
%   globals/ every spring at the starting spring constant; true damping,
%            dynamic friction and resting length differ from the start
%   springs/ every spring at a different spring constant; everything else
%            at the start
%   rotation/ globals, with the forces and moments turned by minus the
%            true force plate rotation about the vertical axis, so GCP's
%            rotation by the true angle gives back the model's values
%
% The ground reactions come from nmsm-core's own contact model, so a bug in
% it is built into the truth; tests/unit/GroundContactPersonalization checks
% the model separately.
%
% Only run this when a fixture or a true value changes on purpose, then run
% GcpSyntheticDataTest and commit the regenerated files.
%
% Usage, with the nmsm-core project open (e.g. after runTests), from the
% nmsm-test folder:
%   addpath("tests/data/gcp/synthetic")
%   generateGcpSyntheticData()
%
% () -> (None)

function generateGcpSyntheticData()
verifyProjectOpened()
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(fullfile(fileparts(fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))))), "helpers"));
fixture = gcpFixtureValues();
outputFolder = testDataPath("gcp", "synthetic");
for caseName = ["globals", "springs", "rotation"]
    [forces, moments, center, numSprings, time] = ...
        modeledGroundReactions(caseName, fixture);
    caseFolder = fullfile(outputFolder, caseName);
    if isfolder(caseFolder)
        rmdir(caseFolder, "s");
    end
    mkdir(fullfile(caseFolder, "GRFData"));
    copyfile(testDataPath("mtp", "preprocessed", "IKData"), ...
        fullfile(caseFolder, "IKData"));
    grfFile = fullfile(caseFolder, "GRFData", fixture.trialName + ".sto");
    copyfile(testDataPath("gcp", "preprocessed", "GRFData", ...
        fixture.trialName + ".sto"), grfFile);
    writeColumns(grfFile, time, [fixture.forceColumns, ...
        fixture.momentColumns, fixture.electricalCenterColumns], ...
        [forces; moments; center]);
    fprintf("Wrote %s (%d springs, ground reactions %.0f to %.0f N " + ...
        "vertical)\n", caseFolder, numSprings, ...
        min(forces(2, :)), max(forces(2, :)));
end
end

% (string, struct) -> (3 x frame, 3 x frame, 3 x frame, double, Array)
% Runs GCP's input preparation for the case's settings in a temporary
% folder and evaluates the contact model at the true values.
function [forces, moments, center, numSprings, time] = ...
    modeledGroundReactions(caseName, fixture)
folder = tempname;
copyGcpFixtures(folder, "settings_synthetic_" + caseName + ".xml");
% The synthetic data does not exist yet; the case reads the fixture data.
settingsFile = fullfile(folder, "settings_synthetic_" + caseName + ".xml");
settings = fileread(settingsFile);
settings = replace(settings, "<input_directory>synthetic/" + caseName, ...
    "<input_directory>preprocessed");
writelines(settings, settingsFile);
originalFolder = cd(folder);
cleanUp = onCleanup(@() leaveAndRemove(originalFolder, folder));
org.opensim.modeling.Logger.removeFileSink();

inputs = parseGroundContactPersonalizationSettingsTree(xml2struct( ...
    "settings_synthetic_" + caseName + ".xml"));
evalc("inputs = prepareGroundContactPersonalizationInputs(inputs);");
surface = inputs.surfaces{1};
truth = fixture.synthetic.(caseName);
numSprings = inputs.numSpringMarkers;
values = struct("springConstants", truth.springConstant * ...
    ones(1, numSprings), ...
    "dampingFactor", truth.dampingFactor, ...
    "dynamicFrictionCoefficient", truth.dynamicFrictionCoefficient, ...
    "viscousFrictionCoefficient", truth.viscousFrictionCoefficient, ...
    "restingSpringLength", truth.restingSpringLength);
% Every ground reaction quantity is computed, using values (not inputs)
% for the spring parameters.
params.tasks = {struct("designVariables", logical([1 1 1 1 1 0 0 0 0 0]), ...
    "costTerms", {{struct("type", 'vertical_grf', "isEnabled", true), ...
    struct("type", 'horizontal_grf', "isEnabled", true), ...
    struct("type", 'ground_reaction_moment', "isEnabled", true)}}, ...
    "neighborStandardDeviation", 0.05)};
[positions, velocities] = calcGCPJointKinematics( ...
    surface.experimentalJointPositions, surface.jointKinematicsBSplines, ...
    surface.bSplineCoefficients);
models.model_1 = Model(surface.model);
[~, modeled] = evalc("calcGCPModeledValues(inputs, values, positions, " + ...
    "velocities, params, 1, 1, models)");
forces = [modeled.anteriorGrf; modeled.verticalGrf; modeled.lateralGrf];
center = surface.midfootSuperiorPosition;
center(2, :) = 0;
moments = [modeled.xGrfMoment; modeled.yGrfMoment; modeled.zGrfMoment];
for i = 1 : size(moments, 2)
    moments(:, i) = moments(:, i) - cross([0; ...
        -truth.restingSpringLength; 0], forces(:, i));
end
% GCP adds the resting length term before rotating; that term is about the
% vertical axis, so it is the same before and after the rotation.
if isfield(truth, "forcePlateRotation")
    [forces, moments] = rotateGroundReactions(forces, moments, ...
        -truth.forcePlateRotation);
end
time = surface.time;
clear models
end

function leaveAndRemove(originalFolder, folder)
cd(originalFolder);
for mex = string({dir(fullfile(folder, "*.mexw64")).name})
    clear(mex)
end
rmdir(folder, "s");
end

% (string, Array, string array, 2D array) -> (None)
% Rewrites the file in place, replacing the named columns (one row of data
% each) at the given times and keeping everything else.
function writeColumns(fileName, time, columnsToReplace, data)
lines = readlines(fileName);
headerEnd = find(startsWith(strtrim(lines), "endheader"), 1);
columnNames = split(strtrim(lines(headerEnd + 1)))';
[fileData, readNames] = readStoFile(fileName);
assert(isequal(readNames, columnNames))
[found, rows] = ismember(round(time, 6), round(fileData(:, 1)', 6));
assert(all(found), "Synthetic times are not in " + fileName)
for i = 1 : length(columnsToReplace)
    column = columnNames == columnsToReplace(i);
    assert(nnz(column) == 1, "No column " + columnsToReplace(i))
    fileData(rows, column) = data(i, :)';
end
out = strings(size(fileData, 1), 1);
for i = 1 : size(fileData, 1)
    out(i) = strjoin(compose("%.17g", fileData(i, :)), char(9));
end
writelines([lines(1 : headerEnd + 1); out], fileName);
end
