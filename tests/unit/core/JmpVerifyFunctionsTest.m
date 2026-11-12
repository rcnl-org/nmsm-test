% Tests for the src/core/verify functions that Joint Model Personalization
% uses to check its inputs before running. Ported from the JMP-related parts
% of legacy/tests/core/verify/testVerify.m.
%
% These functions throw MExceptions with no identifier, so errors are
% checked by message with verifyErrorMessage (tests/helpers). A "no error"
% check calls the function inside verifyWarningFree, which fails the test
% if it errors or warns.

classdef (TestTags = {'Unit'}) JmpVerifyFunctionsTest < matlab.unittest.TestCase

    properties
        modelFile
        markerFile
    end

    methods (TestClassSetup)
        % Runs once before all tests in this file.
        function findDataFiles(testCase)
            testCase.modelFile = testDataPath("jmp", "simple_arm.osim");
            testCase.markerFile = testDataPath("jmp", "simple_arm.trc");
        end
    end

    methods (Test)
        function verifyCharAcceptsTextOnly(testCase)
            testCase.verifyWarningFree(@() verifyChar('test'));
            testCase.verifyWarningFree(@() verifyChar("test"));
            verifyErrorMessage(testCase, @() verifyChar(6), ...
                "input is not a string");
            verifyErrorMessage(testCase, @() verifyChar({}), ...
                "input is not a string");
        end

        function verifyNumericAcceptsNumbersOnly(testCase)
            testCase.verifyWarningFree(@() verifyNumeric(5));
            testCase.verifyWarningFree(@() verifyNumeric(-0.00123));
            testCase.verifyWarningFree(@() verifyNumeric([1 2 3]));
            verifyErrorMessage(testCase, @() verifyNumeric('Hello'), ...
                "input is not numeric");
        end

        function verifyLengthChecksExactLength(testCase)
            testCase.verifyWarningFree(@() verifyLength([1, 2, 3], 3));
            verifyErrorMessage(testCase, @() verifyLength([1, 2, 3], 2), ...
                "object is not of expected length");
            % The JMP parser uses this on space-separated booleans.
            verifyErrorMessage(testCase, @() verifyLength( ...
                strsplit("true false", " "), 3), ...
                "object is not of expected length");
        end

        function verifyModelArgAcceptsFileOrModel(testCase)
            testCase.verifyWarningFree(@() verifyModelArg(testCase.modelFile));
            testCase.verifyWarningFree(@() verifyModelArg( ...
                Model(testCase.modelFile)));
            verifyErrorMessage(testCase, @() verifyModelArg(6), ...
                "input is not a model");
            verifyErrorMessage(testCase, @() verifyModelArg("missing.osim"), ...
                "input is not a model");
        end

        function verifyMarkersReferenceArgNeedsReadableFile(testCase)
            testCase.verifyWarningFree(@() ...
                verifyMarkersReferenceArg(testCase.markerFile));
            verifyErrorMessage(testCase, ...
                @() verifyMarkersReferenceArg("missing.trc"), ...
                "input is not valid to make a MarkersReference");
            verifyErrorMessage(testCase, @() verifyMarkersReferenceArg(7), ...
                "input is not valid to make a MarkersReference");
        end

        function functionsArgsAcceptValidParameters(testCase)
            % {jointName, isParent, isTranslation, coordinate (0, 1, or 2)}
            parameters = {{'r_elbow', 1, 1, 0}, {'r_elbow', 0, 0, 2}};
            testCase.verifyWarningFree(@() ...
                verifyJointModelPersonalizationFunctionsArgs( ...
                testCase.modelFile, parameters));
        end

        function functionsArgsRejectCoordinateOutOfRange(testCase)
            verifyErrorMessage(testCase, @() ...
                verifyJointModelPersonalizationFunctionsArgs( ...
                testCase.modelFile, {{'r_elbow', 1, 1, 3}}), ...
                "invalid function input parameters");
        end
    end
end
