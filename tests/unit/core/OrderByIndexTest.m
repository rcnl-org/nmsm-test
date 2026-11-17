% Tests for src/core/parse/orderByIndex.m, which the JMP parser uses to put
% <JMPTask> elements in the order given by their <index> element.
% Ported from legacy/tests/core/parse/testIndexElement.m.

classdef (TestTags = {'Unit'}) OrderByIndexTest < matlab.unittest.TestCase

    methods (Test)
        function preorderedTasksKeepOrder(testCase)
            tasks = {makeTask("1", "one"), makeTask("2", "two"), ...
                makeTask("3", "three")};
            ordered = orderByIndex(tasks);
            testCase.verifyEqual(taskNames(ordered), ["one", "two", "three"]);
        end

        function outOfOrderTasksAreSorted(testCase)
            tasks = {makeTask("2", "two"), makeTask("1", "one"), ...
                makeTask("3", "three")};
            ordered = orderByIndex(tasks);
            testCase.verifyEqual(taskNames(ordered), ["one", "two", "three"]);
        end

        function multiDigitIndicesSortNumerically(testCase)
            % "10" must come after "9"; a text sort would put it first.
            tasks = {makeTask("10", "ten"), makeTask("9", "nine")};
            ordered = orderByIndex(tasks);
            testCase.verifyEqual(taskNames(ordered), ["nine", "ten"]);
        end

        function duplicateIndicesKeepFileOrder(testCase)
            tasks = {makeTask("1", "first"), makeTask("1", "second")};
            ordered = orderByIndex(tasks);
            testCase.verifyEqual(taskNames(ordered), ["first", "second"]);
        end

        function singleTaskIsReturnedUnchanged(testCase)
            % xml2struct gives a struct (not a cell) when there is only one
            % <JMPTask>, and that task does not need an <index>.
            task = struct("name", "only");
            testCase.verifyEqual(orderByIndex(task), task);
        end

        function missingIndexThrows(testCase)
            tasks = {makeTask("2", "two"), struct("name", "one"), ...
                makeTask("3", "three")};
            % orderByIndex throws an MException with no identifier, so the
            % error is checked by message (see tests/helpers).
            verifyErrorMessage(testCase, @() orderByIndex(tasks), ...
                "<index> element not included for task");
        end
    end
end

function task = makeTask(index, name)
task = struct("index", struct("Text", index), "name", name);
end

function names = taskNames(tasks)
names = cellfun(@(task) string(task.name), tasks);
end
