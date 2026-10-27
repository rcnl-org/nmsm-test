% Tests for Treatment Optimization's registries of cost and constraint
% terms (src/TreatmentOptimization): generateCostTermStruct and
% generateConstraintTermStruct, which give, for a tool (and, for
% constraints, a controller), the term types allowed and the function that
% computes each.
%
% Every allowed type must have a calculation that calls an existing
% function, and the per-tool and per-controller restrictions below are the
% ones candidate-1.5.4 documents. At runtime an enabled term whose type is
% not allowed is skipped silently (calcTreatmentOptimizationCost and
% calcGpopsConstraint have their errors commented out); only
% makeMaxAllowableError reports an unknown cost type, which
% ToCostTermsTest checks.

classdef (TestTags = {'Unit'}) ToTermRegistryTest < matlab.unittest.TestCase

    properties (TestParameter)
        tool = {'TrackingOptimization', 'VerificationOptimization', ...
            'DesignOptimization'}
        costKind = {'continuous', 'discrete'}
        constraintKind = {'path', 'terminal'}
        controller = {'torque', 'synergy'}
    end

    methods (Test)
        % ---- every allowed type can be computed -------------------------

        function everyAllowedCostTypeHasACalculation(testCase, tool, ...
                costKind)
            [calculations, allowed] = generateCostTermStruct(costKind, tool);
            for type = string(allowed)
                testCase.verifyTrue(isfield(calculations, type), type);
                if isfield(calculations, type) && type ~= "user_defined"
                    name = calledFunction(calculations.(type));
                    testCase.verifyEqual(exist(name, "file"), 2, ...
                        type + " calls " + name + ", which does not exist.");
                end
            end
        end

        function everyAllowedConstraintTypeHasACalculation(testCase, tool, ...
                constraintKind, controller)
            [calculations, allowed] = generateConstraintTermStruct( ...
                constraintKind, controller, tool);
            for type = string(allowed)
                testCase.verifyTrue(isfield(calculations, type), type);
                if isfield(calculations, type) && type ~= "user_defined"
                    name = calledFunction(calculations.(type));
                    testCase.verifyEqual(exist(name, "file"), 2, ...
                        type + " calls " + name + ", which does not exist.");
                end
            end
        end

        function allowedTypesAreListedOnce(testCase, tool, costKind)
            [~, allowed] = generateCostTermStruct(costKind, tool);
            testCase.verifyEqual(numel(unique(string(allowed))), ...
                numel(allowed));
        end

        % ---- cost term restrictions -------------------------------------

        function verificationHasNoDiscreteCostTerms(testCase)
            [~, allowed] = generateCostTermStruct("discrete", ...
                "VerificationOptimization");
            testCase.verifyEmpty(allowed);
        end

        function verificationTracksButDoesNotMinimize(testCase)
            % Verification checks that the controls reproduce the
            % motion: it can track, but has no ID load, muscle or
            % controller minimization terms.
            [~, allowed] = generateCostTermStruct("continuous", ...
                "VerificationOptimization");
            testCase.verifyTrue(ismember("controller_tracking", allowed));
            for type = ["inverse_dynamics_load_tracking", ...
                    "muscle_activation_tracking", "controller_minimization"]
                testCase.verifyFalse(ismember(type, allowed), type);
            end
        end

        function designOnlyCostTerms(testCase)
            designOnly = ["controller_shape_tracking", ...
                "joint_energy_generation_goal", ...
                "joint_energy_absorption_goal", ...
                "inverse_dynamics_shape_tracking", ...
                "angular_momentum_minimization", "user_defined"];
            [~, design] = generateCostTermStruct("continuous", ...
                "DesignOptimization");
            [~, tracking] = generateCostTermStruct("continuous", ...
                "TrackingOptimization");
            testCase.verifyTrue(all(ismember(designOnly, design)));
            testCase.verifyFalse(any(ismember(designOnly, tracking)));
        end

        function designGoalsAreDiscrete(testCase)
            [~, allowed] = generateCostTermStruct("discrete", ...
                "DesignOptimization");
            testCase.verifyTrue(all(ismember(["relative_walking_speed_goal", ...
                "absolute_metabolic_cost_per_time", ...
                "relative_metabolic_cost_per_distance", ...
                "propulsive_impulse_goal", "braking_impulse_goal", ...
                "user_defined"], allowed)));
        end

        function unknownToolIsReported(testCase)
            testCase.verifyError(@() generateCostTermStruct("continuous", ...
                "MuscleTendonPersonalization"), ?MException);
        end

        % ---- constraint term restrictions -------------------------------

        function muscleActivationConstraintsNeedSynergies(testCase, tool)
            [~, torque] = generateConstraintTermStruct("path", "torque", tool);
            [~, synergy] = generateConstraintTermStruct("path", ...
                "synergy", tool);
            types = ["muscle_activation_deviation", "muscle_activation_value"];
            testCase.verifyFalse(any(ismember(types, torque)));
            testCase.verifyTrue(all(ismember(types, synergy)));
        end

        function synergyVectorConstraintsAreNotVerified(testCase)
            % Verification keeps the synergy vectors fixed.
            types = ["synergy_vector_sum", "synergy_vector_magnitude", ...
                "synergy_vector_symmetry"];
            for tool = ["TrackingOptimization", "DesignOptimization"]
                [~, allowed] = generateConstraintTermStruct("terminal", ...
                    "synergy", tool);
                testCase.verifyTrue(all(ismember(types, allowed)), tool);
            end
            [~, allowed] = generateConstraintTermStruct("terminal", ...
                "synergy", "VerificationOptimization");
            testCase.verifyFalse(any(ismember(types, allowed)));
            [~, allowed] = generateConstraintTermStruct("terminal", ...
                "torque", "TrackingOptimization");
            testCase.verifyFalse(any(ismember(types, allowed)));
        end

        function designOnlyConstraints(testCase, controller)
            [~, design] = generateConstraintTermStruct("path", ...
                controller, "DesignOptimization");
            testCase.verifyTrue(all(ismember(["limit_normalized_fiber_length", ...
                "user_defined"], design)));
            for tool = ["TrackingOptimization", "VerificationOptimization"]
                [~, allowed] = generateConstraintTermStruct("path", ...
                    controller, tool);
                testCase.verifyFalse(any(ismember( ...
                    ["limit_normalized_fiber_length", "user_defined"], ...
                    allowed)), tool);
            end
        end

        function centerOfPressureIsNotVerified(testCase, controller)
            [~, verification] = generateConstraintTermStruct("path", ...
                controller, "VerificationOptimization");
            [~, tracking] = generateConstraintTermStruct("path", ...
                controller, "TrackingOptimization");
            testCase.verifyFalse(ismember("center_of_pressure_deviation", ...
                verification));
            testCase.verifyTrue(ismember("center_of_pressure_deviation", ...
                tracking));
        end

        function kineticConsistencyIsEverywhere(testCase, tool, controller)
            [~, allowed] = generateConstraintTermStruct("path", ...
                controller, tool);
            testCase.verifyTrue(ismember("kinetic_consistency", allowed));
        end
    end
end

function name = calledFunction(calculation)
% The function a registry entry calls: the first name after the
% anonymous function's argument list, e.g. calcTrackingCoordinateIntegrand
% in "@(values,modeledValues,auxdata,costTerm)calcTrackingCoordinateIntegrand(...".
name = string(regexp(func2str(calculation), "^@\([^)]*\)\s*(\w+)", ...
    "tokens", "once"));
end
