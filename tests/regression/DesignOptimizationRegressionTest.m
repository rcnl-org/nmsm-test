% Full DesignOptimizationTool runs of the tutorial's problems, starting
% from the published Verification solutions, each run once for the whole
% class with the small GPOPS-II settings (gpops_small.xml):
% - torqueV3: free final time (0.26 to 0.36 s) with joint limits;
% - torqueV4: V3 with a user-defined cost (footSpeedCost, which runs
%   OpenSim in every evaluation, so this run takes about 2 minutes);
% - synergy: the synergy-driven problem with a free final time.
% The tutorial's V5 (a user-defined constraint) is not run: it takes about
% 3 minutes and stops at the iteration limit with the small settings. Its
% constraint is checked at the published solution in
% TreatmentOptimizationSetupRegressionTest.
%
% IPOPT's solutions differ between computers, so there is no truth or
% nominal solution here. The checks hold for any converged run on any
% computer: the run completes, IPOPT does not fail, the results are
% written, the solution stays within its bounds, its final time is in the
% allowed range, and the torque-driven solutions are kinetically
% consistent.
%
% Needs GPOPS-II; without a license the tests are reported as not run.

classdef (TestTags = {'Regression'}) DesignOptimizationRegressionTest ...
        < matlab.unittest.TestCase

    properties
        expected
        runs
    end

    properties (TestParameter)
        run = struct( ...
            "torqueV3", struct("problem", "torque", "settings", ...
                "settings_design_torque_tutorial_v3.xml"), ...
            "torqueV4", struct("problem", "torque", "settings", ...
                "settings_design_torque_tutorial_v4.xml"), ...
            "synergy", struct("problem", "synergy", "settings", ...
                "settings_design_synergy_tutorial.xml"))
        torqueRun = {'torqueV3', 'torqueV4'}
    end

    methods (TestClassSetup)
        function runEveryCase(testCase)
            testCase.assumeTrue(gpopsIsLicensed(), ...
                "GPOPS-II is not licensed on this computer.");
            testCase.expected = toFixtureValues();
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            for name = string(fieldnames(testCase.run))'
                testCase.runs.(name) = runToCase(fullfile(fixture.Folder, ...
                    name), testCase.run.(name).problem, ...
                    testCase.run.(name).settings);
            end
        end
    end

    methods (Test)
        function ipoptDoesNotFail(testCase, run)
            result = testCase.ranCase(run);
            testCase.verifyMatches(result.exit, "EXIT: (Optimal Solution " + ...
                "Found|Solved To Acceptable Level|Maximum Number of " + ...
                "Iterations Exceeded)", "IPOPT: " + result.exit);
        end

        function writesExpectedResultFiles(testCase, run)
            result = testCase.ranCase(run);
            trial = testCase.expected.trialName;
            files = ["IKData/" + trial + ".sto", "IDData/" + trial + ".sto", ...
                trial + "_states.sto", trial + "_accelerations.sto", ...
                "commandWindowOutput.txt", run.settings];
            if run.problem == "torque"
                files = [files, trial + "_torqueControls.sto"];
            else
                files = [files, trial + "_synergyCommands.sto", ...
                    trial + "_combinedActivations.sto"];
            end
            for file = files
                testCase.verifyTrue(isfile(fullfile(result.resultsDirectory, ...
                    file)), file);
            end
        end

        function solutionIsWithinBounds(testCase, run)
            verifyToSolutionBounds(testCase, testCase.ranCase(run), ...
                testCase.expected.trialName);
        end

        function finalTimeIsInTheAllowedRange(testCase, run)
            result = testCase.ranCase(run);
            solution = readToSolution(result.resultsDirectory, ...
                testCase.expected.trialName);
            testCase.verifyEqual(result.bounds.finalTimeRange, [0.26, 0.36]);
            testCase.verifyGreaterThanOrEqual(solution.time(end), 0.26 - 1e-6);
            testCase.verifyLessThanOrEqual(solution.time(end), 0.36 + 1e-6);
        end

        function torqueSolutionIsKineticallyConsistent(testCase, torqueRun)
            verifyToKineticConsistency(testCase, testCase.ranCase( ...
                testCase.run.(torqueRun)), testCase.expected.trialName, 0.1);
        end
    end

    methods
        function result = ranCase(testCase, run)
            names = string(fieldnames(testCase.run))';
            name = names(arrayfun(@(n) isequal(testCase.run.(n), run), ...
                names));
            result = testCase.runs.(name);
            testCase.assertEqual(result.error, "", "The " + name + ...
                " run failed: " + result.error);
        end
    end
end
