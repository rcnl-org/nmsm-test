% Tests for calcMtpCost, which adds up MTP's enabled cost terms. The
% individual terms are tested in MtpCostTermsTest; this checks the dispatch:
% which terms are added, which modeled values (with or without synergy
% extrapolation) each one uses, and how bad input is handled.
%
% Uses the candidate-1.5.4 cost term names.

classdef (TestTags = {'Unit'}) MtpCostTest < matlab.unittest.TestCase

    properties
        values
        modeled
        inputs
        params
    end

    methods (TestMethodSetup)
        function makeSmallProblem(testCase)
            % Two muscles, one coordinate, four frames. Values are chosen
            % so each term below has a different, nonzero cost.
            testCase.values.activationTimeConstants = [2.5, 2.5];
            testCase.values.activationNonlinearityConstants = [0.1, 0.3];
            testCase.values.emgScaleFactors = [0.3, 0.5];
            testCase.modeled.muscleJointMoments = 2.5 * ones(1, 1, 4);
            testCase.modeled.passiveForce = 100 * ones(1, 2, 4);
            testCase.modeled.normalizedFiberLength = ones(1, 2, 4);
            testCase.inputs.inverseDynamicsMoments = zeros(1, 1, 4);
            testCase.inputs.normalizedFiberLength = ones(1, 2, 4);
            testCase.params = struct();
        end
    end

    methods (Test)
        function sumsOnlyEnabledTerms(testCase)
            testCase.params.costTerms = { ...
                term("inverse_dynamics_joint_moment", true, 2.5), ...
                term("activation_nonlinearity_constant", true, 0.1), ...
                term("emg_scale_factor", false, 0.2)};
            expected = calcMomentTrackingCost(testCase.modeled, ...
                testCase.inputs, testCase.params.costTerms{1}) + ...
                calcActivationNonlinearityDeviationCost(testCase.values, ...
                testCase.params.costTerms{2});
            testCase.verifyEqual(calcMtpCost(testCase.values, struct(), ...
                testCase.modeled, testCase.inputs, testCase.params), ...
                expected, "AbsTol", 1e-12);
            testCase.verifyGreaterThan(expected, 0);
        end

        function noEnabledTermsCostsZero(testCase)
            testCase.params.costTerms = { ...
                term("inverse_dynamics_joint_moment", false, 2.5)};
            testCase.verifyEqual(calcMtpCost(testCase.values, struct(), ...
                testCase.modeled, testCase.inputs, testCase.params), 0);
        end

        function synergyOnlyTermsAddNothingWithoutSynergies(testCase)
            % These terms need synergy extrapolation; without it they are
            % skipped rather than failing.
            testCase.params.costTerms = { ...
                term("measured_inverse_dynamics_joint_moment", true, 2), ...
                term("extrapolated_muscle_activation", true, 0.3), ...
                term("residual_muscle_activation", true, 0.3), ...
                term("muscle_excitation_penalty", true, 0.25)};
            testCase.verifyEqual(calcMtpCost(testCase.values, struct(), ...
                testCase.modeled, testCase.inputs, testCase.params), 0);
        end

        function synergyRunUsesSynergyModeledFiberLengths(testCase)
            % With synergy extrapolation, the passive force term uses the
            % synergy model's values: 200 N instead of 100 N.
            testCase.inputs.synergyExtrapolation = struct();
            synx = testCase.modeled;
            synx.passiveForce = 2 * testCase.modeled.passiveForce;
            testCase.params.costTerms = { ...
                term("passive_muscle_force", true, 50)};
            testCase.verifyEqual(calcMtpCost(testCase.values, synx, ...
                testCase.modeled, testCase.inputs, testCase.params), ...
                (200 / 50) ^ 2, "AbsTol", 1e-12);
        end

        function unknownTermIsReported(testCase)
            testCase.params.costTerms = {term("not_a_term", true, 1)};
            verifyErrorMessage(testCase, @() calcMtpCost(testCase.values, ...
                struct(), testCase.modeled, testCase.inputs, ...
                testCase.params), "not_a_term is not valid for MTP");
        end

        function infiniteCostIsCapped(testCase)
            % fmincon cannot step away from Inf, so it is replaced.
            testCase.modeled.muscleJointMoments(1) = Inf;
            testCase.params.costTerms = { ...
                term("inverse_dynamics_joint_moment", true, 2.5)};
            testCase.verifyEqual(calcMtpCost(testCase.values, struct(), ...
                testCase.modeled, testCase.inputs, testCase.params), 1e100);
        end
    end
end

function costTerm = term(type, isEnabled, maxAllowableError)
% A cost term as parseRcnlCostTermSet builds it from a file without
% <error_center>.
costTerm = struct("type", type, "isEnabled", isEnabled, ...
    "maxAllowableError", maxAllowableError, "errorCenter", 0);
end
