% Checks that the NCP test fixtures in tests/data/ncp still match the
% values recorded in tests/helpers/ncpFixtureValues.m. If a fixture file is
% edited or corrupted, this fails first, instead of the parsing and
% regression tests failing for reasons that look like code bugs.
%
% Data files are read with readStoFile and readstruct, not nmsm-core, so
% these checks do not depend on the code under test.

classdef (TestTags = {'Unit'}) NcpFixtureTest < matlab.unittest.TestCase

    properties
        expected
    end

    properties (TestParameter)
        muscleAnalysisFile = {"Length", "Velocity", ...
            "MomentArm_hip_flexion_r", "MomentArm_knee_angle_r", ...
            "MomentArm_ankle_angle_r"}
    end

    methods (TestClassSetup)
        function loadExpectedValues(testCase)
            testCase.expected = ncpFixtureValues();
        end
    end

    methods (Test)
        function synergyGroupIsEveryMuscle(testCase)
            model = Model(testDataPath("mtp", testCase.expected.modelFileName));
            members = model.getForceSet().getGroup( ...
                char(testCase.expected.synergyGroupName)).getMembers();
            names = strings(1, members.getSize());
            for i = 1 : members.getSize()
                names(i) = string(members.get(i - 1).getName());
            end
            testCase.verifyEqual(names, testCase.expected.muscleNames);
        end

        function gaitFilesShareOneTimeGrid(testCase)
            id = readStoFile(dataFile("IDData", testCase.expected.trialName + ...
                ".sto"));
            ik = readStoFile(dataFile("IKData", testCase.expected.trialName + ...
                ".sto"));
            testCase.verifySize(id, [testCase.expected.numFrames, 42]);
            testCase.verifyEqual(id(:, 1), ik(:, 1), "AbsTol", 1e-12);
            testCase.verifyEqual(id([1, end], 1)', ...
                testCase.expected.timeRange, "AbsTol", 1e-9);
        end

        function emgIsPaddedOnTheGaitTimeGrid(testCase)
            emg = readStoFile(dataFile("EMGData", testCase.expected.trialName + ...
                ".sto"));
            id = readStoFile(dataFile("IDData", testCase.expected.trialName + ...
                ".sto"));
            padding = testCase.expected.numEmgPaddingFrames;
            testCase.verifyEqual(emg(padding + 1 : end - padding, 1), ...
                id(:, 1), "AbsTol", 1e-9);
        end

        function muscleAnalysisMatchesGaitTimeAndMuscles(testCase, ...
                muscleAnalysisFile)
            trial = testCase.expected.trialName;
            [data, names] = readStoFile(dataFile("MAData", trial, trial + ...
                "_" + muscleAnalysisFile + ".sto"));
            testCase.verifyEqual(names(2 : end), testCase.expected.muscleNames);
            id = readStoFile(dataFile("IDData", trial + ".sto"));
            testCase.verifyEqual(data(:, 1), id(:, 1), "AbsTol", 1e-9);
        end

        function mtpActivationsCoverEveryMuscleOnGaitTime(testCase)
            [data, names] = readStoFile(testDataPath("ncp", "mtpResults", ...
                "muscleActivations", testCase.expected.trialName + ...
                "_muscleActivations.sto"));
            testCase.verifyEqual(names(2 : end), testCase.expected.muscleNames);
            testCase.verifySize(data, [testCase.expected.numFrames, 10]);
            testCase.verifyEqual(data([1, end], 1)', ...
                testCase.expected.timeRange, "AbsTol", 1e-9);
            activations = data(:, 2 : end);
            testCase.verifyEqual([min(activations, [], "all"), ...
                max(activations, [], "all")], ...
                testCase.expected.mtpActivationRange, "AbsTol", 1e-6);
        end

        function osimxHasRecordedMuscleValues(testCase)
            osimx = readstruct(testDataPath("ncp", "mtpResults", ...
                "UF_Subject_3_reduced_muscles_mtp.osimx"), "FileType", "xml");
            muscles = osimx.OsimxModel.RCNLMuscleSet.RCNLMuscle;
            names = [muscles.nameAttribute];
            testCase.verifyEqual(sort(names), sort(testCase.expected.muscleNames));
            [~, order] = ismember(testCase.expected.muscleNames, names);
            muscles = muscles(order);
            testCase.verifyEqual([muscles.optimal_fiber_length], ...
                testCase.expected.mtpOptimalFiberLength, "AbsTol", 1e-12);
            testCase.verifyEqual([muscles.tendon_slack_length], ...
                testCase.expected.mtpTendonSlackLength, "AbsTol", 1e-12);
            testCase.verifyEqual([muscles.max_isometric_force], ...
                testCase.expected.mtpMaxIsometricForce, "AbsTol", 1e-9);
        end

        function osimxNamesTheFixtureModel(testCase)
            osimx = readstruct(testDataPath("ncp", "mtpResults", ...
                "UF_Subject_3_reduced_muscles_mtp.osimx"), "FileType", "xml");
            testCase.verifyEqual(osimx.OsimxModel.associated_osim_model, ...
                testCase.expected.modelFileName);
        end
    end
end

function fileName = dataFile(varargin)
fileName = testDataPath("ncp", "preprocessed", varargin{:});
end
