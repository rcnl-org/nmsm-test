% Tests for Treatment Optimization's constraint terms
% (src/TreatmentOptimization/PathTerms and TerminalTerms), how they are
% combined (calcGpopsConstraint) and their bounds (makePathConstraintBounds,
% makeTerminalConstraintBounds).
%
% A path constraint is a value at each collocation point and a terminal
% constraint a single value; GPOPS-II keeps each between the term's
% min_error and max_error. Expected values are worked out by hand.

classdef (TestTags = {'Unit'}) ToConstraintTermsTest < matlab.unittest.TestCase

    methods (Test)
        % ---- path constraints -------------------------------------------

        function kineticConsistencyIsInverseDynamicsMinusTorque(testCase)
            % A torque-driven model must produce, with its torque
            % controls, the moments inverse dynamics needs.
            inputs.controllerType = 'torque';
            inputs.inverseDynamicsMomentLabels = ["a_moment", "b_moment"];
            inputs.torqueControllerCoordinateNames = ["b", "a"];
            modeled.inverseDynamicsMoments = [1, 10; 2, 20];
            torqueControls = [9, 0; 21, 0];
            constraint = calcKineticPathConstraint(struct(), inputs, ...
                modeled, torqueControls, "b_moment");
            testCase.verifyEqual(constraint, [1; -1]);
        end

        function kineticConsistencyAddsMuscleMoments(testCase)
            % Synergy-driven: muscle moment (for a surrogate coordinate)
            % plus any torque control on the same coordinate.
            inputs.controllerType = 'synergy';
            inputs.coordinateNames = ["a", "b"];
            inputs.surrogateModelIndex = [2, 1];
            inputs.inverseDynamicsMomentLabels = ["a_moment", "b_moment"];
            inputs.torqueControllerCoordinateNames = "b";
            modeled.inverseDynamicsMoments = [1, 10; 2, 20];
            modeled.muscleJointMoments = [6, 0.5; 15, 1];
            torqueControls = [3; 4];
            constraint = calcKineticPathConstraint(struct(), inputs, ...
                modeled, torqueControls, "b_moment");
            testCase.verifyEqual(constraint, [10 - 6 - 3; 20 - 15 - 4]);
        end

        function uncontrolledLoadIsReported(testCase)
            inputs.controllerType = 'torque';
            inputs.inverseDynamicsMomentLabels = ["a_moment", "b_moment"];
            inputs.torqueControllerCoordinateNames = "b";
            modeled.inverseDynamicsMoments = zeros(2);
            verifyErrorMessage(testCase, @() calcKineticPathConstraint( ...
                struct(), inputs, modeled, zeros(2, 1), "a_moment"), ...
                "not a controlled load");
        end

        % ---- terminal constraints ---------------------------------------

        function periodicityIsLastMinusFirst(testCase)
            % Terminal constraints get the first and last point only.
            positions = [0.1, 1; 0.4, 3];
            testCase.verifyEqual(calcStatePositionPeriodicity(struct(), ...
                positions, ["a", "b"], "b"), 2, "AbsTol", 1e-15);
        end

        function synergyWeightSumAndMagnitude(testCase)
            % Groups Left (2 synergies) and Right (2): Right_1 is the
            % third row of weights.
            inputs.synergyGroups = synergyGroups();
            weights = [1 1 0; 0 1 1; 3 4 0; 0 0 1];
            testCase.verifyEqual(calcSynergyWeightsSum(struct(), weights, ...
                inputs, "Right_1"), 7);
            testCase.verifyEqual(calcSynergyWeightsMagnitude(struct(), ...
                weights, inputs, "Right_1"), 5, "AbsTol", 1e-14);
        end

        % ---- combining and bounding -------------------------------------

        function enabledConstraintsAreConcatenated(testCase)
            calculations.one = @(values, modeled, inputs, term) term.value;
            constraints = {struct("type", "one", "isEnabled", true, ...
                "value", 1), struct("type", "one", "isEnabled", false, ...
                "value", 2), struct("type", "one", "isEnabled", true, ...
                "value", 3)};
            testCase.verifyEqual(calcGpopsConstraint(constraints, ...
                calculations, "one", struct(), struct(), struct()), [1, 3]);
        end

        function boundsComeFromEnabledTermsOnly(testCase)
            inputs.path = {bounds(true, 1, -1), bounds(false, 2, -2), ...
                bounds(true, 0.5, 0)};
            inputs.terminal = {bounds(false, 9, -9), bounds(true, 0.1, -0.2)};
            inputs = makePathConstraintBounds(inputs);
            inputs = makeTerminalConstraintBounds(inputs);
            testCase.verifyEqual([inputs.maxPath; inputs.minPath], ...
                [1, 0.5; -1, 0]);
            testCase.verifyEqual([inputs.maxTerminal; inputs.minTerminal], ...
                [0.1; -0.2]);
        end
    end
end

function groups = synergyGroups()
groups = {struct("muscleGroupName", "Left", "numSynergies", 2, ...
    "muscleNames", ["l1", "l2", "l3"]), struct("muscleGroupName", ...
    "Right", "numSynergies", 2, "muscleNames", ["r1", "r2", "r3"])};
end

function term = bounds(isEnabled, maxError, minError)
term = struct("type", "generalized_coordinate_value", "isEnabled", ...
    isEnabled, "maxError", maxError, "minError", minError);
end
