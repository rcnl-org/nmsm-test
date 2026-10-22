% Full GroundContactPersonalizationTool runs, each case run once for the
% whole class (TestClassSetup) and then checked by several tests:
%
% - globals: synthetic known truth (tests/data/gcp/synthetic/globals). GCP
%   must recover the true damping, dynamic friction and resting spring
%   length.
% - springs: synthetic known truth with a different spring constant. GCP
%   must recover it for all 37 springs (those that never touch the ground
%   only through the spring constant mean term) and leave the rest at the
%   truth.
% - rotation: the globals truth measured by a force plate turned by a known
%   angle. GCP must find the angle.
% - neighbor: the springs case kept near neighboring springs instead of
%   the mean, without a moment cost term.
% - tutorial: the nmsm-tutorial Step 2 problem (resting length
%   initialization and three tasks), with 5 iterations per task instead of
%   20 to keep the run short; checked for fit and against its nominal.
%
% On candidate-1.5.4, rotation does not find the angle (the cost uses the
% stored rotation, not the design variable) and neighbor crashes (the
% neighbor term needs spring positions only computed for the moment terms).
% A case that errors is recorded in TestClassSetup, and its tests fail with
% that error, so the other cases still run. See tests/README.md.
%
% Cases that run are also compared with their nominal results
% (tests/data/gcp/nominal). If a change is intentional, regenerate them
% with tests/regression/updateGcpNominal.m and commit them.

