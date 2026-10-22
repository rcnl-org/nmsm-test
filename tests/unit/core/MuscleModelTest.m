% Tests for the Hill-type muscle model in src/core/muscle (and the EMG time
% delays in src/MuscleTendonPersonalization/Modeling) that MTP uses to go
% from EMG to joint moments:
%   EMG --delay, scale--> excitation --activation dynamics--> neural
%   activation --nonlinearity--> activation --fiber length, velocity,
%   force curves--> muscle force --moment arms--> joint moment
%
% Each step is checked against values worked out by hand or against the
% differential equation it solves. Arrays follow MTP's layout: (trial x
% muscle x frame), moment arms (trial x coordinate x muscle x frame).

classdef (TestTags = {'Unit'}) MuscleModelTest < matlab.unittest.TestCase

    properties (Constant)
        % passiveForceLengthCurve is e1 * log(1 + exp(e2 * (l - e3)))
        e1 = 0.232000797810576
        e2 = 12.438535493526128
        e3 = 1.329470475731338
    end

    methods (Test)
        % ---- EMG -> excitation ------------------------------------------

        function commonDelayShiftsEmgLater(testCase)
            % EMG ramps e(t) = t and 2t. A delay of 0.5 (stored x10, so
            % 0.05 s) means the excitation at t is the EMG at t - 0.05.
            % The splines come from makeEmgSplines, as in the MTP parser.
            % Expected to fail on candidate-1.5.4, where a shared delay
            % only works with one multi-muscle spline per trial; see
            % tests/README.md.
            [time, splines] = rampEmg([1, 2]);
            excitation = calcMuscleExcitations(time, splines, 0.5, [1, 1]);
            expected = permute([time - 0.05; 2 * (time - 0.05)], [3, 1, 2]);
            testCase.verifyEqual(excitation, expected, "AbsTol", 1e-12);
        end

        function muscleSpecificDelaysShiftEachMuscle(testCase)
            [time, splines] = rampEmg([1, 2]);
            excitation = calcMuscleExcitations(time, splines, ...
                [0.2, 0.8], [1, 1]);
            expected = permute([time - 0.02; 2 * (time - 0.08)], ...
                [3, 1, 2]);
            testCase.verifyEqual(excitation, expected, "AbsTol", 1e-12);
        end

        function scaleFactorsMultiplyEachMuscle(testCase)
            [time, splines] = rampEmg([1, 1]);
            excitation = calcMuscleExcitations(time, splines, [0, 0], ...
                [0.5, 2]);
            expected = permute([0.5 * time; 2 * time], [3, 1, 2]);
            testCase.verifyEqual(excitation, expected, "AbsTol", 1e-12);
        end

        % ---- excitation -> neural activation ----------------------------

        function constantExcitationIsReachedExactly(testCase)
            % The steady state of the activation dynamics is a = e.
            time = 0 : 1e-3 : 1;
            excitation = 0.5 * ones(1, 1, length(time));
            activation = calcNeuralActivations(excitation, 1.5, time, 0);
            testCase.verifyEqual(activation(end), 0.5, "AbsTol", 1e-9);
        end

        function activationRisesWithActivationTimeConstant(testCase)
            % With e = 1, da/dt = (1 - a) / tauA, so a = 1 - exp(-t/tauA).
            % The time constant input is in hundredths of a second
            % (1.5 -> 15 ms). The first two frames are fixed at 0, so time
            % is counted from frame 2. Starting the second-order scheme
            % from that rest lags the exact curve by about half a frame,
            % an error of dt / (2 * tauA), so dt is small here.
            dt = 1e-5;
            tauA = 0.015;
            time = 0 : dt : 0.1;
            activation = squeeze(calcNeuralActivations( ...
                ones(1, 1, length(time)), 1.5, time, 0))';
            t = time(3 : end) - time(2);
            testCase.verifyEqual(activation(3 : end), 1 - exp(-t / tauA), ...
                "AbsTol", 1e-3);
        end

        function deactivationIsFourTimesSlower(testCase)
            % After a long e = 1, setting e = 0 gives da/dt = -a / tauD,
            % with tauD = 4 * tauA = 60 ms.
            dt = 1e-4;
            tauD = 0.06;
            time = 0 : dt : 0.5;
            switchFrame = 2001; % a is 1 to within 1e-50 by then
            excitation = ones(1, 1, length(time));
            excitation(switchFrame : end) = 0;
            activation = squeeze(calcNeuralActivations(excitation, 1.5, ...
                time, 0))';
            t = time(switchFrame : end) - time(switchFrame - 1);
            testCase.verifyEqual(activation(switchFrame : end), ...
                exp(-t / tauD), "AbsTol", 1e-3);
        end

        function eachTrialUsesItsOwnTimeStep(testCase)
            % Two trials with different frame spacing, same excitation:
            % each should follow 1 - exp(-t/tauA) in its own time.
            tauA = 0.015;
            time = [0 : 1e-5 : 0.03; 0 : 2e-5 : 0.06];
            activation = calcNeuralActivations(ones(2, 1, ...
                size(time, 2)), 1.5, time, 0);
            for trial = 1 : 2
                t = time(trial, 3 : end) - time(trial, 2);
                testCase.verifyEqual(squeeze(activation(trial, 1, ...
                    3 : end))', 1 - exp(-t / tauA), "AbsTol", 2e-3);
            end
        end

        function paddingFramesAreRemoved(testCase)
            time = 0 : 1e-3 : 0.05;
            excitation = reshape(linspace(0, 1, length(time)), 1, 1, []);
            full = calcNeuralActivations(excitation, 1.5, time, 0);
            padded = calcNeuralActivations(excitation, 1.5, time, 5);
            testCase.verifySize(padded, [1, 1, length(time) - 10]);
            testCase.verifyEqual(padded, full(:, :, 6 : end - 5), ...
                "AbsTol", 1e-15);
        end

        function undershootBelowZeroIsSetToZero(testCase)
            % With frames far apart compared with the 60 ms deactivation
            % time constant, the scheme overshoots past zero after the
            % excitation switches off: by hand, with c = 2 * dt / tauD,
            % a = (4 * a(-1) - a(-2)) / (3 + c) goes 1, 1, 0.474, 0.142,
            % 0.015, -0.013. Those negative values must come out as 0.
            time = 0 : 0.1 : 5;
            excitation = ones(1, 1, length(time));
            excitation(31 : end) = 0;
            activation = calcNeuralActivations(excitation, 1.5, time, 0);
            testCase.verifyGreaterThanOrEqual(activation, 0);
            testCase.verifyEqual(activation(34), 0);
        end

        % ---- neural activation -> activation ----------------------------

        function zeroNonlinearityLeavesActivationUnchanged(testCase)
            neural = rand(2, 3, 4);
            testCase.verifyEqual(calcMuscleActivations(neural, ...
                [0, 0, 0]), neural, "AbsTol", 1e-15);
        end

        function nonlinearityKeepsZeroAndOneFixed(testCase)
            neural = reshape([0, 1, 0, 1], 1, 2, 2);
            testCase.verifyEqual(calcMuscleActivations(neural, ...
                [0.35, 1]), neural, "AbsTol", 1e-4);
        end

        function nonlinearityRaisesLowActivations(testCase)
            % The nonlinear curve lies above the line: a muscle produces
            % more force at low activation than a linear model predicts.
            neural = reshape(linspace(0.05, 0.95, 19), 1, 1, []);
            testCase.verifyGreaterThan(calcMuscleActivations(neural, 1), ...
                neural);
        end

        function nonlinearityBlendsLinearAndNonlinearCurves(testCase)
            % activation = (1 - A) * linear + A * fully nonlinear
            neural = rand(1, 1, 10);
            linear = calcMuscleActivations(neural, 0);
            nonlinear = calcMuscleActivations(neural, 1);
            testCase.verifyEqual(calcMuscleActivations(neural, 0.3), ...
                0.7 * linear + 0.3 * nonlinear, "AbsTol", 1e-12);
        end

        function nonlinearityIsAppliedPerMuscle(testCase)
            neural = 0.1 * ones(1, 2, 3);
            activation = calcMuscleActivations(neural, [0, 1]);
            testCase.verifyEqual(activation(1, 1, :), neural(1, 1, :), ...
                "AbsTol", 1e-15);
            testCase.verifyEqual(activation(1, 2, :), ...
                calcMuscleActivations(neural(1, 2, :), 1), "AbsTol", 1e-15);
        end

        % ---- fiber length and velocity ----------------------------------

        function normalizedFiberLengthAndVelocity(testCase)
            % Muscle 1: no pennation. (0.3 - 0.2) / 0.1 = 1;
            %   velocity 0.5 / (10 * 0.1) = 0.5.
            % Muscle 2: 60 deg pennation, cos = 0.5.
            %   (0.5 - 0.3) / (0.2 * 0.5) = 2; -0.4 / (10 * 0.2 * 0.5) = -0.4.
            data = twoMuscleData();
            [lengths, velocities] = ...
                calcNormalizedMuscleFiberLengthsAndVelocities(data, ...
                [1, 1], [1, 1]);
            testCase.verifyEqual(lengths, [1, 2], "AbsTol", 1e-12);
            testCase.verifyEqual(velocities, [0.5, -0.4], "AbsTol", 1e-12);
        end

        function scaleFactorsScaleOptimalAndSlackLengths(testCase)
            % Muscle 1: optimal length x2, (0.3 - 0.2) / 0.2 = 0.5.
            % Muscle 2: slack length x0.5, (0.5 - 0.15) / 0.1 = 3.5.
            data = twoMuscleData();
            [lengths, velocities] = ...
                calcNormalizedMuscleFiberLengthsAndVelocities(data, ...
                [2, 1], [1, 0.5]);
            testCase.verifyEqual(lengths, [0.5, 3.5], "AbsTol", 1e-12);
            testCase.verifyEqual(velocities, [0.25, -0.4], "AbsTol", 1e-12);
        end

        function missingLengthOrVelocityGivesEmpty(testCase)
            data = rmfield(twoMuscleData(), "muscleTendonVelocity");
            [lengths, velocities] = ...
                calcNormalizedMuscleFiberLengthsAndVelocities(data, ...
                [1, 1], [1, 1]);
            testCase.verifyEqual(lengths, [1, 2], "AbsTol", 1e-12);
            testCase.verifyEmpty(velocities);
        end

        % ---- forces and moments -----------------------------------------

        function passiveForceIncludesPennation(testCase)
            % F0 * cos(pennation) * passive curve, at the curve center
            % where the passive curve is e1 * log(2).
            force = calcPassiveForceLengthCurve(testCase.e3, 1000, pi / 3);
            testCase.verifyEqual(force, 1000 * 0.5 * testCase.e1 * log(2), ...
                "AbsTol", 1e-9);
        end

        function muscleForceAtOptimalLengthAndZeroVelocity(testCase)
            % Active force = F0 * a; passive = F0 * passive curve at 1;
            % tendon force = total * cos(pennation).
            passiveAtOne = testCase.e1 * log1p(exp(testCase.e2 * ...
                (1 - testCase.e3)));
            [active, passive, total] = calcMuscleForce(1, 0, 1000, 0.5);
            testCase.verifyEqual(active, 500, "AbsTol", 1e-3);
            testCase.verifyEqual(passive, 1000 * passiveAtOne, ...
                "AbsTol", 1e-9);
            testCase.verifyEqual(total, active + passive, "AbsTol", 1e-12);
            testCase.verifyEqual(calcTendonForce(1, 0, 1000, 0.5, ...
                pi / 3), 0.5 * total, "AbsTol", 1e-9);
        end

        function passiveMomentIsMomentArmTimesPassiveForce(testCase)
            % One muscle at the passive curve center: F0 = 1000 N, no
            % pennation, moment arm 0.05 m -> 50 * e1 * log(2) Nm.
            data.pennationAngle = 0;
            data.momentArms = 0.05 * ones(1, 1, 1, 3);
            moments = calcPassiveMuscleMoments(data, 1000, ...
                testCase.e3 * ones(1, 1, 3));
            testCase.verifyEqual(moments, 50 * testCase.e1 * log(2) * ...
                ones(1, 1, 3), "AbsTol", 1e-9);
        end

        function jointMomentSumsMusclesWithMomentArmSigns(testCase)
            % Two muscles at optimal length and zero velocity, so each
            % produces F0 * (a + passive curve at 1) along the tendon,
            % times cos(pennation). Muscle 1 flexes coordinate 1; muscle 2
            % extends it. Only muscle 2 crosses coordinate 2.
            passiveAtOne = testCase.e1 * log1p(exp(testCase.e2 * ...
                (1 - testCase.e3)));
            data.maxIsometricForce = [1000, 2000];
            data.pennationAngle = [0, pi / 3];
            data.momentArms = zeros(1, 2, 2, 4);
            data.momentArms(1, 1, :, :) = repmat([0.05; -0.02], 1, 4);
            data.momentArms(1, 2, 2, :) = 0.03;
            activations = repmat([0.5, 0.2], 1, 1, 4);
            force1 = 1000 * (0.5 + passiveAtOne);
            force2 = 2000 * (0.2 + passiveAtOne) * 0.5;
            expected = zeros(1, 2, 4);
            expected(1, 1, :) = 0.05 * force1 - 0.02 * force2;
            expected(1, 2, :) = 0.03 * force2;

            moments = calcMuscleJointMoments(data, activations, ...
                ones(1, 2, 4), zeros(1, 2, 4));
            testCase.verifyEqual(moments, expected, "AbsTol", 1e-2);
        end

        function maxIsometricForceFromVolumeAndStress(testCase)
            % F0 = volume / optimal length * stress:
            % 1e-4 m^3 / 0.1 m * 610 kPa = 610 N.
            testCase.verifyEqual(calcMaxIsometricForce([1e-4, 2e-4], ...
                [0.1, 0.1], 610e3), [610, 1220], "AbsTol", 1e-9);
        end
    end
end

function [time, splines] = rampEmg(slopes)
% One trial of EMG that is a straight line per muscle, e(t) = slope * t.
% A spline through a line is that line, so delayed values are exact.
time = 0 : 0.01 : 1;
emg = permute(slopes' * time, [3, 1, 2]);
splines = makeEmgSplines(time, emg);
end

function data = twoMuscleData()
data.optimalFiberLength = [0.1, 0.2];
data.tendonSlackLength = [0.2, 0.3];
data.pennationAngle = [0, pi / 3];
data.vMaxFactor = 10;
data.muscleTendonLength = [0.3, 0.5];
data.muscleTendonVelocity = [0.5, -0.4];
end
