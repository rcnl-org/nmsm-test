% Tests for the shared synergy group helpers in src/core used by NCP's
% parser: verifyNoDuplicateMusclesBetweenSynergyGroups and
% matchMuscleNamesFromCoordinatesAndSynergyGroups, which decide which
% muscles NCP models and in what order.

classdef (TestTags = {'Unit'}) SynergyGroupsTest < matlab.unittest.TestCase

    properties
        expected
    end

    methods (TestClassSetup)
        function loadFixtureValues(testCase)
            testCase.expected = ncpFixtureValues();
        end
    end

    methods (Test)
        function separateGroupsAreAccepted(testCase)
            groups = {struct("muscleNames", ["a", "b"]), ...
                struct("muscleNames", "c")};
            testCase.verifyWarningFree( ...
                @() verifyNoDuplicateMusclesBetweenSynergyGroups(groups));
        end

        function duplicateMuscleIsNamed(testCase)
            groups = {struct("muscleNames", ["a", "b"]), ...
                struct("muscleNames", ["c", "b"])};
            verifyErrorMessage(testCase, ...
                @() verifyNoDuplicateMusclesBetweenSynergyGroups(groups), ...
                'duplicate muscle "b"');
        end

        function musclesFollowSynergyGroupOrder(testCase)
            % Two groups splitting the nine muscles, listed in a different
            % order from the coordinate-based muscle list: the result
            % follows the groups.
            names = testCase.expected.muscleNames;
            inputs = fixtureInputs(names);
            inputs.synergyGroups = {struct("muscleNames", names(6 : 9)), ...
                struct("muscleNames", names(1 : 5))};
            matched = matchMuscleNamesFromCoordinatesAndSynergyGroups(inputs);
            testCase.verifyEqual(matched.muscleNames, [names(6 : 9), names(1 : 5)]);
            testCase.verifyEqual(matched.synergyGroups{1}.muscleNames, names(6 : 9));
        end

        function groupMusclesNotCrossingCoordinatesAreDropped(testCase)
            % A synergy group may contain muscles NCP does not need; they
            % are removed from the group.
            names = testCase.expected.muscleNames;
            inputs = fixtureInputs(names(1 : 8));
            inputs.synergyGroups = {struct("muscleNames", names)};
            matched = matchMuscleNamesFromCoordinatesAndSynergyGroups(inputs);
            testCase.verifyEqual(matched.synergyGroups{1}.muscleNames, ...
                names(1 : 8));
        end

        function muscleOutsideEverySynergyGroupIsNamed(testCase)
            names = testCase.expected.muscleNames;
            inputs = fixtureInputs(names);
            inputs.synergyGroups = {struct("muscleNames", ...
                names(names ~= "iliacus_r"))};
            verifyErrorMessage(testCase, ...
                @() matchMuscleNamesFromCoordinatesAndSynergyGroups(inputs), ...
                "iliacus_r");
        end
    end
end

function inputs = fixtureInputs(muscleNames)
inputs.model = char(testDataPath("mtp", ncpFixtureValues().modelFileName));
inputs.muscleNames = muscleNames;
end