classdef (TestTags = {'Regression'}) GroundContactPersonalizationRegressionTest ...
        < matlab.unittest.TestCase

    properties (Constant)
        % GCP writes the contact model values to the osimx file with 5
        % significant digits (spring constants in full).
        osimxRelativeTolerance = 1e-4
        % Nominal comparisons: GCP is deterministic here (two runs agree
        % exactly), so these only allow for summing in a different order.
        nominalForceTolerance = 1e-6 % N and Nm
        nominalValueRelativeTolerance = 1e-9
        % The 5-iteration tutorial run on candidate-1.5.4: RMS of modeled
        % minus experimental Fx, Fy, Fz (N) and Mx, My, Mz (Nm). Not
        % converged (vertical 64 N against an 810 N peak); the test's
        % ceilings are 25% above.
        tutorialRms = [22.48, 63.83, 24.00, 3.153, 3.823, 7.574]
    end

    properties
        expected
        folders
        errors
        outputs % command window output of each run
    end

    properties (TestParameter)
        run = struct( ...
            "globals", "settings_synthetic_globals.xml", ...
            "springs", "settings_synthetic_springs.xml", ...
            "rotation", "settings_synthetic_rotation.xml", ...
            "neighbor", "settings_synthetic_neighbor.xml", ...
            "tutorial", "settings_tutorial.xml")
        % Cases with nominal results: those that run on candidate-1.5.4
        % and give a correct answer
        nominalRun = {"globals", "springs", "tutorial"}
        % Synthetic cases whose truth GCP finds on candidate-1.5.4
        fitRun = {"globals", "springs"}
    end

    methods (TestClassSetup)
        function runEveryCase(testCase)
            testCase.expected = gcpFixtureValues();
            startQuietParallelPool();
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.addTeardown(@clearGcpMexFiles, fixture.Folder);
            runs = testCase.run;
            for name = string(fieldnames(runs))'
                folder = fullfile(fixture.Folder, name);
                testCase.folders.(name) = folder;
                [testCase.errors.(name), testCase.outputs.(name)] = ...
                    runGcpCase(folder, runs.(name));
            end
        end
    end

    methods (Test)
        function globalsRecoversContactValues(testCase)
            testCase.assertCaseRan("globals");
            truth = testCase.expected.synthetic.globals;
            values = testCase.osimxValues("globals");
            testCase.verifyEqual([values.dampingFactor, ...
                values.dynamicFrictionCoefficient, ...
                values.restingSpringLength], [truth.dampingFactor, ...
                truth.dynamicFrictionCoefficient, ...
                truth.restingSpringLength], "RelTol", ...
                testCase.osimxRelativeTolerance);
            testCase.verifyEqual(values.springConstants, ...
                repmat(truth.springConstant, 1, ...
                testCase.expected.synthetic.numSprings));
        end

        function springsRecoversSpringConstants(testCase)
            % A correct run is within 1e-11 relative.
            testCase.assertCaseRan("springs");
            truth = testCase.expected.synthetic.springs;
            values = testCase.osimxValues("springs");
            testCase.verifyEqual(values.springConstants, ...
                repmat(truth.springConstant, 1, ...
                testCase.expected.synthetic.numSprings), "RelTol", 1e-6);
            testCase.verifyEqual([values.dampingFactor, ...
                values.dynamicFrictionCoefficient, ...
                values.restingSpringLength], [truth.dampingFactor, ...
                truth.dynamicFrictionCoefficient, ...
                truth.restingSpringLength], "RelTol", ...
                testCase.osimxRelativeTolerance);
        end

        function syntheticRunFitsGroundReactions(testCase, fitRun)
            % At the truth the model's ground reactions equal the
            % experimental ones (as GCP compares them). 0.01 N and Nm is
            % far below the allowable errors.
            testCase.assertCaseRan(fitRun);
            [modeled, experimental] = testCase.groundReactions(fitRun);
            testCase.verifyLessThan(rms(modeled - experimental), ...
                0.01 * ones(1, 6));
        end

        function rotationFindsForcePlateAngle(testCase)
            % Expected to fail on candidate-1.5.4: the cost rotates the
            % ground reactions by the surface's stored rotation (0 during
            % the task) instead of the design variable, so the optimizer
            % sees no change and reports 0 degrees. See tests/README.md.
            testCase.assertCaseRan("rotation");
            angle = regexp(testCase.outputs.rotation, ...
                "Foot 1 force plate rotation: (\S+) degrees", "tokens", ...
                "once");
            testCase.assertNotEmpty(angle, ...
                "GCP did not report the force plate rotation.");
            testCase.verifyEqual(str2double(angle{1}), rad2deg( ...
                testCase.expected.synthetic.rotation.forcePlateRotation), ...
                "AbsTol", 0.01, "GCP did not find the force plate angle.");
            % With the right angle, the experimental ground reactions GCP
            % saves (rotated by it) match the model's.
            [modeled, experimental] = testCase.groundReactions("rotation");
            testCase.verifyLessThan(rms(modeled - experimental), ...
                0.01 * ones(1, 6));
        end

        function neighborTermWorksWithoutMomentTerms(testCase)
            % Expected to fail on candidate-1.5.4 (GCP crashes: the
            % neighbor term uses spring x and z positions only computed
            % when a moment cost term is enabled). Once fixed, the uniform
            % true spring constants have no neighbor error, so GCP should
            % recover them; 1e-3 relative is provisional.
            testCase.assertCaseRan("neighbor");
            values = testCase.osimxValues("neighbor");
            testCase.verifyEqual(values.springConstants, repmat( ...
                testCase.expected.synthetic.springs.springConstant, 1, ...
                testCase.expected.synthetic.numSprings), "RelTol", 1e-3);
        end

        function tutorialFitsGroundReactions(testCase)
            % 25% above the candidate-1.5.4 run, loose enough to allow
            % small intended changes that the nominal comparison would
            % catch.
            testCase.assertCaseRan("tutorial");
            [modeled, experimental] = testCase.groundReactions("tutorial");
            testCase.verifyLessThan(rms(modeled - experimental), ...
                1.25 * testCase.tutorialRms);
        end

        function tutorialValuesArePhysical(testCase)
            testCase.assertCaseRan("tutorial");
            values = testCase.osimxValues("tutorial");
            testCase.verifyLength(values.springConstants, ...
                testCase.expected.synthetic.numSprings);
            testCase.verifyGreaterThanOrEqual(values.springConstants, 0);
            testCase.verifyGreaterThanOrEqual([values.dampingFactor, ...
                values.dynamicFrictionCoefficient, ...
                values.viscousFrictionCoefficient], 0);
            % A resting length (the springs' height above the floor in the
            % unloaded foot) of a few cm.
            testCase.verifyGreaterThan(values.restingSpringLength, 0);
            testCase.verifyLessThan(values.restingSpringLength, 0.1);
        end

        function matchesNominalResult(testCase, nominalRun)
            testCase.assertCaseRan(nominalRun);
            message = " differ from tests/data/gcp/nominal. If this " + ...
                "change is intended, run updateGcpNominal.";
            nominalValues = readOsimxValues(testDataPath("gcp", ...
                "nominal", nominalRun + "_bodyModel_gcp.osimx"));
            testCase.verifyEqual(testCase.osimxValues(nominalRun), ...
                nominalValues, "RelTol", ...
                testCase.nominalValueRelativeTolerance, ...
                "Contact model values" + message);
            fileName = "bodyModel_Foot_1_optimizedGroundReactions.sto";
            testCase.verifyEqual(readStoFile(testCase.resultFile( ...
                nominalRun, fileName)), readStoFile(testDataPath("gcp", ...
                "nominal", nominalRun + "_" + fileName)), "AbsTol", ...
                testCase.nominalForceTolerance, ...
                "Optimized ground reactions" + message);
        end

        function writesExpectedResultFiles(testCase, run)
            [~, settingsName, extension] = fileparts(run);
            name = runName(testCase, run);
            testCase.assertCaseRan(name);
            for file = ["bodyModel_gcp.osimx", ...
                    "bodyModel_Foot_1_experimentalFootKinematics.sto", ...
                    "bodyModel_Foot_1_optimizedFootKinematics.sto", ...
                    "bodyModel_Foot_1_optimizedGroundReactions.sto", ...
                    "bodyModel_Foot_1_replacedExperimentalGroundReactions.sto", ...
                    "commandWindowOutput.txt", settingsName + extension]
                testCase.verifyTrue(isfile(testCase.resultFile(name, file)), ...
                    file);
            end
        end
    end

    methods
        function assertCaseRan(testCase, name)
            testCase.assertEqual(testCase.errors.(name), "", "The " + ...
                name + " run failed: " + testCase.errors.(name));
        end

        function fileName = resultFile(testCase, name, file)
            fileName = fullfile(testCase.folders.(name), "GCPResults", file);
            if name == "tutorial"
                fileName = fullfile(testCase.folders.(name), ...
                    "GCPResultsV1", file);
            end
        end

        function values = osimxValues(testCase, name)
            values = readOsimxValues(testCase.resultFile(name, ...
                "bodyModel_gcp.osimx"));
        end

        function [modeled, experimental] = groundReactions(testCase, name)
            % (frame x 6) forces then moments: the model's, and the
            % experimental ones as GCP compares them (moved to the midfoot,
            % with the resting length and plate rotation applied)
            modeled = readStoFile(testCase.resultFile(name, ...
                "bodyModel_Foot_1_optimizedGroundReactions.sto"));
            experimental = readStoFile(testCase.resultFile(name, ...
                "bodyModel_Foot_1_replacedExperimentalGroundReactions.sto"));
            modeled = modeled(:, 2 : 7);
            experimental = experimental(:, 2 : 7);
        end
    end
