% Tests for prepareNcpInitialValues, which builds NCP's starting design
% vector, on candidate-1.5.4:
% - without MTP activations: every weight and command node is the same
%   constant, chosen so each synergy's weights meet the normalization
%   target (sum: value / muscles, magnitude: value / sqrt(muscles); 0.15
%   without a target);
% - with fixed synergy weights and MTP activations: the weights are kept
%   and the commands are fitted to the activations by non-negative least
%   squares;
% - with bilateral symmetry: the synergy groups are checked first.
%
% The NNMF starting values used when MTP activations are given (1000
% replicates on the parallel pool) are exercised by the regression tests.

classdef (TestTags = {'Unit'}) NcpInitialValuesTest < matlab.unittest.TestCase

    methods (Test)
        function magnitudeGivesEachSynergyTheTargetNorm(testCase)
            % Group A has 3 muscles: 10 / sqrt(3); group B has 2:
            % 10 / sqrt(2). Each synergy's weight vector then has norm 10.
            inputs = constantInputs("magnitude", 10);
            values = evalcValues(inputs);
            weights = findSynergyWeightsAndCommands(values, inputs);
            testCase.verifyEqual(vecnorm(weights, 2, 2), [10; 10; 10], ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(values(1 : 8)', [repmat(10 / sqrt(3), ...
                1, 6), repmat(10 / sqrt(2), 1, 2)], "AbsTol", 1e-12);
        end

        function sumGivesEachSynergyTheTargetSum(testCase)
            inputs = constantInputs("sum", 10);
            values = evalcValues(inputs);
            weights = findSynergyWeightsAndCommands(values, inputs);
            testCase.verifyEqual(sum(weights, 2), [10; 10; 10], ...
                "AbsTol", 1e-12);
        end

        function commandsStartAtTheGroupConstant(testCase)
            % Each synergy's command nodes, in every trial, equal its
            % group's weight constant.
            inputs = constantInputs("sum", 10);
            values = evalcValues(inputs);
            [~, ~, nodes] = findSynergyWeightsAndCommands(values, inputs);
            testCase.verifyEqual(squeeze(nodes(2, :, 1)), ...
                repmat(10 / 3, 1, 4), "AbsTol", 1e-12);
            testCase.verifyEqual(squeeze(nodes(1, :, 3)), ...
                repmat(10 / 2, 1, 4), "AbsTol", 1e-12);
        end

        function withoutTargetEverythingStartsAt015(testCase)
            inputs = constantInputs("magnitude", NaN);
            values = evalcValues(inputs);
            testCase.verifyEqual(values, 0.15 * ones(size(values)));
        end

        function fixedWeightsFitCommandsToMtpActivations(testCase)
            % Activations made from known non-negative commands and the
            % fixed weights: the NNLS fit finds those commands, and the
            % weights are left as given. (Identity B-spline matrix, so
            % the nodes are the commands.)
            inputs = constantInputs("magnitude", 10);
            inputs.optimize_synergy_vectors = false;
            inputs.fixedSynergyWeights = [1 0.5 0 0 0; 0.2 1 0.7 0 0; ...
                0 0 0 1 0.3];
            commands = cat(1, reshape([0.1 0.5 0.3 0.2; 0.4 0 0.2 0.6; ...
                0.3 0.3 0.1 0.5]', 1, 4, 3), reshape([0.2 0.2 0.4 0.1; ...
                0.5 0.1 0 0.3; 0.1 0.6 0.2 0.4]', 1, 4, 3));
            inputs.mtpActivations = zeros(2, 5, 4);
            for t = 1 : 2
                inputs.mtpActivations(t, :, :) = (squeeze(commands(t, :, ...
                    :)) * inputs.fixedSynergyWeights)';
            end
            values = evalcValues(inputs);
            [weights, ~, nodes] = findSynergyWeightsAndCommands(values, inputs);
            testCase.verifyEqual(weights, inputs.fixedSynergyWeights);
            testCase.verifyEqual(nodes, commands, "AbsTol", 1e-10);
        end

        function bilateralSymmetryNeedsTwoGroups(testCase)
            inputs = constantInputs("magnitude", 10);
            inputs.enforce_bilateral_symmetry = true;
            inputs.synergyGroups{3} = struct("numSynergies", 1, ...
                "muscleNames", "c1", "muscleGroupName", "C");
            verifyErrorMessage(testCase, @() prepareNcpInitialValues( ...
                inputs, struct()), "requires exactly two synergy groups");
        end

        function bilateralSymmetryNeedsEqualGroups(testCase)
            % Groups of 3 and 2 muscles cannot mirror each other.
            inputs = constantInputs("magnitude", 10);
            inputs.enforce_bilateral_symmetry = true;
            verifyErrorMessage(testCase, @() prepareNcpInitialValues( ...
                inputs, struct()), "same number of muscles");
        end
    end
end

function inputs = constantInputs(method, value)
% Group A: 2 synergies, 3 muscles; group B: 1 synergy, 2 muscles. Two
% trials, four nodes, identity B-spline matrix (4 frames).
inputs.synergyGroups = {struct("numSynergies", 2, ...
    "muscleNames", ["a1", "a2", "a3"], "muscleGroupName", "A"), ...
    struct("numSynergies", 1, "muscleNames", ["b1", "b2"], ...
    "muscleGroupName", "B")};
inputs.numSynergies = 3;
inputs.numMuscles = 5;
inputs.numTrials = 2;
inputs.numNodes = 4;
inputs.numPoints = 4;
inputs.Bmatrix = eye(4);
inputs.invBmatrix = eye(4);
inputs.numWeightsPerGroup = [6, 2];
inputs.optimize_synergy_vectors = true;
inputs.enforce_bilateral_symmetry = false;
inputs.synergy_vector_normalization_method = string(method);
inputs.synergy_vector_normalization_value = value;
end

function values = evalcValues(inputs)
% prepareNcpInitialValues prints progress; keep the test report readable.
[~, values] = evalc("prepareNcpInitialValues(inputs, struct())");
end
