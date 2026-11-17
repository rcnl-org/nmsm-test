% Tests that Verification Optimization settings files in
% tests/data/to/settings parse into the expected inputs: the tutorial's
% torque-driven verification of the published Tracking results, and
% Verification's refusal to optimize synergy vectors. Written for
% candidate-1.5.4.

classdef (TestTags = {'Parsing'}) VerificationOptimizationParsingTest < ...
        matlab.unittest.TestCase

    properties
        expected
        folder
        tutorial
    end

    methods (TestClassSetup)
        function parseTutorialFile(testCase)
            testCase.expected = toFixtureValues();
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.folder = string(fixture.Folder);
            copyToFixtures(fullfile(testCase.folder, "torque"), "torque", ...
                "settings_verification_torque_tutorial.xml");
            copyToFixtures(fullfile(testCase.folder, "synergy"), ...
                "synergy", "bad_verification_optimizes_synergies.xml");
            testCase.tutorial = testCase.parse("torque", ...
                "settings_verification_torque_tutorial.xml");
        end
    end

    methods (Test)
        function dataComeFromThePublishedTracking(testCase)
            % Both the initial guess and the tracked data are the
            % Tracking results, on its 101 collocation points.
            inputs = testCase.tutorial;
            frames = testCase.expected.torque.publishedFrames;
            testCase.verifyEqual(inputs.toolName, "VerificationOptimization");
            testCase.verifyEqual(inputs.initialGuessDirectory, ...
                'published/TorqueTOResultsV1');
            testCase.verifySize(inputs.experimentalJointAngles, [frames, 41]);
            testCase.verifySize(inputs.initialStates, [frames, 6]);
            testCase.verifyEqual(inputs.initialStatesLabels, ...
                [testCase.expected.statesCoordinates, ...
                testCase.expected.statesCoordinates + "_u"]);
        end

        function torqueControlsStartFromTracking(testCase)
            inputs = testCase.tutorial;
            [controls, names] = readStoFile(testDataPath("to", "torque", ...
                "published", "TorqueTOResultsV1", ...
                testCase.expected.trialName + "_torqueControls.sto"));
            testCase.verifyEqual(inputs.initialTorqueControlsLabels, ...
                names(2 : end));
            testCase.verifyEqual(inputs.initialTorqueControls, ...
                controls(:, 2 : end), "AbsTol", 1e-9);
        end

        function controllerTrackingAndEndConditions(testCase)
            % Track the controls under kinetic consistency, with initial
            % states and final toe position, foot orientation and toe
            % speed constrained (axes split into one term each).
            inputs = testCase.tutorial;
            testCase.verifyEqual(cellfun(@(t) string(t.type), ...
                inputs.costTerms), repmat("controller_tracking", 1, 3));
            types = cellfun(@(t) string(t.type), inputs.terminal);
            testCase.verifyEqual(types, [ ...
                repmat("initial_generalized_coordinate_deviation", 1, 3), ...
                repmat("initial_generalized_speed_deviation", 1, 3), ...
                repmat("final_marker_position_deviation", 1, 3), ...
                repmat("final_body_orientation_deviation", 1, 3), ...
                "final_marker_velocity_value"]);
            speed = inputs.terminal{13};
            testCase.verifyEqual([speed.minError, speed.maxError], ...
                [13.1, 13.2]);
        end

        function synergyVectorsCannotBeOptimized(testCase)
            testCase.verifyError(@() testCase.parse("synergy", ...
                "bad_verification_optimizes_synergies.xml"), ...
                "VerificationOptimizationTool:" + ...
                "parseVerificationOptimizationSettingsTree");
        end
    end

    methods
        function inputs = parse(testCase, problem, fileName)
            originalFolder = cd(fullfile(testCase.folder, problem));
            restoreFolder = onCleanup(@() cd(originalFolder));
            [~, inputs] = evalc("parseToSettingsFile(fileName)");
        end
    end
end
