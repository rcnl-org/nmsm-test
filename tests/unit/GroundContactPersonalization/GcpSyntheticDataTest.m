% Checks the synthetic known-truth GCP data in tests/data/gcp/synthetic,
% written by generateGcpSyntheticData from the true values in
% gcpFixtureValues().synthetic. If these fail, the regression tests that
% try to recover the truth cannot be trusted.
%
% - Each case's data differs from the fixture data only in the plate 2
%   (right foot) force, moment and electrical center columns.
% - The electrical center is the floor point under the midfoot superior
%   marker, so GCP's move of the moments to that point changes nothing.
% - GCP's own task cost (calcGroundContactPersonalizationTaskCost) is zero
%   at the true values, and clearly not zero at the starting values (so
%   there is something to find).

classdef (TestTags = {'Unit'}) GcpSyntheticDataTest < matlab.unittest.TestCase

    properties
        expected
        % Per case: the prepared inputs and the task cost at the true and
        % starting values.
        results
    end

    properties (TestParameter)
        syntheticCase = {'globals', 'springs', 'rotation'}
    end

    methods (TestClassSetup)
        function evaluateCases(testCase)
            testCase.expected = gcpFixtureValues();
            folder = setUpGcpWorkingFolder(testCase, ...
                ["settings_synthetic_globals.xml", ...
                "settings_synthetic_springs.xml", ...
                "settings_synthetic_rotation.xml"]);
            testCase.addTeardown(@clearGcpMexFiles, folder);
            for caseName = ["globals", "springs", "rotation"]
                testCase.results.(caseName) = evaluateCase(folder, ...
                    caseName, testCase.expected.synthetic);
            end
        end
    end

    methods (Test)
        function onlyPlateTwoColumnsDiffer(testCase, syntheticCase)
            [source, names] = readStoFile(testDataPath("gcp", ...
                "preprocessed", "GRFData", testCase.expected.trialName + ...
                ".sto"));
            [synthetic, syntheticNames] = readStoFile(testDataPath("gcp", ...
                "synthetic", syntheticCase, "GRFData", ...
                testCase.expected.trialName + ".sto"));
            testCase.verifyEqual(syntheticNames, names);
            replaced = ismember(names, [testCase.expected.forceColumns, ...
                testCase.expected.momentColumns, ...
                testCase.expected.electricalCenterColumns]);
            testCase.verifyEqual(nnz(replaced), 9);
            testCase.verifyEqual(synthetic(:, ~replaced), ...
                source(:, ~replaced), "AbsTol", 1e-12);
            testCase.verifyNotEqual(synthetic(:, replaced), ...
                source(:, replaced));
        end

        function motionIsTheFixtureMotion(testCase, syntheticCase)
            fileName = fullfile("IKData", testCase.expected.trialName + ".sto");
            testCase.verifyEqual(fileread(testDataPath("gcp", "synthetic", ...
                syntheticCase, fileName)), fileread(testDataPath("mtp", ...
                "preprocessed", fileName)));
        end

        function electricalCenterIsUnderTheMidfoot(testCase, syntheticCase)
            surface = testCase.results.(syntheticCase).inputs.surfaces{1};
            center = surface.midfootSuperiorPosition;
            center(2, :) = 0;
            testCase.verifyEqual(surface.electricalCenter, center, ...
                "AbsTol", 1e-12);
        end

        function footHasTheExpectedSprings(testCase, syntheticCase)
            % The 5 x 11 grid, trimmed to the foot outline, gives 37
            % springs; the regression tests compare spring by spring.
            testCase.verifyEqual(testCase.results.(syntheticCase).inputs ...
                .numSpringMarkers, testCase.expected.synthetic.numSprings);
        end

        function truthHasZeroCost(testCase, syntheticCase)
            % Scaled by the allowable errors (5 N, 2 N, 0.5 Nm, and 50 N/m
            % for the spring constant mean), so 1e-6 is far below anything
            % an optimizer would notice.
            testCase.verifyLessThan(max(abs( ...
                testCase.results.(syntheticCase).truthCost)), 1e-6);
        end

        function startingValuesHaveLargeCost(testCase, syntheticCase)
            % The sum of squares lsqnonlin minimizes; each enabled term
            % contributes (RMS error / allowable error) ^ 2, so 1 means a
            % term is at its allowable error.
            testCase.verifyGreaterThan(sum(testCase.results ...
                .(syntheticCase).startCost .^ 2), 1);
        end
    end
