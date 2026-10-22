% Tests for NCP's cost function, calcNcpCost
% (src/NeuralControlPersonalization/Optimization), on candidate-1.5.4.
%
% Each enabled term turns its raw errors e into (e / allowable error) /
% sqrt(numel(e)) and adds their sum of squares, i.e. the mean of
% (e / allowable error)^2. The problem here is small enough to work out by
% hand: one trial, two muscles m1 and m2 in one synergy group with one
% synergy, three frames, and an identity B-spline matrix so the command
% equals its nodes c = [0.2 0.4 0.6]. With weights [1 w2], m1's activation
% is c and m2's is w2 * c.

classdef (TestTags = {'Unit'}) NcpCostTest < matlab.unittest.TestCase

    properties (Constant)
        command = [0.2, 0.4, 0.6]
        % passiveForceLengthCurve at normalized fiber length 1
        passiveAtOne = 0.232000797810576 * log1p(exp(12.438535493526128 * ...
            (1 - 1.329470475731338)))
    end

    methods (Test)
        function momentTrackingIsMeanSquaredScaledError(testCase)
            % Fibers at optimal length and rest, F0 = 100 N, no pennation,
            % moment arms 0.01 m: each muscle adds (a + passive) Nm.
            % Inverse dynamics is off by [1 2 3] Nm; allowable error 2:
            % ((1/2)^2 + (2/2)^2 + (3/2)^2) / 3
            inputs = smallInputs();
            values = designVector([1, 1]);
            moments = sum(activationsOf(values, inputs) + ...
                testCase.passiveAtOne, 2);
            inputs.inverseDynamicsMoments = moments - reshape([1, 2, 3], ...
                1, 1, 3);
            cost = calcNcpCost(values, inputs, ...
                params(term("moment_tracking", 2)));
            testCase.verifyEqual(cost, 3.5 / 3, "AbsTol", 1e-9);
        end

        function activationTrackingUsesOnlyMusclesWithMtpData(testCase)
            % Only m1 has MTP activations, 0.1 above NCP's. Allowable
            % error 0.05: (0.1 / 0.05)^2 = 4. m2 is not compared.
            inputs = withMtpData(smallInputs(), "m1", testCase.command + 0.1);
            cost = calcNcpCost(designVector([1, 5]), inputs, ...
                params(term("activation_tracking", 0.05)));
            testCase.verifyEqual(cost, 4, "AbsTol", 1e-12);
        end

        function activationTrackingWithoutMtpDataCostsNothing(testCase)
            cost = calcNcpCost(designVector([1, 1]), smallInputs(), ...
                params(term("activation_tracking", 0.05)));
            testCase.verifyEqual(cost, 0);
        end

        function activationMinimizationUsesMusclesWithoutMtpData(testCase)
            % m2 (no MTP data) has activation c; allowable error 0.5:
            % (0.4^2 + 0.8^2 + 1.2^2) / 3. m1 (MTP data) is not included.
            inputs = withMtpData(smallInputs(), "m1", testCase.command);
            expected = mean((testCase.command / 0.5) .^ 2);
            for type = ["activation_minimization", ...
                    "muscle_activation_minimization"]
                cost = calcNcpCost(designVector([7, 1]), inputs, ...
                    params(term(type, 0.5)));
                testCase.verifyEqual(cost, expected, "AbsTol", 1e-12, type);
            end
        end

        function synergyActivationMinimizationUsesCommands(testCase)
            % The command itself, whatever the weights.
            cost = calcNcpCost(designVector([3, 3]), smallInputs(), ...
                params(term("synergy_activation_minimization", 0.5)));
            testCase.verifyEqual(cost, mean((testCase.command / 0.5) .^ 2), ...
                "AbsTol", 1e-12);
        end

        function groupedActivationsPenalizeDifferenceFromGroupMean(testCase)
            % Weights [1 2]: activations c and 2c, group mean 1.5c, so
            % each is 0.5c from it: +-[0.1 0.2 0.3]; allowable error 0.1:
            % (1 + 4 + 9) * 2 / 6
            p = params(term("grouped_activations", 0.1));
            p.activationGroups = {[1, 2]};
            cost = calcNcpCost(designVector([1, 2]), smallInputs(), p);
            testCase.verifyEqual(cost, 28 / 6, "AbsTol", 1e-12);
        end

        function groupedFiberLengthsGroupActivationsByFiberLengthGroup( ...
                testCase)
            % Despite its name, grouped_fiber_lengths
            % (calcGroupedNormalizedFiberLengthCost) compares activations,
            % grouped by the normalized fiber length muscle groups: the same
            % cost as grouped_activations above (28 / 6), even though both
            % muscles' fiber lengths are identical. NCP's fiber lengths do
            % not depend on its design variables, so a cost on the lengths
            % themselves would be constant. This records the current
            % behavior; whether it is intended is an open question in
            % tests/README.md.
            p = params(term("grouped_fiber_lengths", 0.1));
            p.normalizedFiberLengthGroups = {[1, 2]};
            cost = calcNcpCost(designVector([1, 2]), smallInputs(), p);
            testCase.verifyEqual(cost, 28 / 6, "AbsTol", 1e-12);
        end

        function enabledTermsAddUp(testCase)
            inputs = withMtpData(smallInputs(), "m1", testCase.command + 0.1);
            values = designVector([1, 1]);
            terms = {term("activation_tracking", 0.05), ...
                term("activation_minimization", 0.5), ...
                term("moment_tracking", 2)};
            terms{3}.isEnabled = false;
            expected = calcNcpCost(values, inputs, params(terms{1})) + ...
                calcNcpCost(values, inputs, params(terms{2}));
            testCase.verifyEqual(calcNcpCost(values, inputs, ...
                params(terms{:})), expected, "AbsTol", 1e-12);
        end

        function unknownTermIsReported(testCase)
            % The parser gives the type as a character array (the message
            % is built with [...], which needs one).
            verifyErrorMessage(testCase, @() calcNcpCost(designVector( ...
                [1, 1]), smallInputs(), params(term('not_a_term', 1))), ...
                "not_a_term does not exist");
        end
    end
