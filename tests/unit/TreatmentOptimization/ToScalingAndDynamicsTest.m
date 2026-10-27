% Tests for the small functions Treatment Optimization uses to move between
% GPOPS-II's scaled variables and real values, and to form its dynamic
% constraint (src/TreatmentOptimization): scaleToBounds, scaleToOriginal,
% calcDynamicConstraint, getCorrectStates, subsetDataByCoordinates and
% transferMoments. Expected values are worked out by hand.
%
% GPOPS-II works with every variable scaled to [-0.5, 0.5] across its
% bounds: scaled = (value - midpoint) / range.

classdef (TestTags = {'Unit'}) ToScalingAndDynamicsTest < matlab.unittest.TestCase

    methods (Test)
        function boundsScaleToPlusMinusOneHalf(testCase)
            % Bounds [0, 10]: midpoint 5, range 10.
            testCase.verifyEqual(scaleToBounds([0, 5, 10, 7.5], 10, 0), ...
                [-0.5, 0, 0.5, 0.25], "AbsTol", 1e-15);
        end

        function scalingIsPerColumn(testCase)
            % Each column has its own bounds.
            value = [1, 30; 3, 10];
            scaled = scaleToBounds(value, [3, 30], [1, 10]);
            testCase.verifyEqual(scaled, [-0.5, 0.5; 0.5, -0.5], ...
                "AbsTol", 1e-15);
        end

        function scaleToOriginalUndoesScaling(testCase)
            value = [-2.5, 0.1, 7; 4, -1, 0];
            maximum = [3, 1, 10];
            minimum = [-3, -2, 0];
            testCase.verifyEqual(scaleToOriginal(scaleToBounds(value, ...
                maximum, minimum), maximum, minimum), value, ...
                "AbsTol", 1e-14);
        end

        function scaledZeroIsTheMidpoint(testCase)
            testCase.verifyEqual(scaleToOriginal(0, 4, -2), 1);
        end

        function dynamicConstraintIsScaledDerivatives(testCase)
            % GPOPS-II's dynamics are d(scaled state) / d(scaled time):
            % [velocities, accelerations] * (time range) ./ (state
            % range). Two coordinates: positions in [0, 2] and [-1, 1],
            % velocities in [-5, 5] and [0, 4]; time [0, 0.5].
            values.stateVelocities = [1, 2; 3, 4];
            values.controlAccelerations = [10, 20; 30, 40];
            params.maxTime = 0.5;
            params.minTime = 0;
            params.maxState = [2, 1, 5, 4];
            params.minState = [0, -1, -5, 0];
            dynamics = calcDynamicConstraint(values, params);
            testCase.verifyEqual(dynamics, 0.5 * [1/2, 2/2, 10/10, 20/4; ...
                3/2, 4/2, 30/10, 40/4], "AbsTol", 1e-14);
        end

        function correctStatesPicksABlockOfColumns(testCase)
            % The state is [positions, velocities], numCoordinates wide
            % each.
            state = [1 2 3 4 5 6; 7 8 9 10 11 12];
            testCase.verifyEqual(getCorrectStates(state, 1, 3), ...
                [1 2 3; 7 8 9]);
            testCase.verifyEqual(getCorrectStates(state, 2, 3), ...
                [4 5 6; 10 11 12]);
        end

        function subsetKeepsTheRequestedOrder(testCase)
            data = [1 2 3; 4 5 6];
            names = ["a", "b", "c"];
            testCase.verifyEqual(subsetDataByCoordinates(data, names, ...
                ["c", "a"]), [3 1; 6 4]);
        end

        function subsetReportsAMissingCoordinate(testCase)
            verifyErrorMessage(testCase, @() subsetDataByCoordinates( ...
                [1 2], ["a", "b"], "z"), "z is not a coordinate");
        end

        function transferredMomentAddsLeverArmCrossForce(testCase)
            % Moving the point from (1, 0, 0) to the origin adds
            % r x F = (1, 0, 0) x (0, 10, 0) = (0, 0, 10).
            moment = transferMoments([1, 0, 0], [0, 0, 0], [1, 2, 3], ...
                [0, 10, 0]);
            testCase.verifyEqual(moment, [1, 2, 13], "AbsTol", 1e-14);
        end
    end
end
