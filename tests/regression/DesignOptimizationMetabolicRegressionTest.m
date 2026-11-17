% Full DesignOptimizationTool runs checking that the metabolic cost goals
% move the solution the way they ask. The synergy-driven tutorial problem
% (the only one with muscles) starts from the published Verification
% solution, whose metabolic cost per unit time is 858
% (toMetabolicCostPerTime), and is run once per goal for the whole class:
% - relativeLower / relativeHigher: relative_metabolic_cost_per_time
%   asking for 0.7 / 1.3 times the initial guess's;
% - absoluteLower / absoluteHigher: absolute_metabolic_cost_per_time
%   asking for 600 / 1200.
% IPOPT's solutions differ between computers, so the checks are on
% direction with a wide margin: a lower goal must end at least 10% below
% the initial guess and a higher goal at least 10% above. Asking in both
% directions is what shows a goal works: a goal with no effect (as the
% absolute goals had before B26 was fixed, ending at 891 like a run with
% no goal) fails both. On the development computer the relative goals end
% at 619 and 1134 and the absolute goals at 564 and 540.
%
% The runs use gpops_synergy_metabolic.xml (the tutorial's 1 interval x 50
% points, at most 50 IPOPT iterations; about 80 s for the class): the
% metabolic goals need the grid the initial guess was solved on (the
% published Verification results, 51 rows), as they will be in practice.
%
% Expected failure (see docs/failures.md):
% higherGoalRaisesTheMetabolicCost(goal=absolute): the absolute goals
% read GPOPS-II's metabolic integral, which is in scaled time, so they see
% 2384 instead of 858 and push the cost down for any target (B30).
%
% Needs GPOPS-II; without a license the tests are reported as not run.

classdef (TestTags = {'Regression'}) DesignOptimizationMetabolicRegressionTest ...
        < matlab.unittest.TestCase

    properties (Constant)
        solverSettings = "gpops_synergy_metabolic.xml"
        initialGuess = "published/SynergyVOResultsV2"
        % A goal run must move the cost at least this far from the
        % initial guess's, in the direction it asks
        requiredChange = 0.1
    end

    properties (TestParameter)
        goal = {'relative', 'absolute'}
        goalRun = {'relativeLower', 'relativeHigher', 'absoluteLower', ...
            'absoluteHigher'}
    end

    properties
        folder
        initialCost
        costs
        errors
        exits
    end

    methods (TestClassSetup)
        function runEveryGoal(testCase)
            testCase.assumeTrue(gpopsIsLicensed(), ...
                "GPOPS-II is not licensed on this computer.");
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.folder = string(fixture.Folder);
            testCase.addTeardown(@clearToCaches);
            startQuietParallelPool();
            for name = string(testCase.goalRun)
                [testCase.costs.(name), testCase.errors.(name), ...
                    testCase.exits.(name), initial] = runAndMeasure( ...
                    fullfile(testCase.folder, name), settingsFile(name), ...
                    testCase.solverSettings, testCase.initialGuess);
                if isfinite(initial)
                    testCase.initialCost = initial;
                end
            end
        end
    end

    methods (Test)
        function goalRunCompletes(testCase, goalRun)
            testCase.assertRan(goalRun);
            testCase.verifyMatches(testCase.exits.(goalRun), "EXIT: " + ...
                "(Optimal Solution Found|Solved To Acceptable Level|" + ...
                "Maximum Number of Iterations Exceeded)", ...
                "IPOPT: " + testCase.exits.(goalRun));
        end

        function lowerGoalLowersTheMetabolicCost(testCase, goal)
            name = goal + "Lower";
            testCase.assertRan(name);
            testCase.verifyLessThan(testCase.costs.(name), ...
                (1 - testCase.requiredChange) * testCase.initialCost, ...
                "The " + name + " goal did not lower the metabolic " + ...
                "cost from the initial guess's " + testCase.initialCost);
        end

        function higherGoalRaisesTheMetabolicCost(testCase, goal)
            % Expected to fail for absolute (B30): see the class comment.
            name = goal + "Higher";
            testCase.assertRan(name);
            testCase.verifyGreaterThan(testCase.costs.(name), ...
                (1 + testCase.requiredChange) * testCase.initialCost, ...
                "The " + name + " goal did not raise the metabolic " + ...
                "cost from the initial guess's " + testCase.initialCost);
        end
    end

    methods
        function assertRan(testCase, name)
            testCase.assertEqual(testCase.errors.(name), "", "The " + ...
                name + " run failed: " + testCase.errors.(name));
        end
    end
end

function file = settingsFile(name)
% e.g. "absoluteHigher" -> settings_design_synergy_absolute_metabolic_high.xml
kind = extractBefore(name, regexpPattern("Lower|Higher"));
file = "settings_design_synergy_" + kind + "_metabolic";
if endsWith(name, "Higher")
    file = file + "_high";
end
file = file + ".xml";
end

function [cost, message, exitLine, initialCost] = runAndMeasure( ...
    folder, settingsFile, solverSettings, initialGuess)
% Runs DesignOptimizationTool on one settings file in its own folder and
% measures the metabolic cost per unit time of its initial guess and its
% solution.
[cost, initialCost] = deal(NaN);
[message, exitLine] = deal("");
copyToFixtures(folder, "synergy", settingsFile);
originalFolder = cd(folder);
restoreFolder = onCleanup(@() cd(originalFolder));
useSolverSettings(settingsFile, solverSettings);
try
    initialCost = toMetabolicCostPerTime(settingsFile, initialGuess);
    clearToCaches();
    output = string(evalc("DesignOptimizationTool(settingsFile)"));
    exitLine = string(regexp(output, "EXIT: [^\n]*", "match", "once"));
    cost = toMetabolicCostPerTime(settingsFile, "DesignResults");
catch exception
    diary off
    message = string(exception.message);
end
clearToCaches();
end

function useSolverSettings(settingsFile, solverSettings)
text = fileread(settingsFile);
text = regexprep(text, "<optimal_control_solver_settings_file>[^<]*<", ...
    "<optimal_control_solver_settings_file>" + solverSettings + "<");
writelines(text, settingsFile);
end
