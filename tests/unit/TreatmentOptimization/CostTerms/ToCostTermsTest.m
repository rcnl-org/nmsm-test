% Tests for Treatment Optimization's continuous cost terms
% (src/TreatmentOptimization/IntegrandTerms and IntegrandComputations), how
% they are combined (calcTreatmentOptimizationCost, calcGpopsIntegrand) and
% how their allowable errors are collected (makeMaxAllowableError).
%
% A continuous term returns, at each collocation point, an error such as
% experimental - modeled. calcGpopsIntegrand divides each term by its
% max_allowable_error and squares it; GPOPS-II integrates that over time.
% With <normalize_by_final_time> (true by default) a term's error is also
% divided by the final time. Expected values are worked out by hand.

classdef (TestTags = {'Unit'}) ToCostTermsTest < matlab.unittest.TestCase

    methods (TestMethodSetup)
        function clearCaches(~)
            clearToCaches();
        end
    end

    methods (Test)
        % ---- tracking and minimizing terms ------------------------------

        function coordinateTrackingIsExperimentalMinusModeled(testCase)
            inputs = threePointInputs(1);
            positions = [1, 2.5; 3, 4; 5, 5];
            cost = calcTrackingCoordinateIntegrand(term(false), inputs, ...
                inputs.collocationTimeOriginal, positions, "b");
            testCase.verifyEqual(cost, [-0.5; 0; 1], "AbsTol", 1e-14);
        end

        function errorsAreDividedByFinalTimeByDefault(testCase)
            % Final time 2 s: the same errors, halved.
            inputs = threePointInputs(2);
            positions = [1, 2.5; 3, 4; 5, 5];
            cost = calcTrackingCoordinateIntegrand(struct(), inputs, ...
                inputs.collocationTimeOriginal, positions, "b");
            testCase.verifyEqual(cost, [-0.25; 0; 0.5], "AbsTol", 1e-14);
        end

        function trackingRemembersItsColumn(testCase)
            % The data column is looked up once and stored on the term.
            inputs = threePointInputs(1);
            [~, updated] = calcTrackingCoordinateIntegrand(term(false), ...
                inputs, inputs.collocationTimeOriginal, zeros(3, 2), "b");
            testCase.verifyEqual(updated.internalDataIndices, 2);
        end

        function speedMinimizationIsDistanceFromErrorCenter(testCase)
            inputs = threePointInputs(1);
            costTerm = term(false);
            costTerm.errorCenter = 1;
            cost = calcMinimizingSpeedIntegrand(costTerm, inputs, ...
                inputs.collocationTimeOriginal, [0, 1; 0, 3; 0, -1], "b");
            testCase.verifyEqual(cost, [0; 2; -2], "AbsTol", 1e-14);
        end

        function inverseDynamicsTrackingUsesTheLoad(testCase)
            % (experimental x scale_factor) - modeled, for the named load.
            inputs = threePointInputs(1);
            inputs.inverseDynamicsMomentLabels = ["a_moment", "b_moment"];
            inputs.splinedJointMoments = [0, 10; 0, 20; 0, 30];
            costTerm = term(false);
            costTerm.scale_factor = 2;
            cost = calcTrackingInverseDynamicLoadsIntegrand(costTerm, ...
                inputs, inputs.collocationTimeOriginal, ...
                [0, 15; 0, 40; 0, 70], "b_moment");
            testCase.verifyEqual(cost, [5; 0; -10], "AbsTol", 1e-14);
        end

        function timeRangesZeroTheOtherPoints(testCase)
            % <time_ranges>0 0.5</time_ranges> keeps the first half of
            % the (normalized) time only.
            inputs = threePointInputs(1);
            inputs.inverseDynamicsMomentLabels = ["a_moment", "b_moment"];
            inputs.splinedJointMoments = [0, 10; 0, 20; 0, 30];
            costTerm = term(false);
            costTerm.time_ranges = "0 0.5";
            cost = calcTrackingInverseDynamicLoadsIntegrand(costTerm, ...
                inputs, inputs.collocationTimeOriginal, zeros(3, 2), ...
                "b_moment");
            testCase.verifyEqual(cost, [10; 20; 0], "AbsTol", 1e-14);
        end

        function torqueControllerMinimizationIsTheControl(testCase)
            inputs = threePointInputs(1);
            inputs.controllerType = 'torque';
            inputs.torqueControllerCoordinateNames = ["a", "b"];
            values.torqueControls = [1, 2; 3, 4; 5, 6];
            cost = calcMinimizingControllerIntegrand(term(false), inputs, ...
                values, inputs.collocationTimeOriginal, "b");
            testCase.verifyEqual(cost, [2; 4; 6]);
        end

        function synergyControllerMinimizationIsTheActivation(testCase)
            % Synergies are named <group>_<index>.
            inputs = threePointInputs(1);
            inputs.controllerType = 'synergy';
            inputs.synergyLabels = ["RightLeg_1", "RightLeg_2"];
            inputs.torqueControllerCoordinateNames = strings(1, 0);
            values.controlSynergyActivations = [0.1, 0.2; 0.3, 0.4; ...
                0.5, 0.6];
            cost = calcMinimizingControllerIntegrand(term(false), inputs, ...
                values, inputs.collocationTimeOriginal, "RightLeg_2");
            testCase.verifyEqual(cost, [0.2; 0.4; 0.6]);
        end

        function unknownControllerIsReported(testCase)
            inputs = threePointInputs(1);
            inputs.controllerType = 'torque';
            inputs.torqueControllerCoordinateNames = "a";
            values.torqueControls = zeros(3, 1);
            verifyErrorMessage(testCase, @() ...
                calcMinimizingControllerIntegrand(term(false), inputs, ...
                values, inputs.collocationTimeOriginal, "b"), ...
                "not a control label");
        end

        function activationMinimizationAppliesTheExponent(testCase)
            % (a / e) ^ (p / 2) x e, so that the integrand's later
            % (x / e) ^ 2 gives (a / e) ^ p. Exponent 4, error 0.5.
            inputs = threePointInputs(1);
            inputs.muscleNames = ["m1", "m2"];
            costTerm = term(false);
            costTerm.maxAllowableError = 0.5;
            costTerm.exponent = 4;
            activations = [0, 0.1; 0, 0.5; 0, 1];
            cost = calcMinimizingMuscleActivationIntegrand(costTerm, ...
                inputs.collocationTimeOriginal, activations, inputs, "m2");
            testCase.verifyEqual((cost / 0.5) .^ 2, ...
                ([0.1; 0.5; 1] / 0.5) .^ 4, "RelTol", 1e-12);
        end

        function costArrayTermsSelectColumns(testCase)
            testCase.verifyEqual(calcTrackingCostArrayTerm([1 2 3; 4 5 6], ...
                [0 2 1; 1 1 1], [3 1]), [2 1; 5 3]);
            testCase.verifyEqual(calcMinimizingCostArrayTerm([1 2]), [1 2]);
        end

        % ---- combining terms --------------------------------------------

        function enabledTermsAreConcatenatedInOrder(testCase)
            calculations.first = @(values, modeled, auxdata, costTerm) ...
                [1; 1];
            calculations.second = @(values, modeled, auxdata, costTerm) ...
                [2; 3];
            auxdata.costTerms = {struct("type", "second", "isEnabled", ...
                true), struct("type", "first", "isEnabled", false), ...
                struct("type", "first", "isEnabled", true)};
            cost = calcTreatmentOptimizationCost(calculations, ...
                ["first", "second"], struct(), struct(), auxdata);
            testCase.verifyEqual(cost, [2, 1; 3, 1]);
        end

        function integrandIsSquaredScaledError(testCase)
            % Two coordinate tracking terms with allowable errors 0.5
            % and 2.
            inputs = threePointInputs(1);
            inputs.toolName = "TrackingOptimization";
            first = term(false);
            first.type = 'generalized_coordinate_tracking';
            first.isEnabled = true;
            first.coordinate = "a";
            second = first;
            second.coordinate = "b";
            inputs.costTerms = {first, second};
            inputs.continuousMaxAllowableError = [0.5, 2];
            values.time = inputs.collocationTimeOriginal;
            values.positions = inputs.splinedJointAngles - [1, 2; 0, 0; ...
                0.5, -2];
            integrand = calcGpopsIntegrand(values, struct(), inputs);
            testCase.verifyEqual(integrand, [(1 / 0.5) ^ 2, (2 / 2) ^ 2; ...
                0, 0; (0.5 / 0.5) ^ 2, (-2 / 2) ^ 2], "AbsTol", 1e-12);
        end

        % ---- allowable errors -------------------------------------------

        function allowableErrorsAreSplitByKind(testCase)
            costTerms = { ...
                enabled("generalized_coordinate_tracking", 0.1), ...
                enabled("relative_walking_speed_goal", 0.2), ...
                setfield(enabled("user_defined", 0.3), "cost_term_type", ...
                "discrete"), ...
                setfield(enabled("user_defined", 0.4), "cost_term_type", ...
                "continuous"), ...
                setfield(enabled("controller_tracking", 0.5), ...
                "isEnabled", false)};
            [continuous, discrete] = makeMaxAllowableError( ...
                "DesignOptimization", costTerms);
            testCase.verifyEqual(continuous, [0.1, 0.4]);
            testCase.verifyEqual(discrete, [0.2, 0.3]);
        end

        function costTypeNotInTheToolIsReported(testCase)
            % angular_momentum_minimization is Design Optimization only.
            verifyErrorMessage(testCase, @() makeMaxAllowableError( ...
                "TrackingOptimization", {enabled( ...
                "angular_momentum_minimization", 1)}), ...
                "does not exist for this tool");
        end

        function userDefinedTermNeedsAKind(testCase)
            costTerm = setfield(enabled("user_defined", 1), ...
                "cost_term_type", "sometimes");
            verifyErrorMessage(testCase, @() makeMaxAllowableError( ...
                "DesignOptimization", {costTerm}), "discrete or continuous");
        end
    end
end

function inputs = threePointInputs(finalTime)
% Coordinates "a" and "b", three collocation points from 0 to finalTime,
% splined experimental angles [1 2; 3 4; 5 6].
inputs.coordinateNames = ["a", "b"];
inputs.collocationTimeOriginal = [0; 0.5; 1] * finalTime;
inputs.splinedJointAngles = [1, 2; 3, 4; 5, 6];
end

function costTerm = term(normalizeByFinalTime)
costTerm.normalize_by_final_time = normalizeByFinalTime;
end

function costTerm = enabled(type, maxAllowableError)
costTerm = struct("type", char(type), "isEnabled", true, ...
    "maxAllowableError", maxAllowableError);
end
