% Checks the synthetic known-truth NCP data in tests/data/ncp/synthetic,
% written by generateNcpSyntheticData from the true synergies in
% ncpFixtureValues().synthetic. If these fail, the regression tests that
% try to recover the truth cannot be trusted.
%
% - Each case's preprocessed data differs from tests/data/ncp/preprocessed
%   only in the tracked inverse dynamics moments.
% - Its MTP activations are the true activations (B * nodes * weights),
%   without iliacus_r in iliacus_hidden.
% - The true activations reproduce the moments through the muscle model.

classdef (TestTags = {'Unit'}) NcpSyntheticDataTest < matlab.unittest.TestCase

    properties
        expected
        truth % (frame x muscle) true activations
    end

    properties (TestParameter)
        syntheticCase = {"all_tracked", "iliacus_hidden", "fixed_weights"}
    end

    methods (TestClassSetup)
        function loadFixtures(testCase)
            files = dir(testDataPath("ncp", "settings", ...
                "settings_synthetic_*.xml"));
            setUpNcpWorkingFolder(testCase, string({files.name}));
            testCase.expected = ncpFixtureValues();
            testCase.truth = trueActivations(testCase.expected.synthetic);
        end
    end

    methods (Test)
        function trueActivationsArePlausible(testCase)
            % Between 0 and 1, and not all near zero.
            testCase.verifyGreaterThan(testCase.truth, 0);
            testCase.verifyLessThan(testCase.truth, 1);
            testCase.verifyGreaterThan(max(testCase.truth, [], "all"), 0.3);
        end

        function onlyTrackedMomentsDifferFromSource(testCase, syntheticCase)
            source = testDataPath("ncp", "preprocessed");
            synthetic = testDataPath("ncp", "synthetic", syntheticCase, ...
                "preprocessed");
            for file = dir(fullfile(source, "**", "*.sto"))'
                relative = erase(fullfile(file.folder, file.name), ...
                    string(source) + filesep);
                if ~startsWith(relative, "IDData")
                    testCase.verifyEqual(fileread(fullfile(synthetic, ...
                        relative)), fileread(fullfile(source, relative)), ...
                        relative);
                    continue
                end
                [sourceData, names] = readStoFile(fullfile(source, relative));
                syntheticData = readStoFile(fullfile(synthetic, relative));
                tracked = ismember(names, ...
                    testCase.expected.coordinateNames + "_moment");
                testCase.verifyEqual(syntheticData(:, ~tracked), ...
                    sourceData(:, ~tracked), "AbsTol", 1e-12);
                testCase.verifyNotEqual(syntheticData(:, tracked), ...
                    sourceData(:, tracked));
            end
        end

        function mtpActivationsAreTheTruth(testCase, syntheticCase)
            [data, names] = readStoFile(testDataPath("ncp", "synthetic", ...
                syntheticCase, "mtpResults", "muscleActivations", ...
                "gait_1_muscleActivations.sto"));
            muscles = testCase.expected.muscleNames;
            if syntheticCase == "iliacus_hidden"
                muscles = muscles(muscles ~= "iliacus_r");
            end
            testCase.verifyEqual(names(2 : end), muscles);
            [~, columns] = ismember(muscles, testCase.expected.muscleNames);
            testCase.verifyEqual(data(:, 2 : end), ...
                testCase.truth(:, columns), "AbsTol", 1e-12);
        end

        function fixedWeightsFileHoldsTheTrueWeights(testCase)
            [data, names] = readStoFile(testDataPath("ncp", "synthetic", ...
                "fixed_weights", "preprocessed", "synergyWeights.sto"));
            testCase.verifyEqual(names(2 : end), testCase.expected.muscleNames);
            testCase.verifyEqual(data(:, 2 : end), ...
                testCase.expected.synthetic.weights, "AbsTol", 1e-12);
        end

        function truthReproducesItsMoments(testCase, syntheticCase)
            % The muscle model at the true activations gives the ID
            % moments NCP will track.
            inputs = parseNeuralControlPersonalizationSettingsTree( ...
                xml2struct("settings_synthetic_" + syntheticCase + ".xml"));
            [lengths, velocities] = ...
                calcNormalizedMuscleFiberLengthsAndVelocities(inputs, ...
                inputs.optimalFiberLengthScaleFactors, ...
                inputs.tendonSlackLengthScaleFactors);
            moments = calcMuscleJointMoments(inputs, ...
                permute(testCase.truth, [3, 2, 1]), lengths, velocities);
            testCase.verifyEqual(moments, inputs.inverseDynamicsMoments, ...
                "AbsTol", 1e-9);
        end
    end
end

function activations = trueActivations(synthetic)
percent = linspace(0, 100, 101)';
B = BSplineMatrices(3, synthetic.numNodes, 101, percent(2) - percent(1));
activations = B * synthetic.commandNodes * synthetic.weights;
end
