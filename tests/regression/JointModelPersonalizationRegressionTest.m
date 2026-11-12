% Full JointModelPersonalizationTool runs on the simple_arm fixtures. Each
% run starts from a model with r_elbow's parent frame moved away from the
% truth and checks the result two ways:
%
% 1. Against the truth (simple_arm.osim, which generated the markers): is
%    the answer still correct? Tolerances are set by what a correct JMP
%    should achieve on noise-free markers.
% 2. Against the stored nominal result (tests/data/jmp/nominal): did the
%    answer change at all? Tolerances are much tighter, so any change in
%    optimizer behavior shows up here even when the result is still
%    correct. If a change is intentional, regenerate the nominal results
%    with tests/regression/updateJmpNominal.m and commit them.

classdef (TestTags = {'Regression'}) JointModelPersonalizationRegressionTest ...
        < matlab.unittest.TestCase

    properties (Constant)
        jointName = 'r_elbow'
        truthTranslationTolerance = 1e-5 % m (0.01 mm)
        truthOrientationTolerance = 1e-4 % rad (0.006 deg)
        nominalTolerance = 1e-7 % m or rad
    end

    properties
        expected
    end

    properties (TestParameter)
        % settings file, output model, and which frame row JMP adjusts:
        % row 1 = parent translation, row 2 = parent orientation.
        run = struct( ...
            "translation", struct( ...
                "settings", "settings_translation.xml", ...
                "output", "simple_arm_translated_jmp.osim", ...
                "start", "translatedAway", ...
                "row", 1), ...
            "orientation", struct( ...
                "settings", "settings_orientation.xml", ...
                "output", "simple_arm_oriented_jmp.osim", ...
                "start", "orientedAway", ...
                "row", 2))
    end

    methods (TestClassSetup)
        function prepare(testCase)
            testCase.expected = jmpFixtureValues();
            startQuietParallelPool();
        end
    end

    methods (Test)
        function recoversTruthAndChangesNothingElse(testCase, run)
            outputModel = testCase.runJmp(run);
            actual = jmpFrameValues(outputModel, testCase.jointName);
            start = testCase.startFrameValues(run);

            % The adjusted parameter (x of the adjusted row) returns to truth.
            truth = [testCase.expected.truth.parentTranslation; ...
                testCase.expected.truth.parentOrientation];
            tolerance = [testCase.truthTranslationTolerance; ...
                testCase.truthOrientationTolerance];
            testCase.verifyEqual(actual(run.row, 1), truth(run.row, 1), ...
                "AbsTol", tolerance(run.row), ...
                "JMP did not move the parameter back to its true value.");

            % Every other frame value is exactly what the start model had.
            adjusted = false(4, 3);
            adjusted(run.row, 1) = true;
            testCase.verifyEqual(actual(~adjusted), start(~adjusted), ...
                "AbsTol", 1e-12, "JMP changed a parameter it was not asked to.");
        end

        function matchesNominalResult(testCase, run)
            outputModel = testCase.runJmp(run);
            nominalModel = Model(testDataPath("jmp", "nominal", run.output));
            testCase.verifyEqual( ...
                jmpFrameValues(outputModel, testCase.jointName), ...
                jmpFrameValues(nominalModel, testCase.jointName), ...
                "AbsTol", testCase.nominalTolerance, ...
                "Result differs from tests/data/jmp/nominal/" + run.output + ...
                ". If this change is intended, run updateJmpNominal.");
        end

        function writesExpectedResultFiles(testCase, run)
            testCase.runJmp(run);
            % The Tool copies the settings file and command window log
            % into <results_directory> next to the output model.
            testCase.verifyTrue(isfile(fullfile("JMPResults", run.output)));
            testCase.verifyTrue(isfile(fullfile("JMPResults", run.settings)));
            testCase.verifyTrue(isfile(fullfile("JMPResults", ...
                "commandWindowOutput.txt")));
            % JMP's temporary model copy is cleaned up.
            testCase.verifyEmpty(dir("*_jmp_temp.osim"));
        end
    end

    methods
        function outputModel = runJmp(testCase, run)
            % Run the Tool in a temporary folder and load its output model.
            setUpJmpWorkingFolder(testCase, run.settings);
            evalc("JointModelPersonalizationTool(run.settings)");
            outputModel = Model(fullfile("JMPResults", run.output));
        end

        function values = startFrameValues(testCase, run)
            start = testCase.expected.(run.start);
            values = [start.parentTranslation; start.parentOrientation; ...
                zeros(2, 3)];
        end
    end
end
