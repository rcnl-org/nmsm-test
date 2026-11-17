% Treatment Optimization up to the point where GPOPS-II starts solving,
% for each tool and controller: each case is prepared once
% (prepareToProblem, the tools' own sequence) and its deterministic
% quantities collected (evaluateToProblem): collocation times, bounds,
% initial guess, and the continuous and endpoint functions evaluated at
% the initial guess. Verification and Design Optimization start from
% published solutions, so for them this is the cost and constraints of a
% known solution.
%
% None of this depends on IPOPT, whose solutions differ between computers,
% so it is compared with nominal results (tests/data/to/nominal). If a
% change is intentional, regenerate them with
% tests/regression/updateToNominal.m and commit them.
%
% Needs GPOPS-II (it finds the collocation times); without a license the
% tests are reported as not run.

classdef (TestTags = {'Regression'}) TreatmentOptimizationSetupRegressionTest ...
        < matlab.unittest.TestCase

    properties (Constant)
        % Two runs agree exactly; these only allow for summing in a
        % different order. A value passes if it is within either.
        nominalRelativeTolerance = 1e-9
        nominalAbsoluteTolerance = 1e-12
        % Spline overshoot: NCP's synergy commands, splined to the guess
        % times, dip just below 0 (scaled -0.5) near zero.
        guessBoundsTolerance = 1e-3
    end

    properties
        results
        errors
    end

    properties (TestParameter)
        setupCase = toSetupCases()
    end

    methods (TestClassSetup)
        function prepareEveryCase(testCase)
            testCase.assumeTrue(gpopsIsLicensed(), ...
                "GPOPS-II is not licensed on this computer.");
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            cases = toSetupCases();
            for name = string(fieldnames(cases))'
                folder = fullfile(fixture.Folder, name);
                copyToFixtures(folder, cases.(name).problem, ...
                    cases.(name).settings);
                [testCase.results.(name), testCase.errors.(name)] = ...
                    evaluateCase(folder, cases.(name).settings);
            end
            testCase.addTeardown(@clearToCaches);
        end
    end

    methods (Test)
        function matchesNominalResult(testCase, setupCase)
            name = caseName(setupCase);
            testCase.assertCaseRan(name);
            nominal = load(testDataPath("to", "nominal", "setup_" + ...
                name + ".mat")).result;
            actual = testCase.results.(name);
            testCase.verifyEqual(sort(fieldnames(actual)), ...
                sort(fieldnames(nominal)));
            for field = string(fieldnames(nominal))'
                testCase.verifyEqual(actual.(field), nominal.(field), ...
                    "RelTol", testCase.nominalRelativeTolerance, ...
                    "AbsTol", testCase.nominalAbsoluteTolerance, ...
                    field + " differs from tests/data/to/nominal. If " + ...
                    "this change is intended, run updateToNominal.");
            end
        end

        function initialGuessIsWithinBounds(testCase, setupCase)
            name = caseName(setupCase);
            testCase.assertCaseRan(name);
            result = testCase.results.(name);
            tolerance = testCase.guessBoundsTolerance;
            testCase.verifyGreaterThanOrEqual(result.guessState, ...
                result.stateBounds(1, :) - tolerance);
            testCase.verifyLessThanOrEqual(result.guessState, ...
                result.stateBounds(2, :) + tolerance);
            testCase.verifyGreaterThanOrEqual(result.guessControl, ...
                result.controlBounds(1, :) - tolerance);
            testCase.verifyLessThanOrEqual(result.guessControl, ...
                result.controlBounds(2, :) + tolerance);
        end

        function collocationPointsFollowTheSolverSettings(testCase)
            % Torque: 25 intervals x 4 points; synergy: 1 x 50.
            testCase.assertCaseRan("trackingTorque");
            testCase.assertCaseRan("trackingSynergy");
            testCase.verifyLength(testCase.results.trackingTorque ...
                .collocationTime, 100);
            testCase.verifyLength(testCase.results.trackingSynergy ...
                .collocationTime, 50);
            testCase.verifyEqual(testCase.results.trackingTorque ...
                .collocationTime([1 end])', [0, 0.31], "AbsTol", 0.01);
        end

        function publishedSolutionsTrackThemselves(testCase)
            % Verification starts at the published Tracking solution and
            % tracks its controls, so its tracking cost there is zero; the
            % same for Design from the published Verification solution.
            for name = ["verificationTorque", "designTorqueV3", ...
                    "designSynergy"]
                testCase.assertCaseRan(name);
                testCase.verifyLessThan(max(testCase.results.(name) ...
                    .integral), 1e-20, name);
            end
        end

        function publishedVerificationMeetsItsEndConditions(testCase)
            % Initial states and the final toe position and foot
            % orientation of the published Verification solution are
            % those it was constrained to (the last terminal value, the
            % toe speed, is what Design changes).
            testCase.assertCaseRan("designTorqueV3");
            event = testCase.results.designTorqueV3.event;
            testCase.verifyLessThan(abs(event([1 : 3, 7 : 12])), 1e-9);
            testCase.verifyLessThan(abs(event(4 : 6)), 0.001);
        end

        function userDefinedConstraintMatchesBuiltInTerm(testCase)
            % Design V5's user-defined footSpeedConstraint and V3's
            % built-in final_marker_velocity_value both give the toe
            % marker's final x velocity, from the same published
            % solution.
            testCase.assertCaseRan("designTorqueV3");
            testCase.assertCaseRan("designTorqueV5");
            testCase.verifyEqual(testCase.results.designTorqueV5.event(end), ...
                testCase.results.designTorqueV3.event(end), "RelTol", 1e-9);
        end
    end

    methods
        function assertCaseRan(testCase, name)
            testCase.assertEqual(testCase.errors.(name), "", "The " + ...
                name + " case failed: " + testCase.errors.(name));
        end
    end
end

function [result, message] = evaluateCase(folder, settingsFile)
% Prepares and evaluates one case in its own folder; returns the error
% message, or "" if it ran.
originalFolder = cd(folder);
restoreFolder = onCleanup(@() cd(originalFolder));
result = struct();
message = "";
try
    [~, setup] = evalc("prepareToProblem(settingsFile)");
    result = evaluateToProblem(setup);
catch exception
    message = string(exception.message);
end
end

function name = caseName(setupCase)
cases = toSetupCases();
names = string(fieldnames(cases))';
name = names(arrayfun(@(n) isequal(cases.(n), setupCase), names));
end
