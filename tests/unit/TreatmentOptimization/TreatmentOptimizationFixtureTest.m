% Checks that the Treatment Optimization test fixtures in tests/data/to
% still match the values recorded in tests/helpers/toFixtureValues.m. If a
% fixture file is edited or corrupted, this fails first, instead of the
% parsing and regression tests failing for reasons that look like code
% bugs.

classdef (TestTags = {'Unit'}) TreatmentOptimizationFixtureTest < ...
        matlab.unittest.TestCase

    properties
        expected
    end

    properties (TestParameter)
        % Published results each problem starts a later tool from
        published = struct( ...
            "torqueTracking", struct("problem", "torque", "folder", ...
                "TorqueTOResultsV1", "controls", "torqueControls"), ...
            "torqueVerification", struct("problem", "torque", "folder", ...
                "TorqueVOResultsV2", "controls", "torqueControls"), ...
            "synergyTracking", struct("problem", "synergy", "folder", ...
                "SynergyTOResultsV1", "controls", "synergyCommands"), ...
            "synergyVerification", struct("problem", "synergy", ...
                "folder", "SynergyVOResultsV2", "controls", ...
                "synergyCommands"))
        problem = {'torque', 'synergy'}
    end

    methods (TestClassSetup)
        function loadValues(testCase)
            testCase.expected = toFixtureValues();
        end
    end

    methods (Test)
        % ---- shared data ------------------------------------------------

        function motionCoversTheKick(testCase)
            [ik, names] = testCase.readData("IKData");
            testCase.verifySize(ik, [testCase.expected.numFrames, ...
                testCase.expected.numIkCoordinates + 1]);
            testCase.verifyEqual(ik([1 end], 1)', ...
                testCase.expected.timeRange, "AbsTol", 1e-9);
            testCase.verifyEqual(diff(ik(:, 1)), 0.005 * ones(62, 1), ...
                "AbsTol", 1e-9);
            testCase.verifyTrue(all(ismember( ...
                testCase.expected.statesCoordinates, names)));
        end

        function inverseDynamicsMatchesMotion(testCase)
            [id, names] = testCase.readData("IDData");
            ik = testCase.readData("IKData");
            testCase.verifySize(id, [testCase.expected.numFrames, ...
                testCase.expected.numIdLoads + 1]);
            testCase.verifyEqual(id(:, 1), ik(:, 1), "AbsTol", 1e-9);
            testCase.verifyTrue(all(ismember(testCase.expected.loads, ...
                names)));
        end

        function userFunctionsArePresent(testCase)
            % The tutorial's user-defined Design Optimization terms
            for name = ["footSpeedCost.m", "footSpeedConstraint.m"]
                testCase.verifyTrue(isfile(testDataPath("to", ...
                    "userFunctions", name)), name);
            end
        end

        % ---- models -----------------------------------------------------

        function torqueModelHasItsMuscles(testCase)
            model = Model(testDataPath("to", "torque", ...
                testCase.expected.modelFileName));
            testCase.verifyEqual(model.getMuscles().getSize(), ...
                testCase.expected.torque.numModelMuscles);
        end

        function synergyModelHasTheNineMuscles(testCase)
            model = Model(testDataPath("to", "synergy", ...
                testCase.expected.modelFileName));
            muscles = model.getMuscles();
            names = strings(1, muscles.getSize());
            for i = 1 : muscles.getSize()
                names(i) = string(muscles.get(i - 1).getName());
            end
            testCase.verifyEqual(names, ...
                testCase.expected.synergy.muscleNames);
        end

        function modelsHaveTheStatesCoordinates(testCase, problem)
            model = Model(testDataPath("to", problem, ...
                testCase.expected.modelFileName));
            for name = testCase.expected.statesCoordinates
                testCase.verifyTrue(model.getCoordinateSet().contains( ...
                    char(name)), name);
            end
        end

        % ---- synergy problem --------------------------------------------

        function osimxHasTheSynergyGroup(testCase)
            text = fileread(testDataPath("to", "synergy", "ncpResults", ...
                "KickingModel_ncp.osimx"));
            testCase.verifySubstring(text, "<muscle_group_name>" + ...
                testCase.expected.synergy.synergyGroup + ...
                "</muscle_group_name>");
            for name = testCase.expected.synergy.muscleNames
                testCase.verifySubstring(text, """" + name + """", name);
            end
        end

        function ncpSynergiesMatchTheGroup(testCase)
            synergy = testCase.expected.synergy;
            [weights, names] = readStoFile(testDataPath("to", "synergy", ...
                "ncpResults", "synergyWeights.sto"));
            testCase.verifyEqual(names(2 : end), synergy.muscleNames);
            testCase.verifySize(weights, [synergy.numSynergies, ...
                length(synergy.muscleNames) + 1]);
            [commands, names] = readStoFile(testDataPath("to", "synergy", ...
                "ncpResults", testCase.expected.trialName + ...
                "_synergyCommands.sto"));
            testCase.verifyEqual(names(2 : end), synergy.synergyGroup + ...
                "_" + (1 : synergy.numSynergies));
            testCase.verifySize(commands, [testCase.expected.numFrames, ...
                synergy.numSynergies + 1]);
        end

        function surrogateDataHasEverySample(testCase)
            % 25 Latin hypercube samples per frame, with the muscle
            % lengths and the moment arms about each surrogate
            % coordinate for the nine muscles.
            synergy = testCase.expected.synergy;
            folder = testDataPath("to", "synergy", "surrogateData");
            numSamples = testCase.expected.numFrames * ...
                synergy.surrogateSamplesPerFrame;
            [ik, names] = readStoFile(fullfile(folder, "IKData", ...
                testCase.expected.trialName + ".sto"));
            testCase.verifySize(ik, [numSamples, ...
                testCase.expected.numIkCoordinates + 1]);
            testCase.verifyTrue(all(ismember( ...
                synergy.surrogateCoordinates, names)));
            muscleAnalysis = fullfile(folder, "MAData", ...
                testCase.expected.trialName);
            suffixes = ["_Length.sto", "_MomentArm_" + ...
                synergy.surrogateCoordinates + ".sto"];
            files = dir(fullfile(muscleAnalysis, "*.sto"));
            testCase.verifyLength(files, length(suffixes));
            for suffix = suffixes
                file = dir(fullfile(muscleAnalysis, "*" + suffix));
                testCase.assertNumElements(file, 1, suffix);
                [data, names] = readStoFile(fullfile(file.folder, ...
                    file.name));
                testCase.verifyEqual(names(2 : end), synergy.muscleNames, ...
                    suffix);
                testCase.verifyEqual(size(data, 1), numSamples, suffix);
            end
        end

        function fittedSurrogateIsPresent(testCase)
            % The tutorial's fitted surrogate model, loaded from the
            % current folder when <load_surrogate_model> is true.
            testCase.verifyTrue(isfile(testDataPath("to", "synergy", ...
                "surrogateMuscles.mat")));
        end

        % ---- published results ------------------------------------------

        function publishedResultsSolveTheStatesCoordinates(testCase, ...
                published)
            folder = testDataPath("to", published.problem, "published", ...
                published.folder);
            trial = testCase.expected.trialName;
            frames = testCase.expected.(published.problem).publishedFrames;
            coordinates = testCase.expected.statesCoordinates;
            [states, names] = readStoFile(fullfile(folder, trial + ...
                "_states.sto"));
            testCase.verifyEqual(names, ["time", coordinates, ...
                coordinates + "_u"]);
            testCase.verifyEqual(size(states, 1), frames);
            testCase.verifyEqual(states([1 end], 1)', ...
                testCase.expected.timeRange, "AbsTol", 1e-9);
            controls = readStoFile(fullfile(folder, trial + "_" + ...
                published.controls + ".sto"));
            testCase.verifyEqual(size(controls, 1), frames);
            for data = ["IKData", "IDData"]
                testCase.verifyTrue(isfile(fullfile(folder, data, ...
                    trial + ".sto")), data);
            end
        end
    end

    methods
        function [data, names] = readData(testCase, folder)
            [data, names] = readStoFile(testDataPath("to", ...
                "preprocessed", folder, testCase.expected.trialName + ...
                ".sto"));
        end
    end
end
