% Smoke test of every GCP cost term: each type
% calcGroundContactPersonalizationTaskCost handles (read from its switch
% statement, so a new term is tested without changing this file) is
% evaluated on its own in GCP's task cost at the starting values of a real
% problem. A term passes if it gives a nonempty column of finite costs.
% Whether the values are right is for GcpCostTermsTest.
%
% The problem is settings_full.xml (every GCP option; its tasks between
% them optimize every design variable), run through
% GroundContactPersonalizationTool's own steps with lsqnonlin replaced by a
% stand-in that records what it is given (stubOptimizer). The cost
% function, its fixed arguments and the starting values are read from the
% recorded call, for the task that optimizes the most design variables.

classdef (TestTags = {'Unit'}) GcpTermSmokeTest < matlab.unittest.TestCase

    properties (TestParameter)
        type = cellstr(costTermTypes( ...
            "calcGroundContactPersonalizationTaskCost"))
    end

    properties
        problem
        error = ""
    end

    methods (TestClassSetup)
        function prepareProblem(testCase)
            folder = setUpGcpWorkingFolder(testCase, "settings_full.xml");
            testCase.addTeardown(@clearGcpMexFiles, folder);
            stubOptimizer(testCase, "lsqnonlin", 2);
            clear calcGroundContactPersonalizationTaskCost
            try
                evalc("runGcpUpToTheOptimizer(""settings_full.xml"")");
            catch exception
                diary off
                testCase.error = string(exception.message);
            end
            calls = optimizerCalls();
            if isempty(calls)
                if testCase.error == ""
                    testCase.error = "GCP never reached its optimizer.";
                end
                return
            end
            [~, largest] = max(cellfun(@(c) numel(c{2}), calls));
            call = calls{largest};
            captured = functions(call{1}).workspace{1};
            testCase.problem = struct("values", call{2}, ...
                "fieldNameOrder", captured.fieldNameOrder, ...
                "inputs", captured.inputs, "params", captured.params, ...
                "task", captured.task);
        end
    end

    methods (Test)
        function termGivesFiniteCosts(testCase, type)
            testCase.assertNotEmpty(testCase.problem, ...
                "Preparing GCP failed: " + testCase.error);
            p = testCase.problem;
            terms = p.params.tasks{p.task}.costTerms;
            p.params.tasks{p.task}.costTerms = {smokeCostTerm( ...
                templateTerm(terms, type), type)};
            clear calcGroundContactPersonalizationTaskCost
            cost = calcGroundContactPersonalizationTaskCost(p.values, ...
                p.fieldNameOrder, p.inputs, p.params, p.task);
            testCase.verifyClass(cost, "double");
            testCase.verifyNotEmpty(cost);
            testCase.verifyTrue(all(isfinite(cost), "all"), type + ...
                " gave costs that are not finite.");
        end
    end
end

function runGcpUpToTheOptimizer(settingsFile)
% GroundContactPersonalizationTool's steps before saving
settingsTree = xml2struct(settingsFile);
[inputs, params] = parseGroundContactPersonalizationSettingsTree( ...
    settingsTree);
GroundContactPersonalization(inputs, params);
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
