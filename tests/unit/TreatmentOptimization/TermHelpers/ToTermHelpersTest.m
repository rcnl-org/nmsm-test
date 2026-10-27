% Tests for the helpers Treatment Optimization's terms share
% (src/TreatmentOptimization/TermHelpers): time ranges, relative errors,
% time normalization, center of pressure, rotation sequences, and finding
% data columns, synergies and synergy weights by name. Expected values are
% worked out by hand.

classdef (TestTags = {'Unit'}) ToTermHelpersTest < matlab.unittest.TestCase

    methods (Test)
        % ---- time ranges and normalization ------------------------------

        function timeRangesKeepThePointsInside(testCase)
            % Time 0 to 1 s in quarters, ranges [0, 0.25] and [0.75, 1]
            % (normalized time): the middle point and its neighbors
            % inside neither range are zeroed.
            time = (0 : 0.25 : 1)';
            values = (1 : 5)';
            [kept, term] = applyTermTimeRanges(values, ...
                struct("time_ranges", "0 0.25 0.75 1"), time);
            testCase.verifyEqual(kept, [1; 2; 0; 4; 5]);
            testCase.verifyEqual(term.time_ranges, [0; 0.25; 0.75; 1]);
        end

        function timeRangesUseNormalizedTime(testCase)
            % Final time 2 s: range [0, 0.5] is the first second.
            time = (0 : 0.5 : 2)';
            kept = applyTermTimeRanges((1 : 5)', struct("time_ranges", ...
                "0 0.5"), time);
            testCase.verifyEqual(kept, [1; 2; 3; 0; 0]);
        end

        function badTimeRangesAreReported(testCase)
            time = (0 : 0.25 : 1)';
            verifyErrorMessage(testCase, @() applyTermTimeRanges( ...
                ones(5, 1), struct("time_ranges", "0 0.5 0.7"), time), ...
                "even number");
            verifyErrorMessage(testCase, @() applyTermTimeRanges( ...
                ones(5, 1), struct("time_ranges", "0.5 0.2"), time), ...
                "strictly increasing");
            verifyErrorMessage(testCase, @() applyTermTimeRanges( ...
                ones(5, 1), struct("time_ranges", "0 2"), time), ...
                "greater than 1");
        end

        function relativeErrorDividesByAtLeastTheMinimum(testCase)
            % Reference values 10 and 0.5 with the default minimum of 1:
            % errors divided by 10 and by 1.
            relative = applyPercentErrorWithMinimum([2; 2], [10; 0.5], ...
                struct("use_relative_error", true));
            testCase.verifyEqual(relative, [0.2; 2]);
            absolute = applyPercentErrorWithMinimum([2; 2], [10; 0.5], ...
                struct());
            testCase.verifyEqual(absolute, [2; 2]);
        end

        function finalTimeNormalizationDefaultsOnAndIsRecorded(testCase)
            inputs.collocationTimeOriginal = [0; 1; 2];
            [time, term] = normalizeTimeColumn(struct(), inputs, ...
                [0; 1; 2], true);
            testCase.verifyTrue(term.normalize_by_final_time);
            testCase.verifyEqual(time, [0; 1; 2]);
            testCase.verifyEqual(normalizeCostByFinalTime(term, inputs, ...
                time, [4; 4; 4]), [2; 2; 2]);
        end

        function finalTimeNormalizationCanBeTurnedOff(testCase)
            inputs.collocationTimeOriginal = [0; 1; 2];
            [~, term] = normalizeTimeColumn(struct( ...
                "normalize_by_final_time", false), inputs, [0; 1; 2], true);
            testCase.verifyEqual(normalizeCostByFinalTime(term, inputs, ...
                [0; 1; 2], [4; 4; 4]), [4; 4; 4]);
        end

        % ---- center of pressure and rotations ---------------------------

        function centerOfPressureAlongX(testCase)
            % x = point_x + Mz / (Fy + sign(Fy)): 1 + 10 / 100.
            cop = calcCenterOfPressureForTermAxis(copTerm('x'), ...
                [0, 99, 0], [0, 0, 10], [1, 0, 2]);
            testCase.verifyEqual(cop, 1.1, "AbsTol", 1e-14);
        end

        function centerOfPressureAlongZ(testCase)
            % z = point_z - Mx / (Fy + sign(Fy)): 2 - 5 / 100.
            cop = calcCenterOfPressureForTermAxis(copTerm('z'), ...
                [0, 99, 0], [5, 0, 0], [1, 0, 2]);
            testCase.verifyEqual(cop, 1.95, "AbsTol", 1e-14);
        end

        function centerOfPressureHasNoYAxis(testCase)
            verifyErrorMessage(testCase, @() ...
                calcCenterOfPressureForTermAxis(copTerm('y'), ...
                [0, 99, 0], [0, 0, 0], [0, 0, 0]), "does not use the Y axis");
        end

        function xyzAnglesAreUnchanged(testCase)
            angles = [0.1, -0.2, 0.3];
            testCase.verifyEqual(convertAnglesToSequence(angles, 'xyz'), ...
                angles);
        end

        function singleAxisRotationKeepsItsAngle(testCase)
            % A rotation about z alone is the same angle in any sequence
            % (z is the first angle in zxy and zyx, the last in the
            % others).
            angles = [0, 0, 0.4];
            testCase.verifyEqual(convertAnglesToSequence(angles, 'xzy'), ...
                [0, 0.4, 0], "AbsTol", 1e-14);
            testCase.verifyEqual(convertAnglesToSequence(angles, 'zyx'), ...
                [0.4, 0, 0], "AbsTol", 1e-14);
        end

        function unknownSequenceIsReported(testCase)
            verifyErrorMessage(testCase, @() convertAnglesToSequence( ...
                [0, 0, 0], 'xxy'), "not supported");
        end

        % ---- finding columns, synergies and weights ---------------------

        function dataIndicesFollowTheTargetOrder(testCase)
            testCase.verifyEqual(findDataIndicesByLabels(["a", "b", "c"], ...
                ["c", "a"]), [3, 1]);
            verifyErrorMessage(testCase, @() findDataIndicesByLabels( ...
                ["a", "b"], "z"), "z is not in");
        end

        function optionalIndicesAreMinusOneWhenMissing(testCase)
            testCase.verifyEqual(findOptionalDataIndicesByLabels( ...
                ["a", "b"], ["b", "z"]), [2, -1]);
        end

        function loadNamesMapToCoordinates(testCase)
            testCase.verifyEqual(findCoordinateIndicesFromLoadNames( ...
                ["a", "b"], ["b_moment", "a_force", "c_moment"]), [2, 1, -1]);
        end

        function synergyNamesCountAcrossGroups(testCase)
            % Groups A (2 synergies) and B (3): "B_2" is the fourth.
            inputs.synergyGroups = {struct("muscleGroupName", "A", ...
                "numSynergies", 2), struct("muscleGroupName", "B", ...
                "numSynergies", 3)};
            [index, term] = findSynergyIndexByLabel(struct(), inputs, "B_2");
            testCase.verifyEqual(index, 4);
            testCase.verifyEqual(term.internalSynergyIndices, 4);
        end

        function synergyNamesNeedAGroupAndNumber(testCase)
            inputs.synergyGroups = {struct("muscleGroupName", "A", ...
                "numSynergies", 2)};
            verifyErrorMessage(testCase, @() findSynergyIndexByLabel( ...
                struct(), inputs, "A"), "<group name>_<index>");
            verifyErrorMessage(testCase, @() findSynergyIndexByLabel( ...
                struct(), inputs, "C_1"), "Unable to find synergy C_1");
        end

        function synergyWeightColumnsAreTheGroupsMuscles(testCase)
            % Groups A (2 synergies over 3 muscles) and B (2 synergies
            % over 4 muscles): A's synergies use weight columns 1-3 and
            % B's columns 4-7.
            % Expected to fail on candidate-1.5.4:
            % findSynergyWeightIndicesByIndex does not stop at the
            % synergy's group, so a synergy in an earlier group gets the
            % column count of the last group (here 1-4 instead of 1-3).
            % It only matters when groups have different numbers of
            % muscles. See tests/README.md.
            inputs.synergyGroups = {struct("numSynergies", 2, ...
                "muscleNames", ["a1", "a2", "a3"]), struct( ...
                "numSynergies", 2, "muscleNames", ["b1", "b2", "b3", "b4"])};
            term.internalSynergyIndices = [1, 3];
            indices = findSynergyWeightIndicesByIndex(term, inputs);
            testCase.verifyEqual(indices, {[1, 3], [4, 7]});
        end
    end
end

function term = copTerm(axes)
% A center of pressure term for one axis. Every term has a type, which
% getTermFieldOrError uses in its message.
term = struct("type", 'center_of_pressure_tracking', "axes", axes);
end
