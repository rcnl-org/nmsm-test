% Tests for Treatment Optimization's synergy-driven muscle model
% (src/TreatmentOptimization): normalizeSynergyData, which rescales the
% synergy weights and commands without changing the activations they make,
% and calcTreatmentOptimizationMuscleJointMoments, the sum over muscles of
% moment arm x Fmax x (a fL fV + fP) x cos(pennation).
%
% The muscle curves (activeForceLengthCurve, forceVelocityCurve,
% passiveForceLengthCurve) are checked in tests/unit/core/MuscleCurvesTest;
% here they give the expected values for the formula.

classdef (TestTags = {'Unit'}) ToSynergyModelTest < matlab.unittest.TestCase

    methods (Test)
        % ---- normalizeSynergyData ---------------------------------------

        function sumNormalizationMakesEachRowSumToTheValue(testCase)
            inputs = synergyInputs("sum", 1);
            normalized = normalizeSynergyData(inputs);
            testCase.verifyEqual(sum(normalized.synergyWeights, 2), ...
                [1; 1], "AbsTol", 1e-14);
            testCase.verifyEqual(normalized.synergyWeights, ...
                [0.25, 0.75; 0.5, 0.5], "AbsTol", 1e-14);
            testCase.verifyEqual(normalized.initialSynergyControls, ...
                [4, 6; 8, 12], "AbsTol", 1e-14);
        end

        function magnitudeNormalizationMakesEachRowNormTheValue(testCase)
            inputs = synergyInputs("magnitude", 2);
            normalized = normalizeSynergyData(inputs);
            testCase.verifyEqual(vecnorm(normalized.synergyWeights, 2, 2), ...
                [2; 2], "AbsTol", 1e-14);
        end

        function normalizationKeepsTheActivations(testCase)
            % commands x weights is unchanged by any normalization.
            for method = ["sum", "magnitude", "none"]
                inputs = synergyInputs(method, 3);
                normalized = normalizeSynergyData(inputs);
                testCase.verifyEqual(normalized.initialSynergyControls * ...
                    normalized.synergyWeights, ...
                    inputs.initialSynergyControls * inputs.synergyWeights, ...
                    "AbsTol", 1e-12, method);
            end
        end

        function normalizationRecordsTheInitialWeights(testCase)
            normalized = normalizeSynergyData(synergyInputs("sum", 1));
            testCase.verifyEqual(normalized.initialSynergyWeights, ...
                normalized.synergyWeights);
        end

        function unknownNormalizationIsReported(testCase)
            verifyErrorMessage(testCase, @() normalizeSynergyData( ...
                synergyInputs("max", 1)), "'sum', 'magnitude', and 'none'");
        end

        function torqueControllerIsLeftAlone(testCase)
            inputs = synergyInputs("sum", 1);
            inputs.controllerType = "torque";
            testCase.verifyEqual(normalizeSynergyData(inputs), inputs);
        end

        % ---- muscle joint moments ---------------------------------------

        function inactiveMuscleGivesOnlyPassiveMoment(testCase)
            % Activation 0: moment arm x Fmax x fP x cos(pennation).
            [inputs, modeled, momentArms] = oneMuscle(0, 1.2, 0);
            moments = calcTreatmentOptimizationMuscleJointMoments(inputs, ...
                modeled, momentArms);
            testCase.verifyEqual(moments, 0.05 * 1000 * ...
                passiveForceLengthCurve(1.2) * cos(0.2), "RelTol", 1e-12);
        end

        function activeMuscleAddsActiveForce(testCase)
            [inputs, modeled, momentArms] = oneMuscle(0.4, 0.9, -0.2);
            moments = calcTreatmentOptimizationMuscleJointMoments(inputs, ...
                modeled, momentArms);
            testCase.verifyEqual(moments, 0.05 * 1000 * (0.4 * ...
                activeForceLengthCurve(0.9) * forceVelocityCurve(-0.2) + ...
                passiveForceLengthCurve(0.9)) * cos(0.2), "RelTol", 1e-12);
        end

        function momentsSumOverMuscles(testCase)
            % Two muscles, two frames, one coordinate: each muscle's
            % moment adds.
            inputs.maxIsometricForce = [1000, 500];
            inputs.pennationAngle = [0, 0];
            inputs.surrogateModelIndex = 1;
            modeled.muscleActivations = [0.5, 1; 0, 0.2];
            modeled.normalizedFiberLength = ones(2);
            modeled.normalizedFiberVelocity = zeros(2);
            momentArms = zeros(2, 1, 2);
            momentArms(:, 1, 1) = 0.02;
            momentArms(:, 1, 2) = -0.03;
            moments = calcTreatmentOptimizationMuscleJointMoments(inputs, ...
                modeled, momentArms);
            force = @(a) a * activeForceLengthCurve(1) * ...
                forceVelocityCurve(0) + passiveForceLengthCurve(1);
            testCase.verifyEqual(moments, [ ...
                0.02 * 1000 * force(0.5) - 0.03 * 500 * force(1); ...
                0.02 * 1000 * force(0) - 0.03 * 500 * force(0.2)], ...
                "RelTol", 1e-12);
        end

        function surrogateIndexSelectsTheCoordinates(testCase)
            % Moment arms are given for every surrogate coordinate; only
            % those in surrogateModelIndex are returned, in its order.
            [inputs, modeled, ~] = oneMuscle(0, 1, 0);
            inputs.surrogateModelIndex = [3, 1];
            momentArms = reshape([0.01, 0.02, 0.03], 1, 3, 1);
            moments = calcTreatmentOptimizationMuscleJointMoments(inputs, ...
                modeled, momentArms);
            testCase.verifyEqual(moments ./ moments(2), [3, 1], ...
                "RelTol", 1e-12);
        end
    end
end

function inputs = synergyInputs(method, value)
% Two synergies over two muscles, two frames of commands
inputs.controllerType = "synergy";
inputs.synergyNormalizationMethod = method;
inputs.synergyNormalizationValue = value;
inputs.synergyWeights = [1, 3; 2, 2];
inputs.initialSynergyControls = [1, 1.5; 2, 3];
end

function [inputs, modeled, momentArms] = oneMuscle(activation, length, ...
    velocity)
% One muscle (Fmax 1000 N, pennation 0.2 rad), one frame, one coordinate
% with moment arm 0.05 m.
inputs.maxIsometricForce = 1000;
inputs.pennationAngle = 0.2;
inputs.surrogateModelIndex = 1;
modeled.muscleActivations = activation;
modeled.normalizedFiberLength = length;
modeled.normalizedFiberVelocity = velocity;
momentArms = 0.05;
end
