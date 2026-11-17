% This function unloads the pointKinematics MEX copies GCP leaves in a
% folder (and its subfolders), so the folder can be deleted. Use it as a
% teardown after setUpGcpWorkingFolder or a WorkingFolderFixture.
%
% Example: testCase.addTeardown(@clearGcpMexFiles, folder)
%
% (string) -> (None)

function clearGcpMexFiles(folder)
for file = dir(fullfile(folder, "**", "*.mexw64"))'
    clear(erase(file.name, ".mexw64"))
end
end
