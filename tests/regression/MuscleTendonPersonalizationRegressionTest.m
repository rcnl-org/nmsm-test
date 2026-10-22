% Full MuscleTendonPersonalizationTool runs on three cases, each run once
% for the whole class (TestClassSetup) and then checked by several tests:
%
% - emgScale: synthetic known truth, only EMG scale factors optimized.
%   MTP must find the true scale factors again.
% - all: synthetic known truth, all six parameter types optimized. MTP
%   fits the moments almost exactly (about 0.1 Nm RMS, from 5 to 18 Nm at
%   the start) but does not find the true parameters: with moment tracking
%   alone on one trial, the parameters trade off against each other (fiber
%   length scale factors end up to 0.15 from the truth, EMG scale factors
%   up to 0.1). A tighter step tolerance stops at the same point, so this
%   is a local minimum, not an early stop. The test checks the fit, not the
%   parameters.
% - twoTrials: the same truth on two gait trials (tests/data/mtp/rebuilt).
%   A second trial pins down most of what one trial cannot: the largest
%   misses shrink 6 to 14 times for the activation parameters and 2 to 4
%   times for the length scale factors. The test checks the parameters,
%   with tolerances below the one-trial misses.
% - passive: synthetic known truth for Muscle-Tendon Length
%   Initialization. MTLI must find the true optimal fiber and tendon slack
%   length scale factors from passive moments alone. MTP runs afterwards
%   without optimizing lengths, so the lengths it reports are MTLI's.
% - tutorial: the nmsm-tutorial problem with MTLI and synergy
%   extrapolation. There is no truth; the fit must be as good as the
%   tutorial's own run.
%
% Every case is also compared with its stored nominal result
% (tests/data/mtp/nominal), so any change in MTP's results shows up even
% when they are still correct. MTP is deterministic here (two runs agree
% exactly), so the nominal tolerances are tight. If a change is
% intentional, regenerate the nominal results with
% tests/regression/updateMtpNominal.m and commit them.
%
% Written for candidate-1.5.4 (and main at v1.5.4, which has the same MTP).

