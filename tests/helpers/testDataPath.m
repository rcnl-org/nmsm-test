% This function returns the absolute path to a file or folder inside
% tests/data, so tests do not depend on the current working directory.
%
% Example: testDataPath("jmp", "simple_arm.osim")
%
% (string, string, ...) -> (string)

function fullPath = testDataPath(varargin)
testsDirectory = fileparts(fileparts(mfilename("fullpath")));
fullPath = string(fullfile(testsDirectory, "data", varargin{:}));
end
