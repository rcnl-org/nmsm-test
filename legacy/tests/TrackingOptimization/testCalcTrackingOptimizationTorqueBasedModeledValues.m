load('trackingOptimizationContinuousInputsAndValues.mat')

inputs.auxdata.mexModel = 'exampleModel.osim';
if isequal(mexext, 'mexw64')
    pointKinematicsMexWindows(inputs.auxdata.mexModel);
    inverseDynamicsMexWindows(inputs.auxdata.mexModel);
end
phaseout = calcTorqueBasedModeledValues(values, inputs.auxdata);

expectedPhaseout = load('expectedPhaseout.mat');

momentLabelsNoSuffix = erase(inputs.auxdata.inverseDynamicMomentLabels, ...
    '_moment');
momentLabelsNoSuffix = erase(momentLabelsNoSuffix, '_force');
includedJointMomentCols = ismember(momentLabelsNoSuffix, ...
    convertCharsToStrings(inputs.auxdata.coordinateNames));
if size(phaseout.inverseDynamicMoments, 2) ~= ...
        size(expectedPhaseout.inverseDynamicMoments, 2)
    expectedPhaseout.inverseDynamicMoments = ...
        expectedPhaseout.inverseDynamicMoments(:, includedJointMomentCols);
end

assertWithinRange(phaseout.bodyLocations.parent{1}, expectedPhaseout.bodyLocations(:,1:3), 1e-1);
assertWithinRange(phaseout.bodyLocations.child{1}, expectedPhaseout.bodyLocations(:,4:6), 1e-1);
assertWithinRange(phaseout.bodyLocations.parent{2}, expectedPhaseout.bodyLocations(:,7:9), 1e-1);
assertWithinRange(phaseout.bodyLocations.child{2}, expectedPhaseout.bodyLocations(:,10:12), 1e-1);
assertWithinRange(phaseout.bodyLocations.midfootSuperior{1}(:,[1 3]), expectedPhaseout.bodyLocations(:,[13 15]), 1e-12);
assertWithinRange(phaseout.bodyLocations.midfootSuperior{2}(:,[1 3]), expectedPhaseout.bodyLocations(:,[16 18]), 1e-12);
assertWithinRange(phaseout.groundReactionsLab.forces{1}, expectedPhaseout.rightGroundReactionsLab(:, 1:3), 1e2);
assertWithinRange(phaseout.groundReactionsLab.moments{1}, expectedPhaseout.rightGroundReactionsLab(:, 4:6), 1e2);
assertWithinRange(phaseout.groundReactionsLab.forces{2}, expectedPhaseout.leftGroundReactionsLab(:, 1:3), 1e2);
assertWithinRange(phaseout.groundReactionsLab.moments{2}, expectedPhaseout.leftGroundReactionsLab(:, 4:6), 1e2);
assertWithinRange(phaseout.inverseDynamicMoments, expectedPhaseout.inverseDynamicMoments, 1e3);
