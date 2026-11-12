% Tests for the inverse kinematics error JMP minimizes, compared against
% ground truth values that can be worked out by hand:
%   computeInnerOptimization -> makeJmpMarkerRef ->
%   computeInnerOptimizationHeuristic -> computeInverseKinematicsSquaredError
%   -> calculateFrameSquaredError
%
% The returned vector holds each marker's distance error divided by
% sqrt(numMarkers * numFrames) and by desiredError, so with desiredError = 1
% its sum of squares is the mean squared marker error over all frames.
%
% Ground truths used:
% - simple_arm.trc was generated from simple_arm.osim, so the truth model
%   has zero error.
% - r_humerus is welded to ground, so IK cannot compensate for a humerus
%   marker moved in the model: that marker's error is exactly the offset in
%   every frame, and the other markers' errors stay zero.

classdef (TestTags = {'Unit'}) InverseKinematicsErrorTest < matlab.unittest.TestCase

    properties (Constant)
        markerOffset = 0.01 % m
        numFramesInMarkerFile = 120
        numMarkers = 6
    end

    properties
        expected
        markerFile
        params
    end

    methods (TestClassSetup)
        function loadFixtureValues(testCase)
            testCase.expected = jmpFixtureValues();
            testCase.markerFile = char(testDataPath("jmp", "simple_arm.trc"));
        end
    end

    methods (TestMethodSetup)
        % Runs before every test. These functions keep "persistent"
        % variables between calls, so clear them to keep tests independent.
        function clearPersistentState(testCase)
            clear computeInnerOptimization
            clear computeInverseKinematicsSquaredError
            clear calculateFrameSquaredError
            testCase.params = struct("accuracy", 1e-8, "desiredError", 1);
        end
    end

    methods (Test)
        function usesEveryFrameInMarkerFile(testCase)
            error = testCase.computeError("simple_arm", 0, testCase.params);
            numFramesUsed = numel(error) / testCase.numMarkers;
            testCase.verifyEqual(numFramesUsed, ...
                testCase.numFramesInMarkerFile, ...
                "Every frame of the marker file should be used.");
        end

        function usesEveryFrameWhenTimesAreRounded(testCase)
            % simple_arm_rounded_times.trc has its times written to 5
            % decimals. Stepping by 1/60 s from a rounded time overshoots
            % the last frame's rounded time, which skipped the last frame.
            testCase.markerFile = char(testDataPath("jmp", ...
                "simple_arm_rounded_times.trc"));
            error = testCase.computeError("simple_arm", 0, testCase.params);
            numFramesUsed = numel(error) / testCase.numMarkers;
            testCase.verifyEqual(numFramesUsed, ...
                testCase.numFramesInMarkerFile, ...
                "Every frame of the marker file should be used.");
            testCase.verifyLessThan(max(abs(error)), 1e-7);
        end

        function timeRangeLimitsTheFrames(testCase)
            % 0.5 s and 1.0 s are frames 31 and 61, so 31 frames.
            testCase.params.startTime = 0.5;
            testCase.params.finishTime = 1.0;
            error = testCase.computeError("simple_arm", 0, testCase.params);
            testCase.verifyEqual(numel(error) / testCase.numMarkers, 31);
        end

        function truthModelHasZeroError(testCase)
            error = testCase.computeError("simple_arm", 0, testCase.params);
            testCase.verifyLessThan(max(abs(error)), 1e-7);
        end

        function fixedBodyMarkerOffsetGivesExactError(testCase)
            error = testCase.computeError("simple_arm", ...
                testCase.markerOffset, testCase.params);
            d = testCase.markerOffset;
            % Frames counted from the output, so this checks the error
            % values independently of usesEveryFrameInMarkerFile.
            n = numel(error);
            numFramesUsed = n / testCase.numMarkers;

            % One marker is off by d in every frame; the rest are exact.
            moved = abs(error) > 1e-6;
            testCase.verifyEqual(nnz(moved), numFramesUsed);
            testCase.verifyEqual(abs(error(moved)), ...
                d / sqrt(n) * ones(1, numFramesUsed), "AbsTol", 1e-9);
            testCase.verifyLessThan(max(abs(error(~moved))), 1e-7);
            testCase.verifyEqual(sum(error .^ 2), ...
                d ^ 2 / testCase.numMarkers, "RelTol", 1e-6);
        end

        function desiredErrorScalesOutput(testCase)
            errorAtOne = testCase.computeError("simple_arm", ...
                testCase.markerOffset, testCase.params);
            testCase.params.desiredError = 0.5;
            errorAtHalf = testCase.computeError("simple_arm", ...
                testCase.markerOffset, testCase.params);
            testCase.verifyEqual(errorAtHalf, 2 * errorAtOne, "AbsTol", 1e-12);
        end

        function selectedMarkersOnlyAreUsed(testCase)
            % Run once with all 6 markers first, so this also checks that
            % calculateFrameSquaredError's persistent array resizes when
            % the marker count changes.
            allMarkersError = testCase.computeError("simple_arm", 0, ...
                testCase.params);
            numFramesUsed = numel(allMarkersError) / testCase.numMarkers;

            testCase.params.markerNames = ...
                {'r_humerus1', 'r_humerus2', 'r_humerus3'};
            error = testCase.computeError("simple_arm", ...
                testCase.markerOffset, testCase.params);
            testCase.verifyNumElements(error, 3 * numFramesUsed);
            testCase.verifyEqual(sum(error .^ 2), ...
                testCase.markerOffset ^ 2 / 3, "RelTol", 1e-6);
        end

        function innerOptimizationIsZeroAtTruth(testCase)
            % The objective JMP minimizes, started from the translated-away
            % model, should be zero when given the true parameter value.
            truthValue = testCase.expected.truth.parentTranslation(1);
            error = testCase.innerOptimization(truthValue);
            testCase.verifyLessThan(max(abs(error)), 1e-6);
        end

        function innerOptimizationMatchesKnownStartingError(testCase)
            % At the translated-away value the RMS marker error is 1.8 mm
            % (measured independently with OpenSim's IK solver).
            awayValue = testCase.expected.translatedAway.parentTranslation(1);
            error = testCase.innerOptimization(awayValue);
            testCase.verifyEqual(sqrt(sum(error .^ 2)), 0.001803, ...
                "AbsTol", 1e-5);
        end

        function failureReturnsLargeErrorInsteadOfThrowing(testCase)
            % Documents current behavior: computeInverseKinematicsSquaredError
            % catches every error and returns 100 for each entry (the size
            % of the last successful call), so a broken model or marker file
            % looks like a large error to the optimizer rather than a crash.
            % If this is changed to rethrow, update this test.
            goodError = testCase.computeError("simple_arm", 0, ...
                testCase.params);
            model = Model(testDataPath("jmp", "simple_arm.osim"));
            markersReference = makeJmpMarkerRef(model, testCase.markerFile, ...
                testCase.params);
            notASolver = [];
            failedError = computeInverseKinematicsSquaredError(model, ...
                notASolver, markersReference, testCase.params);
            testCase.verifyEqual(failedError, 100 * ones(size(goodError)));
        end
    end

    methods
        function error = computeError(testCase, modelName, markerOffset, ...
                params)
            % IK error for a fixture model, with r_humerus1 moved by
            % markerOffset along x.
            model = Model(testDataPath("jmp", modelName + ".osim"));
            if markerOffset ~= 0
                location = model.getMarkerSet().get('r_humerus1') ...
                    .get_location();
                adjustMarkerPosition(model, 'r_humerus1', ...
                    location.get(0) + markerOffset, "x");
            end
            markersReference = makeJmpMarkerRef(model, testCase.markerFile, ...
                params);
            error = computeInnerOptimizationHeuristic(model, ...
                markersReference, params);
        end

        function error = innerOptimization(testCase, parentTranslationX)
            adjustX = makeJointFunction(testCase.expected.jointName, ...
                true, true, 0);
            error = computeInnerOptimization(parentTranslationX, {adjustX}, ...
                char(testDataPath("jmp", "simple_arm_translated_away.osim")), ...
                testCase.markerFile, testCase.params);
        end
    end
end
