% Checks that the JMP test fixtures in tests/data/jmp still match the
% values recorded in tests/helpers/jmpFixtureValues.m. If a fixture file is
% edited or corrupted, this fails first, instead of the parsing and
% regression tests failing for reasons that look like code bugs.

classdef (TestTags = {'Unit'}) JmpFixtureTest < matlab.unittest.TestCase

    properties
        expected
    end

    properties (TestParameter)
        % Each test below runs once per fixture model.
        fixture = struct( ...
            "truth", "simple_arm", ...
            "translatedAway", "simple_arm_translated_away", ...
            "orientedAway", "simple_arm_oriented_away")
    end

    methods (TestClassSetup)
        function loadExpectedValues(testCase)
            testCase.expected = jmpFixtureValues();
        end
    end

    methods (Test)
        function parentFrameMatchesRecordedValues(testCase, fixture)
            model = Model(testDataPath("jmp", fixture + ".osim"));
            fieldName = fixtureFieldName(fixture);
            jointName = testCase.expected.jointName;
            translation = arrayfun(@(axis) getFrameParameterValue(model, ...
                jointName, true, true, axis), 0:2);
            orientation = arrayfun(@(axis) getFrameParameterValue(model, ...
                jointName, true, false, axis), 0:2);
            testCase.verifyEqual(translation, testCase.expected. ...
                (fieldName).parentTranslation, "AbsTol", 1e-9);
            testCase.verifyEqual(orientation, testCase.expected. ...
                (fieldName).parentOrientation, "AbsTol", 1e-9);
        end

        function modelHasExpectedMarkers(testCase, fixture)
            model = Model(testDataPath("jmp", fixture + ".osim"));
            markerSet = model.getMarkerSet();
            names = strings(1, markerSet.getSize());
            for i = 1 : markerSet.getSize()
                names(i) = string(markerSet.get(i - 1).getName());
            end
            testCase.verifyEqual(sort(names), ...
                sort(testCase.expected.markerNames));
        end

        % Tests without a "fixture" argument run only once.
        function markerFileWasGeneratedFromTruthModel(testCase)
            % Inverse kinematics on the truth model should match the
            % markers almost exactly; this is what makes it the "truth".
            errors = computeMarkerErrors( ...
                testDataPath("jmp", "simple_arm.osim"), ...
                testDataPath("jmp", "simple_arm.trc"));
            testCase.verifyLessThan(max(errors), 1e-6);
        end

        function markerFileHasExpectedTimeRange(testCase)
            markersReference = MarkersReference( ...
                char(testDataPath("jmp", "simple_arm.trc")));
            timeRange = markersReference.getValidTimeRange();
            testCase.verifyEqual([timeRange.get(0), timeRange.get(1)], ...
                testCase.expected.markerFileTimeRange, "AbsTol", 1e-4);
        end

        function roundedTimesFileDiffersOnlyInItsTimes(testCase)
            % simple_arm_rounded_times.trc must hold the same markers as
            % simple_arm.trc, with each time rounded to 5 decimals. Line 1
            % (the file name) and the Time column are compared separately.
            exact = readTrcCells(testDataPath("jmp", "simple_arm.trc"));
            rounded = readTrcCells(testDataPath("jmp", ...
                "simple_arm_rounded_times.trc"));
            testCase.verifyEqual(rounded(2:end, [1 3:end]), ...
                exact(2:end, [1 3:end]));
            firstFrameRow = find(exact(:, 1) == "1", 1);
            exactTimes = str2double(exact(firstFrameRow:end, 2));
            roundedTimes = str2double(rounded(firstFrameRow:end, 2));
            testCase.verifyNumElements(roundedTimes, ...
                testCase.expected.markerFileNumFrames);
            testCase.verifyEqual(roundedTimes, round(exactTimes, ...
                testCase.expected.roundedTimesDecimals), "AbsTol", 1e-12);
        end
    end
end

function cells = readTrcCells(fileName)
lines = readlines(fileName, "EmptyLineRule", "skip");
cells = strings(numel(lines), max(count(lines, sprintf("\t"))) + 1);
for i = 1:numel(lines)
    fields = split(lines(i), sprintf("\t"))';
    cells(i, 1:numel(fields)) = fields;
end
end

function fieldName = fixtureFieldName(fixture)
switch fixture
    case "simple_arm"
        fieldName = "truth";
    case "simple_arm_translated_away"
        fieldName = "translatedAway";
    case "simple_arm_oriented_away"
        fieldName = "orientedAway";
end
end

function errors = computeMarkerErrors(modelFile, markerFile)
import org.opensim.modeling.InverseKinematicsSolver
import org.opensim.modeling.SimTKArrayCoordinateReference
[model, state] = Model(modelFile);
markersReference = MarkersReference(char(markerFile));
solver = InverseKinematicsSolver(model, markersReference, ...
    SimTKArrayCoordinateReference());
solver.setAccuracy(1e-8);
times = markersReference.getMarkerTable().getIndependentColumn();
state.setTime(double(times.get(0)));
solver.assemble(state);
errors = [];
for i = 0 : times.size() - 1
    state.setTime(double(times.get(i)));
    solver.track(state);
    for marker = 0 : solver.getNumMarkersInUse() - 1
        errors(end + 1) = solver.computeCurrentMarkerError(marker);
    end
end
end
