% This function verifies that calling fn throws an error whose message
% contains expectedText. Use it instead of verifyError(fn, ?MException)
% for NMSM Pipeline functions that throw MExceptions with no identifier:
% checking only the class would also accept an unrelated crash.
%
% Example: verifyErrorMessage(testCase, @() verifyNumeric('a'), "not numeric")
%
% (matlab.unittest.TestCase, function_handle, string) -> (None)

function verifyErrorMessage(testCase, fn, expectedText)
try
    fn();
catch exception
    testCase.verifySubstring(string(exception.message), ...
        string(expectedText), "The error thrown was not the expected one.");
    return
end
testCase.verifyFail("Expected an error containing """ + expectedText + ...
    """, but no error was thrown.");
end
