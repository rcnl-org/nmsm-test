% This function clears the state Treatment Optimization keeps between calls
% on candidate-1.5.4, so one test's leftovers cannot change the next test's
% result:
% - persistent variables in calcSynergyBasedModeledValues,
%   calcTorqueBasedModeledValues, calcSurrogateModel, calcGpopsIntegrand,
%   computeGpopsContinuousFunction, computeGpopsEndpointFunction,
%   inverseDynamicsMatlabParallel and pointKinematicsMatlabParallel;
% - the globals initialIntegral and initialMetabolicCost;
% - the Windows MEX functions that hold the model (point kinematics and
%   inverse dynamics), so a working folder can be deleted.
% The tools clear most of these themselves while preparing their inputs;
% tests that call the functions directly must call this in
% TestMethodSetup.
%
% () -> (None)

function clearToCaches()
clear calcSynergyBasedModeledValues calcTorqueBasedModeledValues
clear calcSurrogateModel calcGpopsIntegrand
clear computeGpopsContinuousFunction computeGpopsEndpointFunction
clear inverseDynamicsMatlabParallel pointKinematicsMatlabParallel
clear global initialIntegral initialMetabolicCost
clear pointKinematicsMexWindows40400 pointKinematicsMexWindows40501
clear inverseDynamicsMomentumMetabolicOrientationMexWindows40400
clear inverseDynamicsMomentumMetabolicOrientationMexWindows40501
end
