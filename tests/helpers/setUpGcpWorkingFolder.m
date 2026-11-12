% This function moves the test into a new temporary folder containing the
% GCP fixtures and the given settings files (see copyGcpFixtures). The
% folder is deleted and the previous current folder restored when the test
% (or, from TestClassSetup, the test class) ends.
%
% GCP resolves its model and data files relative to the current folder
% (or <input_directory>) and writes foot models, MEX copies and results
% there, so parsing and full-run tests must not run inside the repository.
%
% Example: setUpGcpWorkingFolder(testCase, "settings_minimal.xml")
%
% (matlab.unittest.TestCase, string array) -> (string)

function folder = setUpGcpWorkingFolder(testCase, settingsFileNames)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.WorkingFolderFixture);
folder = string(fixture.Folder);
copyGcpFixtures(folder, settingsFileNames);
end
