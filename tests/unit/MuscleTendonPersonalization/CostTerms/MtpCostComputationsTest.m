% Tests for the building blocks of MTP's cost terms in
% src/MuscleTendonPersonalization/Optimization/CostComputations: the
% tracking and deviation formulas, and the group, magnitude and shape
% comparisons the grouped terms use. Expected values are worked out by
% hand in the comments.
%
% Arrays follow MTP's layout: (trial x muscle x frame).

classdef (TestTags = {'Unit'}) MtpCostComputationsTest < matlab.unittest.TestCase

    methods (Test)
        function trackingCostIsMeanSquaredScaledError(testCase)
            % Errors 1, 2, 3 with allowable error 2:
            % ((1/2)^2 + (2/2)^2 + (3/2)^2) / 3 = 3.5 / 3
            cost = calcTrackingCostTerm([1, 2, 3], [0, 0, 0], 0, 2);
            testCase.verifyEqual(cost, 3.5 / 3, "AbsTol", 1e-12);
        end

        function trackingCostSubtractsErrorCenter(testCase)
            % Errors 1, 3 around a center of 1: (0^2 + 2^2) / 2 = 2
            cost = calcTrackingCostTerm([2, 4], [1, 1], 1, 1);
            testCase.verifyEqual(cost, 2, "AbsTol", 1e-12);
        end

        function trackingCostIgnoresNaNButCountsIt(testCase)
            % A NaN (e.g. missing data) adds nothing but still counts in
            % the mean: (2^2 + 0) / 2 = 2
            cost = calcTrackingCostTerm([2, NaN], [0, 0], 0, 1);
            testCase.verifyEqual(cost, 2, "AbsTol", 1e-12);
        end

        function deviationCostIsMeanSquaredScaledDeviation(testCase)
            % Values 0.1, 0.3 around 0.1 with allowable error 0.1:
            % (0^2 + 2^2) / 2 = 2
            cost = calcDeviationCostTerm([0.1, 0.3], 0.1, 0.1);
            testCase.verifyEqual(cost, 2, "AbsTol", 1e-12);
        end

        function deviationCostOfMatrixUsesEveryElement(testCase)
            % 4 elements, one of them 1 away: 1 / 4
            cost = calcDeviationCostTerm([0, 1; 0, 0], 0, 1);
            testCase.verifyEqual(cost, 0.25, "AbsTol", 1e-12);
        end

        function groupDifferencesAreFromEachGroupMean(testCase)
            % Groups {1, 2} and {3}: [0.2 0.4] - 0.3 and 0.9 - 0.9
            differences = calcDifferencesInEmgGroups([0.2, 0.4, 0.9], ...
                {[1, 2], 3});
            testCase.verifyEqual(differences, [-0.1, 0.1, 0], ...
                "AbsTol", 1e-12);
        end

        function groupsWithoutFirstMuscleCompareTheRightMuscles(testCase)
            % Group indices are positions among the model's muscles
            % (groupNamesToGroups). For the fixture model those are also
            % positions in MTP's muscle list (see
            % groupIndicesArePositionsInMuscleList). A group of muscles 2
            % and 3 must compare values 2 and 3: [20 35] - 27.5.
            % Expected to fail: the indices are shifted down by the lowest
            % grouped index minus 1, which compares muscles 1 and 2
            % instead whenever no group contains muscle 1. See
            % tests/README.md.
            differences = calcDifferencesInEmgGroups([10, 20, 35, 40], ...
                {[2, 3]});
            testCase.verifyEqual(differences, [-7.5, 7.5], "AbsTol", 1e-12);
        end

        function groupIndicesArePositionsInMuscleList(testCase)
            % For the fixture model, groupNamesToGroups gives each member's
            % position in mtpFixtureValues().muscleNames.
            values = mtpFixtureValues();
            groups = groupNamesToGroups(["HamslatActivationGroupR", ...
                "GasActivationGroupR", "VasActivationGroupR"], ...
                testDataPath("mtp", values.modelFileName));
            position = @(name) find(values.muscleNames == name);
            testCase.verifyEqual(groups, {[position("bflh_r"), ...
                position("bfsh_r")], position("gasmed_r"), ...
                position("vasmed_r")});
        end

        function magnitudeDeviationIsChangeInTrialMean(testCase)
            % Two trials; the trial means change by 0.1 and 0.
            original = cat(1, [1, 2], [3, 4]);
            optimized = cat(1, [1.1, 2], [3.1, 4]);
            testCase.verifyEqual(calcMagnitudeDeviations(optimized, ...
                original), [0.1, 0], "AbsTol", 1e-12);
        end

        function shapeDeviationIgnoresAConstantShift(testCase)
            % Muscle 1 shifts by a constant (same shape), muscle 2 changes
            % shape: [1 2 3] -> [1 1 4], whose mean-removed shape is
            % [-1 -1 2] instead of [-1 0 1].
            original = reshape([1, 1; 2, 2; 3, 3]', 1, 2, 3);
            optimized = reshape([1.5, 1; 2.5, 1; 3.5, 4]', 1, 2, 3);
            deviations = calcShapeDeviations(optimized, original);
            testCase.verifyEqual(squeeze(deviations(1, 1, :))', ...
                [0, 0, 0], "AbsTol", 1e-12);
            testCase.verifyEqual(squeeze(deviations(1, 2, :))', ...
                [0, -1, 1], "AbsTol", 1e-12);
        end

        function meanDeviationIsChangeRelativeToGroup(testCase)
            % Muscle means change by 0.2 and 0; the group's average change
            % is 0.1, so each muscle is 0.1 above or below it.
            original = ones(1, 2, 3);
            optimized = original;
            optimized(1, 1, :) = 1.2;
            testCase.verifyEqual(calcMeanDeviations(optimized, original), ...
                [0.1, -0.1], "AbsTol", 1e-12);
        end

        function meanShapeDeviationIsFromGroupMeanShape(testCase)
            % Muscle 1 [1 3] has shape [-1 1]; muscle 2 [2 2] has shape
            % [0 0]. The group's mean shape is [-0.5 0.5].
            curves = reshape([1, 2; 3, 2], 1, 2, 2);
            deviations = calcMeanShapeDeviations(curves);
            testCase.verifyEqual(squeeze(deviations), [-0.5, 0.5; 0.5, ...
                -0.5], "AbsTol", 1e-12);
        end
    end
end
