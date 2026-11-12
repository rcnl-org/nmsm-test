% Tests for how Treatment Optimization lays out its design variables and
% their bounds (src/TreatmentOptimization): makeGpopsValuesAsStruct, which
% unscales GPOPS-II's time, state, control and parameter arrays into named
% values, and makeOptimalControlBounds, which sets the bounds from the
% experimental data's ranges.
%
% Layout on candidate-1.5.4:
% - state: [positions, velocities] of the states coordinates;
% - control: [accelerations, synergy activations, torque controls];
% - parameters: synergy weights (if optimized), then Design
%   Optimization's user-defined variables.

classdef (TestTags = {'Unit'}) ToDesignVariablesTest < matlab.unittest.TestCase

    methods (Test)
        % ---- makeGpopsValuesAsStruct ------------------------------------

        function torqueValuesAreUnscaled(testCase)
            [inputs, phase, truth] = torqueProblem();
            values = makeGpopsValuesAsStruct(phase, inputs);
            testCase.verifyEqual(values.time, truth.time, "AbsTol", 1e-12);
            testCase.verifyEqual(values.statePositions, truth.positions, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(values.stateVelocities, ...
                truth.velocities, "AbsTol", 1e-12);
            testCase.verifyEqual(values.controlAccelerations, ...
                truth.accelerations, "AbsTol", 1e-12);
            testCase.verifyEqual(values.torqueControls, truth.torques, ...
                "AbsTol", 1e-12);
        end

        function stateCoordinatesReplaceTheSplinedData(testCase)
            % Coordinates that are not states keep their splined
            % experimental values; the states coordinate ("b", column 2)
            % takes the optimized values.
            [inputs, phase, truth] = torqueProblem();
            values = makeGpopsValuesAsStruct(phase, inputs);
            testCase.verifyEqual(values.positions(:, 1), ...
                inputs.splinedJointAngles(:, 1));
            testCase.verifyEqual(values.positions(:, 2), truth.positions, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(values.velocities(:, 2), ...
                truth.velocities, "AbsTol", 1e-12);
            testCase.verifyEqual(values.accelerations(:, 1), ...
                inputs.splinedJointAccelerations(:, 1));
            testCase.verifyEqual(values.accelerations(:, 2), ...
                truth.accelerations, "AbsTol", 1e-12);
        end

        function synergyActivationsComeBeforeTorqueControls(testCase)
            [inputs, phase, truth] = torqueProblem();
            inputs.controllerType = 'synergy';
            inputs.numSynergies = 2;
            inputs.synergyWeights = [1, 0; 0, 1];
            inputs.optimizeSynergyVectors = false;
            synergies = [0.1, 0.2; 0.3, 0.4; 0.5, 0.6];
            inputs.maxControl = [100, 1, 1, 50];
            inputs.minControl = [-100, 0, 0, -50];
            phase.control = scaleToBounds([truth.accelerations, ...
                synergies, truth.torques], inputs.maxControl, ...
                inputs.minControl);
            values = makeGpopsValuesAsStruct(phase, inputs);
            testCase.verifyEqual(values.controlSynergyActivations, ...
                synergies, "AbsTol", 1e-12);
            testCase.verifyEqual(values.torqueControls, truth.torques, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(values.synergyWeights, inputs.synergyWeights);
        end

        function optimizedSynergyWeightsComeFromParameters(testCase)
            % Tracking with optimize_synergy_vectors: the parameters fill
            % synergyWeightsIndices.
            [inputs, phase] = synergyWeightProblem("TrackingOptimization");
            values = makeGpopsValuesAsStruct(phase, inputs);
            testCase.verifyEqual(values.synergyWeights, [0.2, 0.8; 0.6, ...
                0.4], "AbsTol", 1e-12);
        end

        function designVariablesFollowSynergyWeights(testCase)
            % Design Optimization: user-defined variables come after the
            % optimized synergy weights, each as long as its
            % initial_values.
            [inputs, phase] = synergyWeightProblem("DesignOptimization");
            values = makeGpopsValuesAsStruct(phase, inputs);
            testCase.verifyEqual(values.synergyWeights, [0.2, 0.8; 0.6, ...
                0.4], "AbsTol", 1e-12);
            testCase.verifyEqual(values.parameters.belt_speed, [1.1, 1.3], ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(values.parameters.max_isometric_force, ...
                900, "AbsTol", 1e-9);
        end

        function variablesOfTheSameTypeAreAllKept(testCase)
            % Two max_isometric_force variables (one per muscle): the
            % built-in model function reads one value per variable, in
            % order (values.parameters.max_isometric_force(counter)).
            % Failed on candidate-1.5.4 (fixed later): each variable
            % overwrites values.parameters.<type>, so only the last one's
            % value is kept. See docs/failures.md (B28).
            [inputs, phase] = synergyWeightProblem("DesignOptimization");
            inputs.userDefinedVariables = { ...
                struct("type", "max_isometric_force", "initial_values", 1000), ...
                struct("type", "max_isometric_force", "initial_values", 1000)};
            inputs.maxParameter = [ones(1, 4), 2000, 2000];
            inputs.minParameter = zeros(1, 6);
            phase.parameter = scaleToBounds([0.2, 0.6, 0.8, 0.4, 900, ...
                1200], inputs.maxParameter, inputs.minParameter);
            values = makeGpopsValuesAsStruct(phase, inputs);
            testCase.verifyEqual(values.parameters.max_isometric_force, ...
                [900, 1200], "AbsTol", 1e-9);
        end

        % ---- makeOptimalControlBounds -----------------------------------

        function stateBoundsExtendTheDataRange(testCase)
            % Positions 0 to 3 (range 3) with multiple 2: 6 below the
            % minimum and above the maximum. Velocities -1 to 1 (range 2)
            % with multiple 1.5: 3 each way.
            inputs = boundsInputs();
            bounds = makeOptimalControlBounds(inputs);
            testCase.verifyEqual(bounds.maxState, [3 + 6, 1 + 3], ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(bounds.minState, [0 - 6, -1 - 3], ...
                "AbsTol", 1e-12);
        end

        function minimumRangeWinsWhenDataBarelyMoves(testCase)
            % Range 2 x multiple 1.5 = 3 is less than the minimum range
            % of 5, so the minimum is used.
            inputs = boundsInputs();
            inputs.jointVelocitiesMinRange = 5;
            bounds = makeOptimalControlBounds(inputs);
            testCase.verifyEqual(bounds.maxState(2), 1 + 5, "AbsTol", 1e-12);
            testCase.verifyEqual(bounds.minState(2), -1 - 5, "AbsTol", 1e-12);
        end

        function controlBoundsCoverAccelerationsAndTorques(testCase)
            % Accelerations -10 to 10 (range 20, multiple 1): +-20 more.
            % Torque on "b" from its ID moment, 0 to 40 (range 40,
            % multiple 1): +-40 more.
            inputs = boundsInputs();
            bounds = makeOptimalControlBounds(inputs);
            testCase.verifyEqual(bounds.maxControl, [10 + 20, 40 + 40], ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(bounds.minControl, [-10 - 20, 0 - 40], ...
                "AbsTol", 1e-12);
        end

        function synergyActivationsAreBoundedByTheMaximum(testCase)
            % Synergy controls go between the accelerations and torques,
            % from 0 to maximum_allowable_synergy_activation.
            inputs = boundsInputs();
            inputs.controllerType = 'synergy';
            inputs.numSynergies = 2;
            inputs.maxControlSynergyActivations = 10;
            inputs.optimizeSynergyVectors = false;
            bounds = makeOptimalControlBounds(inputs);
            testCase.verifyEqual(bounds.maxControl, [30, 10, 10, 80], ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(bounds.minControl, [-30, 0, 0, -40], ...
                "AbsTol", 1e-12);
        end

        function optimizedSynergyWeightsAreBoundedByTheNormalization(testCase)
            % One parameter per weight (groups of 2x3 and 1x2 = 8),
            % between 0 and synergy_vector_normalization_value.
            inputs = boundsInputs();
            inputs.controllerType = 'synergy';
            inputs.numSynergies = 3;
            inputs.maxControlSynergyActivations = 10;
            inputs.optimizeSynergyVectors = true;
            inputs.synergyNormalizationValue = 2;
            inputs.synergyGroups = {struct("numSynergies", 2, ...
                "muscleNames", ["m1", "m2", "m3"]), ...
                struct("numSynergies", 1, "muscleNames", ["m4", "m5"])};
            bounds = makeOptimalControlBounds(inputs);
            testCase.verifyEqual(bounds.maxParameter, 2 * ones(1, 8));
            testCase.verifyEqual(bounds.minParameter, zeros(1, 8));
        end

        function designVariableBoundsAreAppended(testCase)
            inputs = boundsInputs();
            inputs.toolName = "DesignOptimization";
            inputs.userDefinedVariables = {struct("upper_bounds", [2, 3], ...
                "lower_bounds", [0.5, 1])};
            bounds = makeOptimalControlBounds(inputs);
            testCase.verifyEqual(bounds.maxParameter, [2, 3]);
            testCase.verifyEqual(bounds.minParameter, [0.5, 1]);
        end
    end
end

function [inputs, phase, truth] = torqueProblem()
% Two model coordinates, "a" and "b"; "b" is the states coordinate and is
% torque controlled. Three collocation points from 0 to 1 s.
truth.time = [0; 0.5; 1];
truth.positions = [0.5; 1; 1.5];
truth.velocities = [-10; 0; 10];
truth.accelerations = [0; 50; -50];
truth.torques = [-25; 0; 25];
inputs.toolName = "TrackingOptimization";
inputs.controllerType = 'torque';
inputs.numSynergies = 0;
inputs.coordinateNames = ["a", "b"];
inputs.statesCoordinateNames = "b";
inputs.statesCoordinateIndices = 2;
inputs.torqueControllerCoordinateNames = "b";
inputs.collocationTimeOriginal = truth.time;
inputs.splinedJointAngles = [10, 0; 11, 0; 12, 0];
inputs.splinedJointSpeeds = [1, 0; 2, 0; 3, 0];
inputs.splinedJointAccelerations = [7, 0; 8, 0; 9, 0];
inputs.maxTime = 1;
inputs.minTime = 0;
inputs.maxState = [2, 20];
inputs.minState = [0, -20];
inputs.maxControl = [100, 50];
inputs.minControl = [-100, -50];
phase.time = scaleToBounds(truth.time, inputs.maxTime, inputs.minTime);
phase.state = scaleToBounds([truth.positions, truth.velocities], ...
    inputs.maxState, inputs.minState);
phase.control = scaleToBounds([truth.accelerations, truth.torques], ...
    inputs.maxControl, inputs.minControl);
end

function [inputs, phase] = synergyWeightProblem(toolName)
% A synergy problem whose 2 x 2 synergy weights are all optimized, plus,
% for Design Optimization, two user-defined variables.
[inputs, phase] = torqueProblem();
inputs.toolName = toolName;
inputs.controllerType = 'synergy';
inputs.numSynergies = 2;
inputs.torqueControllerCoordinateNames = strings(1, 0);
inputs.maxControl = [100, 1, 1];
inputs.minControl = [-100, 0, 0];
phase.control = zeros(3, 3);
inputs.synergyWeights = zeros(2);
inputs.optimizeSynergyVectors = true;
inputs.synergyWeightsIndices = 1 : 4; % column-major: (1,1) (2,1) (1,2) (2,2)
weights = [0.2, 0.6, 0.8, 0.4];
parameters = weights;
inputs.maxParameter = ones(1, 4);
inputs.minParameter = zeros(1, 4);
if toolName == "DesignOptimization"
    inputs.userDefinedVariables = { ...
        struct("type", "belt_speed", "initial_values", [1, 1]), ...
        struct("type", "max_isometric_force", "initial_values", 1000)};
    parameters = [parameters, 1.1, 1.3, 900];
    inputs.maxParameter = [inputs.maxParameter, 2, 2, 2000];
    inputs.minParameter = [inputs.minParameter, 0, 0, 0];
end
phase.parameter = scaleToBounds(parameters, inputs.maxParameter, ...
    inputs.minParameter);
end

function inputs = boundsInputs()
% Coordinates "a" and "b"; "b" is the states coordinate and is torque
% controlled. Default range multiples (2, 1.5, 1, torque 1) and minimum
% ranges (0).
inputs.toolName = "TrackingOptimization";
inputs.controllerType = 'torque';
inputs.coordinateNames = ["a", "b"];
inputs.statesCoordinateNames = "b";
inputs.experimentalJointAngles = [5, 0; 6, 3; 7, 1];
inputs.experimentalJointVelocities = [0, -1; 0, 1; 0, 0];
inputs.experimentalJointAccelerations = [0, -10; 0, 10; 0, 0];
inputs.jointPositionsMultiple = 2;
inputs.jointVelocitiesMultiple = 1.5;
inputs.jointAccelerationsMultiple = 1;
inputs.jointPositionsMinRange = 0;
inputs.jointVelocitiesMinRange = 0;
inputs.jointAccelerationsMinRange = 0;
inputs.torqueControllerCoordinateNames = "b";
inputs.inverseDynamicsMomentLabels = ["a_moment", "b_moment"];
inputs.experimentalJointMoments = [100, 0; 100, 40; 100, 10];
inputs.maxTorqueControlsMultiple = 1;
inputs.maxTorqueControlsMinRange = 0;
end
