% Smoke test of every Muscle-Tendon Length Initialization cost term: each
% type calcMuscleTendonLengthInitializationCost handles (read from its
% switch statement, so a new term is tested without changing this file) is
% evaluated on its own in MTLI's objective
% (computeMuscleTendonLengthInitializationCostFunction) at the starting
% values of a real problem. A term passes if it gives a nonempty column of
% finite costs. Whether the values are right is for MtliCostTermsTest.
%
% The problem is MTP's settings_full.xml (MTLI with every cost term and
% passive data), run through MuscleTendonPersonalizationTool's own steps
% with the optimizers replaced by stand-ins that record what they are
% given (stubOptimizer).

classdef (TestTags = {'Unit'}) MtliTermSmokeTest < matlab.unittest.TestCase

    properties (TestParameter)
        type = cellstr(costTermTypes( ...
            "calcMuscleTendonLengthInitializationCost"))
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
                evalc("runMtliUpToTheOptimizer(""settings_full.xml"")");
            catch exception
                diary off
                testCase.error = string(exception.message);
            end
            calls = optimizerCalls();
            isMtli = cellfun(@numel, calls) == 5;
            if any(isMtli)
                testCase.call = calls{find(isMtli, 1)};
            elseif testCase.error == ""
                testCase.error = "MTLI never reached its optimizer.";
            end
        end
    end

    methods (Test)
        function termGivesFiniteCosts(testCase, type)
            testCase.assertNotEmpty(testCase.call, ...
                "Preparing MTLI failed: " + testCase.error);
            values = testCase.call{1};
            experimentalData = testCase.call{4};
            experimentalData.costTerms = {smokeCostTerm(templateTerm( ...
                experimentalData.costTerms, type), type)};
            cost = computeMuscleTendonLengthInitializationCostFunction( ...
                values, experimentalData);
            testCase.verifyClass(cost, "double");
            testCase.verifyNotEmpty(cost);
            testCase.verifySize(cost, [numel(cost), 1]);
            testCase.verifyTrue(all(isfinite(cost)), type + ...
                " gave costs that are not finite.");
        end
    end
end

function runMtliUpToTheOptimizer(settingsFile)
% MuscleTendonPersonalizationTool's steps up to MTLI's optimizer
settingsTree = xml2struct(settingsFile);
precalInputs = parseMuscleTendonLengthInitializationSettingsTree( ...
    settingsTree);
MuscleTendonLengthInitialization(precalInputs);
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
