% Full TrackingOptimizationTool runs of the tutorial's torque-driven and
% synergy-driven problems, each run once for the whole class with the
% small GPOPS-II settings (gpops_small.xml).
%
% IPOPT's solutions differ between computers, so there is no truth or
% nominal solution here. The checks hold for any converged run on any
% computer: the run completes, IPOPT does not fail, the results are
% written, the solution stays within its bounds, and the torque-driven
% solution is kinetically consistent (its inverse dynamics loads equal its
% torque controls within the constraint). The deterministic setup is
% compared with nominal results in TreatmentOptimizationSetupRegressionTest.
%
% Needs GPOPS-II; without a license the tests are reported as not run.

classdef (TestTags = {'Regression'}) TrackingOptimizationRegressionTest ...
        < matlab.unittest.TestCase

    properties
        expected
        runs
    end

    properties (TestParameter)
        run = struct( ...
            "torque", struct("problem", "torque", "settings", ...
                "settings_tracking_torque_tutorial.xml"), ...
            "synergy", struct("problem", "synergy", "settings", ...
                "settings_tracking_synergy_tutorial.xml"))
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
            % Optimal, acceptable, or stopped at the iteration limit; not
            % infeasible or failed.
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
                "Analysis/" + trial + "_modeledPositions.sto", ...
                "Analysis/" + trial + "_trackedPositions.sto", ...
                "commandWindowOutput.txt", run.settings];
            if run.problem == "torque"
                files = [files, trial + "_torqueControls.sto"];
            else
                files = [files, trial + "_synergyCommands.sto", ...
                    trial + "_combinedActivations.sto", "synergyWeights.sto"];
            end
            for file = files
                testCase.verifyTrue(isfile(fullfile(result.resultsDirectory, ...
                    file)), file);
            end
        end

        function solutionIsWithinBounds(testCase, run)
            result = testCase.ranCase(run);
            verifyToSolutionBounds(testCase, result, ...
                testCase.expected.trialName);
        end

        function torqueSolutionIsKineticallyConsistent(testCase)
            % |ID load - torque control| <= 0.1 Nm (the tutorial's
            % kinetic_consistency bounds) at every saved point but the
            % last, where the saved control is the ID load itself.
            result = testCase.ranCase(testCase.run.torque);
            verifyToKineticConsistency(testCase, result, ...
                testCase.expected.trialName, 0.1);
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