classdef (TestTags = {'Regression'}) MuscleTendonPersonalizationRegressionTest ...
        < matlab.unittest.TestCase

    properties (Constant)
        % muscleModelParameters.sto rows: activation time constant (s),
        % activation nonlinearity, electromechanical delay (s), EMG scale
        % factor, optimal fiber length and tendon slack length scale
        % factors (relative to the input model). MTP's bounds on
        % candidate-1.5.4, in those units.
        lowerBounds = [0.0075; 0; 0; 0.05; 0.6; 0.6]
        upperBounds = [0.035; 0.35; 0.125; 1; 1.4; 1.4]
        nominalParameterTolerance = 1e-6
        nominalMomentTolerance = 1e-4 % Nm
    end

    properties
        expected
        folders
    end

    properties (TestParameter)
        run = struct( ...
            "emgScale", struct("settings", "settings_synthetic_emg_scale.xml", ...
                "results", "MTPResults", ...
                "osimx", "UF_Subject_3_reduced_muscles_synthetic_mtp.osimx"), ...
            "all", struct("settings", "settings_synthetic_all.xml", ...
                "results", "MTPResults", ...
                "osimx", "UF_Subject_3_reduced_muscles_synthetic_mtp.osimx"), ...
            "twoTrials", struct("settings", ...
                "settings_synthetic_two_trials.xml", "results", ...
                "MTPResults", ...
                "osimx", "UF_Subject_3_reduced_muscles_synthetic_mtp.osimx"), ...
            "passive", struct("settings", "settings_synthetic_passive.xml", ...
                "results", "MTPResults", ...
                "osimx", "UF_Subject_3_reduced_muscles_mtp.osimx"), ...
            "tutorial", struct("settings", "settings_tutorial.xml", ...
                "results", "MTPResultsV1", ...
                "osimx", "UF_Subject_3_reduced_muscles_mtp.osimx"))
    end

    methods (TestClassSetup)
        function runEveryCase(testCase)
            testCase.expected = mtpFixtureValues();
            startQuietParallelPool();
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            runs = testCase.run;
            for name = string(fieldnames(runs))'
                folder = fullfile(fixture.Folder, name);
                testCase.folders.(name) = folder;
                runMtpCase(folder, runs.(name).settings);
            end
        end
    end

    methods (Test)
        function emgScaleRecoversTruth(testCase)
            parameters = testCase.parameters("emgScale");
            truth = testCase.expected.synthetic.emgScale;
            hasEmg = testCase.expected.muscleNames ~= "iliacus_r";
            % 0.001 on scale factors around 0.3 to 0.65; a correct run is
            % within 1e-4.
            testCase.verifyEqual(parameters(4, hasEmg), ...
                truth.emgScaleFactors(hasEmg), "AbsTol", 1e-3, ...
                "MTP did not find the true EMG scale factors.");
            % iliacus_r has no EMG, so nothing moves its scale factor.
            testCase.verifyEqual(parameters(4, ~hasEmg), ...
                testCase.expected.initialGuess.emgScaleFactors, ...
                "AbsTol", 1e-9);
            % Parameters this case does not optimize keep their starting
            % values exactly.
            start = startingParameters(testCase.expected);
            testCase.verifyEqual(parameters([1 : 3, 5, 6], :), ...
                start([1 : 3, 5, 6], :), "AbsTol", 1e-9, ...
                "MTP changed a parameter it was not asked to optimize.");
            testCase.verifyLessThan(testCase.momentRms("emgScale", ...
                "modelJointMoments"), 0.01);
        end

        function allFitsMomentsButCannotIdentifyParameters(testCase)
            % See the class comment: the fit is checked, not the
            % parameters. 0.5 Nm is well below the 5 to 18 Nm at the
            % start; a correct run reaches about 0.1 Nm.
            testCase.verifyLessThan(testCase.momentRms("all", ...
                "modelJointMoments"), 0.5);
            parameters = testCase.parameters("all");
            testCase.verifyParametersWithinBounds(parameters, ...
                testCase.lowerBounds, testCase.upperBounds);
            % iliacus_r has no EMG, so the cost does not depend on its
            % activation parameters. They stay at their starting values,
            % apart from tiny moves (about 2e-7) from fmincon's
            % quasi-Newton Hessian coupling them to other parameters.
            iliacus = testCase.expected.muscleNames == "iliacus_r";
            start = startingParameters(testCase.expected);
            testCase.verifyEqual(parameters(1 : 4, iliacus), ...
                start(1 : 4, iliacus), "AbsTol", 1e-6);
        end

        function twoTrialsIdentifiesParameters(testCase)
            % Tolerances per row of muscleModelParameters.sto. A correct
            % run is within about a third of each (activation time
            % constant 0.0006 s, nonlinearity 0.006, delay 0.001 s, EMG
            % scale 0.016, lengths 0.04 and 0.06), and each is below what
            % the one-trial case misses by (0.0036 s, 0.077, 0.0125 s,
            % 0.10, 0.15, 0.13), so passing needs the second trial.
            tolerance = [0.002; 0.02; 0.003; 0.03; 0.08; 0.1];
            parameters = testCase.parameters("twoTrials");
            truth = toParameterRows(testCase.expected.synthetic.twoTrials);
            hasEmg = testCase.expected.muscleNames ~= "iliacus_r";
            for row = 1 : 6
                % iliacus_r's activation parameters cannot be identified
                % (no EMG), but its lengths can, through passive force.
                muscles = hasEmg | row >= 5;
                testCase.verifyEqual(parameters(row, muscles), ...
                    truth(row, muscles), "AbsTol", tolerance(row), ...
                    "Row " + row + " of muscleModelParameters.sto is " + ...
                    "not within " + tolerance(row) + " of the truth.");
            end
            testCase.verifyLessThan(testCase.momentRms("twoTrials", ...
                "modelJointMoments"), 0.5);
        end

        function passiveRecoversTrueLengths(testCase)
            % MTLI on noise-free passive moments finds the lengths to
            % within 2.3e-4; 1e-3 is 0.1% of a scale factor.
            truth = testCase.expected.synthetic.passive;
            parameters = testCase.parameters("passive");
            testCase.verifyEqual(parameters(5, :), ...
                truth.optimalFiberLengthScaleFactors, "AbsTol", 1e-3, ...
                "MTLI did not find the true optimal fiber lengths.");
            testCase.verifyEqual(parameters(6, :), ...
                truth.tendonSlackLengthScaleFactors, "AbsTol", 1e-3, ...
                "MTLI did not find the true tendon slack lengths.");
            % From 18 Nm RMS at the start; a correct run reaches 3e-5.
            testCase.verifyLessThan(testCase.passiveMomentRms("passive"), ...
                0.01);
        end

        function tutorialFitsAsWellAsPublishedRun(testCase)
            % The tutorial's own run reached 5.78, 6.52 and 7.45 Nm RMS
            % (synergy model moments); allow 10% more.
            testCase.verifyLessThan(testCase.momentRms("tutorial", ...
                "modelJointMomentsSynx"), ...
                1.1 * testCase.expected.tutorialMomentRms);
            % Length scale factors are relative to the input model and
            % combine MTLI's bounds (0.5 to 2) with MTP's (0.6 to 1.4).
            lower = testCase.lowerBounds;
            upper = testCase.upperBounds;
            lower(5 : 6) = 0.5 * 0.6;
            upper(5 : 6) = 2 * 1.4;
            testCase.verifyParametersWithinBounds( ...
                testCase.parameters("tutorial"), lower, upper);
        end

        function matchesNominalResult(testCase, run)
            name = runName(testCase, run);
            actual = testCase.parameters(name);
            nominal = readStoFile(testDataPath("mtp", "nominal", name + ...
                "_muscleModelParameters.sto"));
            testCase.verifyEqual(actual, nominal(:, 2 : end), "AbsTol", ...
                testCase.nominalParameterTolerance, ...
                "Parameters differ from tests/data/mtp/nominal. If this " + ...
                "change is intended, run updateMtpNominal.");
            for fileName = testCase.analysisFiles(name, "modelJointMoments")
                [~, trialFile, extension] = fileparts(fileName);
                nominalMoments = readStoFile(testDataPath("mtp", ...
                    "nominal", name + "_" + trialFile + extension));
                testCase.verifyEqual(readStoFile(fileName), ...
                    nominalMoments, "AbsTol", ...
                    testCase.nominalMomentTolerance, trialFile + ...
                    " differs from tests/data/mtp/nominal. If this " + ...
                    "change is intended, run updateMtpNominal.");
            end
        end

        function writesExpectedResultFiles(testCase, run)
            % The osimx file downstream tools read, the copied settings
            % file and log, and the analysis files. (The log is empty here
            % because evalc stops diary from capturing output.)
            results = fullfile(testCase.folders.(runName(testCase, run)), ...
                run.results);
            for file = [run.osimx, run.settings, "commandWindowOutput.txt"]
                testCase.verifyTrue(isfile(fullfile(results, file)), file);
            end
            for analysis = ["muscleModelParameters", "modelJointMoments", ...
                    "inverseDynamicsJointMoments", "muscleActivations", ...
                    "normalizedFiberLengths", "totalMuscleForces"]
                testCase.verifyNotEmpty(dir(fullfile(results, "Analysis", ...
                    analysis, "*.sto")), analysis);
            end
        end
    end

    methods
        function parameters = parameters(testCase, name)
            % (6 x muscle) from muscleModelParameters.sto, muscle order
            [data, names] = readStoFile(testCase.analysisFiles(name, ...
                "muscleModelParameters"));
            [~, columns] = ismember(testCase.expected.muscleNames, names);
            parameters = data(:, columns);
        end

        function value = momentRms(testCase, name, analysis)
            % RMS of model minus inverse dynamics moments per coordinate,
            % over every trial
            error = [];
            for trial = testCase.trialNames(name)
                model = readStoFile(testCase.analysisFile(name, analysis, ...
                    trial));
                inverseDynamics = readStoFile(testCase.analysisFile(name, ...
                    "inverseDynamicsJointMoments", trial));
                error = [error; model(:, 2 : end) - ...
                    inverseDynamics(:, 2 : end)]; %#ok<AGROW>
            end
            value = rms(error);
        end

        function value = passiveMomentRms(testCase, name)
            % RMS of modeled minus experimental passive moments over every
            % passive trial and coordinate
            error = [];
            for trial = testCase.expected.passiveTrialNames
                modeled = readStoFile(testCase.analysisFile(name, ...
                    "passiveJointMomentsModeled", trial));
                experimental = readStoFile(testCase.analysisFile(name, ...
                    "passiveJointMomentsExperimental", trial));
                error = [error; modeled(:, 2 : end) - ...
                    experimental(:, 2 : end)]; %#ok<AGROW>
            end
            value = rms(error, "all");
        end

        function names = trialNames(testCase, name)
            files = testCase.analysisFiles(name, "inverseDynamicsJointMoments");
            [~, names] = fileparts(files);
            names = extractBefore(names, "_inverseDynamicsJointMoments");
        end

        function fileNames = analysisFiles(testCase, name, analysis)
            folder = fullfile(testCase.folders.(name), ...
                testCase.run.(name).results, "Analysis", analysis);
            files = dir(fullfile(folder, "*.sto"));
            fileNames = string(fullfile(folder, {files.name}));
        end

        function fileName = analysisFile(testCase, name, analysis, trial)
            fileName = fullfile(testCase.folders.(name), ...
                testCase.run.(name).results, "Analysis", analysis, ...
                trial + "_" + analysis + ".sto");
        end

        function verifyParametersWithinBounds(testCase, parameters, ...
                lower, upper)
            tolerance = 1e-9;
            testCase.verifyGreaterThanOrEqual(parameters, ...
                repmat(lower, 1, size(parameters, 2)) - tolerance, ...
                "A parameter is below MTP's lower bound.");
            testCase.verifyLessThanOrEqual(parameters, ...
                repmat(upper, 1, size(parameters, 2)) + tolerance, ...
                "A parameter is above MTP's upper bound.");
        end
    end
end

function runMtpCase(folder, settingsFile)
% Runs MuscleTendonPersonalizationTool on one case in its own folder.
copyMtpFixtures(folder, settingsFile);
originalFolder = cd(folder);
restoreFolder = onCleanup(@() cd(originalFolder));
evalc("MuscleTendonPersonalizationTool(settingsFile)");
end

function name = runName(testCase, run)
% The run's field name in the TestParameter struct (e.g. "tutorial")
names = string(fieldnames(testCase.run))';
name = names(arrayfun(@(n) isequal(testCase.run.(n), run), names));
end

function parameters = startingParameters(expected)
% MTP's starting values in muscleModelParameters.sto units
parameters = toParameterRows(structfun(@(x) repmat(x, 1, 9), ...
    expected.initialGuess, "UniformOutput", false));
end

function rows = toParameterRows(values)
% MTP parameter values (as in mtpFixtureValues) in the rows and units of
% muscleModelParameters.sto: time constants and delays are stored x100 and
% x10.
rows = [values.activationTimeConstants / 100; ...
    values.activationNonlinearityConstants; ...
    values.electromechanicalDelays / 10; values.emgScaleFactors; ...
    values.optimalFiberLengthScaleFactors; ...
    values.tendonSlackLengthScaleFactors];
end
