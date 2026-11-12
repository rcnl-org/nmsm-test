% This function checks that a Treatment Optimization solution (see
% runToCase, readToSolution) stays within the bounds it was solved with:
% states, accelerations, synergy commands and torque controls. GPOPS-II
% enforces bounds at its collocation points, which are the saved points,
% so only IPOPT's bound tolerance (here 1e-6 of each range) is allowed.
% The last torque control sample is not checked: the tool saves the
% inverse dynamics load there instead (see verifyToKineticConsistency).
%
% (matlab.unittest.TestCase, struct, string) -> (None)

function verifyToSolutionBounds(testCase, run, trialName)
solution = readToSolution(run.resultsDirectory, trialName);
bounds = run.bounds;
check(testCase, solution.states, bounds.minState, bounds.maxState, ...
    "states");
numStates = size(solution.accelerations, 2);
check(testCase, solution.accelerations, bounds.minControl(1 : ...
    numStates), bounds.maxControl(1 : numStates), "accelerations");
numSynergies = size(solution.synergyCommands, 2);
if numSynergies > 0
    columns = numStates + (1 : numSynergies);
    check(testCase, solution.synergyCommands, bounds.minControl(columns), ...
        bounds.maxControl(columns), "synergy commands");
end
numTorques = size(solution.torqueControls, 2);
if numTorques > 0
    columns = numStates + numSynergies + (1 : numTorques);
    check(testCase, solution.torqueControls(1 : end - 1, :), ...
        bounds.minControl(columns), bounds.maxControl(columns), ...
        "torque controls");
end
end

function check(testCase, values, minimum, maximum, name)
tolerance = 1e-6 * (maximum - minimum);
testCase.verifyGreaterThanOrEqual(values, minimum - tolerance, ...
    name + " below their lower bounds.");
testCase.verifyLessThanOrEqual(values, maximum + tolerance, ...
    name + " above their upper bounds.");
end
