% Tests for Muscle-Tendon Length Initialization's cost terms
% (src/MuscleTendonLengthInitialization/CostComputations) and the function
% that collects them, calcMuscleTendonLengthInitializationCost.
%
% MTLI uses lsqnonlin, so each term returns a vector of residuals r rather
% than a number; lsqnonlin minimizes sum(r.^2). Every term scales its
% residuals so that sum(r.^2) is the mean of ((value - center) / allowable
% error)^2, the same quantity MTP's terms return. The tests check sum(r.^2)
% against that, worked out by hand.

classdef (TestTags = {'Unit'}) MtliCostTermsTest < matlab.unittest.TestCase

    methods (Test)
        % ---- residual formulas ------------------------------------------

        function deviationResidualsGiveMeanSquare(testCase)
            % Values 0.1, 0.3 around 0.1, allowable error 0.1:
            % (0^2 + 2^2) / 2 = 2
            r = calcDeviationCostArray([0.1, 0.3], 0.1, 0.1);
            testCase.verifySize(r, [2, 1]);
            testCase.verifyEqual(sum(r .^ 2), 2, "AbsTol", 1e-12);
        end

        function trackingResidualsGiveMeanSquare(testCase)
            % Errors 1, 2, 3, allowable error 2: 3.5 / 3
            r = calcTrackingCostArray([1, 2, 3], [0, 0, 0], 0, 2);
            testCase.verifyEqual(sum(r .^ 2), 3.5 / 3, "AbsTol", 1e-12);
        end

        % ---- parameter terms --------------------------------------------

        function optimalFiberLengthScaleDefaults(testCase)
            % Default center 1, allowable error 0.3: (1^2 + 0) / 2
            values.optimalFiberLengthScaleFactors = [1.3, 1];
            r = calcOptimalFiberLengthScaleFactorDeviationCost(values, ...
                struct());
            testCase.verifyEqual(sum(r .^ 2), 0.5, "AbsTol", 1e-12);
        end

        function tendonSlackLengthScaleDefaults(testCase)
            % Default center 1, allowable error 1: (0.5^2 + 0) / 2
            values.tendonSlackLengthScaleFactors = [1.5, 1];
            r = calcTendonSlackLengthScaleFactorDeviationCost(values, ...
                struct());
            testCase.verifyEqual(sum(r .^ 2), 0.125, "AbsTol", 1e-12);
        end

        function absoluteLengthDeviationsFromInitialLengths(testCase)
            % 0.01 m changes, default allowable error 0.05 m:
            % (0.2^2 + 0) / 2 = 0.02 each
            data.optimalFiberLength = [0.11, 0.2];
            data.initialOptimalFiberLength = [0.1, 0.2];
            data.tendonSlackLength = [0.3, 0.39];
            data.initialTendonSlackLength = [0.3, 0.4];
            r = calcOptimalFiberLengthAbsoluteDeviationCost(data, struct());
            testCase.verifyEqual(sum(r .^ 2), 0.02, "AbsTol", 1e-12);
            r = calcTendonSlackLengthAbsoluteDeviationCost(data, struct());
            testCase.verifyEqual(sum(r .^ 2), 0.02, "AbsTol", 1e-12);
        end

        function muscleStressDefaults(testCase)
            % Default center 1.2, allowable error 0.1: ((1 - 1.2) / 0.1)^2
            values.maximumMuscleStressScaleFactor = 1;
            r = calcMaximumMuscleStressPenaltyCost(values, struct());
            testCase.verifyEqual(sum(r .^ 2), 4, "AbsTol", 1e-12);
        end

        % ---- modeled value terms ----------------------------------------

        function passiveForceDefaults(testCase)
            % Default allowable error 10 N: (0 + 2^2) / 2
            modeled.passiveForce = [0, 20];
            r = calcPassiveForcePenaltyCost(modeled, struct());
            testCase.verifyEqual(sum(r .^ 2), 2, "AbsTol", 1e-12);
        end

        function minimumFiberLengthPenalizesShortfall(testCase)
            % Limit 0.6. Muscle 1's shortest fiber is 0.1 short, muscle
            % 2's is above the limit. Default allowable error 0.3:
            % ((0.1 / 0.3)^2 + 0) / 2. Unlike MTP's term, this grows from
            % 0 at the limit.
            data = twoMuscleData();
            data.minNormalizedMuscleFiberLength = 0.6;
            modeled.normalizedFiberLength = cat(2, ...
                reshape([0.5, 1], 1, 1, 2), reshape([0.8, 1], 1, 1, 2));
            r = calcMinimumNormalizedFiberLengthDeviationCost(modeled, ...
                data, struct());
            testCase.verifyEqual(sum(r .^ 2), (0.1 / 0.3) ^ 2 / 2, ...
                "AbsTol", 1e-12);
        end

        function maximumFiberLengthTracksItsDesignValue(testCase)
            % Each muscle's longest fiber should match the maximum length
            % design value of its group: [1.1 0.9] vs [1.0 0.95]. Default
            % allowable error 0.03: ((0.1 / 0.03)^2 + (0.05 / 0.03)^2) / 2
            data.groupedMaxNormalizedFiberLength = [1, 2];
            values.maxNormalizedFiberLength = [1, 0.95];
            modeled.normalizedFiberLength = cat(2, ...
                reshape([1, 1.1], 1, 1, 2), reshape([0.9, 0.8], 1, 1, 2));
            r = calcMaximumNormalizedFiberLengthDeviationCost(modeled, ...
                values, data, struct());
            testCase.verifyEqual(sum(r .^ 2), ((0.1 / 0.03) ^ 2 + ...
                (0.05 / 0.03) ^ 2) / 2, "AbsTol", 1e-9);
        end

        function groupedMaximumFiberLengthTracksSetting(testCase)
            % Muscles 1 and 2 share design value 1.1, muscle 3 has 1.0;
            % the setting is 1. Default allowable error 0.1:
            % (1 + 1 + 0) / 3
            data.maxNormalizedMuscleFiberLength = 1;
            data.groupedMaxNormalizedFiberLength = [1, 1, 2];
            values.maxNormalizedFiberLength = [1.1, 1];
            r = calcMaximumNormalizedFiberLengthSimilarityCost(values, ...
                data, struct());
            testCase.verifyEqual(sum(r .^ 2), 2 / 3, "AbsTol", 1e-12);
        end

        function groupedFiberLengthsPenalizeLargestDifference(testCase)
            % Two grouped muscles at constant 1.0 and 1.2: each is 0.1
            % from the group mean. The soft maximum over frames is 0.1 to
            % within log(3) / 500, so sum(r.^2) is about (1 + 1) / 2.
            data.normalizedFiberLengthGroups = {[1, 2]};
            modeled.normalizedFiberLength = cat(2, ones(1, 1, 3), ...
                1.2 * ones(1, 1, 3));
            r = calcNormalizedFiberLengthMeanSimilarityCost(modeled, ...
                data, struct());
            testCase.verifyEqual(sum(r .^ 2), 1, "AbsTol", 0.05);
        end

        function passiveMomentTrackingSkipsEmptyCoordinates(testCase)
            % Coordinate 2 has no passive moment data (all zeros), so it
            % is skipped even though the model predicts a moment there.
            % Coordinate 1 is off by 2 Nm, the default allowable error.
            [data, modeled] = passiveMoments(101);
            r = calcPassiveMomentTrackingCost(modeled, data, struct());
            testCase.verifyEqual(sum(r .^ 2), 1, "AbsTol", 1e-12);
        end

        function passiveMomentTrackingWorksForAnyTrialLength(testCase)
            % Same as above with 50 frames per passive trial. Expected to
            % fail: the frame count is fixed at 101 in the code. See
            % tests/README.md.
            [data, modeled] = passiveMoments(50);
            r = calcPassiveMomentTrackingCost(modeled, data, struct());
            testCase.verifyEqual(sum(r .^ 2), 1, "AbsTol", 1e-12);
        end

        % ---- collecting the terms ---------------------------------------

        function enabledTermsAreStacked(testCase)
            % The result starts with a 0 and then each enabled term's
            % residuals, so the total sum of squares is the sum of terms.
            values.optimalFiberLengthScaleFactors = [1.3, 1];
            values.maximumMuscleStressScaleFactor = 1;
            data = twoMuscleData();
            data.costTerms = {term("optimal_muscle_fiber_length", true, ...
                0.3, 1), term("maximum_muscle_stress", true, 0.1, 1.2), ...
                term("tendon_slack_length", false, 1, 1)};
            r = calcMuscleTendonLengthInitializationCost(values, ...
                struct(), data);
            testCase.verifySize(r, [1 + 2 + 1, 1]);
            testCase.verifyEqual(sum(r .^ 2), 0.5 + 4, "AbsTol", 1e-12);
        end

        function absoluteLengthsSwitchTheLengthTerms(testCase)
            data = twoMuscleData();
            data.useAbsoluteLengths = true;
            data.optimalFiberLength = [0.11, 0.2];
            data.initialOptimalFiberLength = [0.1, 0.2];
            data.costTerms = {term("optimal_muscle_fiber_length", true, ...
                0.05, 0)};
            r = calcMuscleTendonLengthInitializationCost(struct(), ...
                struct(), data);
            testCase.verifyEqual(sum(r .^ 2), 0.02, "AbsTol", 1e-12);
        end

        function passiveMomentTermNeedsPassiveData(testCase)
            data = twoMuscleData();
            data.costTerms = {term("passive_joint_moment", true, 2, 0)};
            verifyErrorMessage(testCase, ...
                @() calcMuscleTendonLengthInitializationCost(struct(), ...
                struct(), data), "without passive data");
        end

        function unknownTermIsReported(testCase)
            % Expected to fail on candidate-1.5.4: the message is built
            % from "type", which is not a variable there, so MATLAB calls
            % its built-in type function and fails with "Too many output
            % arguments." instead. See tests/README.md.
            data = twoMuscleData();
            data.costTerms = {term("not_a_term", true, 1, 0)};
            verifyErrorMessage(testCase, ...
                @() calcMuscleTendonLengthInitializationCost(struct(), ...
                struct(), data), ...
                "not valid for Muscle Tendon Length Initialization");
        end
    end
end

function data = twoMuscleData()
data.muscleNames = ["a", "b"];
data.muscleTendonLength = zeros(1, 2, 2);
data.useAbsoluteLengths = false;
end

function [data, modeled] = passiveMoments(numFrames)
% One passive trial, two coordinates: data on coordinate 1 only.
data.passiveData.inverseDynamicsMoments = zeros(1, 2, numFrames);
data.passiveData.inverseDynamicsMoments(1, 1, :) = 5;
modeled.passiveModelMoments = zeros(1, 2, numFrames);
modeled.passiveModelMoments(1, 1, :) = 7;
modeled.passiveModelMoments(1, 2, :) = 3;
end

function costTerm = term(type, isEnabled, maxAllowableError, errorCenter)
costTerm = struct("type", type, "isEnabled", isEnabled, ...
    "maxAllowableError", maxAllowableError, "errorCenter", errorCenter);
end