end

function [message, output] = runGcpCase(folder, settingsFile)
% Runs GroundContactPersonalizationTool on one case in its own folder and
% returns the error message ("" if it ran) and the command window output.
copyGcpFixtures(folder, settingsFile);
originalFolder = cd(folder);
restoreFolder = onCleanup(@() cd(originalFolder));
message = "";
output = "";
try
    output = string(evalc("GroundContactPersonalizationTool(settingsFile)"));
catch exception
    % Like NCP, GCP leaves its diary on when it fails.
    diary off
    message = string(exception.message);
end
end

function name = runName(testCase, run)
% The run's field name in the TestParameter struct (e.g. "tutorial")
names = string(fieldnames(testCase.run))';
name = names(arrayfun(@(n) testCase.run.(n) == run, names));
end

function values = readOsimxValues(fileName)
% The contact model values GCP writes to its osimx file (one surface)
text = fileread(fileName);
read = @(element) str2double(string(regexp(text, "<" + element + ...
    ">([^<]*)</", "tokens")));
values.restingSpringLength = read("resting_spring_length");
values.dynamicFrictionCoefficient = read("dynamic_friction_coefficient");
values.viscousFrictionCoefficient = read("viscous_friction_coefficient");
values.dampingFactor = read("damping_factor");
values.springConstants = read("spring_constant");
end
