% This function returns whether GPOPS-II can be used: gpops2 is on the path
% and gpops2License reports an expiration date that has not passed. GPOPS-II
% is installed and licensed separately from nmsm-core, and Treatment
% Optimization on candidate-1.5.4 calls it even while preparing its inputs.
%
% Tests that need GPOPS-II should assume it in TestClassSetup, so a machine
% without a license reports them as not run, with the reason, instead of
% failing deep inside a tool:
%   testCase.assumeTrue(gpopsIsLicensed(), "GPOPS-II is not licensed here.")
%
% () -> (logical)

function licensed = gpopsIsLicensed()
licensed = false;
if ~exist("gpops2", "file") || ~exist("gpops2License", "file")
    return
end
try
    report = evalc("gpops2License()");
catch
    return
end
% "License Expiration Date [year, month, day] : [2027, 2, 10]"
date = regexp(report, "Expiration Date[^:]*:\s*\[(\d+),\s*(\d+),\s*(\d+)\]", ...
    "tokens", "once");
if isempty(date)
    return
end
expiration = datetime(str2double(date{1}), str2double(date{2}), ...
    str2double(date{3}));
licensed = datetime("today") <= expiration;
end