end

function values = designVector(weights)
% One synergy: weights for m1 and m2, then the three command nodes.
values = [weights, NcpCostTest.command]';
end

function activations = activationsOf(values, inputs)
activations = calcActivationsFromSynergyDesignVariables(values, inputs);
end

function inputs = smallInputs()
inputs.synergyGroups = {struct("numSynergies", 1, ...
    "muscleNames", ["m1", "m2"], "muscleGroupName", "G")};
inputs.numSynergies = 1;
inputs.numMuscles = 2;
inputs.numTrials = 1;
inputs.numNodes = 3;
inputs.numPoints = 3;
inputs.Bmatrix = eye(3);
inputs.muscleTendonColumnNames = ["m1", "m2"];
inputs.maxIsometricForce = [100, 100];
inputs.pennationAngle = [0, 0];
inputs.momentArms = 0.01 * ones(1, 1, 2, 3);
inputs.normalizedFiberLengths = ones(1, 2, 3);
inputs.normalizedFiberVelocities = zeros(1, 2, 3);
inputs.inverseDynamicsMoments = zeros(1, 1, 3);
end

function inputs = withMtpData(inputs, muscle, activation)
inputs.mtpActivationsColumnNames = muscle;
inputs.mtpActivations = reshape(activation, 1, 1, []);
end

function costTerm = term(type, maxAllowableError)
% As parseRcnlCostTermSet builds it from a file without <error_center>.
costTerm = struct("type", type, "isEnabled", true, ...
    "maxAllowableError", maxAllowableError, "errorCenter", 0);
end

function p = params(varargin)
p.costTerms = varargin;
p.activationGroups = {};
p.normalizedFiberLengthGroups = {};
end
