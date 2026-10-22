% Tests for MTP's cost terms in
% src/MuscleTendonPersonalization/Optimization/CostTerms, using the
% candidate-1.5.4 names and behavior. Each term is called with small values
% whose cost is worked out by hand in the comments.
%
% Defaults: each term has a default error center and allowable error, used
% when its costTerm struct lacks the field. When MTP runs from a settings
% file, parseRcnlCostTermSet always sets errorCenter (to 0 if the file has
% no <error_center>), so the default error centers tested here only apply
% when a term is called directly.

classdef (TestTags = {'Unit'}) MtpCostTermsTest < matlab.unittest.TestCase

    methods (Test)
        % ---- parameter deviation terms ----------------------------------

        function activationTimeConstantDefaults(testCase)
            % Time constants are stored x100: 1.5, 2.5 -> 0.015, 0.025 s.
            % Default center 0.015, allowable error 0.02:
            % (0^2 + 0.5^2) / 2 = 0.125
            values.activationTimeConstants = [1.5, 2.5];
            testCase.verifyEqual(calcActivationTimeConstantDeviationCost( ...
                values, struct()), 0.125, "AbsTol", 1e-12);
        end

        function activationTimeConstantWithParsedZeroCenter(testCase)
            % As parsed from a file without <error_center>: center 0.
            % (0.75^2 + 1.25^2) / 2 = 1.0625
            values.activationTimeConstants = [1.5, 2.5];
            costTerm = struct("errorCenter", 0, "maxAllowableError", 0.02);
            testCase.verifyEqual(calcActivationTimeConstantDeviationCost( ...
                values, costTerm), 1.0625, "AbsTol", 1e-12);
        end

        function activationNonlinearityDefaults(testCase)
            % Default center 0, allowable error 0.1: (1^2 + 3^2) / 2 = 5
            values.activationNonlinearityConstants = [0.1, 0.3];
            testCase.verifyEqual(calcActivationNonlinearityDeviationCost( ...
                values, struct()), 5, "AbsTol", 1e-12);
        end

        function emgScaleFactorDefaults(testCase)
            % Default center 0.3, allowable error 0.2: (0^2 + 1^2) / 2
            values.emgScaleFactors = [0.3, 0.5];
            testCase.verifyEqual(calcEmgScaleFactorDevationCost(values, ...
                struct()), 0.5, "AbsTol", 1e-12);
        end

        function electromechanicalDelayIsChangeFromTaskStart(testCase)
            % experimentalData.electromechanicalDelays holds the values at
            % the start of the task. Changes +-0.1, allowable error 0.1:
            % (1 + 1) / 2 = 1
            values.electromechanicalDelays = [0.6, 0.4];
            data.electromechanicalDelays = [0.5, 0.5];
            testCase.verifyEqual(calcElectromechanicalDelayDeviationCost( ...
                values, data, struct()), 1, "AbsTol", 1e-12);
        end

        function optimalFiberLengthIsChangeInMeters(testCase)
            % 0.1 m scaled by 1.1 is a 0.01 m change; allowable error
            % 0.1 m: ((0.01 / 0.1)^2 + 0) / 2 = 0.005
            values.optimalFiberLengthScaleFactors = [1.1, 1];
            data.optimalFiberLength = [0.1, 0.2];
            testCase.verifyEqual(calcOptimalFiberLengthDeviationCost( ...
                values, data, struct()), 0.005, "AbsTol", 1e-12);
        end

        function tendonSlackLengthIsChangeInMeters(testCase)
            % 0.3 m scaled by 0.9 is a -0.03 m change:
            % ((0.03 / 0.1)^2 + 0) / 2 = 0.045
            values.tendonSlackLengthScaleFactors = [1, 0.9];
            data.tendonSlackLength = [0.2, 0.3];
            testCase.verifyEqual(calcTendonSlackLengthDeviationCost( ...
                values, data, struct()), 0.045, "AbsTol", 1e-12);
        end

        % ---- grouped similarity terms -----------------------------------

        function groupedEmgScaleFactorUsesActivationGroups(testCase)
            % On candidate-1.5.4 this term groups muscles by
            % activationGroups. Differences from group means
            % [-0.1 0.1 0], allowable error 0.1: (1 + 1 + 0) / 3
            values.emgScaleFactors = [0.2, 0.4, 0.9];
            data.activationGroups = {[1, 2], 3};
            testCase.verifyEqual(calcEmgScaleFactorGroupedSimilarityCost( ...
                values, data, struct()), 2 / 3, "AbsTol", 1e-12);
        end

        function groupedElectromechanicalDelayDefaults(testCase)
            % Differences [-0.2 0.2 0], allowable error 0.2: 2 / 3
            values.electromechanicalDelays = [0.3, 0.7, 0.5];
            data.activationGroups = {[1, 2], 3};
            testCase.verifyEqual( ...
                calcElectromechanicalDelayGroupedSimilarityCost(values, ...
                data, struct()), 2 / 3, "AbsTol", 1e-12);
        end

        function groupedFiberLengthComparesChangesWithinGroup(testCase)
            % Two muscles in one group with the same shape. Muscle 1's
            % curve rises by 0.1 and muscle 2's does not, so each is 0.05
            % from the group's mean change: (1^2 + 1^2) / 2 = 1 with
            % allowable error 0.05. The shapes still match, so the shape
            % part adds 0.
            data.normalizedFiberLength = repmat(reshape([1, 1.1, 1.2], ...
                1, 1, 3), 1, 2, 1);
            data.normalizedFiberLengthGroups = {[1, 2]};
            modeled.normalizedFiberLength = data.normalizedFiberLength;
            modeled.normalizedFiberLength(1, 1, :) = ...
                modeled.normalizedFiberLength(1, 1, :) + 0.1;
            testCase.verifyEqual( ...
                calcNormalizedFiberLengthGroupedSimilarityCost(modeled, ...
                data, struct()), 1, "AbsTol", 1e-12);
        end

        % ---- modeled value terms ----------------------------------------

        function momentTrackingDefaultAllowableError(testCase)
            % Error 2.5 Nm everywhere, default allowable error 2.5: 1
            modeled.muscleJointMoments = 2.5 * ones(1, 2, 3);
            data.inverseDynamicsMoments = zeros(1, 2, 3);
            testCase.verifyEqual(calcMomentTrackingCost(modeled, data, ...
                struct()), 1, "AbsTol", 1e-12);
        end

        function synergyMomentTrackingDefaultAllowableError(testCase)
            % Error 2.5 Nm, default allowable error 2: 1.25^2
            modeled.muscleJointMoments = 2.5 * ones(1, 2, 3);
            data.inverseDynamicsMoments = zeros(1, 2, 3);
            testCase.verifyEqual(calcSynergyExtrapolationMomentTrackingCost( ...
                modeled, data, struct()), 1.5625, "AbsTol", 1e-12);
        end

        function passiveForceDefaults(testCase)
            % Allowable error 50 N: (0 + 2^2) / 2 = 2
            modeled.passiveForce = [0, 100];
            testCase.verifyEqual(calcPassiveForceCost(modeled, struct()), ...
                2, "AbsTol", 1e-12);
        end

        function fiberLengthDeviationIsMagnitudePlusShape(testCase)
            % Muscle 1 shifts up by 0.1 (magnitude only), muscle 2 does
            % not change. Magnitude: 3 of 6 elements are 0.1 / 0.1 = 1,
            % so 0.5; shape: 0.
            data.normalizedFiberLength = repmat(reshape([1, 1.1, 1.2], ...
                1, 1, 3), 1, 2, 1);
            modeled.normalizedFiberLength = data.normalizedFiberLength;
            modeled.normalizedFiberLength(1, 1, :) = ...
                modeled.normalizedFiberLength(1, 1, :) + 0.1;
            testCase.verifyEqual(calcNormalizedFiberLengthDeviationCost( ...
                modeled, data, struct()), 0.5, "AbsTol", 1e-12);
        end

        function maximumFiberLengthPenaltyStartsAtTheLimit(testCase)
            % Limit 1.05. A muscle whose longest fiber is just over the
            % limit should cost about as little as one just under it.
            % Expected to fail: the penalty is the whole length (1.06),
            % not the amount over the limit, so crossing the limit jumps
            % the cost from 0 to (1.06 / 0.05)^2 = 449. See
            % tests/README.md.
            params.maxNormalizedMuscleFiberLength = 1.05;
            under.normalizedFiberLength = reshape([1, 1.04], 1, 1, 2);
            over.normalizedFiberLength = reshape([1, 1.06], 1, 1, 2);
            testCase.verifyEqual( ...
                calcMaximumNormalizedFiberLengthMtpDeviationCost(under, ...
                params, struct()), 0);
            testCase.verifyEqual( ...
                calcMaximumNormalizedFiberLengthMtpDeviationCost(over, ...
                params, struct()), (0.01 / 0.05) ^ 2, "AbsTol", 1e-9);
        end

        function minimumFiberLengthPenaltyStartsAtTheLimit(testCase)
            % Limit 0.6. Expected to fail for the same reason: the
            % shortest fiber (0.59) is penalized as a whole,
            % (0.59 / 0.05)^2 = 139, not by its 0.01 shortfall.
            params.minNormalizedMuscleFiberLength = 0.6;
            under.normalizedFiberLength = reshape([1, 0.59], 1, 1, 2);
            testCase.verifyEqual( ...
                calcMinimumNormalizedFiberLengthMtpDeviationCost(under, ...
                params, struct()), (0.01 / 0.05) ^ 2, "AbsTol", 1e-9);
        end

        function fiberLengthPenaltiesAreZeroWithinLimits(testCase)
            params.maxNormalizedMuscleFiberLength = 1.05;
            params.minNormalizedMuscleFiberLength = 0.6;
            modeled.normalizedFiberLength = reshape([0.7, 1, 1.04], ...
                1, 1, 3);
            testCase.verifyEqual( ...
                calcMaximumNormalizedFiberLengthMtpDeviationCost(modeled, ...
                params, struct()), 0);
            testCase.verifyEqual( ...
                calcMinimumNormalizedFiberLengthMtpDeviationCost(modeled, ...
                params, struct()), 0);
        end

        % ---- synergy extrapolation terms --------------------------------

        function excitationPenaltySkipsPaddingAndMissingMuscles(testCase)
            % Muscle 2 is a missing-EMG muscle and frames 1 and 3 are
            % padding, so only muscle 1, frame 2 counts: excitation 1,
            % default center 0.5 and allowable error 0.25.
            % 30 / 0.25 * 0.5^8 = 0.46875; 0.1 * 0.46875^2 = 0.02197265625
            modeled.muscleExcitationsNoTDelay = reshape([5, 5; 1, 5; ...
                5, 5]', 1, 2, 3);
            data.synergyExtrapolation.missingEmgChannelGroups = {2};
            data.numPaddingFrames = 1;
            testCase.verifyEqual(calcMuscleExcitationPenaltyCost( ...
                modeled, data, struct()), 0.02197265625, "AbsTol", 1e-12);
        end

        function residualActivationComparesMeasuredMuscles(testCase)
            % Muscle 1 differs by 0.3 between the synergy and plain
            % models; muscle 2 (missing EMG) is not compared. Default
            % allowable error 0.3: 1 per element.
            synx.muscleActivations = cat(2, 0.5 * ones(1, 1, 4), ...
                ones(1, 1, 4));
            plain.muscleActivations = cat(2, 0.2 * ones(1, 1, 4), ...
                zeros(1, 1, 4));
            data.synergyExtrapolation.missingEmgChannelGroups = {2};
            testCase.verifyEqual(calcResidualMuscleActivationCost(synx, ...
                plain, data, struct()), 1, "AbsTol", 1e-12);
        end

        function extrapolatedActivationPenalizesMissingMuscles(testCase)
            % Only muscle 2 (missing EMG) counts: activation 0.3 with
            % default allowable error 0.3 gives 1. The fiber length
            % groups include muscle 1, so no index shift applies.
            modeled.muscleActivations = cat(2, ones(1, 1, 4), ...
                0.3 * ones(1, 1, 4));
            data.synergyExtrapolation.missingEmgChannelGroups = {2};
            data.normalizedFiberLengthGroups = {1, 2};
            testCase.verifyEqual(calcSynergyExtrapolationMuscleActivationCost( ...
                modeled, data, struct()), 1, "AbsTol", 1e-12);
        end
    end
end
