% This is a minimal example of a class-based test. It does not test NMSM
% Pipeline code; it shows the structure every other test file follows.
%
% - The class inherits from matlab.unittest.TestCase.
% - TestTags puts it in a tier, so runTests("unit") selects it.
% - Each method in a "methods (Test)" block is one independent test.
% - testCase.verify* records a failure and keeps going; testCase.assert*
%   stops the current test. Prefer verify* unless later lines would crash.

classdef (TestTags = {'Unit'}) ExampleTest < matlab.unittest.TestCase

    methods (Test)
        function additionIsCorrect(testCase)
            actual = 2 + 2;
            expected = 4;
            testCase.verifyEqual(actual, expected);
        end

        function floatingPointNeedsTolerance(testCase)
            % 0.1 + 0.2 is not exactly 0.3 in floating point, so numeric
            % results are compared with a tolerance.
            testCase.verifyEqual(0.1 + 0.2, 0.3, "AbsTol", 1e-12);
        end

        function errorIsThrown(testCase)
            % verifyError checks that calling the function throws an
            % error with the given identifier.
            testCase.verifyError(@() ones(2, 2) * ones(3, 3), ...
                "MATLAB:innerdim");
        end
    end
end
