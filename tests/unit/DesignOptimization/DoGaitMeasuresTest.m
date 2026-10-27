% Tests for the gait measures Design Optimization's goal terms are built on
% (src/TreatmentOptimization/DesignOptimization): calcBrakingForce,
% calcPropulsiveForce and calcBhargavaMetabolicCost. Expected values are
% worked out by hand.

classdef (TestTags = {'Unit'}) DoGaitMeasuresTest < matlab.unittest.TestCase

    methods (Test)
        function brakingAndPropulsiveForcesSplitTheAnteriorForce(testCase)
            % Anterior (x) ground reaction force per foot: negative is
            % braking, positive propulsive; the other part is zero.
            modeled.groundReactionsLab.forces = {[-10, 700, 0; 5, 600, 0; ...
                0, 0, 0], [20, 500, 0; -3, 400, 0; 1, 1, 1]};
            values.time = [0; 0.5; 1];
            surfaces = cell(1, 2);
            testCase.verifyEqual(calcBrakingForce(modeled, values, ...
                surfaces), [10, 0; 0, 3; 0, 0], "AbsTol", 1e-12);
            testCase.verifyEqual(calcPropulsiveForce(modeled, values, ...
                surfaces), [0, 20; 5, 0; 0, 1], "AbsTol", 1e-12);
        end

        function restingMetabolicPowerIsBasalPlusMinimumHeat(testCase)
            % With no activation, at optimal length and no velocity, a
            % muscle does no work and its heat rate is held at its
            % minimum of 1 W/kg (smoothed: 0.5 + 0.5 tanh(10) W/kg).
            % Basal rate 1.2 W/kg x 70 kg. Muscle mass is density 1059.7
            % kg/m^3 x Fmax / 610 kPa x optimal fiber length.
            mass = 70;
            maxForce = [1000, 2000];
            optimalLength = [0.1, 0.05];
            power = calcBhargavaMetabolicCost(mass, zeros(2, 2), ...
                ones(2, 2), zeros(2, 2), maxForce, optimalLength, 10, ...
                [0, 0]);
            muscleMass = 1059.7 * maxForce / 610e3 .* optimalLength;
            minimumHeat = 0.5 + 0.5 * tanh(10);
            testCase.verifyEqual(power, (1.2 * mass + sum(muscleMass) * ...
                minimumHeat) * ones(2, 1), "RelTol", 1e-12);
        end

        function activeMusclesCostMore(testCase)
            power = @(a) calcBhargavaMetabolicCost(70, [a; a], ones(2, 1), ...
                zeros(2, 1), 1000, 0.1, 10, 0);
            resting = power(0);
            testCase.verifyGreaterThan(power(0.5), resting);
            testCase.verifyGreaterThan(power(1), power(0.5));
        end
    end
end
