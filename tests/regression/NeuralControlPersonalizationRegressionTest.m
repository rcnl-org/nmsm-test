% Full NeuralControlPersonalizationTool runs, each case run once for the
% whole class (TestClassSetup) and then checked by several tests:
%
% - allTracked: synthetic known truth with MTP activations for all nine
%   muscles. NCP must find synergies whose activations equal the truth.
%   Synergies are only unique up to scaling and recombination, so the
%   activations (weights x commands) are compared, not the weights.
% - iliacusHidden: the same without iliacus_r in the MTP activations. NCP
%   must predict iliacus_r's activation from the synergies and the
%   moments, which is NCP's main purpose.
% - fixedWeights: the true weights given in synergyWeights.sto
%   (optimize_synergy_vectors false); NCP fits only the commands.
% - sum: allTracked with sum normalization instead of magnitude.
% - mtli: iliacusHidden with Muscle-Tendon Length Initialization enabled
%   (real passive data, so no truth: the run must complete and fit).
% - tutorial: the nmsm-tutorial problem, compared with the tutorial's
%   published run.
%
% On candidate-1.5.4, iliacusHidden and mtli crash: NCP's starting values
% assume every muscle has MTP activations. A case that errors is recorded
% in TestClassSetup, and its tests fail with that error, so the other
% cases still run. See tests/README.md.
%
% Cases that run are also compared with their nominal results
% (tests/data/ncp/nominal). NCP is deterministic here (two tutorial runs
% agree exactly). If a change is intentional, regenerate the nominal
% results with tests/regression/updateNcpNominal.m and commit them.

