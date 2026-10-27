# Test failures

Every test that fails, why, whether the behavior it catches is intended, and how to fix it. Test names are as
`runTests` prints them; each test is described in [test-catalog.md](test-catalog.md).

| Branch | Commit | Pass | Fail | Total |
|---|---|---|---|---|
| `candidate-1.5.4` (the branch the tests are written for) | `851c627f` | 682 | 35 | 717 |
| `matlab-gui-dev` (diagnostic run) | `6e7fc4e7` | 534 | 183 | 717 |

Both runs were on 2026-10-22/26 with MATLAB R2025a, OpenSim 4.5 and a licensed GPOPS-II.

**What "intended" means here.**

- **No: a bug.** The test describes correct behavior, and the code is wrong. Fix the code; the test then
  passes. All 35 candidate failures are this kind (they are the suite's "expected failures").
- **Yes: an intended change.** The code was changed on purpose (on `matlab-gui-dev`), and the test still
  expects the old behavior. Update the test, not the code.
- **Unclear: possibly a regression.** The code changed in a way that may not have been meant. The developers
  should decide; the fix depends on that decision.

Contents:
[Part 1: candidate-1.5.4 (35 failures)](#part-1-expected-failures-on-candidate-154) ·
[Part 2: matlab-gui-dev (183 failures)](#part-2-failures-on-matlab-gui-dev) ·
[Quick reference](#quick-reference)

---

## Part 1: Expected failures on `candidate-1.5.4`

35 tests fail on purpose, from 26 bugs. None of this behavior is intended. "On dev" says whether the bug is
still in `matlab-gui-dev`'s code.

### Joint Model Personalization

**B1. IK skips the last marker frame** — `InverseKinematicsErrorTest/usesEveryFrameInMarkerFile`
- *What happens:* JMP's IK error uses 119 of the marker file's 120 frames.
- *Why:* in `computeInverseKinematicsSquaredError.m` (line 46), the loop stops on
  `state.getTime() + 1/frequency > finishTime`. Floating-point rounding makes that true one frame early.
- *Intended:* no. *On dev:* still there.
- *Fix:* loop over the marker table's own times instead of adding `1/frequency` (for example
  `for i = 1 : numFrames; state.setTime(times.get(i - 1)); ... end`), or compare with a tolerance
  (`> finishTime + 1e-9`).

**B2. Disabling every task gives an unclear error** — `JointModelPersonalizationParsingTest/allTasksDisabledIsReported`
- *What happens:* `Output argument "inputs" ... not assigned`.
- *Why:* `getTasks` in `parseJointModelPersonalizationSettingsTree.m` only assigns `inputs` inside the loop.
- *Intended:* no. *On dev:* still there.
- *Fix:* start with `inputs = {};` and, after the loop,
  `assert(~isempty(inputs), "Every <JMPTask> is disabled; enable at least one.")`.

### Muscle-Tendon Personalization

**B3. A shared electromechanical delay does not work with per-muscle EMG** — `MuscleModelTest/commonDelayShiftsEmgLater`
- *What happens:* with one delay for all muscles, the EMG is not shifted correctly when each muscle has its
  own EMG spline (the form MTP's parser builds).
- *Intended:* no. *On dev:* **fixed** (the test passes there).
- *Fix:* bring dev's `calcEmgDataWithCommonTimeDelay` change to candidate.

**B4. Muscle groups that leave out the first muscle compare the wrong muscles** — `MtpCostComputationsTest/groupsWithoutFirstMuscleCompareTheRightMuscles`
- *What happens:* group indices are shifted down by (lowest grouped index − 1), so if no group contains the
  model's first muscle, every grouped term compares the wrong muscles.
- *Why:* `lowestIndex = min(cell2mat(groups)) - 1` and `groups{i} - lowestIndex`, in
  `calcDifferencesInEmgGroups`, `calcNormalizedFiberLengthGroupedSimilarityCost`,
  `calcSynergyExtrapolationMuscleActivationCost` and synergy extrapolation's `updateEmgSignals`.
- *Intended:* no. *On dev:* still there.
- *Fix:* remove the `lowestIndex` shift; the group indices are already positions in the muscle list.

**B5. Fiber length penalties jump at the limit** — `MtpCostTermsTest/maximumFiberLengthPenaltyStartsAtTheLimit`, `MtpCostTermsTest/minimumFiberLengthPenaltyStartsAtTheLimit`
- *What happens:* crossing the limit makes the cost jump from 0 to about 450 (maximum) or 140 (minimum).
- *Why:* `calcMaximumNormalizedFiberLengthMtpDeviationCost` zeroes lengths under the limit but then penalizes
  the whole length of those over it, not the amount over it (the minimum term likewise).
- *Intended:* no. *On dev:* still there.
- *Fix:* penalize the excess: `excess = max(0, maxLength - limit)` (and `max(0, limit - minLength)`), then
  `calcDeviationCostTerm(excess, errorCenter, allowableError)`.

**B6. Disabling every task gives an unclear error** — `MuscleTendonPersonalizationParsingTest/allTasksDisabledIsReported`
- Same as B2, in `getTasks` of `parseMuscleTendonPersonalizationSettingsTree.m`. *On dev:* still there.
- *Fix:* as B2: `output = {};` before the loop and a clear error if it stays empty.

**B7. A missing `<results_directory>` gives "Dot indexing is not supported"** — `MuscleTendonPersonalizationParsingTest/missingResultsDirectoryIsReported`, `NeuralControlPersonalizationParsingTest/missingResultsDirectoryIsReported`, `GroundContactPersonalizationParsingTest/missingResultsDirectoryIsReported`
- *Why:* `getFieldByName(settingsTree, 'results_directory').Text` in the MTP, NCP and GCP parsers;
  `getFieldByName` returns `false` for a missing element.
- *Intended:* no. *On dev:* still there.
- *Fix:* use `getFieldByNameOrError` (which names the element), or default to the current folder, as
  Treatment Optimization means to (see B23).

**B8. A misspelled coordinate gives an unclear error** — `MuscleTendonPersonalizationParsingTest/unknownCoordinateIsReported`
- *What happens:* "Unable to perform assignment because the size of the left side is 0-by-139 ...", deep in
  EMG parsing.
- *Intended:* no. *On dev:* still there.
- *Fix:* in the parser, check each `<coordinate_list>` entry against the model's coordinates (or the ID
  columns) and report the unknown name.

**B9. An EMG channel missing from the data gives an unclear error** — `MuscleTendonPersonalizationParsingTest/emgChannelMissingFromDataIsReported`
- *What happens:* "Index in position 1 exceeds array bounds".
- *Intended:* no. *On dev:* still there.
- *Fix:* check each `<collected_emg_channel_muscle_groups>` entry against the EMG file's columns and report the
  missing one.

### Muscle-Tendon Length Initialization

**B10. Passive moment tracking only works for 101-frame trials** — `MtliCostTermsTest/passiveMomentTrackingWorksForAnyTrialLength`
- *Why:* `calcPassiveMomentTrackingCost.m` (lines 35 and 37) uses `repmat(~columnsWithAllZeros, 1, 1, 101)`.
- *Intended:* no. *On dev:* still there.
- *Fix:* use the data's frame count:
  `repmat(~columnsWithAllZeros, 1, 1, size(experimentalData.passiveData.inverseDynamicsMoments, 3))`.

**B11. An unknown MTLI cost term gives "Too many output arguments"** — `MtliCostTermsTest/unknownTermIsReported`
- *Why:* the message in `calcMuscleTendonLengthInitializationCost.m` (line 76) uses `type` (MATLAB's built-in
  function) instead of `costTerm.type`.
- *Intended:* no. *On dev:* **fixed**.
- *Fix:* `"Cost term " + costTerm.type + " is not valid ..."` (as dev has it).

### Neural Control Personalization

**B12. NCP crashes when a muscle has no MTP activations** — `NeuralControlPersonalizationRegressionTest/iliacusHiddenPredictsIliacus`, `mtliRunCompletesAndFits`, `writesExpectedResultFiles(run=iliacusHidden)`, `writesExpectedResultFiles(run=mtli)`
- *What happens:* "Number of elements must not change" — in exactly the case NCP exists for (predicting
  muscles without MTP results). MTLI inside NCP, which only updates such muscles, can never run.
- *Why:* `stackMtpActivations` in `prepareNcpInitialValues.m` (line 281) reshapes the MTP activations to
  `numMuscles` columns, as if every modeled muscle had them.
- *Intended:* no. *On dev:* still there.
- *Fix:* stack only the muscles that have MTP activations (their names are known when the activations are
  parsed), and give the others a neutral starting value, or leave them out of the initial fit.

**B13. A char settings file name crashes NCP** — `NeuralControlPersonalizationRegressionTest/acceptsCharacterSettingsFileName`
- *What happens:* `NeuralControlPersonalizationTool('file.xml')` fails with "Arrays have incompatible sizes".
- *Why:* `NeuralControlPersonalizationTool.m` (line 49) copies the settings to `fname + fext`, which adds the
  character codes of two char arrays.
- *Intended:* no. *On dev:* still there.
- *Fix:* `fullfile(resultsDirectory, [fname fext])` or `strcat(fname, fext)`.

### Ground Contact Personalization

**B14. Merging a task's result shifts every variable after the resting length** — `GcpCostTermsTest/mergedResultFollowsDesignVariableOrder`
- *Why:* `mergeGroundContactPersonalizationRoundResults` reads the resting spring length without advancing its
  index, so the first B-spline coefficient is read as the resting length, and so on. The tutorial's task 1
  is affected.
- *Intended:* no. *On dev:* still there.
- *Fix:* add `index = index + 1;` after reading `restingSpringLength`.

**B15. No enabled contact surface gives an unclear error** — `GroundContactPersonalizationParsingTest/noEnabledSurfaceIsReported`
- *Why:* `getContactSurfaces` only assigns its output inside the loop over enabled surfaces.
- *Intended:* no. *On dev:* still there.
- *Fix:* start with an empty output and report "No enabled <GCPContactSurface>" if it stays empty.

**B16. A misspelled ground reaction column parses as NaN forces** — `GroundContactPersonalizationParsingTest/misspelledForceColumnIsReported`
- *Why:* the check `any([isnan(grf) isnan(moments) isnan(ec)])` applies `any` to a matrix, so it is only
  true if every column has a NaN. (Names of a different length fail instead, because the column names are a
  char matrix.)
- *Intended:* no. *On dev:* still there.
- *Fix:* `any(isnan([grf moments ec]), "all")`, and store the column names as a string array.

**B17. The force plate rotation design variable does nothing** — `GroundContactPersonalizationRegressionTest/rotationFindsForcePlateAngle`
- *Why:* `calcGroundContactPersonalizationTaskCost` rotates the ground reactions by
  `inputs.surfaces{foot}.forcePlateRotation` (0 during the task), not by the value being optimized.
- *Intended:* no. *On dev:* still there.
- *Fix:* rotate by `valuesStruct.("forcePlateRotation" + foot)`.

**B18. `neighbor_spring_constant` crashes without a moment cost term** — `GroundContactPersonalizationRegressionTest/neighborTermWorksWithoutMomentTerms`, `writesExpectedResultFiles(run=neighbor)`
- *What happens:* `Unrecognized field name "xPosition"`.
- *Why:* `calcGCPModeledValues` only fills the springs' x and z positions when a moment term is enabled, but
  the neighbor term's Gaussian weights need them.
- *Intended:* no. *On dev:* still there.
- *Fix:* fill `markerKinematics.xPosition`/`zPosition` whenever the neighbor term is enabled (or always; they
  come from the same point kinematics call).

### Treatment Optimization

**B19. Synergy weight columns are wrong for groups of different sizes** — `ToTermHelpersTest/synergyWeightColumnsAreTheGroupsMuscles`
- *Why:* `findSynergyWeightIndicesByIndex` has no `break` after finding the synergy's group, so later groups
  overwrite the end column. Affects `synergy_vector_symmetry` when groups differ in size.
- *Intended:* no. *On dev:* still there.
- *Fix:* `break` after setting `indices{i}`.

**B20. Three Design cost terms crash whenever enabled** — `DoCostTermsTest/jointEnergyGenerationRewardsPositivePower`, `jointEnergyAbsorptionRuns`, `angularMomentumMinimizationIsTheAxis`
- *What happens:* "Unrecognized function or variable 'inputs'".
- *Why:* `calcJointEnergyGenerationGoalIntegrand`, `calcJointEnergyAbsorptionGoalIntegrand` (argument named
  `params`) and `calcMinimizingAngularMomentumIntegrand` (no such argument) call
  `normalizeTimeColumn(costTerm, inputs, ...)`.
- *Intended:* no. *On dev:* the code is unchanged (the test cannot reach it there; see Part 2).
- *Fix:* rename the `params` argument to `inputs` in the two energy terms; give the angular momentum term an
  `inputs` argument and pass `auxdata` to it from `generateCostTermStruct`.

**B21. `inverse_dynamics_shape_tracking` crashes whenever enabled** — `DoCostTermsTest/inverseDynamicsShapeIgnoresScale`
- *Why:* `calcTrackingInverseDynamicsShapeIntegrand.m` (line 42): `scaleFactor = modeled \ experimental`; neither
  variable exists.
- *Intended:* no. *On dev:* code unchanged.
- *Fix:* `scaleFactor = idMoment \ experimentalMoment;` (least-squares scale of the modeled onto the
  experimental moment), keeping `cost = experimentalMoment - idMoment * scaleFactor`.

**B22. The built-in Design model functions cannot be used** — `DoModelFunctionsTest/beltSpeedParameterSetsTheBeltSpeed`
- *Why:* `updateSystemFromUserDefinedFunctions` calls `[inputs, values] = func(inputs, values)`, but
  `applyBeltSpeedParameter`, `applyMaxIsometricForceParameter`, ... return one output, and they read
  `values.belt_speed` where `makeGpopsValuesAsStruct` puts it in `values.parameters.belt_speed`.
- *Intended:* no. *On dev:* code unchanged.
- *Fix:* give each `apply*Parameter` the signature `[inputs, values] = apply...(inputs, values)` and read
  `values.parameters.<name>`.

**B23. Without `<results_directory>`, the results directory is `false`** — `TreatmentOptimizationParsingTest/omittedResultsDirectoryIsTheCurrentFolder`
- *Why:* `parseBasicInputs` uses `getTextFromField(getFieldByName(tree, 'results_directory'))`, which is
  `false` for a missing element; the `pwd` default only applies to an empty one.
- *Intended:* no. *On dev:* **worse**: parsing crashes in `getUniqueResultsDirectory(false)`.
- *Fix:* `inputs.resultsDirectory = parseTextOrAlternate(tree, "results_directory", pwd);` (and treat empty
  the same way).

**B24. A misspelled states coordinate gives an unclear error** — `TreatmentOptimizationParsingTest/unknownStatesCoordinateIsReported`
- *What happens:* "Unable to perform assignment because the left and right sides have a different number of
  elements."
- *Intended:* no. *On dev:* not reached (B23 crashes first for this file).
- *Fix:* in `findStatesCoordinateIndices`, check each `<states_coordinate_list>` entry against the IK
  coordinates and report the unknown name.

**B25. Muscle parameters can belong to the wrong muscle** — `TrackingOptimizationParsingTest/muscleParametersFollowTheModeledMuscles`
- *What happens:* with an ankle-only surrogate model, soleus_r gets 1,800 N instead of its 18,600 N, and every
  pennation angle is another muscle's.
- *Why:* `getModelOrOsimxInputs` reads each modeled muscle's values from `getMuscles().get(i-1)` (the model's
  i-th muscle), not the muscle named `muscleNames(i)`.
- *Intended:* no. *On dev:* still there.
- *Fix:* `muscle = model.getMuscles().get(char(inputs.muscleNames(i)));` and read every value from `muscle`.

**B26. Absolute metabolic goals never compute the metabolic cost** — `DesignOptimizationParsingTest/metabolicGoalTurnsOnMetabolicCost`
- *Why:* `parseTreatmentOptimizationInputs` sets `calculateMetabolicCost` only for the
  `relative_metabolic_cost_*` terms.
- *Intended:* no. *On dev:* still there.
- *Fix:* include `absolute_metabolic_cost_per_time` and `absolute_metabolic_cost_per_distance` in that
  check.

---

## Part 2: Failures on `matlab-gui-dev`

183 tests fail on `matlab-gui-dev` (commit `6e7fc4e7`):

| Group | Tests | Intended? | What to do |
|---|---|---|---|
| [D0. Candidate bugs still on dev](#d0-candidate-bugs-still-on-dev) | 33 | No | Fix the code (Part 1). |
| [D1. Intended interface changes](#d1-intended-interface-changes) | 110 | Yes | Update the tests. |
| [D2. Collateral of the results-directory crash](#d2-collateral-of-the-results-directory-crash) | 24 | (No) | Fix B23 on dev, or give the test file a results directory. |
| [D3. Possible regressions](#d3-possible-regressions) | 15 | Unclear | Decide; then fix the code or update the tests. |
| [D4. Not merged yet](#d4-not-merged-yet) | 1 | Yes | Resolves when candidate is merged into dev. |

Two candidate failures pass on dev (B3 and B11 are fixed there).

### D0. Candidate bugs still on dev

33 tests: every Part 1 bug except B3 and B11. Most fail exactly as on candidate. Some fail earlier on dev,
because of an interface change, before reaching the bug: B20, B21, B22, B24. Fix them as in Part 1; the
tests then also need the interface updates in D1.

### D1. Intended interface changes

The code was changed on purpose; the tests still use candidate's interface. **Fix: update the tests** (keep
the same hand-worked expected values).

**Treatment Optimization (77 tests)**

| Tests | Change on dev | How to update the test |
|---|---|---|
| `ToTermRegistryTest` (42), `DoCostTermsTest/walkingSpeedGoalIsScaledSquaredDifference`, `DoCostTermsTest/userDefinedTermCallsTheNamedFunction` | `generateCostTermStruct(type, controllerTypes, tool)` and `generateConstraintTermStruct(type, controllerTypes, tool)` take a logical `[torque synergy muscle user]` vector and return `supportAD` and `termMetadata` too. | Pass `controllerTypes` (e.g. `[true false false false]` for torque) and add the new controller combinations; check the allowed lists again (dev filters cost terms by controller). |
| `ToCostTermsTest` (7) | `makeMaxAllowableError(tool, controllerTypes, terms)`; `findControlsByLabels` reads `controllerTypes` and new cached fields. | Add `controllerTypes` to the calls and hand-built inputs. |
| `ToDesignVariablesTest` (11), `ToSynergyModelTest` (6), `ToConstraintTermsTest` (3), `ToScalingAndDynamicsTest/dynamicConstraintIsScaledDerivatives` | `inputs.controllerType` → `inputs.controllerTypes`; new required fields (`useJerk`, `useControlDynamicsFilter`, `numIndividualMuscles`, `numUserDefinedControls`, `collocationTimeOriginalWithEnd`, ...). | Build the hand-made inputs with the new fields (a shared helper that fills dev's defaults would keep this in one place). |
| `TrackingOptimizationParsingTest` (3), `DesignOptimizationParsingTest/synergyDesignStartsFromPublishedVerification` | The parser sets `controllerTypes`, not `controllerType`; `load_surrogate_model`/`save_surrogate_model` were removed (the surrogate always loads from `<surrogate_model_file_name>` if it exists). | Check `controllerTypes`; drop the `loadSurrogate`/`saveSurrogate` checks and test `surrogateModelFileName` instead. |
| `DoModelFunctionsTest/userModelFunctionChangesTheSetup` | `updateSystemFromUserDefinedFunctions` reads `inputs.systemFns`, not `inputs.auxdata.systemFns`. | Put `systemFns` at the top level of the struct passed in. |

**Muscle-Tendon Personalization and MTLI (18 tests)**

| Tests | Change on dev | How to update the test |
|---|---|---|
| `MtpCostTermsTest` (7), `MtpCostTest` (4) | Cost terms were renamed: candidate's `calcEmgScaleFactorDevationCost` and `calcMuscleExcitationPenaltyCost` and the types `inverse_dynamics_joint_moment` and `passive_muscle_force` no longer exist; some term functions take an extra argument; groups moved to `inputs.emgParameterGroups`. | Call dev's names and signatures. |
| `MuscleTendonPersonalizationParsingTest/minimalUsesDefaults`, `sharedDelaySettingIsRead`, `missingMuscleSpecificDelaysIsReported` | `<muscle_specific_electromechanical_delays>` moved from each task to the tool level (it is no longer required per task). | Read it from the tool level and drop the per-task requirement test. |
| `MtliCostTermsTest/enabledTermsAreStacked`, `absoluteLengthsSwitchTheLengthTerms`, `passiveMomentTermNeedsPassiveData` | MTLI cost term types were renamed (e.g. `optimal_muscle_fiber_length`, `passive_joint_moment` are no longer valid names). | Use the new type names. |
| `MtliCostTermsTest/muscleStressDefaults` | A deviation term's default center is now the initial guess (1), not 1.2. | Expect the cost around 1. |

**Neural Control Personalization (15 tests)**

| Tests | Change on dev | How to update the test |
|---|---|---|
| `NeuralControlPersonalizationParsingTest/fixedWeightsAreReadInMuscleOrder`, `fixedWeightsMissingAMuscleAreReported`, `fixedWeightsWithAnExtraMuscleAreReported`, `fixedWeightsWithWrongSynergyCountAreReported`, `fixedWeightsWithoutFileAreReported`; `NeuralControlPersonalizationRegressionTest/fixedWeightsKeepWeightsAndRecoverCommands`, `matchesNominalResult(nominalRun=fixedWeights)`, `writesExpectedResultFiles(run=fixedWeights)`; `NcpSyntheticDataTest/truthReproducesItsMoments(syntheticCase=fixed_weights)` | Fixed synergy weights are now read from `<initial_guess_directory>`, which must be given. | Add `<initial_guess_directory>` to the fixed-weights settings files and put `synergyWeights.sto` there. |
| `NcpInitialValuesTest` (5) | `prepareNcpInitialValues` needs `initialGuessHasWeights` and `initialGuessHasCommands`. | Set the new fields in the hand-built inputs. |
| `NcpCostTest/activationTrackingWithoutMtpDataCostsNothing` | An enabled `activation_tracking` term without MTP data is now an error, not zero cost. | Expect the error. |

### D2. Collateral of the results-directory crash

24 tests: every other test in `TreatmentOptimizationParsingTest`. The class parses
`settings_tracking_torque_minimal.xml`, which leaves `<results_directory>` out, in its setup, and on dev that
crashes (B23), so the whole class fails. **Fix:** fix B23 on dev (the parser should default to the current
folder). Or, if leaving it out is meant to be an error now, add `<results_directory>` to the minimal file
and change B23's test to expect a clear error.

### D3. Possible regressions

The code changed in a way that may not be intended. **The developers should decide.**

**R1. MTP writes time constants and delays in internal units** — `MuscleTendonPersonalizationRegressionTest`
(9): `emgScaleRecoversTruth`, `allFitsMomentsButCannotIdentifyParameters`, `twoTrialsIdentifiesParameters`,
`tutorialFitsAsWellAsPublishedRun`, `matchesNominalResult` (5 cases)
- *What happens:* `muscleModelParameters.sto` has activation time constants 100× and electromechanical delays
  10× their values in seconds, so they look out of bounds and differ from the nominal results.
- *Why:* `saveMtpMuscleModelParameters` no longer divides by 100 and 10, and the plot labels lost "[s]", while
  `plotMtpHillTypeMuscleParams` now divides the delay by 10 itself. It came in with the candidate→dev merges.
- *Fix if unintended:* restore the `/ 100` and `/ 10` in `saveMtpMuscleModelParameters` and remove the plot's
  extra division. *If intended:* document the new units and update the tests' expected rows (and
  `updateMtpNominal`).

**R2. MTLI inside NCP requires coordinates NCP does not track** — `NeuralControlPersonalizationParsingTest/fullAlsoParsesMtli`, `mtliCanBeEnabled`; `NeuralControlPersonalizationRegressionTest/mtliRunCompletesAndFits` (also B12)
- *What happens:* "The following coordinate(s) are required but were not found in the moment arm data:
  hip_adduction_r, hip_rotation_r, subtalar_angle_r".
- *Why:* MTLI's passive data reordering (`reorderPreprocessedDataByMuscleNames`) now requires every passive
  coordinate in the gait moment arm data.
- *Fix if unintended:* only require the coordinates both data sets have. *If intended:* the fixtures need
  moment arms for those coordinates.

**R3. Duplicate muscles give a misleading error** — `NeuralControlPersonalizationParsingTest/duplicateMusclesAreRejectedWhenNcpRuns`
- *What happens:* a muscle in two synergy groups is now reported as "required ... but not found in the muscle
  tendon length/velocity data" instead of as a duplicate.
- *Fix:* check for duplicate muscles (`verifyNoDuplicateMusclesBetweenSynergyGroups`) before reordering the
  data.

**R4. NCP no longer saves `commandWindowOutput.txt`** — `NeuralControlPersonalizationRegressionTest/writesExpectedResultFiles(run=allTracked)`, `(run=sum)`, `(run=tutorial)`
- *What happens:* every other result file is written, but not the command window log.
- *Fix if unintended:* restore the diary move into the results folder (possibly affected by dev commit `6e7fc4e7`,
  "Fix copy settings file to results dir"). *If intended:* drop the file from the test's list.

### D4. Not merged yet

**`MuscleModelTest/muscleForceAtOptimalLengthAndZeroVelocity`** (1 test) — `calcMuscleForce` (and
`calcTendonForce`) were added on `candidate-1.5.4` after dev branched off and are not on dev yet. Resolves
when candidate is merged into dev.

---

## Quick reference

Every failing test, alphabetically by class. "Cand." and "Dev" say whether it fails on each branch; the last
column points to the explanation above.

| Test | Cand. | Dev | See |
|---|---|---|---|
| `DesignOptimizationParsingTest/metabolicGoalTurnsOnMetabolicCost` | ✗ | ✗ | B26 |
| `DesignOptimizationParsingTest/synergyDesignStartsFromPublishedVerification` | | ✗ | D1 |
| `DoCostTermsTest/angularMomentumMinimizationIsTheAxis` | ✗ | ✗ | B20 |
| `DoCostTermsTest/inverseDynamicsShapeIgnoresScale` | ✗ | ✗ | B21 |
| `DoCostTermsTest/jointEnergyAbsorptionRuns` | ✗ | ✗ | B20 |
| `DoCostTermsTest/jointEnergyGenerationRewardsPositivePower` | ✗ | ✗ | B20 |
| `DoCostTermsTest/userDefinedTermCallsTheNamedFunction` | | ✗ | D1 |
| `DoCostTermsTest/walkingSpeedGoalIsScaledSquaredDifference` | | ✗ | D1 |
| `DoModelFunctionsTest/beltSpeedParameterSetsTheBeltSpeed` | ✗ | ✗ | B22 |
| `DoModelFunctionsTest/userModelFunctionChangesTheSetup` | | ✗ | D1 |
| `GcpCostTermsTest/mergedResultFollowsDesignVariableOrder` | ✗ | ✗ | B14 |
| `GroundContactPersonalizationParsingTest/misspelledForceColumnIsReported` | ✗ | ✗ | B16 |
| `GroundContactPersonalizationParsingTest/missingResultsDirectoryIsReported` | ✗ | ✗ | B7 |
| `GroundContactPersonalizationParsingTest/noEnabledSurfaceIsReported` | ✗ | ✗ | B15 |
| `GroundContactPersonalizationRegressionTest/neighborTermWorksWithoutMomentTerms` | ✗ | ✗ | B18 |
| `GroundContactPersonalizationRegressionTest/rotationFindsForcePlateAngle` | ✗ | ✗ | B17 |
| `GroundContactPersonalizationRegressionTest/writesExpectedResultFiles(run=neighbor)` | ✗ | ✗ | B18 |
| `InverseKinematicsErrorTest/usesEveryFrameInMarkerFile` | ✗ | ✗ | B1 |
| `JointModelPersonalizationParsingTest/allTasksDisabledIsReported` | ✗ | ✗ | B2 |
| `MtliCostTermsTest/absoluteLengthsSwitchTheLengthTerms` | | ✗ | D1 |
| `MtliCostTermsTest/enabledTermsAreStacked` | | ✗ | D1 |
| `MtliCostTermsTest/muscleStressDefaults` | | ✗ | D1 |
| `MtliCostTermsTest/passiveMomentTermNeedsPassiveData` | | ✗ | D1 |
| `MtliCostTermsTest/passiveMomentTrackingWorksForAnyTrialLength` | ✗ | ✗ | B10 |
| `MtliCostTermsTest/unknownTermIsReported` | ✗ | | B11 |
| `MtpCostComputationsTest/groupsWithoutFirstMuscleCompareTheRightMuscles` | ✗ | ✗ | B4 |
| `MtpCostTermsTest/maximumFiberLengthPenaltyStartsAtTheLimit` | ✗ | ✗ | B5 |
| `MtpCostTermsTest/minimumFiberLengthPenaltyStartsAtTheLimit` | ✗ | ✗ | B5 |
| `MtpCostTermsTest/activationNonlinearityDefaults`, `activationTimeConstantDefaults`, `activationTimeConstantWithParsedZeroCenter`, `emgScaleFactorDefaults`, `excitationPenaltySkipsPaddingAndMissingMuscles`, `groupedElectromechanicalDelayDefaults`, `groupedEmgScaleFactorUsesActivationGroups` | | ✗ | D1 |
| `MtpCostTest/infiniteCostIsCapped`, `sumsOnlyEnabledTerms`, `synergyOnlyTermsAddNothingWithoutSynergies`, `synergyRunUsesSynergyModeledFiberLengths` | | ✗ | D1 |
| `MuscleModelTest/commonDelayShiftsEmgLater` | ✗ | | B3 |
| `MuscleModelTest/muscleForceAtOptimalLengthAndZeroVelocity` | | ✗ | D4 |
| `MuscleTendonPersonalizationParsingTest/allTasksDisabledIsReported` | ✗ | ✗ | B6 |
| `MuscleTendonPersonalizationParsingTest/emgChannelMissingFromDataIsReported` | ✗ | ✗ | B9 |
| `MuscleTendonPersonalizationParsingTest/minimalUsesDefaults`, `missingMuscleSpecificDelaysIsReported`, `sharedDelaySettingIsRead` | | ✗ | D1 |
| `MuscleTendonPersonalizationParsingTest/missingResultsDirectoryIsReported` | ✗ | ✗ | B7 |
| `MuscleTendonPersonalizationParsingTest/unknownCoordinateIsReported` | ✗ | ✗ | B8 |
| `MuscleTendonPersonalizationRegressionTest/*` (9: four truth/fit checks, five nominal) | | ✗ | R1 |
| `NcpCostTest/activationTrackingWithoutMtpDataCostsNothing` | | ✗ | D1 |
| `NcpInitialValuesTest/*` (5) | | ✗ | D1 |
| `NcpSyntheticDataTest/truthReproducesItsMoments(syntheticCase=fixed_weights)` | | ✗ | D1 |
| `NeuralControlPersonalizationParsingTest/duplicateMusclesAreRejectedWhenNcpRuns` | | ✗ | R3 |
| `NeuralControlPersonalizationParsingTest/fixedWeights*` (5) | | ✗ | D1 |
| `NeuralControlPersonalizationParsingTest/fullAlsoParsesMtli`, `mtliCanBeEnabled` | | ✗ | R2 |
| `NeuralControlPersonalizationParsingTest/missingResultsDirectoryIsReported` | ✗ | ✗ | B7 |
| `NeuralControlPersonalizationRegressionTest/acceptsCharacterSettingsFileName` | ✗ | ✗ | B13 |
| `NeuralControlPersonalizationRegressionTest/fixedWeightsKeepWeightsAndRecoverCommands`, `matchesNominalResult(nominalRun=fixedWeights)`, `writesExpectedResultFiles(run=fixedWeights)` | | ✗ | D1 |
| `NeuralControlPersonalizationRegressionTest/iliacusHiddenPredictsIliacus`, `mtliRunCompletesAndFits`, `writesExpectedResultFiles(run=iliacusHidden)`, `writesExpectedResultFiles(run=mtli)` | ✗ | ✗ | B12 (and R2 for mtli) |
| `NeuralControlPersonalizationRegressionTest/writesExpectedResultFiles(run=allTracked)`, `(run=sum)`, `(run=tutorial)` | | ✗ | R4 |
| `ToConstraintTermsTest/*` (3) | | ✗ | D1 |
| `ToCostTermsTest/*` (7) | | ✗ | D1 |
| `ToDesignVariablesTest/*` (11) | | ✗ | D1 |
| `ToScalingAndDynamicsTest/dynamicConstraintIsScaledDerivatives` | | ✗ | D1 |
| `ToSynergyModelTest/*` (6) | | ✗ | D1 |
| `ToTermHelpersTest/synergyWeightColumnsAreTheGroupsMuscles` | ✗ | ✗ | B19 |
| `ToTermRegistryTest/*` (42) | | ✗ | D1 |
| `TrackingOptimizationParsingTest/muscleParametersFollowTheModeledMuscles` | ✗ | ✗ | B25 |
| `TrackingOptimizationParsingTest/synergyControllerDefaults`, `synergyControllerReadsTheSynergyGroups`, `torqueTutorialTracksCoordinatesAndLoads` | | ✗ | D1 |
| `TreatmentOptimizationParsingTest/omittedResultsDirectoryIsTheCurrentFolder` | ✗ | ✗ | B23 |
| `TreatmentOptimizationParsingTest/unknownStatesCoordinateIsReported` | ✗ | ✗ | B24 |
| `TreatmentOptimizationParsingTest/*` (the other 24) | | ✗ | D2 |
