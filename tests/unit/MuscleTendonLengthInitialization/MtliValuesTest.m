% Tests for how Muscle-Tendon Length Initialization (MTLI) unpacks its
% design vector, computes maximum isometric force, and hands its result to
% MTP (src/MuscleTendonLengthInitialization).
%
% MTLI's design vector is laid out as
%   [optimal fiber length (n), tendon slack length (n),
%    maximum normalized fiber length (one per group, then one per
%    ungrouped muscle), maximum muscle stress scale factor (if optimized)]
% where the lengths are scale factors, or absolute lengths when
% <optimize_absolute_length_changes> is true.

classdef (TestTags = {'Unit'}) MtliValuesTest < matlab.unittest.TestCase

    properties
        data
    end

    methods (TestMethodSetup)
        function makeTwoMuscleInputs(testCase)
            % Two muscles: one fiber length group plus one ungrouped muscle
            % gives two maximum normalized fiber length values.
            testCase.data.muscleNames = ["a", "b"];
            testCase.data.optimalFiberLength = [0.1, 0.2];
            testCase.data.tendonSlackLength = [0.3, 0.4];
            testCase.data.maxIsometricForce = [1000, 2000];
            testCase.data.maximumMuscleStress = 610e3;
            % As parseMuscleTendonLengthInitializationSettingsTree computes
            testCase.data.muscleVolume = testCase.data.maxIsometricForce ...
                / testCase.data.maximumMuscleStress .* ...
                testCase.data.optimalFiberLength;
            testCase.data.numMuscleGroups = 1;
            testCase.data.numMusclesIndividual = 1;
            testCase.data.maximumMuscleStressIsIncluded = true;
            testCase.data.useAbsoluteLengths = false;
            testCase.data.optimizeIsometricMaxForce = true;
        end
    end

    methods (Test)
        function scaleFactorLayout(testCase)
            [values, data] = makeMuscleTendonLengthInitializationValuesAsStruct( ...
                [1.1, 1.2, 0.9, 0.8, 1.05, 1.15, 1.3], testCase.data);
            testCase.verifyEqual(values.optimalFiberLengthScaleFactors, ...
                [1.1, 1.2]);
            testCase.verifyEqual(values.tendonSlackLengthScaleFactors, ...
                [0.9, 0.8]);
            testCase.verifyEqual(values.maxNormalizedFiberLength, ...
                [1.05, 1.15]);
            testCase.verifyEqual(values.maximumMuscleStressScaleFactor, 1.3);
            testCase.verifyEqual(data, testCase.data);
        end

        function stressScaleIsOneWhenNotOptimized(testCase)
            testCase.data.maximumMuscleStressIsIncluded = false;
            values = makeMuscleTendonLengthInitializationValuesAsStruct( ...
                [1, 1, 1, 1, 1.05, 1.15], testCase.data);
            testCase.verifyEqual(values.maximumMuscleStressScaleFactor, 1);
        end

        function absoluteLengthsReplaceModelLengths(testCase)
            % With absolute lengths the design values are the lengths
            % themselves, and the scale factors are 1.
            testCase.data.useAbsoluteLengths = true;
            [values, data] = makeMuscleTendonLengthInitializationValuesAsStruct( ...
                [0.11, 0.19, 0.31, 0.42, 1.05, 1.15, 1], testCase.data);
            testCase.verifyEqual(data.optimalFiberLength, [0.11, 0.19]);
            testCase.verifyEqual(data.tendonSlackLength, [0.31, 0.42]);
            testCase.verifyEqual(values.optimalFiberLengthScaleFactors, ...
                [1, 1]);
            testCase.verifyEqual(values.tendonSlackLengthScaleFactors, ...
                [1, 1]);
        end

        function maxForceIsUnchangedAtInitialValues(testCase)
            % Volume = F0 / stress * optimal length, so recomputing F0
            % from it with no changes gives F0 back.
            values = unscaledValues();
            testCase.verifyEqual(getMaxIsometricForce(testCase.data, ...
                values), [1000, 2000], "RelTol", 1e-12);
        end

        function longerFibersOfSameVolumeAreWeaker(testCase)
            % Same volume over twice the fiber length is half the
            % cross-sectional area, so half the force.
            values = unscaledValues();
            values.optimalFiberLengthScaleFactors = [2, 1];
            testCase.verifyEqual(getMaxIsometricForce(testCase.data, ...
                values), [500, 2000], "RelTol", 1e-12);
        end

        function maxForceScalesWithMuscleStress(testCase)
            values = unscaledValues();
            values.maximumMuscleStressScaleFactor = 1.5;
            testCase.verifyEqual(getMaxIsometricForce(testCase.data, ...
                values), [1500, 3000], "RelTol", 1e-12);
        end

        function maxForceIsKeptWhenNotOptimized(testCase)
            testCase.data.optimizeIsometricMaxForce = false;
            values = unscaledValues();
            values.optimalFiberLengthScaleFactors = [2, 2];
            testCase.verifyEqual(getMaxIsometricForce(testCase.data, ...
                values), [1000, 2000]);
        end

        function mtpStartsFromScaledLengths(testCase)
            mtpInputs.optimalFiberLength = [0, 0];
            mtpInputs.tendonSlackLength = [0, 0];
            mtpInputs.maxIsometricForce = [0, 0];
            mtpInputs.other = "unchanged";
            mtpInputs = updateMtpInitialGuess(mtpInputs, testCase.data, ...
                [2, 1, 0.5, 1, 1.05, 1.15, 1]);
            testCase.verifyEqual(mtpInputs.optimalFiberLength, [0.2, 0.2], ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(mtpInputs.tendonSlackLength, [0.15, 0.4], ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(mtpInputs.maxIsometricForce, [500, 2000], ...
                "RelTol", 1e-12);
            testCase.verifyEqual(mtpInputs.other, "unchanged");
        end

        function ncpUpdatesOnlyMusclesWithoutMtpResults(testCase)
            % In NCP, MTLI only replaces the lengths and forces of muscles
            % MTP did not personalize. Muscle a has MTP activations, so it
            % keeps its values; muscle b gets MTLI's.
            ncpInputs.muscleTendonColumnNames = ["a", "b"];
            ncpInputs.mtpActivationsColumnNames = "a";
            ncpInputs.optimalFiberLength = [0.5, 0.5];
            ncpInputs.tendonSlackLength = [0.6, 0.6];
            ncpInputs.maxIsometricForce = [7, 7];
            ncpInputs = updateNcpInitialGuess(ncpInputs, testCase.data, ...
                [2, 1.5, 0.5, 1.2, 1.05, 1.15, 1]);
            testCase.verifyEqual(ncpInputs.optimalFiberLength, [0.5, 0.3], ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(ncpInputs.tendonSlackLength, [0.6, 0.48], ...
                "AbsTol", 1e-12);
            % Same volume over 1.5 times the fiber length: F0 / 1.5.
            testCase.verifyEqual(ncpInputs.maxIsometricForce, ...
                [7, 2000 / 1.5], "RelTol", 1e-12);
        end

        function ncpWithoutMtpResultsUpdatesEveryMuscle(testCase)
            ncpInputs.muscleTendonColumnNames = ["a", "b"];
            ncpInputs.optimalFiberLength = [0.5, 0.5];
            ncpInputs.tendonSlackLength = [0.6, 0.6];
            ncpInputs.maxIsometricForce = [7, 7];
            ncpInputs = updateNcpInitialGuess(ncpInputs, testCase.data, ...
                [2, 1.5, 0.5, 1.2, 1.05, 1.15, 1]);
            testCase.verifyEqual(ncpInputs.optimalFiberLength, [0.2, 0.3], ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(ncpInputs.maxIsometricForce, ...
                [500, 2000 / 1.5], "RelTol", 1e-12);
        end

        function mtpStartsFromAbsoluteLengths(testCase)
            testCase.data.useAbsoluteLengths = true;
            mtpInputs = updateMtpInitialGuess(struct(), testCase.data, ...
                [0.11, 0.19, 0.31, 0.42, 1.05, 1.15, 1]);
            testCase.verifyEqual(mtpInputs.optimalFiberLength, [0.11, 0.19]);
            testCase.verifyEqual(mtpInputs.tendonSlackLength, [0.31, 0.42]);
        end
    end
end

function values = unscaledValues()
values.optimalFiberLengthScaleFactors = [1, 1];
values.tendonSlackLengthScaleFactors = [1, 1];
values.maximumMuscleStressScaleFactor = 1;
end
