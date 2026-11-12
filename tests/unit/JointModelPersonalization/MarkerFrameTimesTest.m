% Tests for the marker frames JMP's IK runs on: getMarkerFrameTimes, and
% the per-marker error report (reportDistanceErrorByMarker) that uses it.
%
% Ground truths used:
% - simple_arm.trc has 120 frames at 60 Hz, at times (k - 1) / 60.
% - simple_arm_rounded_times.trc is the same file with its times rounded to
%   5 decimals. Stepping from frame to frame by adding 1/60 s to a rounded
%   time overshoots the last frame's rounded time, so a frame loop built
%   that way skips the last frame. Every frame must still be used.
% - A time range keeps the frames inside it, plus a frame within half a
%   frame of either end, so a range typed with fewer decimals than the
%   file still includes its end frames.

classdef (TestTags = {'Unit'}) MarkerFrameTimesTest < matlab.unittest.TestCase

    properties
        expected
    end

    properties (TestParameter)
        markerFile = struct( ...
            "exact", "simple_arm.trc", ...
            "rounded", "simple_arm_rounded_times.trc")
    end

    methods (TestClassSetup)
        function loadFixtureValues(testCase)
            testCase.expected = jmpFixtureValues();
        end
    end

    methods (Test)
        function everyFrameIsUsedByDefault(testCase, markerFile)
            frameTimes = getMarkerFrameTimes(markersReferenceFor(markerFile));
            testCase.verifyNumElements(frameTimes, ...
                testCase.expected.markerFileNumFrames);
            testCase.verifyEqual(frameTimes([1 end]), ...
                testCase.expected.markerFileTimeRange, "AbsTol", 1e-4);
        end

        function timeRangeIncludesBothEndFrames(testCase, markerFile)
            % 0.5 s and 1.0 s are frames 31 and 61, so 31 frames.
            frameTimes = getMarkerFrameTimes( ...
                markersReferenceFor(markerFile), 0.5, 1.0);
            testCase.verifyNumElements(frameTimes, 31);
            testCase.verifyEqual(frameTimes([1 end]), [0.5 1.0], ...
                "AbsTol", 1e-9);
        end

        function timeRangeEndsMatchTheNearestFrame(testCase, markerFile)
            % 0.5167 s is 31/60 s typed to 4 decimals, just after the
            % frame, and 0.9833 s is 59/60 s, just before it, so exact
            % comparisons would leave out both end frames. 29 frames.
            frameTimes = getMarkerFrameTimes( ...
                markersReferenceFor(markerFile), 0.5167, 0.9833);
            testCase.verifyNumElements(frameTimes, 29);
            testCase.verifyEqual(frameTimes([1 end]), [31 59] / 60, ...
                "AbsTol", 1e-5);
        end

        function timeRangeWithoutFramesIsReported(testCase)
            verifyErrorMessage(testCase, @() getMarkerFrameTimes( ...
                markersReferenceFor("simple_arm.trc"), 5, 6), ...
                "No marker frames are in the time range");
        end

        function nonNumericTimeRangeIsReported(testCase)
            % A <time_range> that is not numeric parses as NaN.
            verifyErrorMessage(testCase, @() getMarkerFrameTimes( ...
                markersReferenceFor("simple_arm.trc"), NaN, NaN), ...
                "No marker frames are in the time range NaN to NaN s.");
        end

        function errorReportHasEveryFrame(testCase, markerFile)
            % The report wrote one row fewer than the file's frames, even
            % without rounded times.
            testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            reportDistanceErrorByMarker( ...
                char(testDataPath("jmp", "simple_arm.osim")), ...
                char(testDataPath("jmp", markerFile)), ...
                testCase.expected.markerNames, "errors.sto");
            times = readStorageTimes("errors.sto");
            testCase.verifyNumElements(times, ...
                testCase.expected.markerFileNumFrames);
            testCase.verifyEqual(times([1 end]), ...
                testCase.expected.markerFileTimeRange, "AbsTol", 1e-4);
        end

        function errorReportUsesTheTimeRange(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            reportDistanceErrorByMarker( ...
                char(testDataPath("jmp", "simple_arm.osim")), ...
                char(testDataPath("jmp", "simple_arm_rounded_times.trc")), ...
                testCase.expected.markerNames, "errors.sto", [0.5 1.0]);
            times = readStorageTimes("errors.sto");
            testCase.verifyNumElements(times, 31);
            testCase.verifyEqual(times([1 end]), [0.5 1.0], "AbsTol", 1e-9);
        end
    end
end

function markersReference = markersReferenceFor(markerFile)
markersReference = MarkersReference(char(testDataPath("jmp", markerFile)));
end

function times = readStorageTimes(fileName)
storage = org.opensim.modeling.Storage(fileName);
timeColumn = org.opensim.modeling.ArrayDouble();
storage.getTimeColumn(timeColumn);
times = zeros(1, timeColumn.getSize());
for i = 1:numel(times)
    times(i) = timeColumn.get(i - 1);
end
end
