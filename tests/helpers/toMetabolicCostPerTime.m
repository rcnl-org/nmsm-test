% This function measures the metabolic cost per unit time of a Treatment
% Optimization solution, the quantity the *_metabolic_cost_per_time terms
% act on: the settings file is prepared (prepareToProblem) with the
% solution's folder as its initial guess and tracked data, the metabolic power
% (calcBhargavaMetabolicCost, through calcTorqueBasedModeledValues) is
% evaluated at the guess, and its time integral is divided by the final
% time. It needs muscles, so a synergy-driven problem.
%
% The settings file is not changed; a copy pointing at guessDirectory is
% written next to it. Needs GPOPS-II (preparing finds the collocation
% times).
%
% Example: toMetabolicCostPerTime("settings_design_synergy_tutorial.xml", ...
%     "DesignResults")
%
% (string, string) -> (number)

function costPerTime = toMetabolicCostPerTime(settingsFile, guessDirectory)
text = fileread(settingsFile);
% Both directories point at the solution: the initial guess and tracked
% data are splined together, so they must have the same frames
for element = ["initial_guess_directory", "tracked_quantities_directory"]
    text = regexprep(text, "<" + element + ">[^<]*</" + element + ">", ...
        replace("<" + element + ">" + guessDirectory + "</" + element + ...
        ">", "\", "\\"));
end
measureFile = "metabolic_measure_" + settingsFile;
writelines(text, measureFile);
clearToCaches();
% Not cleared again before evaluating: the point kinematics MEX keeps the
% model prepareToProblem loaded
[~, setup] = evalc("prepareToProblem(measureFile)");
auxdata = setup.auxdata;
auxdata.calculateMetabolicCost = true;
phase = setup.guess.phase;
if isfield(setup.guess, "parameter")
    phase.parameter = repmat(setup.guess.parameter, size(phase.time, 1), 1);
end
values = makeGpopsValuesAsStruct(phase, auxdata);
modeled = calcSynergyBasedModeledValues(values, auxdata);
modeled = calcTorqueBasedModeledValues(values, auxdata, modeled);
costPerTime = trapz(values.time, modeled.metabolicCost) / values.time(end);
end
