% Tests that JMP settings files (tests/data/jmp/settings) parse into the
% expected outputFile, inputs, and params. Each test runs the same steps as
% JointModelPersonalizationTool before it starts optimizing:
%   xml2struct -> verifyVersion -> parseJointModelPersonalizationSettingsTree
% inside a temporary folder holding copies of the fixture files.
%
% Expected values are written out by hand from the settings files and the
% simple_arm model, not taken from a previous run of the parser.

classdef (TestTags = {'Parsing'}) JointModelPersonalizationParsingTest ...
        < matlab.unittest.TestCase

    properties
        expected
        truthModel
    end

    methods (TestClassSetup)
        function loadFixtureValues(testCase)
            testCase.expected = jmpFixtureValues();
            testCase.truthModel = Model(testDataPath("jmp", "simple_arm.osim"));
        end
    end

    % ------------------------------------------------------------------- %
    % Valid settings files
    % ------------------------------------------------------------------- %
    methods (Test)
        function minimalSettingsUseDefaults(testCase)
            [outputFile, inputs, params] = testCase.parse("settings_minimal.xml");

            % No <results_directory>: output goes in the current folder.
            testCase.verifyEqual(string(outputFile), "simple_arm_minimal_jmp.osim");
            testCase.verifyFalse(isfolder("JMPResults"));
            testCase.verifyEqual(string(inputs.modelFileName), "simple_arm.osim");
            testCase.verifyEqual(inputs.desiredError, 0.01);
            % Optional parameters that are omitted are not set at all.
            testCase.verifyEmpty(fieldnames(params));

            testCase.verifyNumElements(inputs.tasks, 1);
            task = inputs.tasks{1};
            testCase.verifyEqual(string(task.markerFile), "simple_arm.trc");
            testCase.verifyEqual(task.parameters, {{'r_elbow', true, true, 0}});
            testCase.verifyEmpty(task.scaling);
            testCase.verifyEmpty(task.markers);
            testCase.verifyEqual(task.initialValues, ...
                testCase.expected.truth.parentTranslation(1), "AbsTol", 1e-12);
            % Without bounds, time range, or marker names these are unset.
            testCase.verifyFalse(isfield(task, "lowerBounds"));
            testCase.verifyFalse(isfield(task, "upperBounds"));
            testCase.verifyFalse(isfield(task, "startTime"));
            testCase.verifyFalse(isfield(task, "markerNames"));
        end

        function fullSettingsOutputAndParams(testCase)
            [outputFile, inputs, params] = testCase.parse("settings_full.xml");

            testCase.verifyEqual(string(outputFile), ...
                string(fullfile("JMPResults", "simple_arm_full_jmp.osim")));
            testCase.verifyTrue(isfolder("JMPResults"), ...
                "The parser should create <results_directory>.");
            testCase.verifyEqual(inputs.desiredError, 0.002);
            testCase.verifyEqual(params, struct( ...
                "accuracy", 1e-6, ...
                "diffMinChange", 1e-4, ...
                "optimalityTolerance", 1e-7, ...
                "functionTolerance", 1e-8, ...
                "stepTolerance", 1e-9, ...
                "maxFunctionEvaluations", 300));
        end

        function fullSettingsOrdersTasksAndDropsDisabled(testCase)
            [~, inputs] = testCase.parse("settings_full.xml");
            % File order is index 2, 1, 3 (disabled); parsed order is 1, 2.
            testCase.verifyNumElements(inputs.tasks, 2);
            testCase.verifyEqual(inputs.tasks{1}.scaling, ...
                "r_ulna_radius_hand", ...
                "The <index>1</index> task (with the body set) should come first.");
            testCase.verifyEqual(inputs.tasks{2}.startTime, 0.5, ...
                "The <index>2</index> task should come second.");
        end

        function fullSettingsJointAndBodyTask(testCase)
            [~, inputs] = testCase.parse("settings_full.xml");
            task = inputs.tasks{1};

            % parent translation x and y, child translation z
            testCase.verifyEqual(task.parameters, { ...
                {'r_elbow', true, true, 0}, ...
                {'r_elbow', true, true, 1}, ...
                {'r_elbow', false, true, 2}});
            testCase.verifyEqual(task.scaling, "r_ulna_radius_hand");
            % <move_markers>false true false</move_markers> moves every
            % r_ulna_radius_hand marker in y.
            testCase.verifyEqual(task.markers, { ...
                ["r_radius1", "y"], ["r_radius2", "y"], ["r_radius3", "y"]});

            % Order: joint parameters, body scales, marker coordinates.
            truth = testCase.expected.truth.parentTranslation;
            radiusY = [testCase.markerLocation("r_radius1"); ...
                testCase.markerLocation("r_radius2"); ...
                testCase.markerLocation("r_radius3")];
            radiusY = radiusY(:, 2)';
            expectedInitial = [truth(1), truth(2), 0, 1, radiusY];
            testCase.verifyEqual(task.initialValues, expectedInitial, ...
                "AbsTol", 1e-12);

            % Joint parameters: initial value +/- the frame's bound
            % (parent 0.01, child 0.02). Scale and markers are unbounded.
            halfWidth = [0.01, 0.01, 0.02, Inf(1, 4)];
            testCase.verifyEqual(task.lowerBounds, ...
                expectedInitial - halfWidth, "AbsTol", 1e-12);
            testCase.verifyEqual(task.upperBounds, ...
                expectedInitial + halfWidth, "AbsTol", 1e-12);
        end

        function fullSettingsOrientationTaskWithTimeRangeAndMarkers(testCase)
            [~, inputs] = testCase.parse("settings_full.xml");
            task = inputs.tasks{2};

            testCase.verifyEqual(task.startTime, 0.5);
            testCase.verifyEqual(task.finishTime, 1.5);
            testCase.verifyEqual(task.markerNames, ...
                ["r_radius1", "r_radius2", "r_radius3"]);
            testCase.verifyEqual(task.parameters, {{'r_elbow', true, false, 0}});
            testCase.verifyEmpty(task.scaling);
            testCase.verifyEmpty(task.markers);
            testCase.verifyEqual(task.initialValues, 0);
            testCase.verifyEqual(task.lowerBounds, -0.5, "AbsTol", 1e-12);
            testCase.verifyEqual(task.upperBounds, 0.5, "AbsTol", 1e-12);
        end

        function translationSettingsStartFromAwayModel(testCase)
            [outputFile, inputs] = testCase.parse("settings_translation.xml");
            task = inputs.tasks{1};
            start = testCase.expected.translatedAway.parentTranslation(1);

            testCase.verifyEqual(string(outputFile), string(fullfile( ...
                "JMPResults", "simple_arm_translated_jmp.osim")));
            testCase.verifyEqual(task.parameters, {{'r_elbow', true, true, 0}});
            testCase.verifyEqual(task.initialValues, start, "AbsTol", 1e-12);
            testCase.verifyEqual([task.lowerBounds, task.upperBounds], ...
                start + [-0.01, 0.01], "AbsTol", 1e-12);
            % The true value must be reachable within the bounds.
            truth = testCase.expected.truth.parentTranslation(1);
            testCase.verifyTrue(task.lowerBounds < truth && ...
                truth < task.upperBounds);
        end

        function orientationSettingsStartFromAwayModel(testCase)
            [outputFile, inputs] = testCase.parse("settings_orientation.xml");
            task = inputs.tasks{1};
            start = testCase.expected.orientedAway.parentOrientation(1);

            testCase.verifyEqual(string(outputFile), string(fullfile( ...
                "JMPResults", "simple_arm_oriented_jmp.osim")));
            testCase.verifyEqual(task.parameters, {{'r_elbow', true, false, 0}});
            testCase.verifyEqual(task.initialValues, start, "AbsTol", 1e-12);
            testCase.verifyEqual([task.lowerBounds, task.upperBounds], ...
                start + [-1, 1], "AbsTol", 1e-12);
            truth = testCase.expected.truth.parentOrientation(1);
            testCase.verifyTrue(task.lowerBounds < truth && ...
                truth < task.upperBounds);
        end
    end

    % ------------------------------------------------------------------- %
    % Invalid settings files: each differs from settings_minimal.xml in
    % one way, and should fail with an error that points at that problem.
    % ------------------------------------------------------------------- %
    methods (Test)
        function majorVersionMismatchIsRejected(testCase)
            testCase.verifyError(@() testCase.parse("bad_major_version.xml"), ...
                "verifyVersion:invalidSettingsFile");
        end

        function settingsForAnotherToolAreRejected(testCase)
            testCase.verifyError(@() testCase.parse("bad_wrong_tool.xml"), ...
                "verifyVersion:invalidSettingsFile");
        end

        function missingOutputModelFileIsReported(testCase)
            verifyErrorMessage(testCase, @() testCase.parse( ...
                "bad_missing_output_model_file.xml"), ...
                "output_model_file was not found");
        end

        function missingTaskListIsReported(testCase)
            verifyErrorMessage(testCase, @() testCase.parse( ...
                "bad_missing_task_list.xml"), "JMPTaskList was not found");
        end

        function translationWithTwoValuesIsReported(testCase)
            verifyErrorMessage(testCase, @() testCase.parse( ...
                "bad_translation_two_values.xml"), ...
                "object is not of expected length");
        end

        function missingModelFileIsNamed(testCase)
            verifyErrorMessage(testCase, @() testCase.parse( ...
                "bad_missing_model_file.xml"), "missing_model.osim");
        end

        function misspelledJointIsNamed(testCase)
            verifyErrorMessage(testCase, @() testCase.parse( ...
                "bad_misspelled_joint.xml"), "r_elbw");
        end
    end

    % ------------------------------------------------------------------- %
    % Edge case where the parser currently crashes with an unrelated
    % MATLAB error. This test describes the intended behavior.
    %
    % <free_markers> and <anatomical_markers> are intentionally not tested:
    % they are not settings the NMSM Pipeline advertises or uses.
    % ------------------------------------------------------------------- %
    methods (Test)
        function allTasksDisabledIsReported(testCase)
            % Fixed 2026-10-27; before, 'Output argument "inputs" ... not assigned'.
            verifyErrorMessage(testCase, @() testCase.parse( ...
                "edge_all_tasks_disabled.xml"), "enabled");
        end
    end

    methods
        function [outputFile, inputs, params] = parse(testCase, settingsFileName)
            % Copy fixtures and the settings file into a temporary folder,
            % then run the Tool's parsing steps there.
            setUpJmpWorkingFolder(testCase, settingsFileName);
            settingsTree = xml2struct(char(settingsFileName));
            verifyVersion(settingsTree, "JointModelPersonalizationTool");
            [outputFile, inputs, params] = ...
                parseJointModelPersonalizationSettingsTree(settingsTree);
        end

        function location = markerLocation(testCase, markerName)
            % Marker location in its body frame, read from simple_arm.osim.
            vec = testCase.truthModel.getMarkerSet().get(char(markerName)) ...
                .get_location();
            location = [vec.get(0), vec.get(1), vec.get(2)];
        end
    end
end
