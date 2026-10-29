% Tests that MTP settings files in tests/data/mtp/settings parse into the
% expected inputs and params structs: xml2struct -> verifyVersion ->
% parseMuscleTendonPersonalizationSettingsTree, as
% MuscleTendonPersonalizationTool does.
%
% Expected values come from mtpFixtureValues, from the settings files
% themselves, and from reading the data files with readStoFile, so they do
% not depend on nmsm-core. Written for candidate-1.5.4.
%
% The three valid files are parsed once for the class; the bad_* and
% edge_* files are parsed in the test that uses them.

classdef (TestTags = {'Parsing'}) MuscleTendonPersonalizationParsingTest < ...
        matlab.unittest.TestCase

    properties
        expected
        minimal
        full
        tutorial
    end

    methods (TestClassSetup)
        function parseValidFiles(testCase)
            files = dir(testDataPath("mtp", "settings", "*.xml"));
            setUpMtpWorkingFolder(testCase, string({files.name}));
            testCase.expected = mtpFixtureValues();
            testCase.minimal = parse("settings_minimal.xml");
            testCase.full = parse("settings_full.xml");
            testCase.tutorial = parse("settings_tutorial.xml");
        end
    end

    methods (Test)
        % ---- settings_minimal: muscles, data and defaults ---------------

        function musclesComeFromCoordinateList(testCase)
            inputs = testCase.minimal.inputs;
            testCase.verifyEqual(inputs.coordinateNames, ...
                testCase.expected.coordinateNames);
            testCase.verifyEqual(inputs.muscleNames, ...
                testCase.expected.muscleNames);
        end

        function muscleModelPropertiesComeFromModel(testCase)
            inputs = testCase.minimal.inputs;
            testCase.verifyEqual(inputs.optimalFiberLength, ...
                testCase.expected.optimalFiberLength, "AbsTol", 1e-12);
            testCase.verifyEqual(inputs.tendonSlackLength, ...
                testCase.expected.tendonSlackLength, "AbsTol", 1e-12);
            testCase.verifyEqual(inputs.pennationAngle, ...
                testCase.expected.pennationAngle, "AbsTol", 1e-12);
            testCase.verifyEqual(inputs.maxIsometricForce, ...
                testCase.expected.maxIsometricForce, "AbsTol", 1e-9);
        end

        function inverseDynamicsMomentsMatchFile(testCase)
            % (trial x coordinate x frame), in coordinate_list order
            inputs = testCase.minimal.inputs;
            [data, names] = readStoFile(gaitFile("IDData"));
            testCase.verifySize(inputs.inverseDynamicsMoments, [1, 3, 101]);
            for i = 1 : 3
                column = names == testCase.expected.coordinateNames(i) + ...
                    "_moment";
                testCase.verifyEqual(squeeze( ...
                    inputs.inverseDynamicsMoments(1, i, :)), ...
                    data(:, column), "AbsTol", 1e-12);
            end
            testCase.verifyEqual(inputs.time', data(:, 1), "AbsTol", 1e-12);
        end

        function muscleTendonLengthsAndVelocitiesMatchFiles(testCase)
            % (trial x muscle x frame), in muscle order
            inputs = testCase.minimal.inputs;
            for quantity = ["Length", "Velocity"]
                [data, names] = readStoFile(muscleAnalysisFile(quantity));
                [~, columns] = ismember(testCase.expected.muscleNames, names);
                parsed = inputs.("muscleTendon" + quantity);
                testCase.verifyEqual(squeeze(parsed(1, :, :)), ...
                    data(:, columns)', "AbsTol", 1e-12, quantity);
            end
        end

        function momentArmsMatchFiles(testCase)
            % (trial x coordinate x muscle x frame)
            inputs = testCase.minimal.inputs;
            testCase.verifySize(inputs.momentArms, [1, 3, 9, 101]);
            for i = 1 : 3
                [data, names] = readStoFile(muscleAnalysisFile( ...
                    "MomentArm_" + testCase.expected.coordinateNames(i)));
                [~, columns] = ismember(testCase.expected.muscleNames, names);
                testCase.verifyEqual(squeeze(inputs.momentArms(1, i, :, :)), ...
                    data(:, columns)', "AbsTol", 1e-12, ...
                    testCase.expected.coordinateNames(i));
            end
        end

        function emgKeepsCollectedChannelsInSettingsOrder(testCase)
            inputs = testCase.minimal.inputs;
            channels = string(fieldnames( ...
                testCase.expected.collectedEmgChannelGroups))';
            [data, names] = readStoFile(gaitFile("EMGData"));
            testCase.verifyEqual(string(inputs.emgDataColumnNames), channels);
            [~, columns] = ismember(channels, names);
            testCase.verifyEqual(squeeze(inputs.emgData(1, :, :)), ...
                data(:, columns)', "AbsTol", 1e-12);
            testCase.verifyEqual(inputs.emgTime', data(:, 1), "AbsTol", 1e-12);
            testCase.verifyEqual(inputs.numPaddingFrames, ...
                testCase.expected.numEmgPaddingFrames);
        end

        function emgIsCopiedToEachMuscleOfItsChannel(testCase)
            % Each muscle gets the EMG of the channel group containing it.
            % iliacus_r has no channel, and without synergy extrapolation
            % its EMG is silently all zeros.
            inputs = testCase.minimal.inputs;
            groups = testCase.expected.collectedEmgChannelGroups;
            [data, names] = readStoFile(gaitFile("EMGData"));
            for channel = string(fieldnames(groups))'
                muscle = testCase.expected.muscleNames == groups.(channel);
                testCase.verifyEqual(squeeze(inputs.emgDataExpanded(1, ...
                    muscle, :)), data(:, names == channel), ...
                    "AbsTol", 1e-12, channel);
            end
            iliacus = testCase.expected.muscleNames == "iliacus_r";
            testCase.verifyEqual(squeeze(inputs.emgDataExpanded(1, ...
                iliacus, :)), zeros(139, 1));
        end

        function minimalUsesDefaults(testCase)
            inputs = testCase.minimal.inputs;
            testCase.verifyEqual(testCase.minimal.resultsDirectory, ...
                'MTPResults');
            testCase.verifyEqual(inputs.vMaxFactor, 10);
            testCase.verifyEqual(testCase.minimal.params, ...
                struct("performMuscleTendonLengthInitialization", 0));
            testCase.verifyFalse(isfield(inputs, "synergyExtrapolation"));
            testCase.verifyEmpty(inputs.activationGroups);
            testCase.verifyEmpty(inputs.normalizedFiberLengthGroups);
            task = inputs.tasks{1};
            testCase.verifyLength(inputs.tasks, 1);
            testCase.verifyEqual(task.isIncluded, ones(1, 7));
            testCase.verifyEqual(task.maxNormalizedMuscleFiberLength, 1.05);
            testCase.verifyEqual(task.minNormalizedMuscleFiberLength, 0.75);
            testCase.verifyTrue(task.muscleSpecificElectromechanicalDelays);
        end

        % ---- settings_full: every option --------------------------------

        function fullReadsToolLevelOptions(testCase)
            inputs = testCase.full.inputs;
            testCase.verifyEqual(inputs.vMaxFactor, 8);
            testCase.verifyEqual(inputs.prefixes, "gait");
            testCase.verifyEqual(string(inputs.trialNames), "gait_1");
            testCase.verifyEqual(testCase.full.params, struct( ...
                "maxIterations", 500, "maxFunctionEvaluations", 20000, ...
                "stepTolerance", 1e-5, ...
                "performMuscleTendonLengthInitialization", 1));
        end

        function groupsAreMusclePositionsInSettingsOrder(testCase)
            inputs = testCase.full.inputs;
            testCase.verifyEqual(inputs.activationGroups, groupPositions( ...
                testCase.expected.activationGroups, ...
                testCase.expected.muscleNames));
            testCase.verifyEqual(inputs.normalizedFiberLengthGroups, ...
                groupPositions(testCase.expected.normalizedFiberLengthGroups, ...
                testCase.expected.muscleNames));
        end

        function tasksAreOrderedByIndexAndDisabledTaskIsDropped(testCase)
            % The file lists tasks 2, 3 (disabled), 1.
            tasks = testCase.full.inputs.tasks;
            testCase.verifyLength(tasks, 2);
            testCase.verifyLength(tasks{1}.costTerms, 15);
            testCase.verifyLength(tasks{2}.costTerms, 1);
            testCase.verifyEqual(tasks{2}.costTerms{1}.maxAllowableError, 2);
        end

        function taskOptimizeFlagsAndLimits(testCase)
            % Task 1 leaves every optimize_* flag at its default (true);
            % task 2 optimizes only delays and EMG scale factors. The
            % seventh flag (synergy weights) is always 1 when parsed.
            tasks = testCase.full.inputs.tasks;
            testCase.verifyEqual(tasks{1}.isIncluded, ones(1, 7));
            testCase.verifyEqual(tasks{2}.isIncluded, [1, 0, 0, 1, 0, 0, 1]);
            testCase.verifyEqual([tasks{1}.maxNormalizedMuscleFiberLength, ...
                tasks{1}.minNormalizedMuscleFiberLength], [1.05, 0.75]);
            testCase.verifyEqual([tasks{2}.maxNormalizedMuscleFiberLength, ...
                tasks{2}.minNormalizedMuscleFiberLength], [1.1, 0.5]);
        end

        function costTermsKeepFileOrderAndValues(testCase)
            terms = testCase.full.inputs.tasks{1}.costTerms;
            testCase.verifyEqual(cellfun(@(t) string(t.type), terms), [ ...
                "inverse_dynamics_joint_moment", ...
                "activation_time_constant", ...
                "activation_nonlinearity_constant", ...
                "optimal_muscle_fiber_length", "tendon_slack_length", ...
                "emg_scale_factor", "electromechanical_delay", ...
                "normalized_muscle_fiber_length", ...
                "minimum_normalized_muscle_fiber_length", ...
                "maximum_normalized_muscle_fiber_length", ...
                "passive_muscle_force", ...
                "grouped_normalized_muscle_fiber_length", ...
                "grouped_emg_scale_factor", ...
                "grouped_electromechanical_delay", ...
                "muscle_excitation_penalty"]);
            testCase.verifyTrue(all(cellfun(@(t) t.isEnabled, terms)));
            testCase.verifyEqual(cellfun(@(t) t.maxAllowableError, terms), ...
                [2.5, 0.02, 0.1, 0.1, 0.1, 0.2, 0.1, 0.01, 0.05, 0.05, ...
                50, 0.05, 0.1, 0.2, 0.25]);
            testCase.verifyEqual(terms{2}.errorCenter, 0.015);
            testCase.verifyEqual(terms{15}.errorCenter, 0.5);
        end

        function omittedErrorCenterParsesAsZero(testCase)
            % On candidate-1.5.4 every parsed term has an errorCenter, so
            % a term's own default (e.g. 0.3 for emg_scale_factor, see
            % MtpCostTermsTest) is never used from a settings file.
            terms = testCase.full.inputs.tasks{1}.costTerms;
            emgScaleFactor = terms{6};
            testCase.verifyEqual(emgScaleFactor.type, 'emg_scale_factor');
            testCase.verifyEqual(emgScaleFactor.errorCenter, 0);
        end

        function synergyExtrapolationSettings(testCase)
            % 2 PCA synergies (+1 constant), extrapolation by task (1
            % task), residuals by trial (1 trial), 1 missing and 8
            % measured channels: 3 x 1 x 1 = 3 and 3 x 8 x 1 = 24 weights.
            inputs = testCase.full.inputs;
            synergy = inputs.synergyExtrapolation;
            testCase.verifyEqual(synergy.matrixFactorizationMethod, 'PCA');
            testCase.verifyEqual(synergy.numberOfSynergies, 2);
            testCase.verifyEqual(synergy.synergyExtrapolationCategorization, ...
                'task');
            testCase.verifyEqual(synergy.residualCategorization, 'trial');
            testCase.verifyEqual(synergy.taskNames, "gait");
            testCase.verifyEqual(synergy.missingEmgChannelGroups, ...
                {find(testCase.expected.muscleNames == "iliacus_r")});
            testCase.verifyEqual([inputs.numberOfExtrapolationWeights, ...
                inputs.numberOfResidualWeights], [3, 24]);
            testCase.verifyEqual(inputs.synergyWeights, zeros(1, 27));
            testCase.verifySize(inputs.extrapolationCommands{1}, [139, 2]);
            testCase.verifyEqual(cellfun(@(t) string(t.type), ...
                synergy.costTerms), ["measured_inverse_dynamics_joint_moment", ...
                "extrapolated_muscle_activation", ...
                "residual_muscle_activation"]);
        end

        function synergyChannelsAreMusclePositionsInSettingsOrder(testCase)
            groups = testCase.expected.collectedEmgChannelGroups;
            expected = cellfun(@(channel) find( ...
                testCase.expected.muscleNames == groups.(channel)), ...
                fieldnames(groups)', "UniformOutput", false);
            testCase.verifyEqual(testCase.full.inputs.synergyExtrapolation. ...
                currentEmgChannelGroups, expected);
        end

        function tutorialSynergyWeightCount(testCase)
            % Same count as SynergyExtrapolationTest works out by hand.
            inputs = testCase.tutorial.inputs;
            testCase.verifyEqual([inputs.numberOfExtrapolationWeights, ...
                inputs.numberOfResidualWeights], [4, 32]);
            testCase.verifyEqual(testCase.tutorial.resultsDirectory, ...
                'MTPResultsV1');
        end

        % ---- edge_* files -----------------------------------------------

        function synergyExtrapolationCanBeEnabled(testCase)
            parsed = parse("edge_synergy_extrapolation_enabled.xml");
            testCase.verifyTrue(isfield(parsed.inputs, "synergyExtrapolation"));
            testCase.verifyEqual([parsed.inputs.numberOfExtrapolationWeights, ...
                parsed.inputs.numberOfResidualWeights], [4, 32]);
        end

        function sharedDelaySettingIsRead(testCase)
            % Parsed, but candidate-1.5.4's MTP does not use it: delays are
            % always one per muscle. See tests/README.md.
            parsed = parse("edge_muscle_specific_delays_false.xml");
            testCase.verifyFalse( ...
                parsed.inputs.tasks{1}.muscleSpecificElectromechanicalDelays);
        end

        function allTasksDisabledIsReported(testCase)
            % Fixed 2026-10-27; before, getTasks returns nothing and MATLAB reports
            % 'Output argument "output" ... not assigned'. See
            % docs/failures.md.
            verifyErrorMessage(testCase, ...
                @() parse("edge_all_tasks_disabled.xml"), "enabled");
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

        function missingDataDirectoryIsReported(testCase)
            verifyErrorMessage(testCase, ...
                @() parse("bad_missing_data_directory.xml"), "data_directory");
        end

        function missingMuscleSpecificDelaysIsReported(testCase)
            verifyErrorMessage(testCase, ...
                @() parse("bad_missing_muscle_specific_delays.xml"), ...
                "muscle_specific_electromechanical_delays");
        end

        function unknownMuscleGroupIsReported(testCase)
            verifyErrorMessage(testCase, ...
                @() parse("bad_unknown_muscle_group.xml"), "NotAGroup");
        end

        function missingResultsDirectoryIsReported(testCase)
            % Fixed 2026-10-27; before, "Dot indexing is not supported for
            % variables of this type." See docs/failures.md.
            verifyErrorMessage(testCase, ...
                @() parse("bad_missing_results_directory.xml"), ...
                "results_directory");
        end

        function unknownCoordinateIsReported(testCase)
            % Fixed 2026-10-27; before, "Unable to perform assignment because the
            % size of the left side is 0-by-139 ...". See docs/failures.md.
            verifyErrorMessage(testCase, ...
                @() parse("bad_unknown_coordinate.xml"), "knee_angl_r");
        end

        function emgChannelMissingFromDataIsReported(testCase)
            % Fixed 2026-10-27; before, "Index in position 1 exceeds array bounds."
            % See docs/failures.md.
            verifyErrorMessage(testCase, ...
                @() parse("bad_emg_channel_not_in_data.xml"), ...
                "HipFlexorsMissingEMGChannelGroup");
        end
    end
end

function parsed = parse(fileName)
% Parses a settings file in the current folder the way
% MuscleTendonPersonalizationTool does.
settingsTree = xml2struct(fileName);
verifyVersion(settingsTree, "MuscleTendonPersonalizationTool");
[parsed.inputs, parsed.params, parsed.resultsDirectory] = ...
    parseMuscleTendonPersonalizationSettingsTree(settingsTree);
end

function fileName = gaitFile(folder)
values = mtpFixtureValues();
fileName = testDataPath("mtp", "preprocessed", folder, ...
    values.trialName + ".sto");
end

function fileName = muscleAnalysisFile(suffix)
values = mtpFixtureValues();
fileName = testDataPath("mtp", "preprocessed", "MAData", ...
    values.trialName, values.trialName + "_" + suffix + ".sto");
end

function positions = groupPositions(groups, muscleNames)
% {positions of group 1's members, ...} in the order the groups are listed
positions = cellfun(@(name) find(ismember(muscleNames, groups.(name))), ...
    fieldnames(groups)', "UniformOutput", false);
end
