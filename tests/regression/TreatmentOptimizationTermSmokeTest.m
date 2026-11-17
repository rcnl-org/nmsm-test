% Smoke test of every Treatment Optimization cost and constraint term: each
% term the registries allow (generateCostTermStruct,
% generateConstraintTermStruct) is enabled in a real problem and evaluated
% on its own at the initial guess. A term passes if it runs and returns
% finite values of the right size: one column with a value per collocation
% point for continuous cost and path constraint terms, one value for
% discrete cost and terminal constraint terms. Whether the values are
% right is for the hand-worked unit tests.
%
% The terms come from the registries when the class is loaded, so a term
% added to a registry is tested without changing this file. Each case
% (tool and controller) is prepared once, as the tool does
% (prepareToProblem), from its tutorial settings file with the cost and
% constraint term sets extended by one term of every type it allows. The
% terms are prepared disabled (preparing evaluates the enabled terms, so
% one broken term would stop the whole case) and each is enabled on its
% own when it is evaluated. Marker and body orientation tracking are set
% up from every term, enabled or not. The cases:
%
% - trackingTorque, verificationTorque, designTorque (the Step 6 kick)
% - trackingSynergy, designSynergy (the Step 8 kick, with
%   optimize_synergy_vectors true so the synergy vector terms have
%   weights to act on)
%
% Terms that need muscles (muscle, synergy, fiber length and metabolic
% terms) are tested in the synergy cases only. Terms that need contact
% surfaces (external forces and moments, center of pressure, braking and
% propulsive impulse) are reported as not run: the kick fixtures have no
% GCP contact surfaces or ground reaction data. user_defined terms call
% small functions written by this test, so they check the plumbing only.
%
% Needs GPOPS-II (preparing a problem finds the collocation times); without
% a license the tests are reported as not run.

classdef (TestTags = {'Regression'}) TreatmentOptimizationTermSmokeTest ...
        < matlab.unittest.TestCase

    properties (TestParameter)
        % "<case>.<kind>.<type>", e.g.
        % "trackingTorque.continuous.generalized_coordinate_tracking"
        term = smokeTerms()
    end

    properties
        problems
        errors
    end

    methods (TestClassSetup)
        function prepareEveryCase(testCase)
            testCase.assumeTrue(gpopsIsLicensed(), ...
                "GPOPS-II is not licensed on this computer.");
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.addTeardown(@clearToCaches);
            cases = smokeCases();
            for name = string(fieldnames(cases))'
                folder = fullfile(fixture.Folder, name);
                [testCase.problems.(name), testCase.errors.(name)] = ...
                    prepareCase(folder, cases.(name));
                % The user_defined terms' functions are in the folder
                testCase.applyFixture( ...
                    matlab.unittest.fixtures.PathFixture(folder));
            end
        end
    end

    methods (Test)
        function termRunsAndHasTheRightSize(testCase, term)
            [caseName, kind, type] = splitTerm(term);
            testCase.assumeFalse(needsContactSurfaces(type), type + ...
                " needs contact surfaces; the kick fixtures have none.");
            testCase.assertEqual(testCase.errors.(caseName), "", ...
                "Preparing " + caseName + " failed: " + ...
                testCase.errors.(caseName));
            problem = testCase.problems.(caseName);
            output = evaluateTerm(problem, kind, type);
            testCase.verifyClass(output, "double");
            testCase.verifyTrue(all(isfinite(output), "all"), ...
                type + " returned values that are not finite.");
            if kind == "continuous" || kind == "path"
                testCase.verifySize(output, ...
                    [numel(problem.continuousValues.time), 1]);
            else
                testCase.verifySize(output, [1, 1]);
            end
        end
    end
end

function cases = smokeCases()
cases.trackingTorque = struct("tool", "TrackingOptimization", ...
    "controller", "torque", "problem", "torque", ...
    "settings", "settings_tracking_torque_tutorial.xml");
cases.trackingSynergy = struct("tool", "TrackingOptimization", ...
    "controller", "synergy", "problem", "synergy", ...
    "settings", "settings_tracking_synergy_tutorial.xml");
cases.verificationTorque = struct("tool", "VerificationOptimization", ...
    "controller", "torque", "problem", "torque", ...
    "settings", "settings_verification_torque_tutorial.xml");
cases.designTorque = struct("tool", "DesignOptimization", ...
    "controller", "torque", "problem", "torque", ...
    "settings", "settings_design_torque_tutorial_v3.xml");
cases.designSynergy = struct("tool", "DesignOptimization", ...
    "controller", "synergy", "problem", "synergy", ...
    "settings", "settings_design_synergy_tutorial.xml");
end

function terms = smokeTerms()
% Every (case, kind, type) the registries allow, minus muscle terms in
% torque cases. Contact terms stay in the list and are reported as not
% run, so the gap stays visible.
terms = {};
cases = smokeCases();
for name = string(fieldnames(cases))'
    for kind = ["continuous", "discrete", "path", "terminal"]
        for type = caseTypes(cases.(name), kind)
            terms{end + 1} = char(name + "." + kind + "." + type); %#ok<AGROW>
        end
    end
