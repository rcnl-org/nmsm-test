% Tests for computeNeuralControlCostFunction, which turns fmincon's design
% vector back into NCP's full one before computing the cost:
% - with fixed synergy weights (optimize_synergy_vectors false), fmincon
%   only sees the command nodes, and the fixed weights are put back in
%   front;
% - with bilateral symmetry, fmincon only sees the first group's weights,
%   which are copied to the second group.

classdef (TestTags = {'Unit'}) NcpDesignVariablesTest < matlab.unittest.TestCase

    methods (Test)
        function fixedWeightsArePutBackInFront(testCase)
            inputs = twoGroupInputs();
            inputs.optimize_synergy_vectors = false;
            inputs.fixedSynergyVectorFlat = [0.1; 0.2; 0.3; 0.4];
            nodes = (1 : 6)' / 10;
            p = minimizationParams();
            testCase.verifyEqual(computeNeuralControlCostFunction(nodes, ...
                inputs, p), calcNcpCost([inputs.fixedSynergyVectorFlat; ...
                nodes], inputs, p), "AbsTol", 1e-15);
        end

        function bilateralSymmetryCopiesFirstGroupWeights(testCase)
            inputs = twoGroupInputs();
            inputs.optimize_synergy_vectors = true;
            inputs.enforce_bilateral_symmetry = true;
            leftWeights = [0.5; 0.7];
            nodes = (1 : 6)' / 10;
            p = minimizationParams();
            testCase.verifyEqual(computeNeuralControlCostFunction( ...
                [leftWeights; nodes], inputs, p), calcNcpCost( ...
                [leftWeights; leftWeights; nodes], inputs, p), ...
                "AbsTol", 1e-15);
        end

        function otherwiseTheVectorIsUsedAsIs(testCase)
            inputs = twoGroupInputs();
            inputs.optimize_synergy_vectors = true;
            inputs.enforce_bilateral_symmetry = false;
            values = [0.5; 0.7; 0.2; 0.9; (1 : 6)' / 10];
            p = minimizationParams();
            testCase.verifyEqual(computeNeuralControlCostFunction(values, ...
                inputs, p), calcNcpCost(values, inputs, p), "AbsTol", 1e-15);
        end
    end
end

function inputs = twoGroupInputs()
% Left and right groups of two muscles, one synergy each, one trial,
% three nodes, identity B-spline matrix.
inputs.synergyGroups = {struct("numSynergies", 1, ...
    "muscleNames", ["l1", "l2"], "muscleGroupName", "Left"), ...
    struct("numSynergies", 1, "muscleNames", ["r1", "r2"], ...
    "muscleGroupName", "Right")};
inputs.numSynergies = 2;
inputs.numMuscles = 4;
inputs.numTrials = 1;
inputs.numNodes = 3;
inputs.numPoints = 3;
inputs.Bmatrix = eye(3);
inputs.numWeightsPerGroup = [2, 2];
inputs.muscleTendonColumnNames = ["l1", "l2", "r1", "r2"];
end

function p = minimizationParams()
% A cost that depends on every weight and node.
p.costTerms = {struct("type", "activation_minimization", ...
    "isEnabled", true, "maxAllowableError", 0.5, "errorCenter", 0)};
p.activationGroups = {};
p.normalizedFiberLengthGroups = {};
end
