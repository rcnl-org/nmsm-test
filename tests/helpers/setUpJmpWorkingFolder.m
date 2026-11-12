% This function moves the test into a new temporary folder containing the
% JMP fixture models, the marker file, and the given settings files. The
% folder is deleted and the previous current folder restored when the test
% ends.
%
% JMP resolves <input_model_file>, <marker_file_name>, <results_directory>
% and <output_model_file> relative to the current folder, and writes files
% there, so parsing and full-run tests must not run inside the repository.
%
% Example: setUpJmpWorkingFolder(testCase, "settings_minimal.xml")
%
% (matlab.unittest.TestCase, string array) -> (string)

function folder = setUpJmpWorkingFolder(testCase, settingsFileNames)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.WorkingFolderFixture);
folder = string(fixture.Folder);
dataFolder = testDataPath("jmp");
copyfile(fullfile(dataFolder, "*.osim"), folder);
copyfile(fullfile(dataFolder, "*.trc"), folder);
for name = settingsFileNames
    copyfile(fullfile(dataFolder, "settings", name), folder);
end
end
