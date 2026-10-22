% Tests that the <MuscleTendonLengthInitialization> section of MTP settings
% files parses into the expected inputs:
% parseMuscleTendonLengthInitializationSettingsTree, as
% MuscleTendonPersonalizationTool calls it. The MTP part of these files is
% covered by MuscleTendonPersonalizationParsingTest.
%
% Expected values come from mtpFixtureValues, the settings files, and the
% passive data files read with readStoFile. Written for candidate-1.5.4.

classdef (TestTags = {'Parsing'}) MuscleTendonLengthInitializationParsingTest < ...
        matlab.unittest.TestCase

    properties
        expected
        tutorial
        full
    end

    methods (TestClassSetup)
        function parseValidFiles(testCase)
            files = dir(testDataPath("mtp", "settings", "*.xml"));
            setUpMtpWorkingFolder(testCase, string({files.name}));
            testCase.expected = mtpFixtureValues();
            testCase.tutorial = parse("settings_tutorial.xml");
            testCase.full = parse("settings_full.xml");
        end
    end

    methods (Test)
        function disabledSectionGivesFalse(testCase)
            testCase.verifyFalse(parse("settings_minimal.xml"));
        end

        function tutorialSettings(testCase)
            inputs = testCase.tutorial;
            testCase.verifyEqual(inputs.muscleNames, ...
                testCase.expected.muscleNames);
            testCase.verifyEqual(inputs.maximumMuscleStress, 610000);
            testCase.verifyEqual(inputs.maxNormalizedMuscleFiberLength, 1);
            testCase.verifyEqual(inputs.minNormalizedMuscleFiberLength, 0.6);
            testCase.verifyTrue(inputs.maximumMuscleStressIsIncluded);
            testCase.verifyTrue(inputs.optimizeIsometricMaxForce);
            testCase.verifyFalse(inputs.useAbsoluteLengths);
            testCase.verifyEqual(cellfun(@(t) string(t.type), ...
                inputs.costTerms), ["passive_joint_moment", ...
                "optimal_muscle_fiber_length", "tendon_slack_length", ...
                "minimum_normalized_muscle_fiber_length", ...
                "maximum_normalized_muscle_fiber_length", ...
                "maximum_muscle_stress", "passive_muscle_force", ...
                "grouped_normalized_muscle_fiber_length", ...
                "grouped_maximum_normalized_muscle_fiber_length"]);
            testCase.verifyEqual(cellfun(@(t) t.isEnabled, inputs.costTerms), ...
                [true, true, true, true, true, true, false, true, true]);
        end

        function fullSettingsOverrideDefaults(testCase)
            inputs = testCase.full;
            testCase.verifyEqual(inputs.maximumMuscleStress, 500000);
            testCase.verifyEqual(inputs.maxNormalizedMuscleFiberLength, 1.05);
            testCase.verifyFalse(inputs.optimizeIsometricMaxForce);
            testCase.verifyTrue(inputs.useAbsoluteLengths);
        end

        function defaultsWhenOptionsAreOmitted(testCase)
            % edge_mtli_enabled gives only the required elements.
            inputs = parse("edge_mtli_enabled.xml");
            testCase.verifyEqual(inputs.maximumMuscleStress, 610e3);
            testCase.verifyTrue(inputs.optimizeIsometricMaxForce);
            testCase.verifyFalse(inputs.useAbsoluteLengths);
            testCase.verifyFalse(isfield(inputs, ...
                "maxNormalizedMuscleFiberLength"));
        end

        function muscleVolumeComesFromForceStressAndLength(testCase)
            % volume = F0 / maximum muscle stress * optimal fiber length
            expectedVolume = testCase.expected.maxIsometricForce / 610000 ...
                .* testCase.expected.optimalFiberLength;
            testCase.verifyEqual(testCase.tutorial.muscleVolume, ...
                expectedVolume, "RelTol", 1e-12);
            testCase.verifyEqual(testCase.tutorial.initialOptimalFiberLength, ...
                testCase.expected.optimalFiberLength, "AbsTol", 1e-12);
            testCase.verifyEqual(testCase.tutorial.initialTendonSlackLength, ...
                testCase.expected.tendonSlackLength, "AbsTol", 1e-12);
        end

        function eachMuscleMapsToItsGroupOrItsOwnSlot(testCase)
            % One maximum fiber length design value per group, in settings
            % order, then one per ungrouped muscle, in muscle order.
            groups = testCase.expected.normalizedFiberLengthGroups;
            names = testCase.expected.muscleNames;
            expectedSlots = zeros(1, length(names));
            groupNames = string(fieldnames(groups))';
            for i = 1 : length(groupNames)
                expectedSlots(ismember(names, groups.(groupNames(i)))) = i;
            end
            ungrouped = find(expectedSlots == 0);
            expectedSlots(ungrouped) = length(groupNames) + ...
                (1 : length(ungrouped));

            testCase.verifyEqual(testCase.tutorial.numMuscleGroups, 4);
            testCase.verifyEqual(testCase.tutorial.numMusclesIndividual, 5);
            testCase.verifyEqual( ...
                testCase.tutorial.groupedMaxNormalizedFiberLength, ...
                expectedSlots);
        end

        function withoutGroupsEveryMuscleHasItsOwnSlot(testCase)
            inputs = parse("edge_mtli_enabled.xml");
            testCase.verifyEqual(inputs.numMuscleGroups, 0);
            testCase.verifyEqual(inputs.groupedMaxNormalizedFiberLength, 1 : 9);
        end

        function passiveTrialsAreFound(testCase)
            inputs = testCase.tutorial;
            testCase.verifyEqual(inputs.passiveMomentDataExists, 1);
            testCase.verifyEqual(inputs.passivePrefixes, ...
                testCase.expected.passiveTrialNames);
            testCase.verifyEqual(string(inputs.coordinateNames), ...
                testCase.expected.passiveCoordinateNames);
        end

        function passiveMomentsMatchFiles(testCase)
            % (trial x coordinate x frame)
            moments = testCase.tutorial.passiveData.inverseDynamicsMoments;
            testCase.verifySize(moments, [12, 6, 101]);
            for i = [1, 5, 12]
                trial = testCase.expected.passiveTrialNames(i);
                data = readStoFile(testDataPath("mtp", ...
                    "passive_moment_data", "IDData", trial + ".sto"));
                testCase.verifyEqual(squeeze(moments(i, :, :)), ...
                    data(:, 2 : end)', "AbsTol", 1e-12, trial);
            end
        end

        function passiveLengthsAndMomentArmsMatchFiles(testCase)
            % Lengths (trial x muscle x frame) and moment arms (trial x
            % coordinate x muscle x frame), in muscle order.
            inputs = testCase.tutorial;
            testCase.verifySize(inputs.passiveMuscleTendonLength, [12, 9, 101]);
            testCase.verifySize(inputs.passiveMomentArms, [12, 6, 9, 101]);
            trial = testCase.expected.passiveTrialNames(9);
            folder = testDataPath("mtp", "passive_moment_data", "MAData", trial);
            [data, names] = readStoFile(fullfile(folder, trial + ...
                "_MuscleAnalysis_Length.sto"));
            [~, columns] = ismember(testCase.expected.muscleNames, names);
            testCase.verifyEqual(squeeze(inputs.passiveMuscleTendonLength( ...
                9, :, :)), data(:, columns)', "AbsTol", 1e-12);
            knee = testCase.expected.passiveCoordinateNames == "knee_angle_r";
            [data, names] = readStoFile(fullfile(folder, trial + ...
                "_MuscleAnalysis_MomentArm_knee_angle_r.sto"));
            [~, columns] = ismember(testCase.expected.muscleNames, names);
            testCase.verifyEqual(squeeze(inputs.passiveMomentArms(9, knee, ...
                :, :)), data(:, columns)', "AbsTol", 1e-12);
        end

        function emptyPassiveFolderMeansNoPassiveData(testCase)
            inputs = parse("edge_mtli_without_passive_data.xml");
            testCase.verifyEqual(inputs.passiveMomentDataExists, 0);
            testCase.verifyFalse(isfield(inputs, "passiveData"));
        end
    end
end

function inputs = parse(fileName)
settingsTree = xml2struct(fileName);
verifyVersion(settingsTree, "MuscleTendonPersonalizationTool");
inputs = parseMuscleTendonLengthInitializationSettingsTree(settingsTree);
end
