% This function moves the test into a new temporary folder containing one
% Treatment Optimization problem's fixtures and the given settings files
% (see copyToFixtures). The folder is deleted and the previous current
% folder restored when the test (or, from TestClassSetup, the test class)
% ends.
%
% Treatment Optimization resolves its model, data and solver settings files
% relative to the current folder and writes files there and next to the
% model, so parsing and full-run tests must not run inside the repository.
%
% Example: setUpToWorkingFolder(testCase, "torque", "settings_tracking_torque_minimal.xml")
%
% (matlab.unittest.TestCase, string, string array) -> (string)

function folder = setUpToWorkingFolder(testCase, problem, settingsFileNames)
arguments
    testCase (1, 1) matlab.unittest.TestCase
    problem (1, 1) string
    settingsFileNames (1, :) string = strings(1, 0)
end
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.WorkingFolderFixture);
folder = string(fixture.Folder);
copyToFixtures(folder, problem, settingsFileNames);
end
