% Tests that Design Optimization settings files in tests/data/to/settings
% parse into the expected inputs: the settings only Design Optimization
% reads (final time range, model functions, user-defined parameters), the
% tutorial's user-defined cost and constraint terms, and what the goal
% terms switch on. Written for candidate-1.5.4.

classdef (TestTags = {'Parsing'}) DesignOptimizationParsingTest < ...
        matlab.unittest.TestCase

    properties
        expected
        folder
        full
    end

    methods (TestClassSetup)
        function parseFullFile(testCase)
            testCase.expected = toFixtureValues();
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.folder = string(fixture.Folder);
            files = string({dir(testDataPath("to", "settings", ...
                "*design*.xml")).name});
            copyToFixtures(fullfile(testCase.folder, "torque"), "torque", ...
                files);
            copyToFixtures(fullfile(testCase.folder, "synergy"), ...
                "synergy", files);
            testCase.full = testCase.parse("torque", ...
                "settings_design_torque_full.xml");
        end
    end

    methods (Test)
        function finalTimeRangeIsRead(testCase)
            testCase.verifyEqual(testCase.full.finalTimeRange, [0.26, 0.36]);
        end

        function emptyFinalTimeRangeIsLeftOut(testCase)
            % An empty <final_time_range/> keeps the final time fixed.
            inputs = testCase.parse("torque", ...
                "edge_design_empty_final_time_range.xml");
            testCase.verifyFalse(isfield(inputs, "finalTimeRange"));
        end

        function modelFunctionsAreRead(testCase)
            testCase.verifyEqual(testCase.full.systemFns, ...
                "applyMaxIsometricForceParameter");
        end

        function parametersHaveValuesAndBounds(testCase)
            parameters = testCase.full.userDefinedVariables;
            testCase.verifyLength(parameters, 1);
            testCase.verifyEqual(parameters{1}.type, 'max_isometric_force');
            testCase.verifyEqual(parameters{1}.muscle, 'soleus_r');
            testCase.verifyEqual([parameters{1}.initial_values, ...
                parameters{1}.upper_bounds, parameters{1}.lower_bounds], ...
                [3000, 4000, 2000]);
        end

        function noParametersGiveAnEmptyList(testCase)
            inputs = testCase.parse("torque", ...
                "settings_design_torque_tutorial_v3.xml");
            testCase.verifyEqual(inputs.userDefinedVariables, {});
            testCase.verifyFalse(isfield(inputs, "systemFns"));
        end

        function userDefinedTermsKeepTheirSettings(testCase)
            % Every element of a user-defined term is passed on to its
            % function.
            cost = testCase.full.costTerms{1};
            testCase.verifyEqual(cost.function_name, 'footSpeedCost');
            testCase.verifyEqual(cost.cost_term_type, 'discrete');
            testCase.verifyEqual(cost.marker_name, 'R_Toe');
            testCase.verifyEqual(cost.target_speed, 14.35);
            constraint = testCase.full.terminal{1};
            testCase.verifyEqual(constraint.function_name, ...
                'footSpeedConstraint');
            testCase.verifyEqual([constraint.minError, constraint.maxError], ...
                [14.3, 14.4]);
        end

        function tutorialUserDefinedFilesParse(testCase)
            v4 = testCase.parse("torque", ...
                "settings_design_torque_tutorial_v4.xml");
            testCase.verifyEqual(v4.costTerms{1}.type, 'user_defined');
            v5 = testCase.parse("torque", ...
                "settings_design_torque_tutorial_v5.xml");
            testCase.verifyEqual(v5.terminal{end}.type, 'user_defined');
        end

        function synergyDesignStartsFromPublishedVerification(testCase)
            inputs = testCase.parse("synergy", ...
                "settings_design_synergy_tutorial.xml");
            testCase.verifyEqual(inputs.controllerType, "synergy");
            testCase.verifyEqual(inputs.finalTimeRange, [0.26, 0.36]);
            testCase.verifySize(inputs.initialSynergyControls, ...
                [testCase.expected.synergy.publishedFrames, 4]);
        end

        function metabolicGoalTurnsOnMetabolicCost(testCase)
            % An enabled metabolic cost goal needs the metabolic cost
            % computed during the optimization.
            % Failed on candidate-1.5.4 (fixed later): only the relative_*
            % metabolic terms switch on calculateMetabolicCost, so an
            % absolute_metabolic_cost_* term gets no metabolic cost. See
            % docs/failures.md.
            inputs = testCase.parse("synergy", ...
                "edge_design_absolute_metabolic_cost.xml");
            testCase.verifyTrue(logical(inputs.calculateMetabolicCost));
        end
    end

    methods
        function inputs = parse(testCase, problem, fileName)
            originalFolder = cd(fullfile(testCase.folder, problem));
            restoreFolder = onCleanup(@() cd(originalFolder));
            [~, inputs] = evalc("parseToSettingsFile(fileName)");
        end
    end
end
