% This function returns the cost term types a cost function handles, read
% from the case labels of its switch statement, so the term smoke tests
% cover a term as soon as it is added to the tool.
%
% Example: costTermTypes("calcNcpCost")
%
% (string) -> (string array)

function types = costTermTypes(functionName)
source = fileread(which(functionName));
types = string(regexp(source, "case [""']([a-z_]+)[""']", "tokens"));
types = unique(reshape(types, 1, []), "stable");
end
