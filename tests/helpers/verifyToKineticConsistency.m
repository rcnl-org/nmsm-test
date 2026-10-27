% This function checks that a torque-driven Treatment Optimization
% solution (see runToCase, readToSolution) is kinetically consistent: at
% each saved point, the inverse dynamics load of each torque-controlled
% coordinate equals its torque control to within the kinetic_consistency
% bound. The last point is skipped: the tool saves the inverse dynamics
% load as the last torque control (a Radau collocation has no control at
% the final time), so it matches by construction.
%
% IPOPT meets constraints to its own tolerance, so 0.01 Nm beyond the
% bound is allowed.
%
% (matlab.unittest.TestCase, struct, string, double) -> (None)

function verifyToKineticConsistency(testCase, run, trialName, bound)
solution = readToSolution(run.resultsDirectory, trialName);
testCase.assertNotEmpty(solution.torqueControls, "No torque controls.");
for i = 1 : length(solution.torqueNames)
    load = solution.inverseDynamicsNames == solution.torqueNames(i) + ...
        "_moment";
    testCase.assertEqual(nnz(load), 1, solution.torqueNames(i));
    difference = solution.inverseDynamics(1 : end - 1, load) - ...
        solution.torqueControls(1 : end - 1, i);
    testCase.verifyLessThanOrEqual(max(abs(difference)), bound + 0.01, ...
        solution.torqueNames(i) + " is not kinetically consistent.");
end
end
