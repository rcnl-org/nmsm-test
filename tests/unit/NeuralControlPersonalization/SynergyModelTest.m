% Tests for NCP's synergy model (src/NeuralControlPersonalization/Modeling
% and Optimization/repackDesignVariables, src/core/BSpline): how the
% design vector holds synergy weights and B-spline command nodes, how
% commands come from the nodes, and how activations come from commands
% and weights.
%
% Layout of the design vector, for synergy groups g with s_g synergies and
% m_g muscles, T trials and N nodes:
%   [group 1 synergy 1 weights (m_1), group 1 synergy 2 weights, ...,
%    group 2 synergy 1 weights (m_2), ...,
%    trial 1 synergy 1 nodes (N), trial 1 synergy 2 nodes, ...,
%    trial 2 synergy 1 nodes, ...]
% A synergy only has weights for the muscles of its own group.
% Activations are (trial x muscle x frame).

classdef (TestTags = {'Unit'}) SynergyModelTest < matlab.unittest.TestCase

    properties
        inputs
    end

    methods (TestMethodSetup)
        function makeTwoGroupInputs(testCase)
            % Group A: 2 synergies, muscles a1 a2 a3. Group B: 1 synergy,
            % muscles b1 b2. Two trials, three nodes, and an identity
            % B-spline matrix, so commands equal their nodes.
            testCase.inputs = twoGroupInputs(eye(3));
        end
    end

    methods (Test)
        % ---- B-spline commands ------------------------------------------

        function bSplineRowsSumToOne(testCase)
            % Each frame is a weighted average of the nodes, so a
            % constant command stays constant.
            B = tutorialBSpline();
            testCase.verifySize(B, [101, 26]);
            testCase.verifyEqual(sum(B, 2), ones(101, 1), "AbsTol", 1e-12);
            testCase.verifyGreaterThanOrEqual(B, 0);
        end

        function bSplineNodesCanBeRecovered(testCase)
            % Full column rank: pinv(B) * B is the identity, which NCP
            % relies on to turn initial commands into nodes.
            B = tutorialBSpline();
            testCase.verifyEqual(pinv(B) * B, eye(26), "AbsTol", 1e-12);
        end

        function bSplineReproducesAStraightLine(testCase)
            % A cubic B-spline can represent any straight line exactly.
            B = tutorialBSpline();
            line = (0 : 100)' * 0.01 + 0.2;
            testCase.verifyEqual(B * (pinv(B) * line), line, "AbsTol", 1e-12);
        end

        % ---- packing the design vector ----------------------------------

        function weightsAreBlockDiagonalByGroup(testCase)
            values = [11 12 13, 21 22 23, 31 32, zeros(1, 18)]';
            weights = findSynergyWeightsAndCommands(values, testCase.inputs);
            testCase.verifyEqual(weights, [11 12 13 0 0; 21 22 23 0 0; ...
                0 0 0 31 32]);
        end

        function commandsComeFromNodesPerTrialAndSynergy(testCase)
            % Trial t, synergy s nodes are 100*t + 10*s + node.
            nodes = zeros(1, 18);
            k = 1;
            for t = 1 : 2
                for s = 1 : 3
                    nodes(k : k + 2) = 100 * t + 10 * s + (1 : 3);
                    k = k + 3;
                end
            end
            [~, commands, commandNodes] = findSynergyWeightsAndCommands( ...
                [zeros(1, 8), nodes]', testCase.inputs);
            testCase.verifyEqual(squeeze(commandNodes(2, :, 3)), [231 232 233]);
            testCase.verifyEqual(commands, commandNodes);
        end

        function repackIsTheInverseOfUnpack(testCase)
            values = (1 : 26)';
            [weights, ~, commandNodes] = findSynergyWeightsAndCommands( ...
                values, testCase.inputs);
            testCase.verifyEqual(repackDesignVariables(weights, ...
                commandNodes, testCase.inputs), values);
        end

        % ---- activations ------------------------------------------------

        function activationsAreCommandsTimesWeights(testCase)
            % Trial 2, muscle a2, frame 3:
            %   commands(2, 3, :) * weights(:, a2)
            values = (1 : 26)';
            [activations, weights, commands] = ...
                calcActivationsFromSynergyDesignVariables(values, ...
                testCase.inputs);
            testCase.verifySize(activations, [2, 5, 3]);
            expected = squeeze(commands(2, 3, :))' * weights(:, 2);
            testCase.verifyEqual(activations(2, 2, 3), expected, ...
                "AbsTol", 1e-12);
            % A group B muscle only gets group B's synergy.
            testCase.verifyEqual(activations(1, 4, 1), ...
                commands(1, 1, 3) * weights(3, 4), "AbsTol", 1e-12);
        end

        function activationsUseTheBSplineCommands(testCase)
            % With a real B-spline matrix, constant nodes give constant
            % commands and so constant activations. (A cubic B-spline
            % needs at least four nodes.)
            inputs = twoGroupInputs(BSplineMatrices(3, 4, 11, 10));
            values = [ones(1, 8), 0.5 * ones(1, 2 * 3 * 4)]';
            activations = calcActivationsFromSynergyDesignVariables(values, ...
                inputs);
            % a1 is in two synergies: 0.5 * 1 + 0.5 * 1
            testCase.verifyEqual(squeeze(activations(1, 1, :)), ...
                ones(11, 1), "AbsTol", 1e-12);
            testCase.verifyEqual(squeeze(activations(2, 4, :)), ...
                0.5 * ones(11, 1), "AbsTol", 1e-12);
        end

        % ---- after the optimization -------------------------------------

        function maximumWeightNormalizationKeepsActivations(testCase)
            weights = [2 4 1; 0.5 0.25 0];
            commands = rand(2, 5, 2); % (trial x frame x synergy)
            [newWeights, newCommands] = normalizeSynergiesByMaximumWeight( ...
                weights, commands);
            testCase.verifyEqual(max(newWeights, [], 2), [1; 1]);
            for t = 1 : 2
                testCase.verifyEqual(squeeze(newCommands(t, :, :)) * ...
                    newWeights, squeeze(commands(t, :, :)) * weights, ...
                    "AbsTol", 1e-12);
            end
        end

        function mtpActivationSubsetSplitsByName(testCase)
            activations = reshape(1 : 2 * 4 * 3, 2, 4, 3);
            [withMtp, withoutMtp] = makeMtpActivatonSubset(activations, ...
                ["m3", "m1"], ["m1", "m2", "m3", "m4"]);
            testCase.verifyEqual(withMtp, activations(:, [1, 3], :));
            testCase.verifyEqual(withoutMtp, activations(:, [2, 4], :));
        end
    end
end

function inputs = twoGroupInputs(Bmatrix)
inputs.synergyGroups = {struct("numSynergies", 2, ...
    "muscleNames", ["a1", "a2", "a3"], "muscleGroupName", "A"), ...
    struct("numSynergies", 1, "muscleNames", ["b1", "b2"], ...
    "muscleGroupName", "B")};
inputs.numSynergies = 3;
inputs.numMuscles = 5;
inputs.numTrials = 2;
inputs.numNodes = size(Bmatrix, 2);
inputs.numPoints = size(Bmatrix, 1);
inputs.Bmatrix = Bmatrix;
inputs.numWeightsPerGroup = [6, 2];
end

function B = tutorialBSpline()
% As NeuralControlPersonalization builds it: cubic, 26 nodes, 101 frames
% over 0 to 100 percent.
percent = linspace(0, 100, 101)';
B = BSplineMatrices(3, 26, 101, percent(2) - percent(1));
end
