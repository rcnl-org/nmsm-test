% Tests for MTP's synergy extrapolation setup
% (src/MuscleTendonPersonalization/SynergyExtrapolation): how many synergy
% weights are optimized, how trials are grouped, the synergy commands
% extracted from measured EMG, and the linear constraints that keep the
% extrapolated excitations between 0 and 1.

classdef (TestTags = {'Unit'}) SynergyExtrapolationTest < matlab.unittest.TestCase

    methods (Test)
        % ---- number of synergy weights ----------------------------------

        function pcaWeightCountForTutorialSettings(testCase)
            % Tutorial: PCA, 3 synergies, trial categorization for the
            % extrapolation, task categorization for the residuals, one
            % gait trial, 8 measured and 1 missing EMG channel.
            % PCA adds a constant term: (3 + 1) per channel and group.
            % Extrapolation: 4 x 1 channel x 1 trial = 4
            % Residual:      4 x 8 channels x 1 task = 32
            params = synergyParams("PCA", 3, "trial", "task", "gait");
            [weights, numExtrapolation, numResidual] = ...
                getSynergyWeights(params, 1, 8, 1);
            testCase.verifyEqual([numExtrapolation, numResidual], [4, 32]);
            testCase.verifyEqual(weights, zeros(1, 36));
        end

        function weightCountGrowsWithCategory(testCase)
            % 3 trials of 2 tasks. Extrapolation by trial: 4 x 2 x 3 = 24;
            % residual by task: 4 x 5 x 2 = 40; by subject: 4 x 5 x 1.
            params = synergyParams("PCA", 3, "trial", "task", ...
                ["gait", "squat"]);
            [~, numExtrapolation, numResidual] = getSynergyWeights( ...
                params, 3, 5, 2);
            testCase.verifyEqual([numExtrapolation, numResidual], [24, 40]);
            params.residualCategorization = "subject";
            [~, ~, numResidual] = getSynergyWeights(params, 3, 5, 2);
            testCase.verifyEqual(numResidual, 20);
        end

        function nmfHasNoConstantTerm(testCase)
            params = synergyParams("NMF", 3, "trial", "task", "gait");
            [~, numExtrapolation, numResidual] = getSynergyWeights( ...
                params, 1, 8, 1);
            testCase.verifyEqual([numExtrapolation, numResidual], [3, 24]);
        end

        % ---- grouping trials --------------------------------------------

        function trialsAreGroupedByTaskName(testCase)
            params = synergyParams("PCA", 3, "trial", "task", ...
                ["gait", "squat", "gait"]);
            params = getTrialIndexes(params, 3, ...
                ["gait_1", "squat_1", "gait_2"]);
            testCase.verifyEqual(params.taskNames, ["gait", "squat"]);
            testCase.verifyEqual(params.trialIndex, {[1, 3], 2});
            testCase.verifyEqual(params.synergyCategorizationOfTrials, ...
                {1, 2, 3});
            testCase.verifyEqual(params.residualCategorizationOfTrials, ...
                {[1, 3], 2});
        end

        function subjectCategorizationGroupsAllTrials(testCase)
            params = synergyParams("PCA", 3, "subject", "subject", ...
                ["gait", "squat"]);
            params = getTrialIndexes(params, 3, ...
                ["gait_1", "squat_1", "gait_2"]);
            testCase.verifyEqual(params.synergyCategorizationOfTrials, ...
                {1 : 3});
        end

        % ---- synergy commands -------------------------------------------

        function pcaCommandsAreUncorrelatedAndCentered(testCase)
            % Principal component scores have zero mean, are mutually
            % uncorrelated, and are ordered by decreasing variance.
            emg = threeChannelEmg();
            commands = getSynergyCommands(emg, 2, "PCA", {1}, {1});
            scores = commands{1};
            testCase.verifySize(scores, [size(emg, 3), 2]);
            testCase.verifyEqual(mean(scores), [0, 0], "AbsTol", 1e-12);
            covariance = scores' * scores;
            testCase.verifyEqual(covariance(1, 2), 0, "AbsTol", 1e-10);
            testCase.verifyGreaterThan(covariance(1, 1), covariance(2, 2));
        end

        function commandsIgnoreEmgAmplitude(testCase)
            % Each channel is normalized by its maximum, so scaling a
            % channel's EMG does not change the commands.
            emg = threeChannelEmg();
            scaled = emg;
            scaled(1, 2, :) = 10 * scaled(1, 2, :);
            original = getSynergyCommands(emg, 2, "PCA", {1}, {1});
            rescaled = getSynergyCommands(scaled, 2, "PCA", {1}, {1});
            testCase.verifyEqual(abs(rescaled{1}), abs(original{1}), ...
                "AbsTol", 1e-10);
        end

        function taskCommandsSpanAllTrialsOfTheTask(testCase)
            % Two trials categorized together give one command set
            % covering both trials' frames.
            emg = cat(1, threeChannelEmg(), 0.5 * threeChannelEmg());
            [extrapolation, residual] = getSynergyCommands(emg, 2, ...
                "PCA", {[1, 2]}, {1, 2});
            testCase.verifySize(extrapolation{1}, [2 * size(emg, 3), 2]);
            testCase.verifyLength(residual, 2);
            testCase.verifySize(residual{1}, [size(emg, 3), 2]);
        end

        % ---- excitation bounds ------------------------------------------

        function constraintsBoundExtrapolatedExcitation(testCase)
            % One trial, one missing channel, 2 PCA synergies. The
            % extrapolated excitation is commands * weights + constant.
            % A * x <= b must say -excitation <= 0 and excitation <= 1 at
            % every frame. With weights 0 and constant 0.4, A * x is
            % -0.4 then +0.4 at every frame.
            numFrames = 20;
            numOther = 5; % e.g. other MTP design variables
            params = synergyParams("PCA", 2, "trial", "task", "gait");
            params = getTrialIndexes(params, 1, "gait_1");
            params.missingEmgChannelGroups = {9};
            commands = {rand(numFrames, 2)};
            emg = rand(numFrames, 1, 8); % (frame x trial x channel)
            [A, b] = getLinearInequalityConstraints(params, numOther, ...
                commands, emg);
            numResidual = (2 + 1) * 1 * 8;
            testCase.verifySize(A, [2 * numFrames, numOther + 3 + ...
                numResidual]);
            testCase.verifyEqual(b, [zeros(numFrames, 1); ...
                ones(numFrames, 1)]);
            x = [rand(1, numOther), 0, 0, 0.4, rand(1, numResidual)]';
            testCase.verifyEqual(A * x, [-0.4 * ones(numFrames, 1); ...
                0.4 * ones(numFrames, 1)], "AbsTol", 1e-12);
        end

        function constraintsUseSynergyCommands(testCase)
            numFrames = 20;
            params = synergyParams("PCA", 2, "trial", "task", "gait");
            params = getTrialIndexes(params, 1, "gait_1");
            params.missingEmgChannelGroups = {9};
            commands = {rand(numFrames, 2)};
            [A, ~] = getLinearInequalityConstraints(params, 0, commands, ...
                rand(numFrames, 1, 8));
            weights = [0.2, -0.1];
            x = [weights, 0, zeros(1, 24)]';
            excitation = commands{1} * weights';
            testCase.verifyEqual(A * x, [-excitation; excitation], ...
                "AbsTol", 1e-12);
        end
    end
end

function params = synergyParams(method, numberOfSynergies, ...
    synergyCategorization, residualCategorization, taskNames)
params.matrixFactorizationMethod = method;
params.numberOfSynergies = numberOfSynergies;
params.synergyExtrapolationCategorization = synergyCategorization;
params.residualCategorization = residualCategorization;
params.taskNames = taskNames;
end

function emg = threeChannelEmg()
% One trial, three channels built from two underlying signals, 60 frames.
t = linspace(0, 1, 60);
sources = [0.5 + 0.4 * sin(2 * pi * t); 0.5 + 0.3 * cos(4 * pi * t)];
emg = permute([1, 0; 0.5, 0.5; 0.2, 0.8] * sources, [3, 1, 2]);
end
