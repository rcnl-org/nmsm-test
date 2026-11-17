% Tests for the cost terms only Design Optimization allows
% (src/TreatmentOptimization: generateCostTermStruct's Design entries),
% called through the registry the way calcTreatmentOptimizationCost and
% computeGpopsEndpointFunction call them: walking speed goal, joint energy
% goals, angular momentum minimization, inverse dynamics shape tracking,
% and user-defined terms. Expected values are worked out by hand.
%
% Several of these crash on candidate-1.5.4 whenever they are enabled;
% those tests are expected to fail (see tests/README.md).

classdef (TestTags = {'Unit'}) DoCostTermsTest < matlab.unittest.TestCase

    properties
        continuous
        discrete
    end

    methods (TestClassSetup)
        function loadRegistry(testCase)
            testCase.continuous = generateCostTermStruct("continuous", ...
                "DesignOptimization");
            testCase.discrete = generateCostTermStruct("discrete", ...
                "DesignOptimization");
        end
    end

    methods (Test)
        function walkingSpeedGoalIsScaledSquaredDifference(testCase)
            % ((speed - error center) / allowable error)^2, already
            % squared by the term itself.
            modeled.massCenterVelocity = 1.5;
            costTerm = struct("type", 'relative_walking_speed_goal', ...
                "errorCenter", 1.2, "maxAllowableError", 0.1);
            cost = testCase.discrete.relative_walking_speed_goal( ...
                struct(), modeled, struct(), costTerm);
            testCase.verifyEqual(cost, 9, "AbsTol", 1e-12);
        end

        function jointEnergyGenerationRewardsPositivePower(testCase)
            % sqrt((moment x velocity - error center) / allowable error),
            % real part only, so absorbed power (negative) costs nothing.
            % Failed on candidate-1.5.4 (fixed later):
            % calcJointEnergyGenerationGoalIntegrand uses an undefined
            % variable (inputs), so it errors whenever it is enabled. See
            % docs/failures.md.
            [values, modeled, auxdata] = jointPowerProblem();
            costTerm = energyTerm('joint_energy_generation_goal');
            cost = testCase.continuous.joint_energy_generation_goal( ...
                values, modeled, auxdata, costTerm);
            power = [2 * 3; 4 * -1; 1 * 1];
            testCase.verifyEqual(cost, real(sqrt(power / 2)), ...
                "AbsTol", 1e-12);
        end

        function jointEnergyAbsorptionRuns(testCase)
            % Failed on candidate-1.5.4 (fixed later) for the same reason as
            % generation (calcJointEnergyAbsorptionGoalIntegrand).
            [values, modeled, auxdata] = jointPowerProblem();
            costTerm = energyTerm('joint_energy_absorption_goal');
            cost = testCase.continuous.joint_energy_absorption_goal( ...
                values, modeled, auxdata, costTerm);
            testCase.verifySize(cost, [3, 1]);
        end

        function angularMomentumMinimizationIsTheAxis(testCase)
            % Failed on candidate-1.5.4 (fixed later):
            % calcMinimizingAngularMomentumIntegrand passes an undefined
            % variable (inputs) to normalizeTimeColumn. See
            % docs/failures.md.
            values.time = [0; 0.5; 1];
            modeled.angularMomentum = [1, 2, 3; 4, 5, 6; 7, 8, 9];
            costTerm = struct("type", 'angular_momentum_minimization', ...
                "axes", 'y', "normalize_by_final_time", false);
            cost = testCase.continuous.angular_momentum_minimization( ...
                values, modeled, struct("collocationTimeOriginal", ...
                values.time), costTerm);
            testCase.verifyEqual(cost, [2; 5; 8]);
        end

        function inverseDynamicsShapeIgnoresScale(testCase)
            % Shape tracking compares the shape of the moment, so an ID
            % moment twice the experimental one fits perfectly.
            % Failed on candidate-1.5.4 (fixed later):
            % calcTrackingInverseDynamicsShapeIntegrand computes its scale
            % factor from variables that do not exist (modeled \
            % experimental). See docs/failures.md.
            auxdata.coordinateNames = ["a", "b"];
            auxdata.collocationTimeOriginal = [0; 0.5; 1];
            auxdata.inverseDynamicsMomentLabels = ["a_moment", "b_moment"];
            auxdata.splinedJointMoments = [0, 1; 0, 3; 0, 2];
            values.time = auxdata.collocationTimeOriginal;
            modeled.inverseDynamicsMoments = 2 * auxdata.splinedJointMoments;
            costTerm = struct("type", 'inverse_dynamics_shape_tracking', ...
                "load", "b_moment", "normalize_by_final_time", false);
            cost = testCase.continuous.inverse_dynamics_shape_tracking( ...
                values, modeled, auxdata, costTerm);
            testCase.verifyEqual(cost, zeros(3, 1), "AbsTol", 1e-12);
        end

        function userDefinedTermCallsTheNamedFunction(testCase)
            % A user_defined term calls function_name(values, modeled,
            % auxdata, term), but only from the registry of its own
            % cost_term_type.
            testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            writelines(["function cost = halfOfTime(values, ~, ~, term)"; ...
                "cost = values.time / 2 + term.offset;"; "end"], ...
                "halfOfTime.m");
            values.time = [0; 1; 2];
            costTerm = struct("type", 'user_defined', "function_name", ...
                'halfOfTime', "cost_term_type", 'continuous', "offset", 1);
            testCase.verifyEqual(testCase.continuous.user_defined(values, ...
                struct(), struct(), costTerm), [1; 1.5; 2]);
            testCase.verifyEmpty(testCase.discrete.user_defined(values, ...
                struct(), struct(), costTerm));
        end
    end
end

function [values, modeled, auxdata] = jointPowerProblem()
% Coordinates "a" and "b"; joint "b" has moments [2; 4; 1] and velocities
% [3; -1; 1], so power [6; -4; 1].
auxdata.coordinateNames = ["a", "b"];
auxdata.inverseDynamicsMomentLabels = ["a_moment", "b_moment"];
auxdata.collocationTimeOriginal = [0; 0.5; 1];
values.time = auxdata.collocationTimeOriginal;
values.velocities = [0, 3; 0, -1; 0, 1];
modeled.inverseDynamicsMoments = [0, 2; 0, 4; 0, 1];
end

function costTerm = energyTerm(type)
costTerm = struct("type", type, "load", "b_moment", "errorCenter", 0, ...
    "maxAllowableError", 2, "normalize_by_final_time", false);
end
