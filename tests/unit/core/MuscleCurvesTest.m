% Tests for the normalized muscle curves in src/core/muscle, which MTP,
% MTLI and NCP all build on: activeForceLengthCurve, forceVelocityCurve
% and passiveForceLengthCurve.
%
% The expected values are the physical facts each curve is built to
% satisfy (e.g. full force at optimal fiber length and zero velocity, no
% force at maximum shortening velocity), not values copied from a run.

classdef (TestTags = {'Unit'}) MuscleCurvesTest < matlab.unittest.TestCase

    properties (Constant)
        % passiveForceLengthCurve coefficients, from its source. The curve
        % is the softplus e1 * log(1 + exp(e2 * (l - e3))).
        e1 = 0.232000797810576
        e2 = 12.438535493526128
        e3 = 1.329470475731338
    end

    properties (TestParameter)
        % Each curve keeps the shape of its input, e.g. the 3D
        % (trial x muscle x frame) arrays MTP passes in.
        curve = {@activeForceLengthCurve, @forceVelocityCurve, ...
            @passiveForceLengthCurve}
    end

    methods (Test)
        function activeForceIsOneAtOptimalLength(testCase)
            testCase.verifyEqual(activeForceLengthCurve(1), 1, ...
                "AbsTol", 1e-6);
        end

        function activeForcePeaksNearOptimalLength(testCase)
            % The three Gaussians overshoot slightly: the peak is 0.1%
            % above 1, about 1% past optimal length.
            lengths = linspace(0.2, 2, 18001);
            [peak, index] = max(activeForceLengthCurve(lengths));
            testCase.verifyEqual(peak, 1, "AbsTol", 2e-3);
            testCase.verifyEqual(lengths(index), 1, "AbsTol", 0.02);
        end

        function activeForceIsSmallFarFromOptimalLength(testCase)
            testCase.verifyLessThan(activeForceLengthCurve([0.4, 1.8]), ...
                0.05);
            testCase.verifyGreaterThan(activeForceLengthCurve( ...
                linspace(0, 3, 301)), 0);
        end

        function forceIsOneAtZeroVelocity(testCase)
            % Isometric: velocity scales active force by exactly 1.
            testCase.verifyEqual(forceVelocityCurve(0), 1, "AbsTol", 1e-6);
        end

        function forceIsZeroAtMaximumShorteningVelocity(testCase)
            % Normalized velocity -1 is the maximum shortening velocity.
            testCase.verifyEqual(forceVelocityCurve(-1), 0, "AbsTol", 1e-6);
        end

        function forceIncreasesWithLengtheningVelocity(testCase)
            % Shortening (v < 0) lowers force, lengthening (v > 0) raises
            % it, up to an eccentric plateau.
            velocities = linspace(-1, 5, 601);
            testCase.verifyGreaterThan(diff(forceVelocityCurve( ...
                velocities)), 0);
            testCase.verifyLessThan(forceVelocityCurve(5), 1.6);
        end

        function passiveForceIsSoftplus(testCase)
            lengths = [0.5, 1, testCase.e3, 1.5, 2];
            expected = testCase.e1 * log1p(exp(testCase.e2 * ...
                (lengths - testCase.e3)));
            testCase.verifyEqual(passiveForceLengthCurve(lengths), ...
                expected, "AbsTol", 1e-12);
        end

        function passiveForceAtCurveCenterIsE1Log2(testCase)
            testCase.verifyEqual(passiveForceLengthCurve(testCase.e3), ...
                testCase.e1 * log(2), "AbsTol", 1e-12);
        end

        function passiveForceIsNearZeroAtOptimalLength(testCase)
            % Passive force should only matter when a fiber is stretched.
            testCase.verifyLessThan(passiveForceLengthCurve(1), 0.005);
            testCase.verifyGreaterThanOrEqual(passiveForceLengthCurve( ...
                linspace(0, 1, 101)), 0);
        end

        function passiveForceGrowsWithSlopeE1E2WhenStretched(testCase)
            slope = (passiveForceLengthCurve(3.001) - ...
                passiveForceLengthCurve(3)) / 0.001;
            testCase.verifyEqual(slope, testCase.e1 * testCase.e2, ...
                "RelTol", 1e-6);
            testCase.verifyGreaterThan(diff(passiveForceLengthCurve( ...
                linspace(0.5, 2, 151))), 0);
        end

        function curveKeepsInputShape(testCase, curve)
            input = 0.5 + rand(2, 3, 5);
            output = curve(input);
            testCase.verifySize(output, size(input));
            testCase.verifyEqual(output(2, 3, 4), curve(input(2, 3, 4)), ...
                "AbsTol", 1e-15);
        end
    end
end
