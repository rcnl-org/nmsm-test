% Tests for how MTP packs its parameters into fmincon's design vector and
% back (src/MuscleTendonPersonalization/Optimization). MTP keeps seven
% parameter sets, "primary values":
%   1 electromechanical delays     4 EMG scale factors
%   2 activation time constants    5 optimal fiber length scale factors
%   3 activation nonlinearities    6 tendon slack length scale factors
%   7 synergy weights (only with synergy extrapolation)
% A task's isIncluded flags pick which sets are optimized; those are
% concatenated in order into the design vector ("secondary values").

classdef (TestTags = {'Unit'}) DesignVariablesTest < matlab.unittest.TestCase

    properties
        primary
    end

    methods (TestMethodSetup)
        function makePrimaryValues(testCase)
            % Two muscles; set k holds [k1, k2] so each value is traceable.
            testCase.primary = arrayfun(@(k) [10 * k + 1, 10 * k + 2], ...
                1 : 7, "UniformOutput", false);
            testCase.primary{7} = [71, 72, 73]; % synergy weights
        end
    end

    methods (Test)
        function includedSetsAreLaidOutInOrder(testCase)
            % Sets 1, 3 and 4 included: 1 -> 1:2, 3 -> 3:4, 4 -> 5:6
            isIncluded = [1, 0, 1, 1, 0, 0, 0];
            [s3, e3] = findIsIncludedStartAndEndIndex(testCase.primary, ...
                isIncluded, 3);
            [s4, e4] = findIsIncludedStartAndEndIndex(testCase.primary, ...
                isIncluded, 4);
            testCase.verifyEqual([s3, e3, s4, e4], [3, 4, 5, 6]);
        end

        function synergyWeightsComeLast(testCase)
            isIncluded = ones(1, 7);
            [startIndex, endIndex] = findIsIncludedStartAndEndIndex( ...
                testCase.primary, isIncluded, 7);
            testCase.verifyEqual([startIndex, endIndex], [13, 15]);
        end

        function valuesComeFromDesignVectorOnlyWhenIncluded(testCase)
            % Sets 2 and 5 are optimized; the rest keep primary values.
            isIncluded = [0, 1, 0, 0, 1, 0, 0];
            secondary = [-21, -22, -51, -52];
            values = makeMtpValuesAsStruct(secondary, testCase.primary, ...
                isIncluded, struct());
            testCase.verifyEqual(values.electromechanicalDelays, [11, 12]);
            testCase.verifyEqual(values.activationTimeConstants, [-21, -22]);
            testCase.verifyEqual(values.activationNonlinearityConstants, ...
                [31, 32]);
            testCase.verifyEqual(values.emgScaleFactors, [41, 42]);
            testCase.verifyEqual(values.optimalFiberLengthScaleFactors, ...
                [-51, -52]);
            testCase.verifyEqual(values.tendonSlackLengthScaleFactors, ...
                [61, 62]);
            testCase.verifyFalse(isfield(values, "synergyWeights"));
        end

        function synergyWeightsAreReadOnlyWithSynergies(testCase)
            isIncluded = [0, 0, 0, 0, 0, 0, 1];
            values = makeMtpValuesAsStruct([-71, -72, -73], ...
                testCase.primary, isIncluded, ...
                struct("synergyExtrapolation", struct()));
            testCase.verifyEqual(values.synergyWeights, [-71, -72, -73]);
        end

        function updateCopiesOptimizedSetsBack(testCase)
            isIncluded = [1, 0, 0, 1, 0, 0, 1];
            secondary = [-11, -12, -41, -42, -71, -72, -73];
            updated = updateDesignVariables(testCase.primary, secondary, ...
                isIncluded);
            expected = testCase.primary;
            expected{1} = [-11, -12];
            expected{4} = [-41, -42];
            expected{7} = [-71, -72, -73];
            testCase.verifyEqual(updated, expected);
        end

        function updateDropsSynergyWeightsWhenNotOptimized(testCase)
            % Without synergy extrapolation there is no seventh set.
            updated = updateDesignVariables(testCase.primary(1 : 6), ...
                [-21, -22], [0, 1, 0, 0, 0, 0, 0]);
            testCase.verifyLength(updated, 6);
            testCase.verifyEqual(updated{2}, [-21, -22]);
        end

        function packingAndUnpackingRoundTrips(testCase)
            % Pack the included sets the way MuscleTendonPersonalization
            % does, unpack with makeMtpValuesAsStruct: same values.
            isIncluded = [1, 1, 0, 1, 1, 1, 0];
            secondary = [testCase.primary{logical(isIncluded)}];
            values = makeMtpValuesAsStruct(secondary, testCase.primary, ...
                isIncluded, struct());
            testCase.verifyEqual(values.electromechanicalDelays, ...
                testCase.primary{1});
            testCase.verifyEqual(values.tendonSlackLengthScaleFactors, ...
                testCase.primary{6});
        end
    end
end
