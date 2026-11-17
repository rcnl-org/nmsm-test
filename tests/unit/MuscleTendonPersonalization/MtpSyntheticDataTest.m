% Checks the synthetic known-truth MTP data in tests/data/mtp/synthetic,
% written by generateMtpSyntheticData from the true values in
% mtpFixtureValues().synthetic, and the rebuilt two-trial data it uses
% (tests/data/mtp/rebuilt). If these fail, the regression tests that try
% to recover the truth cannot be trusted.
%
% - The synthetic model differs from the fixture model only in optimal
%   fiber and tendon slack lengths, and keeps every normalized fiber
%   length inside MTP's limits at the starting values.
% - Each case's data differs from the data it was made from only in the
%   inverse dynamics moments the case replaces.
% - The forward model (MTP's, or MTLI's for the passive case) at the true
%   values reproduces those moments, and at the starting values it does
%   not (so there is something to find).

classdef (TestTags = {'Unit'}) MtpSyntheticDataTest < matlab.unittest.TestCase

    properties
        expected
        model
    end

    properties (TestParameter)
        % folder: the case's data; source: the data it was made from;
        % columns: which ID columns it replaces ("tracked" moments for MTP
        % cases, every coordinate for the passive case).
        syntheticCase = struct( ...
            "emgScale", struct("field", "emgScale", "folder", "emg_scale", ...
                "source", "preprocessed", "columns", "tracked"), ...
            "all", struct("field", "all", "folder", "all", ...
                "source", "preprocessed", "columns", "tracked"), ...
            "twoTrials", struct("field", "twoTrials", "folder", ...
                "two_trials", "source", "rebuilt/preprocessed", ...
                "columns", "tracked"), ...
            "passive", struct("field", "passive", "folder", "passive", ...
                "source", "passive_moment_data", "columns", "all"))
        mtpCase = struct("emgScale", "emg_scale", "all", "all", ...
            "twoTrials", "two_trials")
    end

    methods (TestClassSetup)
        function loadFixtures(testCase)
            files = dir(testDataPath("mtp", "settings", ...
                "settings_synthetic_*.xml"));
            setUpMtpWorkingFolder(testCase, string({files.name}));
            testCase.expected = mtpFixtureValues();
            testCase.model = Model(fullfile("synthetic", ...
                testCase.expected.synthetic.modelFileName));
        end
    end

    methods (Test)
        function syntheticModelOnlyChangesMuscleLengths(testCase)
            names = testCase.expected.muscleNames;
            for i = 1 : length(names)
                muscle = testCase.model.getMuscles().get(char(names(i)));
                testCase.verifyEqual(muscle.getMaxIsometricForce(), ...
                    testCase.expected.maxIsometricForce(i), "AbsTol", ...
                    1e-9, names(i));
                testCase.verifyEqual( ...
                    muscle.getPennationAngleAtOptimalFiberLength(), ...
                    testCase.expected.pennationAngle(i), "AbsTol", ...
                    1e-12, names(i));
            end
        end

        function syntheticModelFiberLengthsAreWithinLimits(testCase)
            % Worked out from the muscle-tendon lengths file and the
            % model's lengths, not with nmsm-core: at the starting values
            % every normalized fiber length is in [0.45, 1.15], well inside
            % MTP's [0.3, 1.3].
            [data, columnNames] = readStoFile(testDataPath("mtp", ...
                "preprocessed", "MAData", testCase.expected.trialName, ...
                testCase.expected.trialName + "_Length.sto"));
            names = testCase.expected.muscleNames;
            for i = 1 : length(names)
                muscle = testCase.model.getMuscles().get(char(names(i)));
                fiberLength = (data(:, columnNames == names(i)) - ...
                    muscle.getTendonSlackLength()) / ...
                    (muscle.getOptimalFiberLength() * ...
                    cos(testCase.expected.pennationAngle(i)));
                testCase.verifyGreaterThan(min(fiberLength), 0.45 - 1e-9, ...
                    names(i));
                testCase.verifyLessThan(max(fiberLength), 1.15 + 1e-9, ...
                    names(i));
            end
        end

        function rebuiltTrialsAreConsecutiveGaitCycles(testCase)
            % gait_1 (0.5 to 1.6 s) and gait_2 (1.6 to 2.7 s), each with
            % 101 frames and EMG padded by 19 frames on the same grid.
            folder = testDataPath("mtp", "rebuilt", "preprocessed");
            ranges = [0.5, 1.6; 1.6, 2.7];
            for i = 1 : 2
                trial = "gait_" + i;
                id = readStoFile(fullfile(folder, "IDData", trial + ".sto"));
                emg = readStoFile(fullfile(folder, "EMGData", trial + ".sto"));
                testCase.verifySize(id, [101, 42], trial);
                testCase.verifyEqual(id([1, end], 1)', ranges(i, :), ...
                    "AbsTol", 1e-9, trial);
                testCase.verifyEqual(emg(20 : end - 19, 1), id(:, 1), ...
                    "AbsTol", 1e-9, trial);
            end
        end

        function onlyReplacedMomentsDifferFromSource(testCase, ...
                syntheticCase)
            source = testDataPath("mtp", syntheticCase.source);
            synthetic = testDataPath("mtp", "synthetic", ...
                syntheticCase.folder);
            files = dir(fullfile(source, "**", "*.sto"));
            for file = files'
                relative = erase(fullfile(file.folder, file.name), ...
                    string(source) + filesep);
                if ~startsWith(relative, "IDData")
                    testCase.verifyEqual(fileread(fullfile(synthetic, ...
                        relative)), fileread(fullfile(source, relative)), ...
                        relative);
                    continue
                end
                [sourceData, names] = readStoFile(fullfile(source, relative));
                syntheticData = readStoFile(fullfile(synthetic, relative));
                if syntheticCase.columns == "tracked"
                    replaced = ismember(names, ...
                        testCase.expected.coordinateNames + "_moment");
                else
                    replaced = names ~= "time";
                end
                testCase.verifyEqual(syntheticData(:, ~replaced), ...
                    sourceData(:, ~replaced), "AbsTol", 1e-12, relative);
                testCase.verifyNotEqual(syntheticData(:, replaced), ...
                    sourceData(:, replaced), relative);
            end
        end

        function truthReproducesItsMoments(testCase, mtpCase)
            inputs = parseMtp(mtpCase);
            truth = testCase.expected.synthetic.(fieldFor(mtpCase));
            modeled = calcMtpModeledValues(truth, inputs, struct());
            testCase.verifyEqual(modeled.muscleJointMoments, ...
                inputs.inverseDynamicsMoments, "AbsTol", 1e-9);
        end

        function startingValuesDoNotReproduceMoments(testCase, mtpCase)
            % MTP starts here; the moment error must be large enough that
            % recovering the truth means something.
            inputs = parseMtp(mtpCase);
            initial = structfun(@(x) repmat(x, 1, 9), ...
                testCase.expected.initialGuess, "UniformOutput", false);
            modeled = calcMtpModeledValues(initial, inputs, struct());
            error = modeled.muscleJointMoments - inputs.inverseDynamicsMoments;
            testCase.verifyGreaterThan(rms(error, "all"), 1);
        end

        function passiveTruthReproducesItsMoments(testCase)
            inputs = parsePassive();
            modeled = calcMuscleTendonLengthInitializationModeledValues( ...
                testCase.expected.synthetic.passive, inputs);
            testCase.verifyEqual(modeled.passiveModelMoments, ...
                inputs.passiveData.inverseDynamicsMoments, "AbsTol", 1e-9);
        end

        function passiveStartingValuesDoNotReproduceMoments(testCase)
            inputs = parsePassive();
            start = struct("optimalFiberLengthScaleFactors", ones(1, 9), ...
                "tendonSlackLengthScaleFactors", ones(1, 9), ...
                "maximumMuscleStressScaleFactor", 1);
            modeled = calcMuscleTendonLengthInitializationModeledValues( ...
                start, inputs);
            testCase.verifyGreaterThan(rms(modeled.passiveModelMoments - ...
                inputs.passiveData.inverseDynamicsMoments, "all"), 1);
        end
    end
end

function inputs = parseMtp(caseFolder)
inputs = parseMuscleTendonPersonalizationSettingsTree(xml2struct( ...
    "settings_synthetic_" + caseFolder + ".xml"));
end

function inputs = parsePassive()
inputs = parseMuscleTendonLengthInitializationSettingsTree(xml2struct( ...
    "settings_synthetic_passive.xml"));
end

function fieldName = fieldFor(caseFolder)
switch caseFolder
    case "emg_scale"
        fieldName = "emgScale";
    case "all"
        fieldName = "all";
    case "two_trials"
        fieldName = "twoTrials";
end
end
