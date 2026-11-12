% This function runs one Treatment Optimization case for the regression
% tests: it copies the problem's fixtures and the settings file into the
% folder, switches the settings to the small GPOPS-II settings
% (gpops_small.xml), prepares the problem once to record its bounds
% (prepareToProblem), then runs the tool named in the settings file, and
% returns what the checks need:
%   error - the tool's error message, or "" if it ran
%   output - the command window output
%   exit - IPOPT's EXIT line, e.g. "EXIT: Optimal Solution Found."
%   bounds - minState, maxState, minControl, maxControl (real units),
%       minPath, maxPath, minTerminal, maxTerminal, and for Design
%       Optimization with a free final time, finalTimeRange
%   resultsDirectory - where the tool wrote its results
%
% The tool turns its diary on and leaves it on if it fails; it is turned
% off here.
%
% Example: run = runToCase("torqueTracking", "torque", "settings_tracking_torque_tutorial.xml")
%
% (string, string, string) -> (struct)

function run = runToCase(folder, problem, settingsFile)
copyToFixtures(folder, problem, settingsFile);
originalFolder = cd(folder);
restoreFolder = onCleanup(@() cd(originalFolder));
text = fileread(settingsFile);
text = regexprep(text, "<optimal_control_solver_settings_file>[^<]*<", ...
    "<optimal_control_solver_settings_file>gpops_small.xml<");
writelines(text, settingsFile);
tool = string(regexp(text, "<(\w+OptimizationTool)[\s>]", "tokens", "once"));

run = struct("error", "", "output", "", "exit", "", "bounds", struct(), ...
    "resultsDirectory", "");
try
    [~, setup] = evalc("prepareToProblem(settingsFile)");
    inputs = setup.auxdata;
    for field = ["minState", "maxState", "minControl", "maxControl", ...
            "minPath", "maxPath", "minTerminal", "maxTerminal"]
        run.bounds.(field) = inputs.(field);
    end
    if isfield(inputs, "finalTimeRange")
        run.bounds.finalTimeRange = inputs.finalTimeRange;
    end
    run.resultsDirectory = fullfile(folder, inputs.resultsDirectory);
    clearToCaches();
    run.output = string(evalc("feval(tool, settingsFile)"));
    run.exit = string(regexp(run.output, "EXIT: [^\n]*", "match", "once"));
catch exception
    diary off
    run.error = string(exception.message);
end
clearToCaches();
end
