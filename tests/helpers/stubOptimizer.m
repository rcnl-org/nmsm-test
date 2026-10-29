% This function replaces an optimization function with a stand-in that
% records the arguments of each call and returns one of them unchanged, so
% a tool can be run through all of its preparation up to the optimizer
% without optimizing. The stand-in is written to a temporary folder put
% at the front of the path for the rest of the test (or test class).
% optimizerCalls returns the recorded calls.
%
% Used by the term smoke tests: the recorded arguments are exactly what
% the tool gives its optimizer, so its objective can then be evaluated with
% one cost term at a time.
%
% Example: stubOptimizer(testCase, "lsqnonlin", 2) % returns x0
%
% (matlab.unittest.TestCase, string, number) -> (None)

function stubOptimizer(testCase, functionName, returnedArgument)
folder = string(testCase.createTemporaryFolder());
writelines(["function varargout = " + functionName + "(varargin)"; ...
    "calls = getappdata(groot, ""nmsmTestOptimizerCalls"");"; ...
    "calls{end + 1} = varargin;"; ...
    "setappdata(groot, ""nmsmTestOptimizerCalls"", calls);"; ...
    "varargout{1} = varargin{" + returnedArgument + "};"; ...
    "for i = 2 : nargout"; "    varargout{i} = [];"; "end"; "end"], ...
    fullfile(folder, functionName + ".m"));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
setappdata(groot, "nmsmTestOptimizerCalls", {});
testCase.addTeardown(@() setappdata(groot, "nmsmTestOptimizerCalls", {}));
end
