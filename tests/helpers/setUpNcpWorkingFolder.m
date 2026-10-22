% This function moves the test into a new temporary folder containing the
% NCP fixtures and the given settings files (see copyNcpFixtures). The
% folder is deleted and the previous current folder restored when the test
% (or, from TestClassSetup, the test class) ends.
%
% NCP resolves <input_model_file>, <input_osimx_file>, <data_directory>,
% <mtp_results_directory> and <results_directory> relative to the current
% folder, and writes files there, so parsing and full-run tests must not
% run inside the repository.
%
% Example: setUpNcpWorkingFolder(testCase, "settings_minimal.xml")
%
% (matlab.unittest.TestCase, string array) -> (string)

function folder = setUpNcpWorkingFolder(testCase, settingsFileNames)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.WorkingFolderFixture);
folder = string(fixture.Folder);
copyNcpFixtures(folder, settingsFileNames);
end