classdef (TestTags = {'Regression'}) NeuralControlPersonalizationRegressionTest ...
        < matlab.unittest.TestCase

    properties (Constant)
        % Any real change to NCP's results moves activations by much more
        % than 1e-6 and moments by much more than 1e-4 Nm (the MTP tests
        % use the same moment tolerance). Summing in a different order
        % alone changes the ~50 Nm moments by a few 1e-6 Nm.
        nominalActivationTolerance = 1e-6
        nominalMomentTolerance = 1e-4 % Nm
        % The tutorial's published run (nmsm-tutorial Step 5,
        % CompletedSettingsFiles/NCPResultsV1): RMS of NCP's moments
        % against inverse dynamics per coordinate (Nm), and of NCP's
        % activations against MTP's.
        publishedMomentRms = [4.567, 3.375, 4.94]
        publishedActivationRms = 0.0233
    end

    properties
        expected
        truth % (frame x muscle) true synthetic activations
        folders
        errors
    end

    properties (TestParameter)
        run = struct( ...
            "allTracked", "settings_synthetic_all_tracked.xml", ...
            "iliacusHidden", "settings_synthetic_iliacus_hidden.xml", ...
            "fixedWeights", "settings_synthetic_fixed_weights.xml", ...
            "sum", "settings_synthetic_sum.xml", ...
            "mtli", "settings_synthetic_mtli.xml", ...
            "tutorial", "settings_tutorial.xml")
        % Cases that run on candidate-1.5.4 and so have nominal results
        nominalRun = {"allTracked", "fixedWeights", "sum", "tutorial"}
    end

    methods (TestClassSetup)
        function runEveryCase(testCase)
            testCase.expected = ncpFixtureValues();
            testCase.truth = trueActivations(testCase.expected.synthetic);
            startQuietParallelPool();
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            runs = testCase.run;
            for name = string(fieldnames(runs))'
                folder = fullfile(fixture.Folder, name);
                testCase.folders.(name) = folder;
                testCase.errors.(name) = runNcpCase(folder, runs.(name));
            end
        end
    end

    methods (Test)
        function allTrackedRecoversActivations(testCase)
            % A correct run is within 3e-8 of the truth everywhere.
            testCase.assertCaseRan("allTracked");
            testCase.verifyEqual(testCase.ncpActivations("allTracked"), ...
                testCase.truth, "AbsTol", 1e-5, ...
                "NCP's synergies do not reproduce the true activations.");
            testCase.verifyLessThan(testCase.momentRms("allTracked"), 0.01);
        end

        function iliacusHiddenPredictsIliacus(testCase)
            % Expected to fail on candidate-1.5.4 (NCP crashes). The
            % tolerance is provisional: set it from a correct run once
            % the crash is fixed. 0.01 is about 3% of iliacus_r's peak
            % activation.
            testCase.assertCaseRan("iliacusHidden");
            iliacus = testCase.expected.muscleNames == "iliacus_r";
            activations = testCase.ncpActivations("iliacusHidden");
            testCase.verifyEqual(activations(:, iliacus), ...
                testCase.truth(:, iliacus), "AbsTol", 0.01, ...
                "NCP did not predict iliacus_r's true activation.");
            testCase.verifyEqual(activations(:, ~iliacus), ...
                testCase.truth(:, ~iliacus), "AbsTol", 0.01);
        end

        function fixedWeightsKeepWeightsAndRecoverCommands(testCase)
            % The weights are not optimized (or renormalized), and the
            % commands fitted to them reproduce the truth: a correct run
            % is within 1e-15.
            testCase.assertCaseRan("fixedWeights");
            testCase.verifyEqual(testCase.weights("fixedWeights"), ...
                testCase.expected.synthetic.weights, "AbsTol", 1e-12);
            testCase.verifyEqual(testCase.ncpActivations("fixedWeights"), ...
                testCase.truth, "AbsTol", 1e-10);
        end

        function sumNormalizationRecoversActivations(testCase)
            % A correct run is within 5e-8 of the truth everywhere.
            testCase.assertCaseRan("sum");
            testCase.verifyEqual(testCase.ncpActivations("sum"), ...
                testCase.truth, "AbsTol", 1e-5);
        end

        function mtliRunCompletesAndFits(testCase)
            % Expected to fail on candidate-1.5.4 (NCP crashes, as for
            % iliacusHidden). 1 Nm is provisional: set it from a correct
            % run once the crash is fixed.
            testCase.assertCaseRan("mtli");
            testCase.verifyLessThan(testCase.momentRms("mtli"), 1);
        end

        function tutorialFitsAsWellAsPublishedRun(testCase)
            % Within 10% of the tutorial's published run, on both what
            % NCP tracks: the moments and MTP's activations.
            testCase.assertCaseRan("tutorial");
            testCase.verifyLessThan(testCase.momentRms("tutorial"), ...
                1.1 * testCase.publishedMomentRms);
            mtp = readStoFile(testDataPath("ncp", "mtpResults", ...
                "muscleActivations", "gait_1_muscleActivations.sto"));
            testCase.verifyLessThan(rms(testCase.ncpActivations( ...
                "tutorial") - mtp(:, 2 : end), "all"), ...
                1.1 * testCase.publishedActivationRms);
        end

        function optimizedWeightsAreNormalizedToMaximumOne(testCase)
            % After optimizing, each synergy is scaled so its largest
            % weight is 1 (the commands take the inverse scale).
            testCase.assertCaseRan("tutorial");
            weights = testCase.weights("tutorial");
            testCase.verifyEqual(max(weights, [], 2), ones(3, 1), ...
                "AbsTol", 1e-12);
            % Weights are bounded below by 0; an optimizer may end a
            % rounding error below a bound.
            testCase.verifyGreaterThanOrEqual(weights, -1e-9);
        end

        function combinedActivationsUseMtpWhereAvailable(testCase)
            % The saved activations are MTP's for every muscle that has
            % them (here all nine), not NCP's synergy approximation.
            testCase.assertCaseRan("tutorial");
            combined = readStoFile(testCase.resultFile("tutorial", ...
                "gait_1_combinedActivations.sto"));
            mtp = readStoFile(testDataPath("ncp", "mtpResults", ...
                "muscleActivations", "gait_1_muscleActivations.sto"));
            testCase.verifyEqual(combined(:, 2 : end), mtp(:, 2 : end), ...
                "AbsTol", 1e-9);
        end

        function matchesNominalResult(testCase, nominalRun)
            testCase.assertCaseRan(nominalRun);
            nominal = @(file) readStoFile(testDataPath("ncp", "nominal", ...
                nominalRun + "_" + file));
            weights = nominal("synergyWeights.sto");
            commands = nominal("gait_1_synergyCommands.sto");
            testCase.verifyEqual(testCase.ncpActivations(nominalRun), ...
                commands(:, 2 : end) * weights(:, 2 : end), "AbsTol", ...
                testCase.nominalActivationTolerance, ...
                "Activations differ from " + ...
                "tests/data/ncp/nominal. If this change is intended, " + ...
                "run updateNcpNominal.");
            moments = readStoFile(testCase.resultFile(nominalRun, ...
                fullfile("modelMoments", "gait_1_modeledMomentsNcp.sto")));
            testCase.verifyEqual(moments, nominal( ...
                "gait_1_modeledMomentsNcp.sto"), "AbsTol", ...
                testCase.nominalMomentTolerance, "Moments differ from " + ...
                "tests/data/ncp/nominal. If this change is intended, " + ...
                "run updateNcpNominal.");
        end

        function writesExpectedResultFiles(testCase, run)
            [~, settingsName, extension] = fileparts(run);
            name = runName(testCase, run);
            testCase.assertCaseRan(name);
            for file = ["synergyWeights.sto", "gait_1_synergyCommands.sto", ...
                    "gait_1_combinedActivations.sto", ...
                    "commandWindowOutput.txt", settingsName + extension, ...
                    fullfile("modelMoments", "gait_1_modeledMomentsNcp.sto"), ...
                    fullfile("modelMoments", ...
                    "gait_1_modeledMomentsMtpNcpCombined.sto")]
                testCase.verifyTrue(isfile(testCase.resultFile(name, file)), ...
                    file);
            end
            testCase.verifyNotEmpty(dir(testCase.resultFile(name, "*.osimx")));
        end

        function acceptsCharacterSettingsFileName(testCase)
            % NeuralControlPersonalizationTool('file.xml') with single
            % quotes should work like "file.xml". Fixed 2026-10-28;
            % before, the copied settings file name was built with
            % fname + fext, which adds character codes for char input.
            % See docs/failures.md.
            folder = tempname;
            copyNcpFixtures(folder, "settings_synthetic_all_tracked.xml");
            cleanUp = onCleanup(@() rmdir(folder, "s"));
            message = runNcpTool(folder, ...
                'settings_synthetic_all_tracked.xml');
            testCase.verifyEqual(message, "", ...
                "NeuralControlPersonalizationTool failed with a char file name.");
        end
    end

    methods
        function assertCaseRan(testCase, name)
            testCase.assertEqual(testCase.errors.(name), "", "The " + ...
                name + " run failed: " + testCase.errors.(name));
        end

        function fileName = resultFile(testCase, name, file)
            fileName = fullfile(testCase.folders.(name), "NCPResults", file);
            if name == "tutorial"
                fileName = fullfile(testCase.folders.(name), ...
                    "NCPResultsV1", file);
            end
        end

        function weights = weights(testCase, name)
            % (synergy x muscle), muscle order
            [data, names] = readStoFile(testCase.resultFile(name, ...
                "synergyWeights.sto"));
            [~, columns] = ismember(testCase.expected.muscleNames, names);
            weights = data(:, columns);
        end

        function activations = ncpActivations(testCase, name)
            % NCP's own (frame x muscle) activations: commands x weights
            commands = readStoFile(testCase.resultFile(name, ...
                "gait_1_synergyCommands.sto"));
            activations = commands(:, 2 : end) * testCase.weights(name);
        end

        function value = momentRms(testCase, name)
            % RMS of NCP's moments minus the inverse dynamics moments it
            % tracked, per coordinate
            [model, names] = readStoFile(testCase.resultFile(name, ...
                fullfile("modelMoments", "gait_1_modeledMomentsNcp.sto")));
            settings = xml2struct(fullfile(testCase.folders.(name), ...
                testCase.run.(name)));
            dataDirectory = getFieldByName(settings, "data_directory").Text;
            [id, idNames] = readStoFile(fullfile(testCase.folders.(name), ...
                dataDirectory, "IDData", "gait_1.sto"));
            [~, columns] = ismember(names(2 : end), idNames);
            value = rms(model(:, 2 : end) - id(:, columns));
        end
    end
