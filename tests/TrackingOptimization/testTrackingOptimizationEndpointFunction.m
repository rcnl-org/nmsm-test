load('trackingOptimizationEndpointInputs.mat')
if isequal(mexext, 'mexw64')
    pointKinematicsMexWindows(inputs.auxdata.mexModel);
    inverseDynamicsMexWindows(inputs.auxdata.mexModel);
end

output.eventgroup.event = calcTrackingOptimizationTerminalConstraint( ...
    inputs, inputs.auxdata);
output.objective = calcTrackingOptimizationObjective(inputs.phase.integral);

expectedOutput = load('expectedOutput.mat');
assertWithinRange(output.eventgroup.event([1:62]), expectedOutput.output.eventgroup.event([1:62]), 1e-5);
