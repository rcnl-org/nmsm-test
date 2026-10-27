% This function collects the deterministic quantities of a prepared
% Treatment Optimization problem (see prepareToProblem): what GPOPS-II is
% given before it starts solving, and the problem's functions evaluated at
% the initial guess. For Verification and Design Optimization the initial
% guess is a published solution, so these are its cost and constraints.
%
% None of this depends on IPOPT, so it should agree across computers to
% rounding; the regression tests compare it with tests/data/to/nominal.
%
% Fields of the result:
%   collocationTime - collocation times (s)
%   stateBounds, controlBounds - [lower; upper], scaled as GPOPS-II sees
%       them; parameterBounds too when there are parameters
%   guessState, guessControl - the scaled initial guess
%   integral - the cost integrals at the initial guess
%   dynamics, path, integrand - the continuous function at the guess
%   objective, event - the endpoint function at the guess
%
% (struct) -> (struct)

function result = evaluateToProblem(setup)
result.collocationTime = setup.auxdata.collocationTimeOriginal;
bounds = setup.bounds.phase;
result.stateBounds = [bounds.state.lower; bounds.state.upper];
result.controlBounds = [bounds.control.lower; bounds.control.upper];
if isfield(setup.bounds, "parameter")
    result.parameterBounds = [setup.bounds.parameter.lower; ...
        setup.bounds.parameter.upper];
end
guess = setup.guess.phase;
result.guessState = guess.state;
result.guessControl = guess.control;
result.integral = guess.integral;

input.phase = guess;
input.auxdata = setup.auxdata;
if isfield(setup.guess, "parameter")
    input.phase.parameter = repmat(setup.guess.parameter, ...
        size(guess.time, 1), 1);
end
continuous = computeGpopsContinuousFunction(input);
result.dynamics = continuous.dynamics;
result.path = fieldOrEmpty(continuous, "path");
result.integrand = fieldOrEmpty(continuous, "integrand");

endpoint.phase.initialtime = guess.time(1);
endpoint.phase.finaltime = guess.time(end);
endpoint.phase.initialstate = guess.state(1, :);
endpoint.phase.finalstate = guess.state(end, :);
endpoint.phase.integral = guess.integral;
endpoint.auxdata = setup.auxdata;
if isfield(setup.guess, "parameter")
    endpoint.parameter = setup.guess.parameter;
end
output = computeGpopsEndpointFunction(endpoint);
result.objective = output.objective;
result.event = [];
if isfield(output, "eventgroup")
    result.event = output.eventgroup.event;
end
end

function value = fieldOrEmpty(structure, name)
value = [];
if isfield(structure, name)
    value = structure.(name);
end
end
