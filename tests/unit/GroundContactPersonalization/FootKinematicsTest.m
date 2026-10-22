% Tests for how GCP represents the foot's motion and places its springs
% (src/GroundContactPersonalization/Modeling):
% - calcGCPJointKinematics fits the experimental joint positions with
%   B-splines and multiplies each node by a "deviation" coefficient, the
%   design variable that lets GCP adjust the motion (1 = no change);
% - the spring grid helpers build and transform the normalized grid of
%   spring locations under the foot.

classdef (TestTags = {'Unit'}) FootKinematicsTest < matlab.unittest.TestCase

    methods (Test)
        function unitCoefficientsReproduceTheBSplineFit(testCase)
            % A smooth motion within the B-spline space is reproduced
            % exactly, and its velocity is the derivative.
            time = linspace(0, 1, 101);
            splines = makeJointKinematicsBSplines(time, 4, 12);
            experimental = [sin(time); time .^ 2; repmat(0.1, 5, 101)];
            [positions, velocities] = calcGCPJointKinematics( ...
                experimental, splines, ones(12, 7));
            testCase.verifySize(positions, [7, 101]);
            testCase.verifyEqual(positions, experimental, "AbsTol", 1e-5);
            testCase.verifyEqual(velocities(2, 20 : 80), 2 * time(20 : 80), ...
                "AbsTol", 1e-3);
        end

        function coefficientsScaleTheFittedNodes(testCase)
            % Doubling every coefficient of one coordinate doubles it.
            time = linspace(0, 1, 101);
            splines = makeJointKinematicsBSplines(time, 4, 12);
            experimental = [sin(time); repmat(0.1, 6, 101)];
            coefficients = ones(12, 7);
            coefficients(:, 1) = 2;
            positions = calcGCPJointKinematics(experimental, splines, ...
                coefficients);
            testCase.verifyEqual(positions(1, :), 2 * experimental(1, :), ...
                "AbsTol", 1e-5);
            testCase.verifyEqual(positions(2 : 7, :), experimental(2 : 7, :), ...
                "AbsTol", 1e-5);
        end

        function normalizedGridCoversTheFoot(testCase)
            % cellsWide columns at cell centers across [0, 1], cellsLong
            % rows from 0 to 1 along the foot.
            points = makeNormalizedGrid(4, 3, false);
            testCase.verifySize(points, [12, 2]);
            testCase.verifyEqual(unique(points(:, 1))', [1 3 5 7] / 8, ...
                "AbsTol", 1e-12);
            testCase.verifyEqual(unique(points(:, 2))', [0, 0.5, 1], ...
                "AbsTol", 1e-12);
        end

        function leftFootGridIsMirrored(testCase)
            right = makeNormalizedGrid(4, 3, false);
            left = makeNormalizedGrid(4, 3, true);
            testCase.verifyEqual(left(:, 1), 1 - right(:, 1), "AbsTol", 1e-12);
            testCase.verifyEqual(left(:, 2), right(:, 2));
        end

        function rotate2DTurnsCounterclockwise(testCase)
            [x, y] = rotateValues2D(1, 0, pi / 2);
            testCase.verifyEqual([x, y], [0, 1], "AbsTol", 1e-12);
        end

        function markersAreNormalizedByFootSize(testCase)
            % Lengths along the foot are divided by the toe-heel
            % distance, widths by the medial-lateral distance; then the
            % heel and the more lateral of the two side markers sit at 0.
            markers = struct("toe", [0.25, 0.01], "heel", [0.05, 0.02], ...
                "medial", [0.2, -0.03], "lateral", [0.18, 0.05]);
            normalized = normalizeMarkerPositions(markers);
            testCase.verifyEqual(normalized.toe, [1.25, 0.125], ...
                "AbsTol", 1e-12);
            shifted = removeNormalizedMarkerOffsets(normalized);
            testCase.verifyEqual(shifted.heel(1), 0, "AbsTol", 1e-12);
            testCase.verifyEqual(min(shifted.medial(2), shifted.lateral(2)), ...
                0, "AbsTol", 1e-12);
            testCase.verifyEqual(shifted.toe(1) - shifted.heel(1), 1, ...
                "AbsTol", 1e-12);
        end
    end
end