end
end

function types = caseTypes(smokeCase, kind)
if kind == "continuous" || kind == "discrete"
    [~, types] = generateCostTermStruct(kind, smokeCase.tool);
else
    [~, types] = generateConstraintTermStruct(kind, ...
        smokeCase.controller, smokeCase.tool);
end
% A row, so "for type = types" runs once per type (an empty list from [] is
% 0 x 1, which a for loop would run once)
types = reshape(unique(string(types), "stable"), 1, []);
if smokeCase.controller == "torque"
    types = types(~needsMuscles(types));
end
end

function tf = needsMuscles(types)
tf = contains(types, ["muscle", "synergy", "fiber_length", "metabolic"]);
end

function tf = needsContactSurfaces(types)
tf = contains(types, ["external_force", "external_moment", ...
    "center_of_pressure", "impulse"]);
end

function [caseName, kind, type] = splitTerm(term)
parts = split(string(term), ".");
[caseName, kind, type] = deal(parts(1), parts(2), parts(3));
end

function [problem, message] = prepareCase(folder, smokeCase)
% Writes the case's smoke settings file and user functions, prepares the
% problem and evaluates the values every term reads.
problem = struct();
message = "";
copyToFixtures(folder, smokeCase.problem, smokeCase.settings);
originalFolder = cd(folder);
restoreFolder = onCleanup(@() cd(originalFolder));
try
    writeSmokeUserFunctions();
    settingsFile = writeSmokeSettings(smokeCase);
    clearToCaches();
    [~, setup] = evalc("prepareToProblem(settingsFile)");
    problem = evaluateValues(setup);
catch exception
    diary off
    message = string(exception.message);
end
end

function settingsFile = writeSmokeSettings(smokeCase)
text = fileread(smokeCase.settings);
costTerms = "";
for kind = ["continuous", "discrete"]
    for type = caseTypes(smokeCase, kind)
        if ~needsContactSurfaces(type)
            costTerms = costTerms + termXml("RCNLCostTerm", type, ...
                kind, smokeCase.controller);
        end
    end
end
constraintTerms = "";
for kind = ["path", "terminal"]
    for type = caseTypes(smokeCase, kind)
        if ~needsContactSurfaces(type)
            constraintTerms = constraintTerms + termXml( ...
                "RCNLConstraintTerm", type, kind, smokeCase.controller);
        end
    end
end
text = appendToElement(text, "RCNLCostTermSet", costTerms);
text = appendToElement(text, "RCNLConstraintTermSet", constraintTerms);
if smokeCase.controller == "synergy"
    text = regexprep(text, ...
        "<optimize_synergy_vectors>\w*</optimize_synergy_vectors>", "");
    text = replace(text, "<RCNLSynergyController>", ...
        "<RCNLSynergyController><optimize_synergy_vectors>true" + ...
        "</optimize_synergy_vectors>");
end
settingsFile = "smoke_" + smokeCase.settings;
writelines(text, settingsFile);
end

function text = appendToElement(text, element, contents)
% Adds contents at the end of the element, after the tutorial's own terms
% (preparing needs at least one enabled cost term, and the tutorial's
% work), or adds the element at the end of the tool if there is none.
closing = "</" + element + ">";
if contains(text, closing)
    text = replace(text, closing, contents + closing);
else
    toolEnd = regexp(text, "</\w+OptimizationTool>", "once");
    text = extractBefore(text, toolEnd) + "<" + element + ">" + ...
        contents + closing + extractAfter(text, toolEnd - 1);
end
end

function xml = termXml(element, type, kind, controller)
% One enabled term with every target element a term might read. Each
% term reads only its own, so the others are ignored.
targets = struct( ...
    "coordinate", "hip_flexion_r", ...
    "load", "hip_flexion_r_moment", ...
    "marker", "R_Toe", ...
    "body", "calcn_r", ...
    "axes", "x", ...
    "muscle", "soleus_r", ...
    "synergy_group", "RightLeg", ...
    "synergy", "RightLeg_1", ...
    "synergies", "RightLeg_1 RightLeg_2");
if controller == "synergy"
    targets.controller = "RightLeg_1";
else
    targets.controller = "hip_flexion_r";
end
xml = "<" + element + "><is_enabled>false</is_enabled><type>" + type + ...
    "</type>";
for name = string(fieldnames(targets))'
    xml = xml + "<" + name + ">" + targets.(name) + "</" + name + ">";
end
if element == "RCNLCostTerm"
    xml = xml + "<max_allowable_error>1</max_allowable_error>";
    if type == "user_defined"
        xml = xml + "<cost_term_type>" + kind + "</cost_term_type>";
    end
