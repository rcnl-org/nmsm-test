% This function reads a .sto file without using nmsm-core, so fixture
% checks do not depend on the code they are testing. It accepts both
% OpenSim header styles used in the fixtures (version=1 and version=3):
% everything up to the "endheader" line is skipped, the next line is the
% column names, and the rest is numbers.
%
% Example: [data, names] = readStoFile(testDataPath("mtp", ...
%              "preprocessed", "IDData", "gait_1.sto"))
%
% (string) -> (2D matrix of number, string array)

function [data, columnNames] = readStoFile(fileName)
lines = strtrim(readlines(fileName));
headerEnd = find(startsWith(lines, "endheader"), 1);
assert(~isempty(headerEnd), "No endheader line in " + fileName)
columnNames = split(lines(headerEnd + 1))';
rows = lines(headerEnd + 2 : end);
rows = rows(strlength(rows) > 0);
data = zeros(length(rows), length(columnNames));
for i = 1 : length(rows)
    data(i, :) = str2double(split(rows(i)))';
end
end
