% Tests for GCP's cost term functions
% (src/GroundContactPersonalization/Optimizations/CostFunctionTerms) and
% for how a task's lsqnonlin result is merged back
% (mergeGroundContactPersonalizationRoundResults). Each returns raw errors
% that calcGroundContactPersonalizationTaskCost scales by
% 1 / (allowable error * sqrt(count)); expected values are worked out by
% hand.

classdef (TestTags = {'Unit'}) GcpCostTermsTest < matlab.unittest.TestCase

    methods (Test)
        % ---- kinematics -------------------------------------------------

        function markerErrorsAreAbsoluteDifferences(testCase)
            % Two markers, two frames: |experimental - modeled|, marker
            % by marker, flattened.
            task.markerNames = struct("toe", "T", "heel", "H");
            task.experimentalMarkerPositions = struct( ...
                "toe", [1 2; 3 4; 5 6], "heel", zeros(3, 2));
            task.experimentalMarkerVelocities = struct( ...
                "toe", zeros(3, 2), "heel", ones(3, 2));
            modeled.markerPositions = struct("toe", [1 1; 1 1; 1 1], ...
                "heel", [0 0; 0.5 0; 0 0]);
            modeled.markerVelocities = struct("toe", zeros(3, 2), ...
                "heel", 3 * ones(3, 2));
            [values, slopes] = calcFootMarkerPositionAndSlopeError(task, ...
                modeled);
            testCase.verifyEqual(values, [0 2 4 1 3 5 0 0.5 0 0 0 0]);
            testCase.verifyEqual(slopes, [zeros(1, 6), 2 * ones(1, 6)]);
        end

        function periodicityComparesFirstAndLastFrame(testCase)
            % Each coordinate's first-minus-last difference, divided by
            % the experimental difference or a floor (0.0175 rad for the
            % four rotations, 1 mm for the three translations).
            coordinates = zeros(7, 3);
            coordinates(:, 1) = [0.035; 0; 0; 0; 0.002; 0; 0];
            experimental = zeros(7, 3);
            experimental(1, 1) = 0.1; % experimental difference 0.1
            cost = calcFootPositionPeriodicityError(coordinates, experimental);
            testCase.verifyEqual(cost, [0.35, 0, 0, 0, 2, 0, 0], ...
                "AbsTol", 1e-12);
        end

        function bSplineCoefficientErrorIsDeviationFromOne(testCase)
            testCase.verifyEqual(calcKinematicsBSplineCoefficientError( ...
                [1 1.1; 0.8 1]), [0, -0.2, 0.1, 0], "AbsTol", 1e-12);
        end

        % ---- spring constants -------------------------------------------

        function springConstantErrorFromMean(testCase)
            testCase.verifyEqual(calcSpringConstantsErrorFromMean( ...
                [1000, 2000, 3000]), [-1000, 0, 1000]);
        end

        function springConstantErrorFromWeightedNeighbors(testCase)
            % Three springs, one frame. Spring 1's neighbors are 2
            % (weight 1) and 3 (weight 0.25): weighted mean
            % (2000 + 0.25 * 4000) / 1.25 = 2400, so its error is
            % 1000 - 2400. A spring's weight with itself is 0.
            weights = zeros(1, 3, 3);
            weights(1, :, :) = [0, 1, 0.25; 1, 0, 1; 0.25, 1, 0];
            errors = calcSpringConstantsErrorFromNeighbors( ...
                [1000, 2000, 4000], weights);
            testCase.verifyEqual(errors, [1000 - 2400, 2000 - 2500, ...
                4000 - (0.25 * 1000 + 2000) / 1.25], "AbsTol", 1e-9);
        end

        % ---- regularization ---------------------------------------------

        function electricalCenterErrorIsTheShift(testCase)
            inputs.surfaces = {struct()};
            values = struct("electricalCenterX1", 0.01, ...
                "electricalCenterY1", 0.02, "electricalCenterZ1", -0.03);
            testCase.verifyEqual(calcElectricalCenterShiftError(inputs, ...
                values, struct()), [0.01, 0.02, -0.03]);
        end

        function electricalCenterErrorCanSkipAxes(testCase)
            % With axes "xz" the y shift is not penalized.
            inputs.surfaces = {struct()};
            values = struct("electricalCenterX1", 0.01, ...
                "electricalCenterY1", 0.02, "electricalCenterZ1", -0.03);
            testCase.verifyEqual(calcElectricalCenterShiftError(inputs, ...
                values, struct("axes", "xz")), [0.01, 0, -0.03]);
        end

        function forcePlateRotationErrorIsTheAngle(testCase)
            inputs.surfaces = {struct(), struct()};
            values = struct("forcePlateRotation1", 0.1, ...
                "forcePlateRotation2", -0.05);
            testCase.verifyEqual(calcForcePlateRotationError(inputs, ...
                values), [0.1, -0.05]);
        end

        function wallErrorIsScaledPower(testCase)
            testCase.verifyEqual(calcWallError([1, 3], 1, 0.5, 2), [0, 16]);
        end

        % ---- ground reactions -------------------------------------------

        function forceErrorsAreExperimentalMinusModeled(testCase)
            % Constant forces, so the modeled slopes (a 25-node B-spline
            % derivative) are 0 and the slope errors are the experimental
            % slopes. 101 frames, as in the fixtures: with far fewer
            % frames than that, 25 nodes no longer fit the ends exactly.
            task.time = linspace(0, 1, 101);
            task.experimentalGroundReactionForces = repmat([10; 700; -5], ...
                1, 101);
            task.experimentalGroundReactionForcesSlope = ...
                repmat([1; 2; 3], 1, 101);
            modeled.anteriorGrf = 8 * ones(1, 101);
            modeled.verticalGrf = 690 * ones(1, 101);
            modeled.lateralGrf = -5 * ones(1, 101);
            [values, slopes] = calcGroundReactionForceAndSlopeError(task, ...
                modeled);
            testCase.verifyEqual(values, repmat([2; 10; 0], 1, 101), ...
                "AbsTol", 1e-9);
            testCase.verifyEqual(slopes, repmat([1; 2; 3], 1, 101), ...
                "AbsTol", 1e-6);
        end

        % ---- merging a task's result ------------------------------------

        function mergedResultFollowsDesignVariableOrder(testCase)
            % Order: spring constants (x1000), damping, dynamic friction,
            % viscous friction, resting length, B-spline coefficients per
            % foot (nodes x 7), electrical center X, Y, Z per foot, plate
            % rotation per foot. Here every variable is included, for one
            % foot with 2 springs and 2 B-spline nodes.
            % Expected to fail on candidate-1.5.4: after reading the
            % resting spring length the index is not advanced, so every
            % later variable is read one position early (the first
            % B-spline coefficient becomes the resting length). See
            % tests/README.md.
            inputs.springConstants = [0, 0];
            inputs.surfaces = {struct("bSplineCoefficients", zeros(2, 7))};
            params.tasks = {struct("designVariables", true(1, 10))};
            results = [2.5, 3, 0.4, 0.6, 0.2, 0.05, 1 : 14, 0.01, 0.02, ...
                0.03, 0.1];
            merged = mergeGroundContactPersonalizationRoundResults(inputs, ...
                results, params, 1);
            testCase.verifyEqual(merged.springConstants, [2500, 3000]);
            testCase.verifyEqual([merged.dampingFactor, ...
                merged.dynamicFrictionCoefficient, ...
                merged.viscousFrictionCoefficient, ...
                merged.restingSpringLength], [0.4, 0.6, 0.2, 0.05]);
            testCase.verifyEqual(merged.surfaces{1}.bSplineCoefficients, ...
                reshape(1 : 14, 2, 7));
            foot = merged.surfaces{1};
            testCase.verifyEqual([foot.electricalCenterShiftX, ...
                foot.electricalCenterShiftY, foot.electricalCenterShiftZ, ...
                foot.forcePlateRotation], [0.01, 0.02, 0.03, 0.1]);
        end

        function mergedResultWithoutRestingLengthFollowsOrder(testCase)
            % The same layout with the resting length not optimized:
            % everything else lands where it should.
            inputs.springConstants = [0, 0];
            inputs.restingSpringLength = 0.05;
            inputs.surfaces = {struct("bSplineCoefficients", zeros(2, 7))};
            params.tasks = {struct("designVariables", ...
                logical([1 1 1 1 0 1 1 1 1 1]))};
            results = [2.5, 3, 0.4, 0.6, 0.2, 1 : 14, 0.01, 0.02, 0.03, 0.1];
            merged = mergeGroundContactPersonalizationRoundResults(inputs, ...
                results, params, 1);
            testCase.verifyEqual(merged.restingSpringLength, 0.05);
            testCase.verifyEqual(merged.surfaces{1}.bSplineCoefficients, ...
                reshape(1 : 14, 2, 7));
            foot = merged.surfaces{1};
            testCase.verifyEqual([foot.electricalCenterShiftX, ...
                foot.electricalCenterShiftY, foot.electricalCenterShiftZ, ...
                foot.forcePlateRotation], [0.01, 0.02, 0.03, 0.1]);
        end

        function excludedVariablesAreLeftAlone(testCase)
            % Only damping and resting length optimized.
            inputs.springConstants = [2000, 2000];
            inputs.dampingFactor = 1;
            inputs.restingSpringLength = 0.05;
            inputs.surfaces = {struct("bSplineCoefficients", ones(2, 7))};
            params.tasks = {struct("designVariables", ...
                logical([0 1 0 0 1 0 0 0 0 0]))};
            merged = mergeGroundContactPersonalizationRoundResults(inputs, ...
                [0.3, 0.04], params, 1);
            testCase.verifyEqual(merged.springConstants, [2000, 2000]);
            testCase.verifyEqual(merged.dampingFactor, 0.3);
            testCase.verifyEqual(merged.restingSpringLength, 0.04);
            testCase.verifyEqual(merged.surfaces{1}.bSplineCoefficients, ...
                ones(2, 7));
        end
    end
end
