% This function moves the test into a new temporary folder containing the
% MTP fixtures and the given settings files (see copyMtpFixtures). The
% folder is deleted and the previous current folder restored when the test
% (or, from TestClassSetup, the test class) ends.
%
% MTP resolves <input_model_file>, <data_directory>,
% <passive_data_input_directory> and <results_directory> relative to the
% current folder, and writes files there, so parsing and full-run tests
% must not run inside the repository.
%
% Example: setUpMtpWorkingFolder(testCase, "settings_minimal.xml")
%
% (matlab.unittest.TestCase, string array) -> (string)

function folder = setUpMtpWorkingFolder(testCase, settingsFileNames)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.WorkingFolderFixture);
folder = string(fixture.Folder);
copyMtpFixtures(folder, settingsFileNames);
end
