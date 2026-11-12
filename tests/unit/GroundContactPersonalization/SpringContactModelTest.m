% Tests for GCP's foot-ground contact model
% (src/GroundContactPersonalization/Optimizations/ModelCalculation): the
% vertical spring force, the friction forces, the moments of the spring
% forces, and the force plate rotation. Expected values come from what the
% formulas are built to do (e.g. no force 1 cm above the resting length,
% stiffness K when compressed) or are worked out by hand.
%
% Vertical model per spring, with y = 0.7 tanh((height - resting length)
% / 0.7) and klow = 0.1, h = c = 1e-3, ymax = 1e-2:
%   F = -s (v y - c log cosh((y + h) / c)) - constant,
%   s = (K - klow) / 2, v = (K + klow) / (K - klow),
% with the constant making F(ymax) = 0. For y well below 0 the slope is
% -K; well above, it is about -klow. Damping multiplies F by (1 - d * vy).

classdef (TestTags = {'Unit'}) SpringContactModelTest < matlab.unittest.TestCase

    properties (Constant)
        restingLength = 0.05 % m
        stiffness = 2500 % N/m
    end

    methods (Test)
        % ---- vertical force ---------------------------------------------

        function noForceOneCentimeterAboveRestingLength(testCase)
            % ymax = 1 cm above the resting length is where the force is
            % zero (tanh moves it by under 1e-6 m).
            force = testCase.vertical(testCase.restingLength + 0.01, 0);
            testCase.verifyEqual(force, 0, "AbsTol", 1e-4);
        end

        function almostNoForceWhenAboveTheGround(testCase)
            % Above the resting length the spring is nearly slack: its
            % stiffness is klow = 0.1 N/m instead of 2500.
            testCase.verifyLessThan(abs(testCase.vertical( ...
                testCase.restingLength + 0.02, 0)), 0.01);
        end

        function compressedSpringHasStiffnessK(testCase)
            % 1 mm more compression adds about K * 1 mm = 2.5 N (tanh
            % shrinks the step by about 1e-4 relative).
            deeper = testCase.vertical(testCase.restingLength - 0.006, 0);
            shallower = testCase.vertical(testCase.restingLength - 0.005, 0);
            testCase.verifyEqual(deeper - shallower, ...
                testCase.stiffness * 0.001, "RelTol", 1e-3);
        end

        function stifferSpringPushesHarder(testCase)
            % Deep in compression the force is about proportional to K
            % (plus a small offset from the smoothing).
            force1 = testCase.vertical(testCase.restingLength - 0.01, 0);
            force2 = testCase.vertical(testCase.restingLength - 0.01, 0, ...
                2 * testCase.stiffness);
            testCase.verifyEqual(force2 / force1, 2, "RelTol", 1e-2);
        end

        function dampingScalesByVerticalVelocity(testCase)
            % Damping factor 2 s/m, moving down at 0.1 m/s: (1 + 0.2)
            static = testCase.vertical(testCase.restingLength - 0.005, 0);
            moving = testCase.vertical(testCase.restingLength - 0.005, ...
                -0.1, testCase.stiffness, 2);
            testCase.verifyEqual(moving, 1.2 * static, "RelTol", 1e-12);
        end

        function verticalForceSumsSprings(testCase)
            kinematics.height = testCase.restingLength - [0.004, 0.008];
            kinematics.yVelocity = [0, 0];
            [total, springForces] = calcModeledVerticalGroundReactionForce( ...
                testCase.stiffness * [1, 1], 0, testCase.restingLength, ...
                kinematics, zeros(3, 2));
            testCase.verifyEqual(total, sum(springForces(2, :)), ...
                "RelTol", 1e-12);
            testCase.verifyEqual(springForces(2, 1), testCase.vertical( ...
                testCase.restingLength - 0.004, 0), "RelTol", 1e-12);
        end

        % ---- friction ---------------------------------------------------

        function frictionOpposesSlipIncludingBeltSpeed(testCase)
            % Spring moving at -1.1 m/s in x on a 1.4 m/s belt: it slips
            % at +0.3 m/s in x and 0.4 m/s in z, 0.5 m/s in total. With
            % 100 N of vertical force, dynamic friction 0.5, viscous
            % friction 0.2 s/m and latching velocity 0.1 m/s the friction
            % magnitude is 100 (0.5 tanh(5) + 0.2 * 0.5), split along
            % -[0.3 0.4] / (0.5 + 1e-4).
            values = struct("springConstants", 2500, ...
                "dynamicFrictionCoefficient", 0.5, ...
                "viscousFrictionCoefficient", 0.2);
            kinematics.xVelocity = -1.1;
            kinematics.zVelocity = 0.4;
            [anterior, lateral, springForces] = ...
                calcModeledHorizontalGroundReactionForces(values, 1.4, 0.1, ...
                kinematics, [0; 100; 0]);
            magnitude = 100 * (0.5 * tanh(5) + 0.2 * 0.5);
            testCase.verifyEqual([anterior, lateral], ...
                -[0.3, 0.4] / 0.5001 * magnitude, "AbsTol", 1e-9);
            testCase.verifyEqual(springForces(:, 1)', [anterior, 100, ...
                lateral], "AbsTol", 1e-12);
        end

        function noFrictionWithoutSlip(testCase)
            % Moving with the belt: no slip, no friction.
            values = struct("springConstants", 2500, ...
                "dynamicFrictionCoefficient", 0.5, ...
                "viscousFrictionCoefficient", 0.2);
            kinematics.xVelocity = -1.4;
            kinematics.zVelocity = 0;
            [anterior, lateral] = calcModeledHorizontalGroundReactionForces( ...
                values, 1.4, 0.1, kinematics, [0; 100; 0]);
            testCase.verifyEqual([anterior, lateral], [0, 0], "AbsTol", 1e-9);
        end

        % ---- moments and force plate rotation ---------------------------

        function momentsAreAboutProjectedMidfoot(testCase)
            % Moments are about the midfoot superior marker projected to
            % the floor (y = 0): a spring 0.1 m in front of it pushing up
            % with 100 N gives r x F = [0.1 0 0] x [0 100 0] = [0 0 10].
            % A second spring 0.05 m to the side with 20 N of x force
            % gives [0 0 0.05] x [20 0 0] = [0 1 0].
            task.midfootSuperiorPosition = [0.3; 0.07; 0.2];
            kinematics.xPosition = [0.4, 0.3];
            kinematics.zPosition = [0.2, 0.25];
            springForces = [0, 20; 100, 0; 0, 0];
            values.springConstants = [1, 1];
            [mx, my, mz] = calcModeledGroundReactionMoments(values, task, ...
                kinematics, springForces, 1);
            testCase.verifyEqual([mx, my, mz], [0, 1, 10], "AbsTol", 1e-12);
        end

        function plateRotationIsAboutVerticalAxis(testCase)
            % Rotating 90 degrees about y turns +x into -z and leaves the
            % vertical component and magnitudes unchanged.
            [forces, moments] = rotateGroundReactions([1; 5; 0], ...
                [2; 3; 0], pi / 2);
            testCase.verifyEqual(forces, [0; 5; -1], "AbsTol", 1e-12);
            testCase.verifyEqual(moments, [0; 3; -2], "AbsTol", 1e-12);
            [unchanged, ~] = rotateGroundReactions([1; 5; 0], [2; 3; 0], 0);
            testCase.verifyEqual(unchanged, [1; 5; 0]);
        end
    end

    methods
        function force = vertical(testCase, height, velocity, stiffness, ...
                damping)
            % One spring's vertical force from
            % calcModeledVerticalGroundReactionForce
            if nargin < 4
                stiffness = testCase.stiffness;
            end
            if nargin < 5
                damping = 0;
            end
            kinematics.height = height;
            kinematics.yVelocity = velocity;
            force = calcModeledVerticalGroundReactionForce(stiffness, ...
                damping, testCase.restingLength, kinematics, zeros(3, 1));
        end
    end
end
