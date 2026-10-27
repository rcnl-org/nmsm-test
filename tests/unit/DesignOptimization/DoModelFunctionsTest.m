% Tests for Design Optimization's model functions (<model_functions>),
% which change the model or the problem from the user-defined parameters
% being optimized (<RCNLParameterTermSet>):
% updateSystemFromUserDefinedFunctions calls each named function, and
% src/TreatmentOptimization/BuiltInParameters provides ready-made ones
% such as applyBeltSpeedParameter.
%
% GPOPS-II's callbacks pass the problem setup (with its auxdata) and the
% values from makeGpopsValuesAsStruct, which puts the parameters in
% values.parameters.<type>.

classdef (TestTags = {'Unit'}) DoModelFunctionsTest < matlab.unittest.TestCase

    methods (Test)
        function noModelFunctionsChangeNothing(testCase)
            setup.auxdata.systemFns = strings(1, 0);
            values.time = 1;
            [newSetup, newValues] = updateSystemFromUserDefinedFunctions( ...
                setup, values);
            testCase.verifyEqual(newSetup, setup);
            testCase.verifyEqual(newValues, values);
        end

        function userModelFunctionChangesTheSetup(testCase)
            % A user function with the signature
            % updateSystemFromUserDefinedFunctions calls.
            testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            writelines(["function [setup, values] = setMass(setup, values)"; ...
                "setup.auxdata.mass = values.parameters.mass;"; "end"], ...
                "setMass.m");
            setup.auxdata.systemFns = "setMass";
            setup.auxdata.mass = 70;
            values.parameters.mass = 75;
            newSetup = updateSystemFromUserDefinedFunctions(setup, values);
            testCase.verifyEqual(newSetup.auxdata.mass, 75);
        end

        function beltSpeedParameterSetsTheBeltSpeed(testCase)
            % The built-in belt speed function sets the belt speed of the
            % contact surfaces on the parameter's side.
            % Expected to fail on candidate-1.5.4: the built-in
            % apply*Parameter functions return one output where
            % updateSystemFromUserDefinedFunctions expects two
            % ([inputs, values]), and read values.belt_speed where the
            % parameters are in values.parameters.belt_speed. See
            % tests/README.md.
            setup.auxdata.systemFns = "applyBeltSpeedParameter";
            setup.auxdata.userDefinedVariables = {struct("type", ...
                'belt_speed', "is_left_foot", false)};
            setup.auxdata.contactSurfaces = {struct("isLeftFoot", true, ...
                "beltSpeed", 1), struct("isLeftFoot", false, ...
                "beltSpeed", 1)};
            values.parameters.belt_speed = 1.3;
            newSetup = updateSystemFromUserDefinedFunctions(setup, values);
            testCase.verifyEqual(newSetup.auxdata.contactSurfaces{2} ...
                .beltSpeed, 1.3);
            testCase.verifyEqual(newSetup.auxdata.contactSurfaces{1} ...
                .beltSpeed, 1);
        end
    end
end