else
    xml = xml + "<max_error>1</max_error><min_error>-1</min_error>";
    if type == "user_defined"
        xml = xml + "<constraint_term_type>" + kind + ...
            "</constraint_term_type>";
    end
end
if type == "user_defined"
    xml = xml + "<function_name>" + userFunctionName(kind) + ...
        "</function_name>";
end
xml = xml + "</" + element + ">";
end

function name = userFunctionName(kind)
name = "smoke" + upper(extractBefore(kind, 2)) + extractAfter(kind, 1);
end

function writeSmokeUserFunctions()
% user_defined terms: zeros of the expected size
for kind = ["continuous", "path"]
    writelines(["function output = " + userFunctionName(kind) + ...
        "(values, ~, ~, ~)"; "output = zeros(numel(values.time), 1);"; ...
        "end"], userFunctionName(kind) + ".m");
end
for kind = ["discrete", "terminal"]
    writelines(["function output = " + userFunctionName(kind) + ...
        "(~, ~, ~, ~)"; "output = 0;"; "end"], ...
        userFunctionName(kind) + ".m");
end
end

function problem = evaluateValues(setup)
% The values and modeled values the continuous and endpoint functions
% give their terms at the initial guess (computeGpopsContinuousFunction,
% computeGpopsEndpointFunction), without evaluating their terms.
auxdata = setup.auxdata;
% The terms were prepared disabled, so set the flags the parser sets for
% enabled angular momentum and metabolic terms (muscles needed for the
% metabolic cost)
auxdata.calculateAngularMomentum = true;
auxdata.calculateMetabolicCost = auxdata.controllerType == "synergy";
guess = setup.guess.phase;
phase = guess;
if isfield(setup.guess, "parameter")
    phase.parameter = repmat(setup.guess.parameter, size(guess.time, 1), 1);
end
input.phase = phase;
input.auxdata = auxdata;
[problem.continuousValues, problem.continuousModeled] = ...
    modeledValuesAt(input);

endpoint.phase.state = [guess.state(1, :); guess.state(end, :)];
endpoint.phase.time = [guess.time(1); guess.time(end)];
endpoint.phase.control = ones(2, length(auxdata.minControl));
if isfield(setup.guess, "parameter")
    endpoint.phase.parameter = setup.guess.parameter;
end
endpoint.auxdata = auxdata;
[problem.endpointValues, problem.endpointModeled] = ...
    modeledValuesAt(endpoint);
% The endpoint function reads the metabolic cost from GPOPS-II's integral
% of the continuous one, which the guess has no slot for here. With a
% metabolic term enabled, preparing stores the initial guess's integral
% as initialMetabolicCost (computeCollocationPointTimes); with the terms
% disabled it does not, so store the same integral.
if auxdata.calculateMetabolicCost
    problem.endpointModeled.metabolicCost = trapz( ...
        problem.continuousValues.time, ...
        problem.continuousModeled.metabolicCost);
    auxdata.initialMetabolicCost = problem.endpointModeled.metabolicCost;
end
problem.auxdata = auxdata;
end

function [values, modeled] = modeledValuesAt(input)
values = makeGpopsValuesAsStruct(input.phase, input.auxdata);
if strcmp(input.auxdata.toolName, "DesignOptimization")
    [input, values] = updateSystemFromUserDefinedFunctions(input, values);
end
modeled = calcSynergyBasedModeledValues(values, input.auxdata);
modeled = calcTorqueBasedModeledValues(values, input.auxdata, modeled);
end

function output = evaluateTerm(problem, kind, type)
% Evaluates the prepared term of this type (as the parser and
% makeTreatmentOptimizationInputs left it) on its own.
auxdata = problem.auxdata;
if kind == "continuous" || kind == "discrete"
    terms = auxdata.costTerms;
    kindField = "cost_term_type";
else
    terms = auxdata.(kind);
    kindField = "constraint_term_type";
end
index = find(cellfun(@(t) string(t.type) == type && ...
    (type ~= "user_defined" || string(t.(kindField)) == kind), terms), 1);
assert(~isempty(index), type + " is not in the prepared " + kind + ...
    " terms.");
terms{index}.isEnabled = true;
if kind == "continuous" || kind == "path"
    values = problem.continuousValues;
    modeled = problem.continuousModeled;
else
    values = problem.endpointValues;
    modeled = problem.endpointModeled;
end
if kind == "continuous" || kind == "discrete"
    [calculations, allowed] = generateCostTermStruct(kind, ...
        auxdata.toolName);
    auxdata.costTerms = terms(index);
    output = calcTreatmentOptimizationCost(calculations, allowed, ...
        values, modeled, auxdata);
else
    [calculations, allowed] = generateConstraintTermStruct(kind, ...
        auxdata.controllerType, auxdata.toolName);
    output = calcGpopsConstraint(terms(index), calculations, allowed, ...
        values, modeled, auxdata);
end
end
