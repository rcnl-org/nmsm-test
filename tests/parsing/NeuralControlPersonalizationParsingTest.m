% Tests that NCP settings files in tests/data/ncp/settings parse into the
% expected inputs and params structs: xml2struct -> verifyVersion ->
% parseNeuralControlPersonalizationSettingsTree, as
% NeuralControlPersonalizationTool does.
%
% Expected values come from ncpFixtureValues, the settings files, and the
% data and MTP result files read with readStoFile, so they do not depend
% on nmsm-core. Written for candidate-1.5.4.
%
% The three valid files are parsed once for the class; the bad_* and
% edge_* files are parsed in the test that uses them. Fixed synergy weight
% tests write synergyWeights.sto into the data folder themselves.

classdef (TestTags = {'Parsing'}) NeuralControlPersonalizationParsingTest < ...
        matlab.unittest.TestCase

    properties
        expected
        minimal
        full
        tutorial
    end

    methods (TestClassSetup)
        function parseValidFiles(testCase)
            files = dir(testDataPath("ncp", "settings", "*.xml"));
            setUpNcpWorkingFolder(testCase, string({files.name}));
            testCase.expected = ncpFixtureValues();
            testCase.minimal = parse("settings_minimal.xml");
            testCase.full = parse("settings_full.xml");
            testCase.tutorial = parse("settings_tutorial.xml");
        end
    end

    methods (Test)
        % ---- tutorial: muscles, data and MTP results --------------------

        function synergyGroupGivesMusclesAndOrder(testCase)
            inputs = testCase.tutorial.inputs;
            testCase.verifyLength(inputs.synergyGroups, 1);
            group = inputs.synergyGroups{1};
            testCase.verifyEqual(string(group.muscleGroupName), ...
                testCase.expected.synergyGroupName);
            testCase.verifyEqual(group.numSynergies, ...
                testCase.expected.numSynergies);
            testCase.verifyEqual(group.muscleNames, ...
                testCase.expected.muscleNames);
            testCase.verifyEqual(inputs.muscleNames, testCase.expected.muscleNames);
            testCase.verifyEqual(inputs.muscleTendonColumnNames, ...
                testCase.expected.muscleNames);
        end

        function dataMatchesFiles(testCase)
            inputs = testCase.tutorial.inputs;
            [id, names] = readStoFile(dataFile("IDData", "gait_1.sto"));
            for i = 1 : 3
                column = names == testCase.expected.coordinateNames(i) + ...
                    "_moment";
                testCase.verifyEqual(squeeze( ...
                    inputs.inverseDynamicsMoments(1, i, :)), id(:, column), ...
                    "AbsTol", 1e-12);
            end
            [lengths, names] = readStoFile(dataFile("MAData", "gait_1", ...
                "gait_1_Length.sto"));
            [~, columns] = ismember(testCase.expected.muscleNames, names);
            testCase.verifyEqual(squeeze(inputs.muscleTendonLength(1, :, :)), ...
                lengths(:, columns)', "AbsTol", 1e-12);
            testCase.verifySize(inputs.momentArms, [1, 3, 9, 101]);
        end

        function mtpActivationsAreReadForEveryMuscle(testCase)
            inputs = testCase.tutorial.inputs;
            [data, names] = readStoFile(testDataPath("ncp", "mtpResults", ...
                "muscleActivations", "gait_1_muscleActivations.sto"));
            testCase.verifyEqual(string(inputs.mtpActivationsColumnNames), ...
                testCase.expected.muscleNames);
            [~, columns] = ismember(testCase.expected.muscleNames, names);
            testCase.verifyEqual(squeeze(inputs.mtpActivations(1, :, :)), ...
                data(:, columns)', "AbsTol", 1e-12);
        end

        function mtpLengthsAndForcesComeFromOsimx(testCase)
            % NCP keeps the model's lengths and scales them by MTP's: the
            % scale factors are osimx length / model length. Forces are
            % MTP's directly.
            inputs = testCase.tutorial.inputs;
            testCase.verifyEqual(inputs.optimalFiberLength, ...
                testCase.expected.optimalFiberLength, "AbsTol", 1e-12);
            testCase.verifyEqual(inputs.optimalFiberLengthScaleFactors, ...
                testCase.expected.mtpOptimalFiberLength ./ ...
                testCase.expected.optimalFiberLength, "RelTol", 1e-12);
            testCase.verifyEqual(inputs.tendonSlackLengthScaleFactors, ...
                testCase.expected.mtpTendonSlackLength ./ ...
                testCase.expected.tendonSlackLength, "RelTol", 1e-12);
            testCase.verifyEqual(inputs.maxIsometricForce, ...
                testCase.expected.mtpMaxIsometricForce, "RelTol", 1e-12);
        end

        function tutorialSettingsAndDefaults(testCase)
            inputs = testCase.tutorial.inputs;
            params = testCase.tutorial.params;
            testCase.verifyEqual(testCase.tutorial.resultsDirectory, ...
                'NCPResultsV1');
            testCase.verifyEqual([params.diffMinChange, ...
                params.stepTolerance, params.optimalityTolerance, ...
                params.functionTolerance, params.maxIterations, ...
                params.maxFunctionEvaluations], [1e-4, 1e-6, 1e-6, 1e-6, ...
                1000, 1e8], "RelTol", 1e-12);
            % Not in the tutorial file, so defaults:
            testCase.verifyEqual(inputs.numNodes, 26);
            testCase.verifyEqual(inputs.synergy_vector_normalization_method, ...
                "magnitude");
            testCase.verifyEqual(inputs.synergy_vector_normalization_value, 10);
            testCase.verifyTrue(inputs.optimize_synergy_vectors);
            testCase.verifyFalse(inputs.enforce_bilateral_symmetry);
            testCase.verifyEqual([params.algorithm, ...
                params.finiteDifferenceType], ["sqp", "central"]);
        end

        function tutorialCostTermsAndGroups(testCase)
            params = testCase.tutorial.params;
            testCase.verifyEqual(cellfun(@(t) string(t.type), ...
                params.costTerms), ["moment_tracking", ...
                "activation_tracking", "activation_minimization"]);
            testCase.verifyEqual(cellfun(@(t) t.isEnabled, params.costTerms), ...
                [true, true, false]);
            testCase.verifyEqual(cellfun(@(t) t.maxAllowableError, ...
                params.costTerms), [10, 0.05, 0.05]);
            positions = @(groups) cellfun(@(name) find(ismember( ...
                testCase.expected.muscleNames, groups.(name))), ...
                fieldnames(groups)', "UniformOutput", false);
            testCase.verifyEqual(params.activationGroups, ...
                positions(testCase.expected.activationGroups));
            testCase.verifyEqual(params.normalizedFiberLengthGroups, ...
                positions(testCase.expected.normalizedFiberLengthGroups));
        end

        % ---- minimal: defaults without MTP results ----------------------

        function withoutMtpResultsModelValuesAreUsed(testCase)
            inputs = testCase.minimal.inputs;
            testCase.verifyFalse(isfield(inputs, "mtpActivations"));
            testCase.verifyEqual(inputs.optimalFiberLengthScaleFactors, ...
                ones(1, 9));
            testCase.verifyEqual(inputs.tendonSlackLengthScaleFactors, ...
                ones(1, 9));
            testCase.verifyEqual(inputs.maxIsometricForce, ...
                testCase.expected.maxIsometricForce, "AbsTol", 1e-9);
        end

        function minimalUsesDefaultOptimizerSettings(testCase)
            params = testCase.minimal.params;
            testCase.verifyEqual([params.diffMinChange, ...
                params.stepTolerance, params.optimalityTolerance, ...
                params.functionTolerance, params.maxIterations, ...
                params.maxFunctionEvaluations], [1e-6, 1e-16, 1e-3, 1e-6, ...
                1e3, 1e6]);
            testCase.verifyEqual([params.algorithm, ...
                params.finiteDifferenceType], ["sqp", "central"]);
            testCase.verifyEmpty(params.activationGroups);
            testCase.verifyEqual(testCase.minimal.inputs.vMaxFactor, 10);
        end

        % ---- full: every option -----------------------------------------

        function fullReadsEveryOption(testCase)
            inputs = testCase.full.inputs;
            params = testCase.full.params;
            testCase.verifyEqual(inputs.vMaxFactor, 8);
            testCase.verifyEqual(inputs.prefixes, "gait");
            testCase.verifyEqual(inputs.numNodes, 20);
            testCase.verifyEqual(inputs.synergy_vector_normalization_method, ...
                "sum");
            testCase.verifyEqual(inputs.synergy_vector_normalization_value, 5);
            testCase.verifyEqual(inputs.synergyGroups{1}.numSynergies, 4);
            testCase.verifyEqual([params.diffMinChange, ...
                params.stepTolerance, params.optimalityTolerance, ...
                params.functionTolerance, params.maxIterations, ...
                params.maxFunctionEvaluations], [1e-3, 1e-8, 1e-5, 1e-7, ...
                200, 50000]);
            testCase.verifyEqual([params.algorithm, ...
                params.finiteDifferenceType], ["interior-point", "forward"]);
        end

        function fullUsesNcpCostTermsNotMtlis(testCase)
            % The MTLI section, with its own RCNLCostTermSet, comes first
            % in the file; NCP must still read its own terms.
            terms = testCase.full.params.costTerms;
            testCase.verifyEqual(cellfun(@(t) string(t.type), terms), [ ...
                "moment_tracking", "activation_tracking", ...
                "activation_minimization", "muscle_activation_minimization", ...
                "synergy_activation_minimization", "grouped_activations", ...
                "grouped_fiber_lengths"]);
            testCase.verifyEqual(cellfun(@(t) t.isEnabled, terms), ...
                [true, true, false, true, true, true, true]);
            testCase.verifyEqual(terms{4}.errorCenter, 0.1);
        end

        function fullAlsoParsesMtli(testCase)
            mtli = parseMuscleTendonLengthInitializationSettingsTree( ...
                xml2struct("settings_full.xml"));
            testCase.verifyEqual(mtli.passiveMomentDataExists, 1);
            testCase.verifyEqual(mtli.maximumMuscleStress, 500000);
            testCase.verifyFalse(mtli.optimizeIsometricMaxForce);
            testCase.verifyEqual(cellfun(@(t) string(t.type), ...
                mtli.costTerms), "passive_joint_moment");
        end

        % ---- edge_* files -----------------------------------------------

        function emptyNormalizationValueMeansTen(testCase)
            parsed = parse("edge_empty_normalization_value.xml");
            testCase.verifyEqual( ...
                parsed.inputs.synergy_vector_normalization_value, 10);
        end

        function bilateralSymmetryIsCheckedWhenNcpRuns(testCase)
            % The flag parses; NCP then needs exactly two synergy groups.
            parsed = parse("edge_bilateral_symmetry.xml");
            testCase.verifyTrue(parsed.inputs.enforce_bilateral_symmetry);
            verifyErrorMessage(testCase, @() runNcpQuietly(parsed), ...
                "requires exactly two synergy groups");
        end

        function duplicateMusclesAreRejectedWhenNcpRuns(testCase)
            parsed = parse("edge_duplicate_muscle_in_synergy_groups.xml");
            testCase.verifyLength(parsed.inputs.synergyGroups, 2);
            verifyErrorMessage(testCase, @() ...
                NeuralControlPersonalization(parsed.inputs, parsed.params), ...
                'duplicate muscle "bflh_r"');
        end

        function mtliCanBeEnabled(testCase)
            mtli = parseMuscleTendonLengthInitializationSettingsTree( ...
                xml2struct("edge_mtli_enabled.xml"));
            testCase.verifyEqual(mtli.passiveMomentDataExists, 1);
            testCase.verifyEqual(testCase.minimal.params.costTerms{1}.type, ...
                'moment_tracking');
        end

        function fixedWeightsAreReadInMuscleOrder(testCase)
            % The file lists muscles in reverse; the parser reorders them
            % to NCP's muscle order, one row per synergy.
            weights = reshape(1 : 27, 3, 9) / 27;
            names = testCase.expected.muscleNames;
            cleanUp = writeWeights(fliplr(names), fliplr(weights)); %#ok<NASGU>
            parsed = parse("edge_fixed_weights.xml");
            testCase.verifyFalse(parsed.inputs.optimize_synergy_vectors);
            testCase.verifyEqual(parsed.inputs.fixedSynergyWeights, weights, ...
                "AbsTol", 1e-12);
        end

        function fixedWeightsMissingAMuscleAreReported(testCase)
            names = testCase.expected.muscleNames;
            cleanUp = writeWeights(names(names ~= "iliacus_r"), ...
                ones(3, 8)); %#ok<NASGU>
            verifyErrorMessage(testCase, @() parse("edge_fixed_weights.xml"), ...
                "missing weights for muscle(s): iliacus_r");
        end

        function fixedWeightsWithAnExtraMuscleAreReported(testCase)
            cleanUp = writeWeights([testCase.expected.muscleNames, ...
                "extra_r"], ones(3, 10)); %#ok<NASGU>
            verifyErrorMessage(testCase, @() parse("edge_fixed_weights.xml"), ...
                "unexpected muscle(s) not in this study's model: extra_r");
        end

        function fixedWeightsWithWrongSynergyCountAreReported(testCase)
            cleanUp = writeWeights(testCase.expected.muscleNames, ...
                ones(2, 9)); %#ok<NASGU>
            verifyErrorMessage(testCase, @() parse("edge_fixed_weights.xml"), ...
                "has 2 synergies but 3 are configured");
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

        function missingSynergySetIsReported(testCase)
            verifyErrorMessage(testCase, ...
                @() parse("bad_missing_synergy_set.xml"), "RCNLSynergySet");
        end

        function unknownSynergyGroupIsReported(testCase)
            verifyErrorMessage(testCase, ...
                @() parse("bad_unknown_synergy_group.xml"), "NotAGroup");
        end

        function muscleOutsideSynergyGroupsIsReported(testCase)
            verifyErrorMessage(testCase, ...
                @() parse("bad_muscle_not_in_synergy_group.xml"), ...
                "not in a synergy group gasmed_r glmax2_r iliacus_r");
        end

        function osimxWithoutMusclesIsReported(testCase)
            verifyErrorMessage(testCase, ...
                @() parse("bad_osimx_without_muscles.xml"), ...
                "contains no RCNLMuscle elements");
        end

        function fixedWeightsWithoutFileAreReported(testCase)
            verifyErrorMessage(testCase, ...
                @() parse("bad_fixed_weights_without_file.xml"), ...
                "synergyWeights.sto was not found");
        end

        function missingResultsDirectoryIsReported(testCase)
            % Expected to fail: "Dot indexing is not supported for
            % variables of this type." (the same as MTP). See
            % tests/README.md.
            verifyErrorMessage(testCase, ...
                @() parse("bad_missing_results_directory.xml"), ...
                "results_directory");
        end
    end
end

function parsed = parse(fileName)
% Parses a settings file in the current folder the way
% NeuralControlPersonalizationTool does.
settingsTree = xml2struct(fileName);
verifyVersion(settingsTree, "NeuralControlPersonalizationTool");
[parsed.inputs, parsed.params, parsed.resultsDirectory] = ...
    parseNeuralControlPersonalizationSettingsTree(settingsTree);
end

function runNcpQuietly(parsed)
% NeuralControlPersonalization prints its progress; keep the report readable.
evalc("NeuralControlPersonalization(parsed.inputs, parsed.params)");
end

function fileName = dataFile(varargin)
fileName = testDataPath("ncp", "preprocessed", varargin{:});
end

function cleanUp = writeWeights(muscleNames, weights)
% Writes preprocessed/synergyWeights.sto in the current folder the way NCP
% saves its results (one row per synergy), and deletes it afterwards.
fileName = fullfile("preprocessed", "synergyWeights.sto");
writeToSto(muscleNames, 1 : size(weights, 1), weights, fileName);
cleanUp = onCleanup(@() delete(fileName));
end
