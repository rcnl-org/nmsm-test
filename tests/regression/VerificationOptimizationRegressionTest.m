% A full VerificationOptimizationTool run of the tutorial's torque-driven
% problem, starting from the published Tracking solution, with the small
% GPOPS-II settings (gpops_small.xml).
%
% IPOPT's solutions differ between computers, so there is no truth or
% nominal solution here. The checks hold for any converged run on any
% computer: the run completes, IPOPT does not fail, the results are
% written, the solution stays within its bounds, is kinetically
% consistent, and starts where its initial state constraints put it. The
% deterministic setup is compared with nominal results in
% TreatmentOptimizationSetupRegressionTest.
%
% Needs GPOPS-II; without a license the tests are reported as not run.

classdef (TestTags = {'Regression'}) VerificationOptimizationRegressionTest ...
        < matlab.unittest.TestCase

    properties
        expected
        result
    end

    methods (TestClassSetup)
        function runTutorial(testCase)
            testCase.assumeTrue(gpopsIsLicensed(), ...
                "GPOPS-II is not licensed on this computer.");
            testCase.expected = toFixtureValues();
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.result = runToCase(fixture.Folder, "torque", ...
                "settings_verification_torque_tutorial.xml");
        end
    end

    methods (TestMethodSetup)
        function assertRan(testCase)
            testCase.assertEqual(testCase.result.error, "", ...
                "The run failed: " + testCase.result.error);
        end
    end

    methods (Test)
        function ipoptDoesNotFail(testCase)
            testCase.verifyMatches(testCase.result.exit, "EXIT: (Optimal " + ...
                "Solution Found|Solved To Acceptable Level|Maximum Number " + ...
                "of Iterations Exceeded)", "IPOPT: " + testCase.result.exit);
        end

        function writesExpectedResultFiles(testCase)
            trial = testCase.expected.trialName;
            for file = ["IKData/" + trial + ".sto", "IDData/" + trial + ...
                    ".sto", trial + "_states.sto", trial + ...
                    "_accelerations.sto", trial + "_torqueControls.sto", ...
                    "commandWindowOutput.txt", ...
                    "settings_verification_torque_tutorial.xml"]
                testCase.verifyTrue(isfile(fullfile( ...
                    testCase.result.resultsDirectory, file)), file);
            end
        end

        function solutionIsWithinBounds(testCase)
            verifyToSolutionBounds(testCase, testCase.result, ...
                testCase.expected.trialName);
        end

        function solutionIsKineticallyConsistent(testCase)
            verifyToKineticConsistency(testCase, testCase.result, ...
                testCase.expected.trialName, 0.1);
        end

        function solutionStartsAtTheTrackedState(testCase)
            % initial_generalized_coordinate_deviation (0.0175 rad) and
            % initial_generalized_speed_deviation (0.175 rad/s) against
            % the published Tracking solution it verifies.
            solution = readToSolution(testCase.result.resultsDirectory, ...
                testCase.expected.trialName);
            tracked = readStoFile(testDataPath("to", "torque", ...
                "published", "TorqueTOResultsV1", ...
                testCase.expected.trialName + "_states.sto"));
            deviation = solution.states(1, :) - tracked(1, 2 : end);
            testCase.verifyLessThanOrEqual(abs(deviation(1 : 3)), ...
                0.0175 + 1e-4);
            testCase.verifyLessThanOrEqual(abs(deviation(4 : 6)), ...
                0.175 + 1e-3);
        end
    end
end
