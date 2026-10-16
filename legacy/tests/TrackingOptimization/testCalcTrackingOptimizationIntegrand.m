load('trackingOptimizationContinuousInputsAndValues.mat')
load('phaseout.mat')

phaseout.integrand = calcTrackingOptimizationIntegrand(values, phaseout, ...
    inputs.auxdata);
expectedIntegrand = load('expectedIntegrand.mat');
assertWithinRange(phaseout.integrand(:,1:31), expectedIntegrand.integrand(:,1:31), 4.5e1);