% Checks that the MTP test fixtures in tests/data/mtp still match the
% values recorded in tests/helpers/mtpFixtureValues.m. If a fixture file is
% edited or corrupted, this fails first, instead of the parsing and
% regression tests failing for reasons that look like code bugs.
%
% Data files are read with readStoFile, not nmsm-core, so these checks do
% not depend on the code under test.

classdef (TestTags = {'Unit'}) MtpFixtureTest < matlab.unittest.TestCase

    properties
        expected
        model
    end

    properties (TestParameter)
        % Each group setting the MTP settings files use.
        groupSetting = {"collectedEmgChannelGroups", ...
            "missingEmgChannelGroups", "activationGroups", ...
            "normalizedFiberLengthGroups"}
        % Each gait muscle analysis file, by its file name suffix.
        muscleAnalysisFile = {"Length", "Velocity", ...
            "MomentArm_hip_flexion_r", "MomentArm_knee_angle_r", ...
            "MomentArm_ankle_angle_r"}
    end

    methods (TestClassSetup)
        function loadFixtures(testCase)
            testCase.expected = mtpFixtureValues();
            testCase.model = Model(testDataPath("mtp", ...
                testCase.expected.modelFileName));
        end
    end

    methods (Test)
        function modelHasOnlyTheExpectedMuscles(testCase)
            muscles = testCase.model.getMuscles();
            names = strings(1, muscles.getSize());
            for i = 1 : muscles.getSize()
                names(i) = string(muscles.get(i - 1).getName());
            end
            testCase.verifyEqual(sort(names), ...
                sort(testCase.expected.muscleNames));
        end

        function musclePropertiesMatchRecordedValues(testCase)
            names = testCase.expected.muscleNames;
            actual = zeros(4, length(names));
            for i = 1 : length(names)
                muscle = testCase.model.getMuscles().get(char(names(i)));
                actual(:, i) = [muscle.getMaxIsometricForce(); ...
                    muscle.getOptimalFiberLength(); ...
                    muscle.getTendonSlackLength(); ...
                    muscle.getPennationAngleAtOptimalFiberLength()];
            end
            testCase.verifyEqual(actual(1, :), ...
                testCase.expected.maxIsometricForce, "AbsTol", 1e-9);
            testCase.verifyEqual(actual(2, :), ...
                testCase.expected.optimalFiberLength, "AbsTol", 1e-12);
            testCase.verifyEqual(actual(3, :), ...
                testCase.expected.tendonSlackLength, "AbsTol", 1e-12);
            testCase.verifyEqual(actual(4, :), ...
                testCase.expected.pennationAngle, "AbsTol", 1e-12);
        end

        function modelHasMuscleGroups(testCase, groupSetting)
            groups = testCase.expected.(groupSetting);
            forceSet = testCase.model.getForceSet();
            for groupName = string(fieldnames(groups))'
                testCase.verifyEqual(groupMembers(forceSet, groupName), ...
                    sort(groups.(groupName)), groupName);
            end
        end

        function everyMuscleSpansATrackedCoordinate(testCase)
            % MTP picks its muscles from <coordinate_list>, so each of the
            % nine must have a nonzero moment arm about at least one.
            spans = false(1, length(testCase.expected.muscleNames));
            for coordinate = testCase.expected.coordinateNames
                [data, names] = readStoFile(gaitMuscleAnalysisFile( ...
                    "MomentArm_" + coordinate));
                momentArms = data(:, columnIndices(names, ...
                    testCase.expected.muscleNames));
                spans = spans | any(abs(momentArms) > 1e-6, 1);
            end
            testCase.verifyTrue(all(spans), "Muscles spanning none: " + ...
                strjoin(testCase.expected.muscleNames(~spans), ", "));
        end

        function gaitFilesShareOneTimeGrid(testCase)
            ik = readStoFile(testDataPath("mtp", "preprocessed", ...
                "IKData", testCase.expected.trialName + ".sto"));
            id = readStoFile(testDataPath("mtp", "preprocessed", ...
                "IDData", testCase.expected.trialName + ".sto"));
            testCase.verifySize(id, [testCase.expected.numFrames, 42]);
            testCase.verifyEqual(id(:, 1), ik(:, 1), "AbsTol", 1e-12);
            testCase.verifyEqual(id([1, end], 1)', ...
                testCase.expected.timeRange, "AbsTol", 1e-9);
        end

        function inverseDynamicsHasTrackedMoments(testCase)
            [~, names] = readStoFile(testDataPath("mtp", "preprocessed", ...
                "IDData", testCase.expected.trialName + ".sto"));
            testCase.verifyTrue(all(ismember( ...
                testCase.expected.coordinateNames + "_moment", names)));
        end

        function muscleAnalysisMatchesGaitTimeAndMuscles(testCase, ...
                muscleAnalysisFile)
            [data, names] = readStoFile(gaitMuscleAnalysisFile( ...
                muscleAnalysisFile));
            testCase.verifyEqual(names(2 : end), ...
                testCase.expected.muscleNames);
            testCase.verifySize(data, [testCase.expected.numFrames, 10]);
            testCase.verifyEqual(data([1, end], 1)', ...
                testCase.expected.timeRange, "AbsTol", 1e-9);
        end

        function emgIsPaddedOnTheGaitTimeGrid(testCase)
            % The EMG frames between the padding must be exactly the
            % ID/IK frames, or the delay and activation dynamics are
            % computed at the wrong times.
            emg = readStoFile(testDataPath("mtp", "preprocessed", ...
                "EMGData", testCase.expected.trialName + ".sto"));
            id = readStoFile(testDataPath("mtp", "preprocessed", ...
                "IDData", testCase.expected.trialName + ".sto"));
            padding = testCase.expected.numEmgPaddingFrames;
            testCase.verifySize(emg, [testCase.expected.numFrames + ...
                2 * padding, testCase.expected.numEmgChannels + 1]);
            testCase.verifyEqual(emg(padding + 1 : end - padding, 1), ...
                id(:, 1), "AbsTol", 1e-9);
            testCase.verifyEqual(emg([1, end], 1)', ...
                testCase.expected.emgTimeRange, "AbsTol", 1e-9);
        end

        function emgHasCollectedChannels(testCase)
            [~, names] = readStoFile(testDataPath("mtp", "preprocessed", ...
                "EMGData", testCase.expected.trialName + ".sto"));
            channels = string(fieldnames( ...
                testCase.expected.collectedEmgChannelGroups))';
            testCase.verifyTrue(all(ismember(channels, names)));
            missing = string(fieldnames( ...
                testCase.expected.missingEmgChannelGroups))';
            testCase.verifyFalse(any(ismember(missing, names)));
        end

        function passiveTrialsAreComplete(testCase)
            folder = testDataPath("mtp", "passive_moment_data");
            for trial = testCase.expected.passiveTrialNames
                [moments, names] = readStoFile(fullfile(folder, ...
                    "IDData", trial + ".sto"));
                testCase.verifyEqual(names, ["time", ...
                    testCase.expected.passiveCoordinateNames], trial);
                testCase.verifySize(moments, ...
                    [testCase.expected.numPassiveFrames, 7], trial);
                [lengths, names] = readStoFile(fullfile(folder, ...
                    "MAData", trial, trial + "_MuscleAnalysis_Length.sto"));
                testCase.verifyTrue(all(ismember( ...
                    testCase.expected.muscleNames, names)), trial);
                testCase.verifySize(lengths, ...
                    [testCase.expected.numPassiveFrames, 10], trial);
            end
            idFiles = dir(fullfile(folder, "IDData", "*.sto"));
            testCase.verifyEqual(sort(string({idFiles.name})), ...
                sort(testCase.expected.passiveTrialNames + ".sto"));
        end
    end
end

function fileName = gaitMuscleAnalysisFile(suffix)
values = mtpFixtureValues();
fileName = testDataPath("mtp", "preprocessed", "MAData", ...
    values.trialName, values.trialName + "_" + suffix + ".sto");
end

function indices = columnIndices(names, wanted)
[~, indices] = ismember(wanted, names);
end

function members = groupMembers(forceSet, groupName)
group = forceSet.getGroup(char(groupName));
objects = group.getMembers();
members = strings(1, objects.getSize());
for i = 1 : objects.getSize()
    members(i) = string(objects.get(i - 1).getName());
end
members = sort(members);
end
