% Smoke test of every MTP cost term: each type calcMtpCost handles (read
% from its switch statement, so a new term is tested without changing this
% file) is evaluated on its own in MTP's objective
% (computeMuscleTendonCostFunction) at the starting values of a real
% problem. A term passes if the cost is one finite number. Whether the
% value is right is for MtpCostTermsTest.
%
% The problem is settings_full.xml (every MTP option, with synergy
% extrapolation and Muscle-Tendon Length Initialization), run through
% MuscleTendonPersonalizationTool's own steps with the optimizers replaced
% by stand-ins that record what they are given (stubOptimizer). Each type
% is evaluated with the last task's arguments.

classdef (TestTags = {'Unit'}) MtpTermSmokeTest < matlab.unittest.TestCase

    properties (TestParameter)
        type = cellstr(costTermTypes("calcMtpCost"))
    end

    properties
        call
        error = ""
    end

    methods (TestClassSetup)
        function prepareProblem(testCase)
            setUpMtpWorkingFolder(testCase, "settings_full.xml");
            stubOptimizer(testCase, ...
                "computeMuscleTendonLengthInitializationOptimization", 1);
            stubOptimizer(testCase, "computeMuscleTendonRoundOptimization", 1);
            try
                evalc("runMtpUpToTheOptimizer(""settings_full.xml"")");
            catch exception
                diary off
                testCase.error = string(exception.message);
            end
            calls = optimizerCalls();
            isMtp = cellfun(@numel, calls) == 10;
            if any(isMtp)
                testCase.call = calls{find(isMtp, 1, "last")};
            elseif testCase.error == ""
                testCase.error = "MTP never reached its optimizer.";
            end
        end
    end

    methods (Test)
        function termGivesOneFiniteCost(testCase, type)
            testCase.assertNotEmpty(testCase.call, ...
                "Preparing MTP failed: " + testCase.error);
            [values, primaryValues, isIncluded] = testCase.call{1 : 3};
            [inputs, params] = testCase.call{6 : 7};
            params.costTerms = {smokeCostTerm( ...
                templateTerm(params.costTerms, type), type)};
            cost = computeMuscleTendonCostFunction(values, ...
                primaryValues, isIncluded, inputs, params);
            testCase.verifyClass(cost, "double");
            testCase.verifySize(cost, [1, 1]);
            testCase.verifyTrue(isfinite(cost), type + ...
                " gave a cost that is not finite.");
        end
    end
end

function runMtpUpToTheOptimizer(settingsFile)
% MuscleTendonPersonalizationTool's steps before saving
settingsTree = xml2struct(settingsFile);
[inputs, params] = parseMuscleTendonPersonalizationSettingsTree( ...
    settingsTree);
precalInputs = parseMuscleTendonLengthInitializationSettingsTree( ...
    settingsTree);
if isstruct(precalInputs)
    optimizedInitialGuess = MuscleTendonLengthInitialization(precalInputs);
    inputs = updateMtpInitialGuess(inputs, precalInputs, ...
        optimizedInitialGuess);
end
MuscleTendonPersonalization(inputs, params);
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
