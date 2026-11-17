% This function returns the calls recorded by a stand-in optimizer (see
% stubOptimizer): a cell array with one cell array of arguments per call.
%
% () -> (Cell array of cell arrays)

function calls = optimizerCalls()
calls = getappdata(groot, "nmsmTestOptimizerCalls");
end