end

% (string, string, struct) -> (struct)
% Prepares the case's inputs in a subfolder of its own (GCP writes the foot
% model and a MEX copy into the current folder) and evaluates the task
% cost at the true and starting values of the task's design variables.
function result = evaluateCase(folder, caseName, synthetic)
caseFolder = fullfile(folder, caseName);
mkdir(caseFolder);
movefile(fullfile(folder, "settings_synthetic_" + caseName + ".xml"), ...
    caseFolder);
copyfile(fullfile(folder, "*.osim"), caseFolder);
copyfile(fullfile(folder, "synthetic"), fullfile(caseFolder, "synthetic"));
originalFolder = cd(caseFolder);
goBack = onCleanup(@() cd(originalFolder));
[inputs, params] = parseGroundContactPersonalizationSettingsTree( ...
    xml2struct("settings_synthetic_" + caseName + ".xml"));
evalc("inputs = prepareGroundContactPersonalizationInputs(inputs);");
% As GroundContactPersonalization does before the tasks. The moments are
% not moved: the electrical center is already the point they are moved to
% (electricalCenterIsUnderTheMidfoot).
surface = inputs.surfaces{1};
inputs.surfaces{1}.experimentalGroundReactionMomentsSlope = ...
    calcBSplineDerivative(surface.time, ...
    surface.experimentalGroundReactionMoments, 2, surface.splineNodes);
result.inputs = inputs;

clear calcGroundContactPersonalizationTaskCost
if caseName == "rotation"
    % The contact model values are already the truth; only the rotation is
    % a design variable. On candidate-1.5.4 the cost rotates by the stored
    % surface rotation rather than the design variable (see
    % tests/README.md), so both are set, keeping this a check of the data
    % rather than of that bug.
    angle = synthetic.rotation.forcePlateRotation;
    truthInputs = inputs;
    truthInputs.surfaces{1}.forcePlateRotation = angle;
    result.truthCost = calcGroundContactPersonalizationTaskCost(angle, ...
        "forcePlateRotation1", truthInputs, params, 1);
    result.startCost = calcGroundContactPersonalizationTaskCost(0, ...
        "forcePlateRotation1", inputs, params, 1);
    clear calcGroundContactPersonalizationTaskCost
    return
end
fieldNameOrder = ["dampingFactor", "dynamicFrictionCoefficient", ...
    "restingSpringLength"];
if caseName == "springs"
    % Spring constants come first, in thousands of N/m.
    fieldNameOrder = ["springConstants", fieldNameOrder];
end
truthValues = designVariables(synthetic.(caseName), fieldNameOrder, ...
    inputs.numSpringMarkers);
startValues = designVariables(synthetic.start, fieldNameOrder, ...
    inputs.numSpringMarkers);
result.truthCost = calcGroundContactPersonalizationTaskCost( ...
    truthValues, fieldNameOrder, inputs, params, 1);
result.startCost = calcGroundContactPersonalizationTaskCost( ...
    startValues, fieldNameOrder, inputs, params, 1);
clear calcGroundContactPersonalizationTaskCost
end

% (struct, string array, double) -> (Array)
% The design variable vector GCP's optimizer would pass for these values,
% with every spring at the one spring constant.
function values = designVariables(source, fieldNameOrder, numSprings)
values = [];
for name = fieldNameOrder
    if name == "springConstants"
        values = [values, 0.001 * source.springConstant * ...
            ones(1, numSprings)];
    else
        values = [values, source.(name)];
    end
end
end
