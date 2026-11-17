% Tests that GCP settings files in tests/data/gcp/settings parse into the
% expected inputs and params structs: xml2struct -> verifyVersion ->
% parseGroundContactPersonalizationSettingsTree, as
% GroundContactPersonalizationTool does.
%
% Expected values come from gcpFixtureValues, the settings files, and the
% GRF file read with readStoFile, so they do not depend on nmsm-core.
% Written for candidate-1.5.4.

classdef (TestTags = {'Parsing'}) GroundContactPersonalizationParsingTest < ...
        matlab.unittest.TestCase

    properties
        expected
        minimal
        full
        tutorial
    end

    methods (TestClassSetup)
        function parseValidFiles(testCase)
            files = dir(testDataPath("gcp", "settings", "*.xml"));
            folder = setUpGcpWorkingFolder(testCase, string({files.name}));
            testCase.addTeardown(@clearGcpMexFiles, folder);
            testCase.expected = gcpFixtureValues();
            testCase.minimal = parse("settings_minimal.xml");
            testCase.full = parse("settings_full.xml");
            testCase.tutorial = parse("settings_tutorial.xml");
        end
    end

    methods (Test)
        % ---- the contact surface ----------------------------------------

        function contactSurfaceDescribesTheRightFoot(testCase)
            surface = testCase.tutorial.inputs.surfaces{1};
            testCase.verifyLength(testCase.tutorial.inputs.surfaces, 1);
            testCase.verifyFalse(surface.isLeftFoot);
            testCase.verifyEqual(string(surface.hindfootBodyName), ...
                testCase.expected.hindfootBody);
            testCase.verifyEqual(surface.beltSpeed, testCase.expected.beltSpeed);
            markers = testCase.expected.markers;
            for field = string(fieldnames(markers))'
                testCase.verifyEqual(string(surface.markerNames.(field)), ...
                    markers.(field), field);
            end
            testCase.verifyEqual(string(cellstr(surface.forceColumns))', ...
                testCase.expected.forceColumns);
        end

        function groundReactionsMatchFile(testCase)
            % (component x frame), forces, moments and electrical center
            % from the plate 2 columns, over the whole 0.5 to 1.6 s.
            surface = testCase.tutorial.inputs.surfaces{1};
            [data, names] = readStoFile(testDataPath("gcp", "preprocessed", ...
                "GRFData", "gait_1.sto"));
            columns = @(wanted) data(:, cellfun(@(n) find(names == n), ...
                cellstr(wanted)))';
            testCase.verifyEqual(surface.experimentalGroundReactionForces, ...
                columns(testCase.expected.forceColumns), "AbsTol", 1e-9);
            testCase.verifyEqual(surface.experimentalGroundReactionMoments, ...
                columns(testCase.expected.momentColumns), "AbsTol", 1e-9);
            testCase.verifyEqual(surface.electricalCenter, ...
                columns(testCase.expected.electricalCenterColumns), ...
                "AbsTol", 1e-9);
            testCase.verifyEqual(surface.time, data(:, 1)', "AbsTol", 1e-9);
        end

        function timeWindowSelectsFramesInsideIt(testCase)
            % 0.6 to 1.5 s: the first frame at or after 0.6 (0.61) to the
            % last at or before 1.5 (1.49), every 0.011 s: 81 frames.
            time = testCase.full.inputs.surfaces{1}.time;
            testCase.verifyEqual(time([1, end]), [0.61, 1.49], "AbsTol", 1e-9);
            testCase.verifyLength(time, 81);
        end

        function dataPathsUseInputDirectory(testCase)
            inputs = testCase.tutorial.inputs;
            testCase.verifyEqual(string(inputs.motionFileName), ...
                string(fullfile("preprocessed", "IKData", "gait_1.sto")));
            testCase.verifyEqual(string(inputs.grfFileName), ...
                string(fullfile("preprocessed", "GRFData", "gait_1.sto")));
        end

        % ---- model and optimizer settings -------------------------------

        function tutorialSettings(testCase)
            inputs = testCase.tutorial.inputs;
            params = testCase.tutorial.params;
            testCase.verifyEqual(testCase.tutorial.resultsDirectory, ...
                'GCPResultsV1');
            testCase.verifyEqual([inputs.kinematicsFilterCutoff, ...
                inputs.gridWidth, inputs.gridHeight], [10, 5, 11]);
            testCase.verifyEqual([inputs.initialRestingSpringLength, ...
                inputs.initialSpringConstants, inputs.initialDampingFactor, ...
                inputs.initialDynamicFrictionCoefficient, ...
                inputs.initialViscousFrictionCoefficient, ...
                inputs.latchingVelocity], [0.05, 2500, 1, 0.5, 0, 0.1], ...
                "AbsTol", 1e-12);
            testCase.verifyTrue(params.restingSpringLengthInitialization);
            % 5 iterations instead of the tutorial's 20 (see the file)
            testCase.verifyEqual([params.diffMinChange, params.stepTolerance, ...
                params.optimalityTolerance, params.functionTolerance, ...
                params.maxIterations, params.maxFunctionEvaluations], ...
                [0.01, 1e-4, 1e-4, 1e-4, 5, 300000], "AbsTol", 1e-12);
        end

        function tutorialTasks(testCase)
            % Three tasks; only the first optimizes resting spring length.
            % Design variable order: spring constants, damping, dynamic
            % friction, viscous friction, resting length, B-spline
            % coefficients, electrical center X, Y, Z, plate rotation.
            tasks = testCase.tutorial.params.tasks;
            testCase.verifyLength(tasks, 3);
            testCase.verifyEqual(double(tasks{1}.designVariables), ...
                [1 1 1 0 1 1 0 0 0 0]);
            testCase.verifyEqual(double(tasks{3}.designVariables), ...
                [1 1 1 0 0 1 0 0 0 0]);
            testCase.verifyEqual(tasks{1}.neighborStandardDeviation, 0.2, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(cellfun(@(t) string(t.type), ...
                tasks{1}.costTerms), ["marker_position", "rotation", ...
                "vertical_grf", "horizontal_grf", "ground_reaction_moment", ...
                "neighbor_spring_constant"]);
            testCase.verifyEqual(tasks{3}.costTerms{5}.maxAllowableError, ...
                0.5);
        end

        function minimalUsesDefaults(testCase)
            inputs = testCase.minimal.inputs;
            params = testCase.minimal.params;
            testCase.verifyEqual([inputs.kinematicsFilterCutoff, ...
                inputs.latchingVelocity, inputs.gridWidth, ...
                inputs.gridHeight], [6, 0.05, 5, 15]);
            testCase.verifyEqual([inputs.initialRestingSpringLength, ...
                inputs.initialSpringConstants, inputs.initialDampingFactor, ...
                inputs.initialDynamicFrictionCoefficient, ...
                inputs.initialViscousFrictionCoefficient], ...
                [0.05, 2500, 1e-4, 0, 5]);
            testCase.verifyTrue(params.restingSpringLengthInitialization);
            testCase.verifyEqual([params.diffMinChange, params.stepTolerance, ...
                params.optimalityTolerance, params.functionTolerance, ...
                params.maxIterations, params.maxFunctionEvaluations], ...
                [1e-6, 1e-6, 1e-6, 1e-6, 400, 300000]);
            % Design variables left out of a task are off.
            testCase.verifyEqual(double(params.tasks{1}.designVariables), ...
                [1 0 0 0 0 0 0 0 0 0]);
            testCase.verifyEqual(params.tasks{1}.neighborStandardDeviation, ...
                0.05);
            testCase.verifyEmpty(inputs.inputOsimxFile);
        end

        function fullReadsEveryOption(testCase)
            inputs = testCase.full.inputs;
            params = testCase.full.params;
            testCase.verifyEqual([inputs.kinematicsFilterCutoff, ...
                inputs.latchingVelocity, inputs.gridWidth, ...
                inputs.gridHeight], [8, 0.2, 6, 12]);
            testCase.verifyEqual([inputs.initialRestingSpringLength, ...
                inputs.initialSpringConstants, inputs.initialDampingFactor, ...
                inputs.initialDynamicFrictionCoefficient, ...
                inputs.initialViscousFrictionCoefficient], ...
                [0.04, 3000, 0.5, 0.6, 2]);
            testCase.verifyFalse(params.restingSpringLengthInitialization);
            testCase.verifyEqual([params.diffMinChange, params.stepTolerance, ...
                params.optimalityTolerance, params.functionTolerance, ...
                params.maxIterations, params.maxFunctionEvaluations], ...
                [1e-3, 1e-5, 1e-5, 1e-5, 30, 10000]);
            testCase.verifyEqual(inputs.surfaces{1}.beltSpeed, 1.2);
        end

        function fullTasksAreOrderedAndDisabledDropped(testCase)
            % Listed as 2, 3 (disabled), 1.
            tasks = testCase.full.params.tasks;
            testCase.verifyLength(tasks, 2);
            testCase.verifyEqual(double(tasks{1}.designVariables), ones(1, 10));
            testCase.verifyLength(tasks{1}.costTerms, 15);
            testCase.verifyEqual(tasks{1}.neighborStandardDeviation, 0.1);
            testCase.verifyEqual(tasks{2}.costTerms{1}.maxAllowableError, 4);
            regularization = tasks{1}.costTerms{14};
            testCase.verifyEqual(regularization.type, ...
                'electrical_center_regularization');
            testCase.verifyEqual(string(regularization.axes), "xz");
        end

        % ---- edge_* files -----------------------------------------------

        function allTasksDisabledGivesNoTasks(testCase)
            parsed = parse("edge_all_tasks_disabled.xml");
            testCase.verifyEmpty(parsed.params.tasks);
        end

        function timeWindowIsClippedToTheData(testCase)
            % end_time 2.5 s is past the data's 1.6 s: the window stops at
            % the last frame, without a warning.
            parsed = parse("edge_time_window_beyond_data.xml");
            testCase.verifyEqual(parsed.inputs.surfaces{1}.time(end), 1.6, ...
                "AbsTol", 1e-9);
        end

        function pathsAreRelativeToCurrentFolderWithoutInputDirectory(testCase)
            parsed = parse("edge_without_input_directory.xml");
            testCase.verifyLength(parsed.inputs.surfaces{1}.time, 101);
            testCase.verifyTrue(endsWith(parsed.inputs.grfFileName, ...
                fullfile("preprocessed", "GRFData", "gait_1.sto")));
        end

        function noEnabledSurfaceIsReported(testCase)
            % Fixed 2026-10-27; before, getContactSurfaces returns nothing and
            % MATLAB reports 'Output argument "output" ... not assigned'.
            % See docs/failures.md.
            verifyErrorMessage(testCase, ...
                @() parse("edge_no_enabled_surface.xml"), "enabled");
        end

        % ---- bad_* files ------------------------------------------------

        function wrongMajorVersionIsRejected(testCase)
            testCase.verifyError(@() parse("bad_major_version.xml"), ...
                "verifyVersion:invalidSettingsFile");
        end

        function wrongToolIsRejected(testCase)
            testCase.verifyError(@() parse("bad_wrong_tool.xml"), ...
                "verifyVersion:invalidSettingsFile");
        end

        function missingContactSurfaceSetIsReported(testCase)
            verifyErrorMessage(testCase, ...
                @() parse("bad_missing_contact_surface_set.xml"), ...
                "GCPContactSurfaceSet");
        end

        function legacyToesCoordinateIsExplained(testCase)
            verifyErrorMessage(testCase, ...
                @() parse("bad_legacy_toes_coordinate.xml"), ...
                "replaced by <hindfoot_body>");
        end

        function unknownMarkerIsReportedWhenPreparingInputs(testCase)
            % Parsing does not check marker names; preparing the inputs
            % (the first step of a run) fails on it.
            parsed = parse("bad_unknown_marker.xml");
            verifyErrorMessage(testCase, @() prepareQuietly(parsed.inputs), ...
                "R_Heal");
        end

        function hindfootMustStartATwoSegmentFoot(testCase)
            parsed = parse("bad_hindfoot_is_toes.xml");
            verifyErrorMessage(testCase, @() prepareQuietly(parsed.inputs), ...
                "two segment foot");
        end

        function misspelledForceColumnIsReported(testCase)
            % Fixed 2026-10-27; before, the check for missing GRF columns,
            % if any([isnan(grf) isnan(moments) isnan(ec)]), uses any() on
            % a matrix, so it only fails if every column has a NaN. A
            % misspelled force column parses, leaving NaN forces. See
            % docs/failures.md.
            verifyErrorMessage(testCase, ...
                @() parse("bad_misspelled_force_column.xml"), ...
                "Unable to parse GRF file");
        end

        function missingResultsDirectoryIsReported(testCase)
            % Fixed 2026-10-27; before, "Dot indexing is not supported for
            % variables of this type." (as in MTP and NCP). See
            % docs/failures.md.
            verifyErrorMessage(testCase, ...
                @() parse("bad_missing_results_directory.xml"), ...
                "results_directory");
        end
    end
end

function parsed = parse(fileName)
% Parses a settings file in the current folder the way
% GroundContactPersonalizationTool does.
settingsTree = xml2struct(fileName);
verifyVersion(settingsTree, "GroundContactPersonalizationTool");
[parsed.inputs, parsed.params, parsed.resultsDirectory] = ...
    parseGroundContactPersonalizationSettingsTree(settingsTree);
end

function prepareQuietly(inputs)
% prepareGroundContactPersonalizationInputs prints and writes the foot
% model into the current folder (the test's temporary folder).
evalc("prepareGroundContactPersonalizationInputs(inputs)");
end
