% Tests that Tracking Optimization settings files in tests/data/to/settings
% parse into the expected inputs: the tutorial's torque-driven and
% synergy-driven problems, the synergy controller's settings and data
% (synergy groups, muscles, surrogate model data), and the settings only
% the synergy controller has. Written for candidate-1.5.4.

classdef (TestTags = {'Parsing'}) TrackingOptimizationParsingTest < ...
        matlab.unittest.TestCase

    properties
        expected
        folder
        torque
        synergy
    end

    methods (TestClassSetup)
        function parseTutorialFiles(testCase)
            testCase.expected = toFixtureValues();
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.folder = string(fixture.Folder);
            files = string({dir(testDataPath("to", "settings", ...
                "*.xml")).name});
            copyToFixtures(fullfile(testCase.folder, "torque"), "torque", ...
                files);
            copyToFixtures(fullfile(testCase.folder, "synergy"), ...
                "synergy", files);
            testCase.torque = testCase.parse("torque", ...
                "settings_tracking_torque_tutorial.xml");
            testCase.synergy = testCase.parse("synergy", ...
                "settings_tracking_synergy_tutorial.xml");
        end
    end

    methods (Test)
        function torqueTutorialTracksCoordinatesAndLoads(testCase)
            inputs = testCase.torque;
            testCase.verifyEqual(inputs.toolName, "TrackingOptimization");
            testCase.verifyEqual(inputs.controllerType, "torque");
            testCase.verifyEqual(inputs.torqueControllerCoordinateNames, ...
                testCase.expected.statesCoordinates);
            testCase.verifyEqual(cellfun(@(t) string(t.type), ...
                inputs.costTerms), [repmat( ...
                "generalized_coordinate_tracking", 1, 3), ...
                repmat("inverse_dynamics_load_tracking", 1, 3)]);
            testCase.verifyEqual(cellfun(@(t) string(t.type), inputs.path), ...
                repmat("kinetic_consistency", 1, 3));
            testCase.verifyEqual([inputs.jointPositionsMultiple, ...
                inputs.jointVelocitiesMultiple], [1.5, 1.25]);
        end

        function synergyControllerReadsTheSynergyGroups(testCase)
            inputs = testCase.synergy;
            synergy = testCase.expected.synergy;
            testCase.verifyEqual(inputs.controllerType, "synergy");
            testCase.verifyLength(inputs.synergyGroups, 1);
            testCase.verifyEqual(string(inputs.synergyGroups{1} ...
                .muscleGroupName), synergy.synergyGroup);
            testCase.verifyEqual(inputs.numSynergies, synergy.numSynergies);
            testCase.verifyEqual(inputs.muscleNames, synergy.muscleNames);
            testCase.verifyEqual(inputs.numMuscles, 9);
        end

        function synergyControllerDefaults(testCase)
            inputs = testCase.synergy;
            testCase.verifyEqual(inputs.epsilon, 1e-4);
            testCase.verifyEqual(inputs.polynomialDegree, 5);
            testCase.verifyEqual(inputs.vMaxFactor, 10);
            testCase.verifyFalse(logical(inputs.optimizeSynergyVectors));
            testCase.verifyEqual(inputs.maxControlSynergyActivations, 10);
            testCase.verifyEqual(inputs.synergyNormalizationMethod, "sum");
            testCase.verifyEqual(inputs.synergyNormalizationValue, 1);
            testCase.verifyTrue(inputs.loadSurrogate);
            testCase.verifyFalse(inputs.saveSurrogate);
        end

        function synergyStartingValuesComeFromNcp(testCase)
            % ncpResults: synergy weights (4 x 9), commands and
            % activations.
            inputs = testCase.synergy;
            synergy = testCase.expected.synergy;
            [weights, names] = readStoFile(testDataPath("to", "synergy", ...
                "ncpResults", "synergyWeights.sto"));
            testCase.verifyEqual(inputs.synergyWeights, weights(:, 2 : end), ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(inputs.synergyWeightsLabels, names(2 : end));
            testCase.verifySize(inputs.initialSynergyControls, ...
                [testCase.expected.numFrames, synergy.numSynergies]);
            testCase.verifyEqual(inputs.initialSynergyControlsLabels, ...
                synergy.synergyGroup + "_" + (1 : synergy.numSynergies));
            testCase.verifySize(inputs.experimentalMuscleActivations, ...
                [testCase.expected.numFrames, 9]);
        end

        function surrogateDataHasEverySample(testCase)
            % 1,575 samples, moment arms about the six surrogate
            % coordinates, for the nine muscles.
            inputs = testCase.synergy;
            synergy = testCase.expected.synergy;
            testCase.verifyEqual(inputs.surrogateModelCoordinateNames, ...
                synergy.surrogateCoordinates);
            testCase.verifySize(inputs.muscleTendonLengths, [1575, 9]);
            testCase.verifySize(inputs.surrogateModelMomentArms, ...
                [1575, 6, 9]);
            testCase.verifySize(inputs.surrogateModelJointAngles, [1575, 41]);
        end

        function muscleParametersComeFromTheOsimx(testCase)
            % The osimx file's optimal fiber and tendon slack lengths
            % (from NCP), muscle by muscle.
            inputs = testCase.synergy;
            text = fileread(testDataPath("to", "synergy", "ncpResults", ...
                "KickingModel_ncp.osimx"));
            lengths = str2double(string(regexp(text, ...
                "<optimal_fiber_length>([^<]*)<", "tokens")));
            testCase.verifyEqual(inputs.optimalFiberLength, lengths, ...
                "AbsTol", 1e-9);
        end

        function muscleParametersFollowTheModeledMuscles(testCase)
            % With a surrogate model of the ankle and subtalar joints
            % only, the modeled muscles are gasmed_r, soleus_r and
            % tibant_r; each muscle's max isometric force and pennation
            % angle must be that muscle's.
            % Failed on candidate-1.5.4 (fixed later): getModelOrOsimxInputs
            % reads them from the model's first, second and third muscles
            % (bflh_r, bfsh_r, gasmed_r) instead of by name. See
            % docs/failures.md.
            inputs = testCase.parse("synergy", ...
                "edge_synergy_ankle_surrogate.xml");
            testCase.assertEqual(inputs.muscleNames, ["gasmed_r", ...
                "soleus_r", "tibant_r"]);
            muscles = inputs.model.getMuscles();
            for i = 1 : 3
                muscle = muscles.get(char(inputs.muscleNames(i)));
                testCase.verifyEqual(inputs.maxIsometricForce(i), ...
                    muscle.getMaxIsometricForce(), "RelTol", 1e-12, ...
                    inputs.muscleNames(i));
                testCase.verifyEqual(inputs.pennationAngle(i), ...
                    muscle.getPennationAngleAtOptimalFiberLength(), ...
                    "AbsTol", 1e-12, inputs.muscleNames(i));
            end
        end

        function synergyControllerNeedsAnOsimx(testCase)
            verifyErrorMessage(testCase, @() testCase.parse("synergy", ...
                "bad_synergy_without_osimx.xml"), "<input_osimx_file>");
        end
    end

    methods
        function inputs = parse(testCase, problem, fileName)
            % Parses a file in the problem's folder
            originalFolder = cd(fullfile(testCase.folder, problem));
            restoreFolder = onCleanup(@() cd(originalFolder));
            [~, inputs] = evalc("parseToSettingsFile(fileName)");
        end
    end
end
