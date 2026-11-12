% Tests for calcMuscleTendonNonLinearConstraints, which keeps every
% normalized fiber length between 0.3 and 1.3 during MTP's optimization.
% fmincon requires c <= 0. The constraints are smooth approximations
% (softmax/softmin with sharpness 500) of
%   c = [max(length) - 1.3, 0.3 - min(length)]   per muscle,
% which are within log(number of frames) / 500 of the exact values.
%
% (The source comment says "less than 1.5"; the code uses 1.3.)

classdef (TestTags = {'Unit'}) NonLinearConstraintsTest < matlab.unittest.TestCase

    methods (Test)
        function constraintsApproximateMaxAndMinFiberLength(testCase)
            % Muscle 1 ranges 0.5 to 1.0, muscle 2 ranges 0.25 to 1.4.
            lengths = [linspace(0.5, 1, 11); linspace(0.25, 1.4, 11)];
            [c, ceq] = constraintsFor(lengths);
            tolerance = log(11) / 500;
            testCase.verifyEmpty(ceq);
            testCase.verifyEqual(c, [1 - 1.3, 1.4 - 1.3, 0.3 - 0.5, ...
                0.3 - 0.25], "AbsTol", tolerance);
        end

        function lengthsWithinLimitsAreFeasible(testCase)
            c = constraintsFor([linspace(0.5, 1.2, 11); ...
                linspace(0.4, 1.1, 11)]);
            testCase.verifyLessThan(c, 0);
        end

        function lengthsOutsideLimitsAreInfeasible(testCase)
            c = constraintsFor([linspace(0.5, 1.35, 11); ...
                linspace(0.25, 1.1, 11)]);
            testCase.verifyGreaterThan(c([1, 4]), 0);
            testCase.verifyLessThan(c([2, 3]), 0);
        end
    end
end

function [c, ceq] = constraintsFor(normalizedFiberLengths)
% Builds the smallest MTP inputs whose modeled normalized fiber lengths
% are the given (muscle x frame) values: optimal fiber length 1 m, tendon
% slack length 0, no pennation, so length = muscle-tendon length. The EMG
% and activation inputs only need to be valid.
[numMuscles, numFrames] = size(normalizedFiberLengths);
inputs.muscleTendonLength = reshape(normalizedFiberLengths, ...
    1, numMuscles, numFrames);
inputs.muscleTendonVelocity = zeros(1, numMuscles, numFrames);
inputs.optimalFiberLength = ones(1, numMuscles);
inputs.tendonSlackLength = zeros(1, numMuscles);
inputs.pennationAngle = zeros(1, numMuscles);
inputs.maxIsometricForce = ones(1, numMuscles);
inputs.vMaxFactor = 10;
inputs.momentArms = zeros(1, 1, numMuscles, numFrames);
inputs.numPaddingFrames = 0;
inputs.emgTime = linspace(0, 1, numFrames);
inputs.emgSplines = makeEmgSplines(inputs.emgTime, ...
    0.5 * ones(1, numMuscles, numFrames));
primaryValues = {zeros(1, numMuscles), 1.5 * ones(1, numMuscles), ...
    zeros(1, numMuscles), 0.5 * ones(1, numMuscles), ...
    ones(1, numMuscles), ones(1, numMuscles)};
[c, ceq] = calcMuscleTendonNonLinearConstraints([], primaryValues, ...
    zeros(1, 7), inputs, struct());
end
