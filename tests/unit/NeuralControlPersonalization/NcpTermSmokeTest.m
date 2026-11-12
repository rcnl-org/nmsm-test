% Smoke test of every NCP cost term: each type calcNcpCost handles (read
% from its switch statement, so a new term is tested without changing this
% file) is evaluated on its own in NCP's objective
% (computeNeuralControlCostFunction) at the starting values of a real
% problem. A term passes if the cost is one finite number. Whether the
% value is right is for NcpCostTest.
%
% The problem is settings_full.xml (every NCP option, with MTP results,
% muscle groups and Muscle-Tendon Length Initialization), run through
% NeuralControlPersonalizationTool's own steps with the optimizers
% replaced by stand-ins that record what they are given (stubOptimizer).

classdef (TestTags = {'Unit'}) NcpTermSmokeTest < matlab.unittest.TestCase

    properties (TestParameter)
        type = cellstr(costTermTypes("calcNcpCost"))
    end

    properties
        call
        error = ""
    end

    methods (TestClassSetup)
        function prepareProblem(testCase)
            setUpNcpWorkingFolder(testCase, "settings_full.xml");
            stubOptimizer(testCase, ...
                "computeMuscleTendonLengthInitializationOptimization", 1);
            stubOptimizer(testCase, "computeNeuralControlOptimization", 1);
            try
                evalc("runNcpUpToTheOptimizer(""settings_full.xml"")");
            catch exception
                diary off
                testCase.error = string(exception.message);
            end
            calls = optimizerCalls();
            isNcp = cellfun(@numel, calls) == 3;
            if any(isNcp)
                testCase.call = calls{find(isNcp, 1)};
            elseif testCase.error == ""
                testCase.error = "NCP never reached its optimizer.";
            end
        end
    end

    methods (Test)
        function termGivesOneFiniteCost(testCase, type)
            testCase.assertNotEmpty(testCase.call, ...
                "Preparing NCP failed: " + testCase.error);
            [values, inputs, params] = testCase.call{:};
            % The design variables fmincon is given
            % (computeNeuralControlOptimization)
            if ~inputs.optimize_synergy_vectors
                values(1 : length(inputs.fixedSynergyVectorFlat)) = [];
            elseif inputs.enforce_bilateral_symmetry
                values(1 : inputs.numWeightsPerGroup(1)) = [];
            end
            params.costTerms = {smokeCostTerm( ...
                templateTerm(params.costTerms, type), type)};
            cost = computeNeuralControlCostFunction(values, inputs, params);
            testCase.verifyClass(cost, "double");
            testCase.verifySize(cost, [1, 1]);
            testCase.verifyTrue(isfinite(cost), type + ...
                " gave a cost that is not finite.");
        end
    end
end

function runNcpUpToTheOptimizer(settingsFile)
% NeuralControlPersonalizationTool's steps before saving
settingsTree = xml2struct(settingsFile);
[inputs, params] = parseNeuralControlPersonalizationSettingsTree( ...
    settingsTree);
precalInputs = parseMuscleTendonLengthInitializationSettingsTree( ...
    settingsTree);
if isstruct(precalInputs)
    optimizedInitialGuess = MuscleTendonLengthInitialization(precalInputs);
    inputs = updateNcpInitialGuess(inputs, precalInputs, ...
        optimizedInitialGuess);
end
NeuralControlPersonalization(inputs, params);
end

function template = templateTerm(terms, type)
% The parsed term of this type if the settings have one, else the first
template = terms{1};
for i = 1 : length(terms)
    if string(terms{i}.type) == type
        template = terms{i};
        return
    end
end
end
