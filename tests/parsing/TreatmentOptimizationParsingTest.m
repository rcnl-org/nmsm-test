% Tests of the parsing all three Treatment Optimization tools share
% (src/core/parse/parseTreatmentOptimizationInputs and the parsers it
% calls), using Tracking Optimization settings files in
% tests/data/to/settings: the data, controllers, design variable bounds,
% cost and constraint terms, GPOPS-II settings, required elements and
% versions. Written for candidate-1.5.4.
%
% Expected values come from toFixtureValues and the settings files, so
% they do not depend on nmsm-core.

classdef (TestTags = {'Parsing'}) TreatmentOptimizationParsingTest < ...
        matlab.unittest.TestCase

    properties
        expected
        minimal
        full
    end

    methods (TestClassSetup)
        function parseValidFiles(testCase)
            files = string({dir(testDataPath("to", "settings", ...
                "*.xml")).name});
            setUpToWorkingFolder(testCase, "torque", files);
            testCase.expected = toFixtureValues();
            testCase.minimal = parseQuietly( ...
                "settings_tracking_torque_minimal.xml");
            testCase.full = parseQuietly("settings_tracking_torque_full.xml");
        end
    end

    methods (Test)
        % ---- data -------------------------------------------------------

        function trialDataIsRead(testCase)
            inputs = testCase.minimal;
            testCase.verifyEqual(inputs.trialName, ...
                char(testCase.expected.trialName));
            testCase.verifySize(inputs.experimentalJointAngles, ...
                [testCase.expected.numFrames, ...
                testCase.expected.numIkCoordinates]);
            testCase.verifySize(inputs.experimentalJointMoments, ...
                [testCase.expected.numFrames, testCase.expected.numIdLoads]);
            testCase.verifyEqual(inputs.experimentalTime([1 end])', ...
                testCase.expected.timeRange, "AbsTol", 1e-9);
        end

        function anglesAreConvertedToRadians(testCase)
            % The IK file is in degrees: hip_flexion_r starts at
            % 25.2883 degrees.
            inputs = testCase.minimal;
            column = inputs.coordinateNamesStrings == "hip_flexion_r";
            testCase.verifyEqual(inputs.experimentalJointAngles(1, column), ...
                deg2rad(25.28830051984858), "AbsTol", 1e-9);
        end

        function statesCoordinatesAreFoundInTheData(testCase)
            inputs = testCase.minimal;
            testCase.verifyEqual(inputs.statesCoordinateNames, ...
                testCase.expected.statesCoordinates);
            testCase.verifyEqual(inputs.coordinateNamesStrings( ...
                inputs.statesCoordinateIndices), ...
                testCase.expected.statesCoordinates);
        end

        function modelMassIsRead(testCase)
            testCase.verifyEqual(testCase.minimal.mass, 73, "AbsTol", 1e-6);
        end

        % ---- tool, controller and defaults ------------------------------

        function minimalUsesDefaults(testCase)
            inputs = testCase.minimal;
            testCase.verifyEqual(inputs.toolName, "TrackingOptimization");
            testCase.verifyEqual(inputs.controllerType, "torque");
            testCase.verifyFalse(inputs.normalizeCostByType);
            testCase.verifyEqual([inputs.jointPositionsMultiple, ...
                inputs.jointVelocitiesMultiple, ...
                inputs.jointAccelerationsMultiple], [2, 1.5, 1]);
            testCase.verifyEqual([inputs.jointPositionsMinRange, ...
                inputs.jointVelocitiesMinRange, ...
                inputs.jointAccelerationsMinRange], [0, 0, 0]);
            testCase.verifyEqual([inputs.maxTorqueControlsMultiple, ...
                inputs.maxTorqueControlsMinRange], [1, 0]);
            testCase.verifyEmpty(inputs.costTerms);
            testCase.verifyEmpty(inputs.path);
            testCase.verifyEmpty(inputs.terminal);
        end

        function missingResultsDirectoryIsReported(testCase)
            % <results_directory> is required by every tool except JMP.
            % Before 2026-10-27, leaving it out gave a results directory
            % of false. See docs/failures.md.
            verifyErrorMessage(testCase, @() parseQuietly( ...
                "bad_missing_results_directory.xml"), "results_directory");
        end

        function fullReadsEveryOption(testCase)
            inputs = testCase.full;
            testCase.verifyEqual(inputs.resultsDirectory, 'TrackingResults');
            testCase.verifyTrue(inputs.normalizeCostByType);
            testCase.verifyEqual([inputs.jointPositionsMultiple, ...
                inputs.jointVelocitiesMultiple, ...
                inputs.jointAccelerationsMultiple], [1.5, 1.25, 0.5]);
            testCase.verifyEqual([inputs.jointPositionsMinRange, ...
                inputs.jointVelocitiesMinRange, ...
                inputs.jointAccelerationsMinRange], [0.1, 0.2, 0.3]);
            testCase.verifyEqual(inputs.torqueControllerCoordinateNames, ...
                testCase.expected.statesCoordinates);
            testCase.verifyEqual([inputs.maxTorqueControlsMultiple, ...
                inputs.maxTorqueControlsMinRange], [2, 5]);
        end

        % ---- cost terms -------------------------------------------------

        function listsAreSplitIntoOneTermEach(testCase)
            % coordinate_list of three: three terms, each with
            % coordinate.
            terms = testCase.full.costTerms;
            testCase.verifyLength(terms, 9);
            coordinates = cellfun(@(t) string(t.coordinate), terms(1 : 3));
            testCase.verifyEqual(coordinates, ...
                testCase.expected.statesCoordinates);
            testCase.verifyFalse(isfield(terms{1}, "coordinate_list"));
            testCase.verifyEqual(terms{1}.maxAllowableError, 0.0873);
        end

        function axesAreSplitIntoOneTermEach(testCase)
            % <axes>xz</axes> gives an x term and a z term.
            terms = testCase.full.costTerms(7 : 8);
            testCase.verifyEqual(cellfun(@(t) string(t.axes), terms), ...
                ["x", "z"]);
            testCase.verifyEqual(terms{1}.body, 'calcn_r');
            testCase.verifyEqual(terms{1}.sequence, 'xyz');
        end

        function termElementsAreConverted(testCase)
            % Numbers become doubles, true/false logicals, and lists
            % string arrays; error_center becomes errorCenter.
            load = testCase.full.costTerms{4};
            testCase.verifyEqual(load.load, 'hip_flexion_r_moment');
            testCase.verifyEqual(load.scale_factor, 0.9);
            testCase.verifyEqual(load.normalize_by_final_time, false);
            testCase.verifyEqual(load.time_ranges, ["0", "0.5"]);
            testCase.verifyEqual(testCase.full.costTerms{6}.errorCenter, 1);
        end

        function disabledTermsAreKeptButMarked(testCase)
            % Defaults: is_enabled false, error center 0.
            term = testCase.full.costTerms{9};
            testCase.verifyEqual(term.type, 'controller_minimization');
            testCase.verifyFalse(term.isEnabled);
            testCase.verifyEqual(term.errorCenter, 0);
        end

        function zeroAllowableErrorIsReported(testCase)
            verifyErrorMessage(testCase, @() parseQuietly( ...
                "bad_zero_allowable_error.xml"), "cannot be 0");
        end

        % ---- constraint terms -------------------------------------------

        function constraintsAreSortedIntoPathAndTerminal(testCase)
            inputs = testCase.full;
            testCase.verifyEqual(cellfun(@(t) string(t.type), inputs.path), ...
                [repmat("kinetic_consistency", 1, 3), ...
                "generalized_coordinate_value"]);
            testCase.verifyEqual(inputs.terminal{1}.type, ...
                'generalized_coordinate_periodicity');
            testCase.verifyEqual([inputs.terminal{1}.maxError, ...
                inputs.terminal{1}.minError], [0.01, -0.02]);
        end

        function valueBoundsBecomeErrorBounds(testCase)
            % <max_value>/<min_value> are another name for the bounds.
            term = testCase.full.path{4};
            testCase.verifyEqual([term.maxError, term.minError], [0.5, -0.5]);
            testCase.verifyFalse(isfield(term, "max_value"));
        end

        function constraintNotInTheToolIsReported(testCase)
            testCase.verifyError(@() parseQuietly( ...
                "bad_constraint_not_in_tool.xml"), ...
                "ConstraintTermSet:InvalidType");
        end

        % ---- GPOPS-II settings ------------------------------------------

        function gpopsSettingsAreRead(testCase)
            % gpops_torque_tutorial.xml. GPOPS-II's intervals and points
            % per interval are stored in misnamed fields: the number of
            % intervals in numCollocationPoints and the points per
            % interval in numIntervals.
            gpops = testCase.minimal.gpops;
            testCase.verifyEqual(gpops.derivativeSupplier, 'sparseCD');
            testCase.verifyEqual(gpops.method, 'RPM-Integration');
            testCase.verifyEqual(gpops.meshMethod, 'none');
            testCase.verifyEqual(gpops.numCollocationPoints, 25);
            testCase.verifyEqual(gpops.numIntervals, 4);
            testCase.verifyEqual(gpops.solverTolerance, 1);
            testCase.verifyEqual(gpops.maxIterations, 100);
            testCase.verifyEqual(gpops.integralBound, 1);
        end

        function gpopsSettingsHaveDefaults(testCase)
            % An empty <GpopsSettings> takes every default.
            writelines(["<NMSMPipelineDocument Version=""1.5.4"">", ...
                "<OptimalControlSolverSettings><GpopsSettings/>" + ...
                "</OptimalControlSolverSettings></NMSMPipelineDocument>"], ...
                "gpops_empty.xml");
            writelines(replace(fileread( ...
                "settings_tracking_torque_minimal.xml"), ...
                "gpops_torque_tutorial.xml", "gpops_empty.xml"), ...
                "settings_gpops_defaults.xml");
            gpops = parseQuietly("settings_gpops_defaults.xml").gpops;
            testCase.verifyEqual(gpops.derivativeSupplier, 'sparseFD');
            testCase.verifyEqual(gpops.method, 'RPM-Differentiation');
            testCase.verifyEqual(gpops.meshMethod, 'hp-PattersonRao');
            testCase.verifyEqual(gpops.meshTolerance, 1e-2);
            testCase.verifyEqual(gpops.meshMaxIterations, 10);
            testCase.verifyEqual([gpops.numCollocationPoints, ...
                gpops.numIntervals], [6, 10]);
            testCase.verifyEqual(gpops.solverType, 'ipopt');
            testCase.verifyEqual(gpops.linearSolverType, 'ma57');
            testCase.verifyEqual(gpops.solverTolerance, 1e-3);
            testCase.verifyEqual(gpops.maxIterations, 2e4);
            testCase.verifyEqual(gpops.integralBound, 1);
        end

        function unsupportedSolverIsReported(testCase)
            writelines(["<NMSMPipelineDocument Version=""1.5.4"">", ...
                "<OptimalControlSolverSettings><CasadiSettings/>" + ...
                "</OptimalControlSolverSettings></NMSMPipelineDocument>"], ...
                "casadi.xml");
            writelines(replace(fileread( ...
                "settings_tracking_torque_minimal.xml"), ...
                "gpops_torque_tutorial.xml", "casadi.xml"), ...
                "settings_casadi.xml");
            testCase.verifyError(@() parseQuietly("settings_casadi.xml"), ...
                "OptimalControlSolverSettings:UnsupportedSolver");
        end

        % ---- bad_* and edge_* files -------------------------------------

        function wrongMajorVersionIsRejected(testCase)
            testCase.verifyError(@() parseQuietly("bad_major_version.xml"), ...
                "verifyVersion:invalidSettingsFile");
        end

        function differentMinorVersionOnlyWarns(testCase)
            % verifyVersion's warning has no identifier, so it is found
            % with lastwarn.
            lastwarn("");
            inputs = parseQuietly("edge_minor_version.xml");
            testCase.verifySubstring(lastwarn, "may not be compatible");
            testCase.verifyEqual(inputs.toolName, "TrackingOptimization");
        end

        function wrongToolIsRejected(testCase)
            testCase.verifyError(@() parseQuietly("bad_wrong_tool.xml"), ...
                "verifyVersion:invalidSettingsFile");
        end

        function missingControllerIsReported(testCase)
            testCase.verifyError(@() parseQuietly( ...
                "bad_missing_controller.xml"), ...
                "ParseTreatmentOptimization:NoController");
        end

        function missingCostTermSetIsReported(testCase)
            verifyErrorMessage(testCase, @() parseQuietly( ...
                "bad_missing_cost_term_set.xml"), "RCNLCostTermSet");
        end

        function missingInitialGuessDirectoryIsReported(testCase)
            testCase.verifyError(@() parseQuietly( ...
                "bad_missing_initial_guess_directory.xml"), ...
                "ParseError:RequiredElement");
        end

        function missingSolverSettingsFileIsReported(testCase)
            verifyErrorMessage(testCase, @() parseQuietly( ...
                "bad_solver_settings_file_not_found.xml"), "gpops_missing.xml");
        end

        function unknownStatesCoordinateIsReported(testCase)
            % Fixed 2026-10-27; before, a misspelled
            % <states_coordinate_list> entry fails with "Unable to
            % perform assignment because the left and right sides have a
            % different number of elements." instead of naming it. See
            % docs/failures.md.
            verifyErrorMessage(testCase, @() parseQuietly( ...
                "bad_unknown_states_coordinate.xml"), "hip_flex_r");
        end
    end
end

function inputs = parseQuietly(fileName)
% Parses without printing (OpenSim and the version check print).
[~, inputs] = evalc("parseToSettingsFile(fileName)");
end