end

function message = runNcpCase(folder, settingsFile)
% Runs NeuralControlPersonalizationTool on one case in its own folder and
% returns the error message, or "" if it ran.
copyNcpFixtures(folder, settingsFile);
message = runNcpTool(folder, settingsFile);
end

function message = runNcpTool(folder, settingsFile)
% Runs NeuralControlPersonalizationTool(settingsFile) in a folder that
% already has the fixtures, passing settingsFile exactly as given (string
% or char), and returns the error message, or "" if it ran.
originalFolder = cd(folder);
restoreFolder = onCleanup(@() cd(originalFolder));
message = "";
try
    evalc("NeuralControlPersonalizationTool(settingsFile)");
catch exception
    % NeuralControlPersonalizationTool leaves its diary on when it fails,
    % which keeps the log open and stops the folder from being deleted.
    diary off
    message = string(exception.message);
end
end

function name = runName(testCase, run)
% The run's field name in the TestParameter struct (e.g. "tutorial")
names = string(fieldnames(testCase.run))';
name = names(arrayfun(@(n) testCase.run.(n) == run, names));
end

function activations = trueActivations(synthetic)
percent = linspace(0, 100, 101)';
B = BSplineMatrices(3, synthetic.numNodes, 101, percent(2) - percent(1));
activations = B * synthetic.commandNodes * synthetic.weights;
end

