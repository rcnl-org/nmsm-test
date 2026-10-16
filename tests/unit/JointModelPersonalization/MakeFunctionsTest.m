% Tests for the factories that turn parsed JMP parameters into functions of
% (value, model), and for adjustModelFromOptimizerOutput, which applies the
% optimizer's final values to the model.

classdef (TestTags = {'Unit'}) MakeFunctionsTest < matlab.unittest.TestCase

    properties (Constant)
        jointName = 'r_elbow'
        newValue = 0.123
    end

    properties
        model
    end

    properties (TestParameter)
        % {isParent, isTranslation} and the jmpFrameValues() row it changes.
        jointParameter = struct( ...
            "parentTranslation", struct("isParent", true, "isTranslation", true, "row", 1), ...
            "parentOrientation", struct("isParent", true, "isTranslation", false, "row", 2), ...
            "childTranslation", struct("isParent", false, "isTranslation", true, "row", 3), ...
            "childOrientation", struct("isParent", false, "isTranslation", false, "row", 4))
        axis = {0, 1, 2}
        markerAxis = {"x", "y", "z"}
    end

    methods (TestMethodSetup)
        function loadFreshModel(testCase)
            testCase.model = Model(testDataPath("jmp", "simple_arm.osim"));
        end
    end

    methods (Test)
        function jointFunctionAdjustsMatchingFrameValue(testCase, ...
                jointParameter, axis)
            fn = makeJointFunction(testCase.jointName, ...
                jointParameter.isParent, jointParameter.isTranslation, axis);
            before = jmpFrameValues(testCase.model, testCase.jointName);
            fn(testCase.newValue, testCase.model);

            expected = before;
            expected(jointParameter.row, axis + 1) = testCase.newValue;
            testCase.verifyEqual(jmpFrameValues(testCase.model, ...
                testCase.jointName), expected, "AbsTol", 1e-12);
        end

        function markerFunctionAdjustsMatchingAxis(testCase, markerAxis)
            fn = makeMarkerFunction('r_radius1', markerAxis);
            fn(testCase.newValue, testCase.model);
            location = testCase.model.getMarkerSet().get('r_radius1') ...
                .get_location();
            actual = [location.get(0), location.get(1), location.get(2)];
            testCase.verifyEqual(actual(markerAxis == ["x", "y", "z"]), ...
                testCase.newValue, "AbsTol", 1e-12);
        end

        function scalingFunctionSetsScaleFactor(testCase)
            fn = makeScalingFunction('r_ulna_radius_hand', true);
            fn(1.1, testCase.model);
            testCase.verifyEqual(getScalingParameterValue(testCase.model, ...
                'r_ulna_radius_hand'), 1.1, "AbsTol", 1e-12);
        end

        function optimizerOutputIsAppliedToCopy(testCase)
            % Given the true values, the translated-away and oriented-away
            % changes are undone, and the input model is left unchanged.
            expected = jmpFixtureValues();
            awayModel = Model(testDataPath("jmp", ...
                "simple_arm_translated_away.osim"));
            functions = { ...
                makeJointFunction(testCase.jointName, true, true, 0), ...
                makeJointFunction(testCase.jointName, true, false, 0)};
            values = [expected.truth.parentTranslation(1), 0.05];

            outputModel = adjustModelFromOptimizerOutput(awayModel, ...
                functions, values);

            output = jmpFrameValues(outputModel, testCase.jointName);
            testCase.verifyEqual(output(1, :), ...
                expected.truth.parentTranslation, "AbsTol", 1e-12);
            testCase.verifyEqual(output(2, :), [0.05, 0, 0], "AbsTol", 1e-12);
            input = jmpFrameValues(awayModel, testCase.jointName);
            testCase.verifyEqual(input(1, :), ...
                expected.translatedAway.parentTranslation, "AbsTol", 1e-12);
        end

        function optimizerOutputIsRoundedToTenDecimals(testCase)
            fn = makeJointFunction(testCase.jointName, true, true, 0);
            outputModel = adjustModelFromOptimizerOutput(testCase.model, ...
                {fn}, 0.0061000000000049);
            output = jmpFrameValues(outputModel, testCase.jointName);
            testCase.verifyEqual(output(1, 1), 0.0061, "AbsTol", 1e-15);
        end
    end
end
