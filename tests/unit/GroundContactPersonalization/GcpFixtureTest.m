% Checks that the GCP test fixtures in tests/data/gcp (and the IK file
% shared with tests/data/mtp) still match the values recorded in
% tests/helpers/gcpFixtureValues.m. If a fixture file is edited or
% corrupted, this fails first, instead of the parsing and regression tests
% failing for reasons that look like code bugs.

classdef (TestTags = {'Unit'}) GcpFixtureTest < matlab.unittest.TestCase

    properties
        expected
        model
    end

    methods (TestClassSetup)
        function loadFixtures(testCase)
            testCase.expected = gcpFixtureValues();
            testCase.model = Model(testDataPath("gcp", ...
                testCase.expected.modelFileName));
        end
    end

    methods (Test)
        function footIsTwoSegmentsJoinedByAPinJoint(testCase)
            % GCP requires a hindfoot and a toes body joined by a joint
            % with one coordinate.
            joint = testCase.model.getJointSet().get( ...
                char(testCase.expected.toesJoint));
            testCase.verifyEqual(joint.numCoordinates(), 1);
            testCase.verifyEqual(string(joint.getCoordinate().getName()), ...
                testCase.expected.toesCoordinate);
            testCase.verifyEqual(string(joint.getParentFrame() ...
                .findBaseFrame().getName()), testCase.expected.hindfootBody);
            testCase.verifyEqual(string(joint.getChildFrame() ...
                .findBaseFrame().getName()), testCase.expected.toesBody);
        end

        function footMarkersAreOnTheFoot(testCase)
            markers = testCase.expected.markers;
            bodies = testCase.expected.markerBodies;
            for field = string(fieldnames(markers))'
                marker = testCase.model.getMarkerSet().get( ...
                    char(markers.(field)));
                testCase.verifyEqual(string(marker.getParentFrame() ...
                    .findBaseFrame().getName()), bodies.(field), field);
            end
        end

        function grfAndIkShareOneTimeGrid(testCase)
            grf = readStoFile(grfFile());
            ik = readStoFile(testDataPath("mtp", "preprocessed", "IKData", ...
                testCase.expected.trialName + ".sto"));
            testCase.verifySize(grf, [testCase.expected.numFrames, 19]);
            testCase.verifyEqual(grf(:, 1), ik(:, 1), "AbsTol", 1e-9);
            testCase.verifyEqual(grf([1, end], 1)', ...
                testCase.expected.timeRange, "AbsTol", 1e-9);
        end

        function grfHasTheRightFootColumns(testCase)
            [~, names] = readStoFile(grfFile());
            columns = [testCase.expected.forceColumns, ...
                testCase.expected.momentColumns, ...
                testCase.expected.electricalCenterColumns];
            testCase.verifyTrue(all(ismember(columns, names)));
        end

        function rightFootHasAStancePhase(testCase)
            % The trial covers one gait cycle of the right foot: its
            % vertical force is near body weight in stance and about zero
            % in swing.
            [grf, names] = readStoFile(grfFile());
            vertical = grf(:, names == testCase.expected.forceColumns(2));
            testCase.verifyGreaterThan(max(vertical), 500);
            testCase.verifyLessThan(min(vertical), 20);
        end
    end
end

function fileName = grfFile()
fileName = testDataPath("gcp", "preprocessed", "GRFData", ...
    gcpFixtureValues().trialName + ".sto");
end
