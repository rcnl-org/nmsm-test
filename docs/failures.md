# Test failures

Every test that fails, why, whether the behavior it catches is intended, and how to fix it. Test names are as
`runTests` prints them; each test is described in [test-catalog.md](test-catalog.md).

| Branch | Commit | Pass | Fail | Total |
|---|---|---|---|---|
| `candidate-1.5.4` (the branch the tests are written for) | `851c627f` | 682 | 35 | 717 |
| `matlab-gui-dev` (diagnostic run) | `6e7fc4e7` | 534 | 183 | 717 |

Both runs were on 2026-10-22/26 with MATLAB R2025a, OpenSim 4.5 and a licensed GPOPS-II.

**Fixed since these runs (2026-10-27 to 30):** B1, B2, B6, B7, B8, B9, B11, B13, B15, B16, B23 and B24 on
`candidate-1.5.4`; B14, B17, B18 and B27 (found later) on `gcp-bug-fixes`; B19, B20, B21, B22, B25, B26 and B28 (found later) on
`treatment-optimization-bug-fixes`. B29 and B30 were found later: B30 is not fixed, and B29 is left as is (see its entry).
Their tests pass there now; each fixed bug below says so, and the quick reference marks them "fixed". The
counts above are from before these fixes.

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

**B1. IK skips the last marker frame** — `InverseKinematicsErrorTest/usesEveryFrameInMarkerFile`, `InverseKinematicsErrorTest/usesEveryFrameWhenTimesAreRounded`, `MarkerFrameTimesTest/errorReportHasEveryFrame` (exact, rounded)
- **Fixed on `candidate-1.5.4`** (2026-10-27).
- *What happens:* JMP's IK error uses 119 of the marker file's 120 frames, and the per-marker error report
  (`MarkerErrors/*.sto`) also leaves out the last frame.
- *Why:* in `computeInverseKinematicsSquaredError.m` (line 46), the loop stops on
  `state.getTime() + 1/frequency > finishTime`. Floating-point rounding makes that true one frame early.
  When the marker file's times are rounded (as motion capture exports often write them), the error is up to
  the rounding, about 5e-6 s, so a small tolerance such as `> finishTime + 1e-6/frequency` still skips the
  frame. `reportDistanceErrorByMarker.m` has the same check, and its loop also runs only
  `getNumFrames() - 1` times.
- *Intended:* no. *On dev:* still there.
- *Fix:* loop over the marker table's own times instead of adding `1/frequency`. The fix (commit `e786478f`) on
  `candidate-1.5.4` adds `getMarkerFrameTimes` (the table times in the time range, each end matched to within
  half a frame) and uses it in both files.

**B2. Disabling every task gives an unclear error** — `JointModelPersonalizationParsingTest/allTasksDisabledIsReported`
- **Fixed on `candidate-1.5.4`** (2026-10-27).
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
- **Fixed on `candidate-1.5.4`** (2026-10-27).
- Same as B2, in `getTasks` of `parseMuscleTendonPersonalizationSettingsTree.m`. *On dev:* still there.
- *Fix:* as B2: `output = {};` before the loop and a clear error if it stays empty.

**B7. A missing `<results_directory>` gives "Dot indexing is not supported"** — `MuscleTendonPersonalizationParsingTest/missingResultsDirectoryIsReported`, `NeuralControlPersonalizationParsingTest/missingResultsDirectoryIsReported`, `GroundContactPersonalizationParsingTest/missingResultsDirectoryIsReported`
- **Fixed on `candidate-1.5.4`** (2026-10-27).
- *Why:* `getFieldByName(settingsTree, 'results_directory').Text` in the MTP, NCP and GCP parsers;
  `getFieldByName` returns `false` for a missing element.
- *Intended:* no. *On dev:* still there.
- *Fix:* `getFieldByNameOrError`, which names the element. Every tool except JMP requires
  `<results_directory>` (see B23); an empty element still means the current folder.

**B8. A misspelled coordinate gives an unclear error** — `MuscleTendonPersonalizationParsingTest/unknownCoordinateIsReported`
- **Fixed on `candidate-1.5.4`** (2026-10-27).
- *What happens:* "Unable to perform assignment because the size of the left side is 0-by-139 ...", deep in
  EMG parsing.
- *Intended:* no. *On dev:* still there.
- *Fix:* in the parser, check each `<coordinate_list>` entry against the model's coordinates (or the ID
  columns) and report the unknown name.

**B9. An EMG channel missing from the data gives an unclear error** — `MuscleTendonPersonalizationParsingTest/emgChannelMissingFromDataIsReported`
- **Fixed on `candidate-1.5.4`** (2026-10-27).
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
- **Fixed on `candidate-1.5.4`** (2026-10-27).
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
- **Fixed on `candidate-1.5.4`** (2026-10-28).
- *What happens:* `NeuralControlPersonalizationTool('file.xml')` fails with "Arrays have incompatible sizes".
- *Why:* `NeuralControlPersonalizationTool.m` (line 49) copies the settings to `fname + fext`, which adds the
  character codes of two char arrays.
- *Intended:* no. *On dev:* still there.
- *Fix:* `fullfile(resultsDirectory, [fname fext])` or `strcat(fname, fext)`.

### Ground Contact Personalization

**B14. Merging a task's result shifts every variable after the resting length** — `GcpCostTermsTest/mergedResultFollowsDesignVariableOrder`
- **Fixed on `gcp-bug-fixes`** (commit `a87025f1`).
- *Why:* `mergeGroundContactPersonalizationRoundResults` reads the resting spring length without advancing its
  index, so the first B-spline coefficient is read as the resting length, and so on. The tutorial's task 1
  is affected.
- *Effect:* the B-spline coefficients are multipliers near 1 on the foot kinematics. After such a task, the
  first coordinate's first multiplier became the resting length (about 0.006), every other one moved one
  slot, and the last was lost. The tutorial's later tasks optimize the coefficients again, so its saved
  kinematics were not the corrupted ones, but task 2 started from them. A last task with this combination
  would have saved wrong values.
- *Intended:* no. *On dev:* still there.
- *Fix:* add `index = index + 1;` after reading `restingSpringLength`. This changes the 5-iteration tutorial's
  path: its nominal and `tutorialRms` were re-recorded on 2026-10-29 (force RMS 25–35% higher after 5
  iterations, which reflects a different, unconverged path, not a worse model).

**B15. No enabled contact surface gives an unclear error** — `GroundContactPersonalizationParsingTest/noEnabledSurfaceIsReported`
- **Fixed on `candidate-1.5.4`** (2026-10-27).
- *Why:* `getContactSurfaces` only assigns its output inside the loop over enabled surfaces.
- *Intended:* no. *On dev:* still there.
- *Fix:* start with an empty output and report "No enabled <GCPContactSurface>" if it stays empty.

**B16. A misspelled ground reaction column parses as NaN forces** — `GroundContactPersonalizationParsingTest/misspelledForceColumnIsReported`
- **Fixed on `candidate-1.5.4`** (2026-10-27).
- *Why:* the check `any([isnan(grf) isnan(moments) isnan(ec)])` applies `any` to a matrix, so it is only
  true if every column has a NaN. (Names of a different length fail instead, because the column names are a
  char matrix.)
- *Intended:* no. *On dev:* still there.
- *Fix:* `any(isnan([grf moments ec]), "all")`, and store the column names as a string array.

**B17. The force plate rotation design variable does nothing** — `GroundContactPersonalizationRegressionTest/rotationFindsForcePlateAngle`
- **Fixed on `gcp-bug-fixes`** (commit `3c1fdeb9`, with B27).
- *Why:* `calcGroundContactPersonalizationTaskCost` rotates the ground reactions by
  `inputs.surfaces{foot}.forcePlateRotation` (0 during the task), not by the value being optimized.
- *Intended:* no. *On dev:* still there.
- *Fix:* rotate by `valuesStruct.("forcePlateRotation" + foot)`.

**B18. `neighbor_spring_constant` crashes without a moment cost term** — `GroundContactPersonalizationRegressionTest/neighborTermWorksWithoutMomentTerms`, `writesExpectedResultFiles(run=neighbor)`, `GcpTermSmokeTest/termGivesFiniteCosts(type=neighbor_spring_constant)`
- **Fixed on `gcp-bug-fixes`** (commit `07101331`).
- *What happens:* `Unrecognized field name "xPosition"`. With that fixed, saving then failed with
  `Unrecognized field name "xGrfMoment"`.
- *Why:* `calcGCPModeledValues` only fills the springs' x and z positions when a moment term is enabled, but
  the neighbor term's Gaussian weights need them. Separately, the saving functions call
  `calcGCPModeledValues` with the last task's cost terms, so only what those terms need is computed: any run
  whose last task has no moment term (or no horizontal force term) failed to write its ground reactions.
- *Intended:* no. *On dev:* still there.
- *Fix:* fill `markerKinematics.xPosition`/`zPosition` whenever the moment terms or the neighbor term are
  enabled; and give `calcGCPModeledValues` an optional `calculateAllValues` argument, which
  `writeOptimizedGroundReactionsToSto`, `writeCombinedOptimizedGroundReactionsToSto` and
  `plotGroundReactionQuantities` pass as `true`.

**B27. A later task ignores the force plate rotation and electrical center shift found earlier** — `GroundContactPersonalizationRegressionTest/laterTasksKeepTheForcePlateAngle`
- **Fixed on `gcp-bug-fixes`** (commit `3c1fdeb9`). Found on 2026-10-28, after the runs above.
- *What happens:* with the rotation optimized in task 1 and not in task 2, task 2 fits the unrotated ground
  reactions. In the `rotationKept` case, damping moves from 1.5 to 1.492 and friction from 0.7 to 0.69974 to
  make up for it. The saved ground reactions are rotated, so they do not match what task 2 fit.
- *Why:* `calcGroundContactPersonalizationTaskCost` applies the shift only if the current task optimizes
  it (`designVariables(7:9)`) and the rotation only if it optimizes it (`designVariables(10)`).
- *Intended:* no. *On dev:* still there.
- *Fix:* apply both in every task, from `valuesStruct` (the stored value when the task does not optimize
  it). A zero shift or rotation changes nothing.

### Treatment Optimization

**B19. Synergy weight columns are wrong for groups of different sizes** — `ToTermHelpersTest/synergyWeightColumnsAreTheGroupsMuscles`
- **Fixed on `treatment-optimization-bug-fixes`** (uncommitted, 2026-10-30).
- *Why:* `findSynergyWeightIndicesByIndex` has no `break` after finding the synergy's group, so later groups
  overwrite the end column. Affects `synergy_vector_symmetry` when groups differ in size.
- *Intended:* no. *On dev:* still there.
- *Fix:* `break` after setting `indices{i}`.

**B20. Three Design cost terms crash whenever enabled** — `DoCostTermsTest/jointEnergyGenerationRewardsPositivePower`, `jointEnergyAbsorptionRuns`, `angularMomentumMinimizationIsTheAxis`, and `TreatmentOptimizationTermSmokeTest` for `joint_energy_generation_goal`, `joint_energy_absorption_goal` and `angular_momentum_minimization` (designTorque and designSynergy)
- **Fixed on `treatment-optimization-bug-fixes`**: the energy terms in commit `5a509374`, angular momentum minimization uncommitted (2026-10-30).
- *What happens:* "Unrecognized function or variable 'inputs'".
- *Why:* `calcJointEnergyGenerationGoalIntegrand`, `calcJointEnergyAbsorptionGoalIntegrand` (argument named
  `params`) and `calcMinimizingAngularMomentumIntegrand` (no such argument) call
  `normalizeTimeColumn(costTerm, inputs, ...)`.
- *Intended:* no. *On dev:* the code is unchanged (the test cannot reach it there; see Part 2).
- *Fix:* rename the `params` argument to `inputs` in the two energy terms; give the angular momentum term an
  `inputs` argument and pass `auxdata` to it from `generateCostTermStruct`.

**B21. `inverse_dynamics_shape_tracking` crashes whenever enabled** — `DoCostTermsTest/inverseDynamicsShapeIgnoresScale`, and `TreatmentOptimizationTermSmokeTest` for `inverse_dynamics_shape_tracking` (designTorque and designSynergy)
- **Fixed on `treatment-optimization-bug-fixes`** (commit `5a509374`).
- *Why:* `calcTrackingInverseDynamicsShapeIntegrand.m` (line 42): `scaleFactor = modeled \ experimental`; neither
  variable exists.
- *Intended:* no. *On dev:* code unchanged.
- *Fix:* `scaleFactor = idMoment \ experimentalMoment;` (least-squares scale of the modeled onto the
  experimental moment), keeping `cost = experimentalMoment - idMoment * scaleFactor`.

**B22. The built-in Design model functions cannot be used** — `DoModelFunctionsTest/beltSpeedParameterSetsTheBeltSpeed`
- **Fixed on `treatment-optimization-bug-fixes`** (uncommitted, 2026-10-30). The related overwrite of same-type variables is B28.
- *Why:* `updateSystemFromUserDefinedFunctions` calls `[inputs, values] = func(inputs, values)`, but
  `applyBeltSpeedParameter`, `applyMaxIsometricForceParameter`, ... return one output, and they read
  `values.belt_speed` where `makeGpopsValuesAsStruct` puts it in `values.parameters.belt_speed`.
- *Intended:* no. *On dev:* code unchanged.
- *Fix:* give each `apply*Parameter` the signature `[inputs, values] = apply...(inputs, values)` and read
  `values.parameters.<name>`.

**B23. Without `<results_directory>`, the results directory is `false`** — `TreatmentOptimizationParsingTest/missingResultsDirectoryIsReported`
- **Fixed on `candidate-1.5.4`** (2026-10-27).
- *Why:* `parseBasicInputs` uses `getTextFromField(getFieldByName(tree, 'results_directory'))`, which is
  `false` for a missing element; the `pwd` default only applies to an empty one.
- *Intended:* no. *On dev:* **worse**: parsing crashes in `getUniqueResultsDirectory(false)`.
- *Fix:* the developers decided that every tool except JMP requires `<results_directory>` (as the XML
  reference says), so the parser uses `getFieldByNameOrError`, as MTP, NCP and GCP do (B7). An empty element
  still means the current folder. The test was `omittedResultsDirectoryIsTheCurrentFolder`; it now expects
  the error, and `settings_tracking_torque_minimal.xml` and the files based on it give a results directory.

**B24. A misspelled states coordinate gives an unclear error** — `TreatmentOptimizationParsingTest/unknownStatesCoordinateIsReported`
- **Fixed on `candidate-1.5.4`** (2026-10-27).
- *What happens:* "Unable to perform assignment because the left and right sides have a different number of
  elements."
- *Intended:* no. *On dev:* not reached (B23 crashes first for this file).
- *Fix:* in `findStatesCoordinateIndices`, check each `<states_coordinate_list>` entry against the IK
  coordinates and report the unknown name.

**B25. Muscle parameters can belong to the wrong muscle** — `TrackingOptimizationParsingTest/muscleParametersFollowTheModeledMuscles`
- **Fixed on `treatment-optimization-bug-fixes`** (commit `23eebd8b`).
- *What happens:* with an ankle-only surrogate model, soleus_r gets 1,800 N instead of its 18,600 N, and every
  pennation angle is another muscle's.
- *Why:* `getModelOrOsimxInputs` reads each modeled muscle's values from `getMuscles().get(i-1)` (the model's
  i-th muscle), not the muscle named `muscleNames(i)`.
- *Intended:* no. *On dev:* still there.
- *Fix:* `muscle = model.getMuscles().get(char(inputs.muscleNames(i)));` and read every value from `muscle`.

**B26. Absolute metabolic goals never compute the metabolic cost** — `DesignOptimizationParsingTest/metabolicGoalTurnsOnMetabolicCost`, and `DesignOptimizationMetabolicRegressionTest/lowerGoalLowersTheMetabolicCost(goal=absolute)` and `higherGoalRaisesTheMetabolicCost(goal=absolute)`
- **Fixed on `treatment-optimization-bug-fixes`** (uncommitted, 2026-10-30). Only the four type names were added; the flags are still only set on Windows (`mexw64`), an open question.
- *Why:* `parseTreatmentOptimizationInputs` sets `calculateMetabolicCost` only for the
  `relative_metabolic_cost_*` terms.
- *Effect:* without the flag the metabolic power is never computed (the inverse dynamics MEX is asked not to), so in
  the endpoint function `metabolicCost` is zeros and an absolute goal is a constant, `((0 - error center) /
  allowable error)^2`, with no gradient. In `DesignOptimizationMetabolicRegressionTest` the absolute goal runs then
  end at 891, exactly where a run with no goal ends, for either target.
- *Intended:* no. *On dev:* still there.
- *Fix:* include `absolute_metabolic_cost_per_time` and `absolute_metabolic_cost_per_distance` in that
  check.

**B28. Design variables of the same type overwrite each other** — `ToDesignVariablesTest/variablesOfTheSameTypeAreAllKept`
- Found on 2026-10-30 while fixing B22. **Fixed on `treatment-optimization-bug-fixes`** (uncommitted, 2026-10-30).
- *What happens:* with two user-defined variables of one type (for example `max_isometric_force` for two
  muscles), `values.parameters.max_isometric_force` holds only the last variable's value.
- *Why:* `makeGpopsValuesAsStruct` assigns `values.parameters.(type)` once per variable, so each one replaces
  the previous. The built-in model functions read one value per variable, in order
  (`values.parameters.<type>(counter)`), so the first muscle gets the second's value and the second reads past
  the end and crashes. With one variable per type (all current fixtures) it works.
- *Intended:* no. *On dev:* not checked.
- *Fix:* append same-type variables in order: start `values.parameters` as an empty struct and, for each
  variable, `values.parameters.(type) = [values.parameters.(type), <its values>]` (creating the field empty
  the first time).

**B29. Metabolic cost goals fail to set up unless the initial guess was solved on the same grid** — no test
- Found on 2026-10-30 while building the metabolic regression test. **Left as is** (decision of 2026-10-30): the
  initial guess for a metabolic goal is in practice a previous run's output on the same grid, so the case is not
  expected to come up, and its test was removed. If it does, the error does not name the cause; an `assert` with a
  clear message in `checkInitialGuess` would be the cheap improvement.
- *What happens:* with any enabled metabolic goal (relative or absolute), preparing the problem fails with
  `Unrecognized field name "initialMetabolicCost"` in `setupMetabolicCost` (`convertToGpopsInputs`), unless the
  initial guess files have exactly one row more than the solver settings' collocation points. That holds only when
  the initial guess is the output of a run solved on the same mesh: the synergy tutorial's published Verification
  results (51 rows) with its 1 interval x 50 points. A guess solved on another mesh (`gpops_small.xml`'s 8 x 3
  against those 51 rows), mesh refinement, or a guess from preprocessed data (the kick's IK has 63 frames, the torque
  tutorial's grid 25 x 4) all fail.
- *Why:* `checkInitialGuess` evaluates the metabolic power at the initial guess's own times (`inputs.initialTime`,
  read from the initial guess files) but only stores it as `inputs.initialMetabolicCost`
  `if length(output.metabolicCost) == length(inputs.experimentalTime)`. By then `experimentalTime` is no longer the
  tracked data's times: `splineExperimentalToCollocationPoints` has replaced it with the collocation points plus the
  end point. `setupMetabolicCost` then reads `initialMetabolicCost` unconditionally.
- *Intended:* no. *On dev:* not checked.
- *Fix:* store it whenever the metabolic cost is calculated. The length the later code expects is the initial
  guess's point count (`computeCollocationPointTimes` uses it when `length(phase.time) ==
  length(initialMetabolicCost) - 1`), so compare with the guess's times, not `experimentalTime`, if a check is
  kept at all.

**B30. Absolute metabolic goals see the metabolic cost in GPOPS-II's scaled time** — `DesignOptimizationMetabolicRegressionTest/higherGoalRaisesTheMetabolicCost(goal=absolute)`
- Found on 2026-10-30 while building the metabolic regression test. Not fixed yet.
- *What happens:* an absolute metabolic goal pushes the metabolic cost toward a target that is off by a factor of
  1 / (maxTime − minTime). In the synergy tutorial problem (final time range 0 to 0.36 s) the term sees 2384 where
  the metabolic cost per unit time is 858, so targets of 600 and 1200 both pull the cost down (the runs end at 564
  and 540). Relative goals are not affected: they divide by the initial guess's integral, which is scaled the same
  way.
- *Why:* GPOPS-II solves in scaled time (`scaleToBounds(time, maxTime, minTime)` maps the time range onto an
  interval of length 1), so the metabolic power integral the endpoint function reads
  (`setup.phase.integral(end - counter)`) is the energy divided by (maxTime − minTime): 739 instead of 266 J here.
  `calcAbsoluteMetabolicCostPerTimeGoalDiscrete` divides it by the real final time as if it were the energy.
- *Intended:* no. *On dev:* not checked.
- *Fix:* multiply the integral by (maxTime − minTime) where the endpoint function reads it, and do the same where
  the initial guess's integral is stored (`computeCollocationPointTimes`, `convertToGpopsInputs`) so the relative
  goals stay consistent. The braking and propulsive impulse goals read their integrals the same way and probably
  need the same correction (not checked).

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
crashes (B23), so the whole class fails. **Resolved in the tests (2026-10-27):** `<results_directory>` is
now required, so the minimal file and the files based on it give one, and B23's test expects a clear error.

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
| `DesignOptimizationMetabolicRegressionTest/higherGoalRaisesTheMetabolicCost(goal=absolute)` | ✗ | not run | B30 |
| `DesignOptimizationParsingTest/metabolicGoalTurnsOnMetabolicCost` | fixed | ✗ | B26 |
| `DesignOptimizationParsingTest/synergyDesignStartsFromPublishedVerification` | | ✗ | D1 |
| `DoCostTermsTest/angularMomentumMinimizationIsTheAxis` | fixed | ✗ | B20 |
| `DoCostTermsTest/inverseDynamicsShapeIgnoresScale` | fixed | ✗ | B21 |
| `DoCostTermsTest/jointEnergyAbsorptionRuns` | fixed | ✗ | B20 |
| `DoCostTermsTest/jointEnergyGenerationRewardsPositivePower` | fixed | ✗ | B20 |
| `DoCostTermsTest/userDefinedTermCallsTheNamedFunction` | | ✗ | D1 |
| `DoCostTermsTest/walkingSpeedGoalIsScaledSquaredDifference` | | ✗ | D1 |
| `DoModelFunctionsTest/beltSpeedParameterSetsTheBeltSpeed` | fixed | ✗ | B22 |
| `DoModelFunctionsTest/userModelFunctionChangesTheSetup` | | ✗ | D1 |
| `GcpCostTermsTest/mergedResultFollowsDesignVariableOrder` | fixed | ✗ | B14 |
| `GcpTermSmokeTest/termGivesFiniteCosts(type=neighbor_spring_constant)` | fixed | not run | B18 |
| `GroundContactPersonalizationParsingTest/misspelledForceColumnIsReported` | fixed | ✗ | B16 |
| `GroundContactPersonalizationParsingTest/missingResultsDirectoryIsReported` | fixed | ✗ | B7 |
| `GroundContactPersonalizationParsingTest/noEnabledSurfaceIsReported` | fixed | ✗ | B15 |
| `GroundContactPersonalizationRegressionTest/laterTasksKeepTheForcePlateAngle` | fixed | ✗ | B27 |
| `GroundContactPersonalizationRegressionTest/neighborTermWorksWithoutMomentTerms` | fixed | ✗ | B18 |
| `GroundContactPersonalizationRegressionTest/rotationFindsForcePlateAngle` | fixed | ✗ | B17 |
| `GroundContactPersonalizationRegressionTest/writesExpectedResultFiles(run=neighbor)` | fixed | ✗ | B18 |
| `InverseKinematicsErrorTest/usesEveryFrameInMarkerFile`, `usesEveryFrameWhenTimesAreRounded` | fixed | ✗ | B1 |
| `JointModelPersonalizationParsingTest/allTasksDisabledIsReported` | fixed | ✗ | B2 |
| `MarkerFrameTimesTest/errorReportHasEveryFrame` (exact, rounded) | fixed | ✗ | B1 |
| `MtliCostTermsTest/absoluteLengthsSwitchTheLengthTerms` | | ✗ | D1 |
| `MtliCostTermsTest/enabledTermsAreStacked` | | ✗ | D1 |
| `MtliCostTermsTest/muscleStressDefaults` | | ✗ | D1 |
| `MtliCostTermsTest/passiveMomentTermNeedsPassiveData` | | ✗ | D1 |
| `MtliCostTermsTest/passiveMomentTrackingWorksForAnyTrialLength` | ✗ | ✗ | B10 |
| `MtliCostTermsTest/unknownTermIsReported` | fixed | | B11 |
| `MtpCostComputationsTest/groupsWithoutFirstMuscleCompareTheRightMuscles` | ✗ | ✗ | B4 |
| `MtpCostTermsTest/maximumFiberLengthPenaltyStartsAtTheLimit` | ✗ | ✗ | B5 |
| `MtpCostTermsTest/minimumFiberLengthPenaltyStartsAtTheLimit` | ✗ | ✗ | B5 |
| `MtpCostTermsTest/activationNonlinearityDefaults`, `activationTimeConstantDefaults`, `activationTimeConstantWithParsedZeroCenter`, `emgScaleFactorDefaults`, `excitationPenaltySkipsPaddingAndMissingMuscles`, `groupedElectromechanicalDelayDefaults`, `groupedEmgScaleFactorUsesActivationGroups` | | ✗ | D1 |
| `MtpCostTest/infiniteCostIsCapped`, `sumsOnlyEnabledTerms`, `synergyOnlyTermsAddNothingWithoutSynergies`, `synergyRunUsesSynergyModeledFiberLengths` | | ✗ | D1 |
| `MuscleModelTest/commonDelayShiftsEmgLater` | ✗ | | B3 |
| `MuscleModelTest/muscleForceAtOptimalLengthAndZeroVelocity` | | ✗ | D4 |
| `MuscleTendonPersonalizationParsingTest/allTasksDisabledIsReported` | fixed | ✗ | B6 |
| `MuscleTendonPersonalizationParsingTest/emgChannelMissingFromDataIsReported` | fixed | ✗ | B9 |
| `MuscleTendonPersonalizationParsingTest/minimalUsesDefaults`, `missingMuscleSpecificDelaysIsReported`, `sharedDelaySettingIsRead` | | ✗ | D1 |
| `MuscleTendonPersonalizationParsingTest/missingResultsDirectoryIsReported` | fixed | ✗ | B7 |
| `MuscleTendonPersonalizationParsingTest/unknownCoordinateIsReported` | fixed | ✗ | B8 |
| `MuscleTendonPersonalizationRegressionTest/*` (9: four truth/fit checks, five nominal) | | ✗ | R1 |
| `NcpCostTest/activationTrackingWithoutMtpDataCostsNothing` | | ✗ | D1 |
| `NcpInitialValuesTest/*` (5) | | ✗ | D1 |
| `NcpSyntheticDataTest/truthReproducesItsMoments(syntheticCase=fixed_weights)` | | ✗ | D1 |
| `NeuralControlPersonalizationParsingTest/duplicateMusclesAreRejectedWhenNcpRuns` | | ✗ | R3 |
| `NeuralControlPersonalizationParsingTest/fixedWeights*` (5) | | ✗ | D1 |
| `NeuralControlPersonalizationParsingTest/fullAlsoParsesMtli`, `mtliCanBeEnabled` | | ✗ | R2 |
| `NeuralControlPersonalizationParsingTest/missingResultsDirectoryIsReported` | fixed | ✗ | B7 |
| `NeuralControlPersonalizationRegressionTest/acceptsCharacterSettingsFileName` | fixed | ✗ | B13 |
| `NeuralControlPersonalizationRegressionTest/fixedWeightsKeepWeightsAndRecoverCommands`, `matchesNominalResult(nominalRun=fixedWeights)`, `writesExpectedResultFiles(run=fixedWeights)` | | ✗ | D1 |
| `NeuralControlPersonalizationRegressionTest/iliacusHiddenPredictsIliacus`, `mtliRunCompletesAndFits`, `writesExpectedResultFiles(run=iliacusHidden)`, `writesExpectedResultFiles(run=mtli)` | ✗ | ✗ | B12 (and R2 for mtli) |
| `NeuralControlPersonalizationRegressionTest/writesExpectedResultFiles(run=allTracked)`, `(run=sum)`, `(run=tutorial)` | | ✗ | R4 |
| `ToConstraintTermsTest/*` (3) | | ✗ | D1 |
| `ToCostTermsTest/*` (7) | | ✗ | D1 |
| `ToDesignVariablesTest/*` (11) | | ✗ | D1 |
| `ToScalingAndDynamicsTest/dynamicConstraintIsScaledDerivatives` | | ✗ | D1 |
| `ToSynergyModelTest/*` (6) | | ✗ | D1 |
| `ToDesignVariablesTest/variablesOfTheSameTypeAreAllKept` | fixed | not run | B28 |
| `ToTermHelpersTest/synergyWeightColumnsAreTheGroupsMuscles` | fixed | ✗ | B19 |
| `ToTermRegistryTest/*` (42) | | ✗ | D1 |
| `TrackingOptimizationParsingTest/muscleParametersFollowTheModeledMuscles` | fixed | ✗ | B25 |
| `TrackingOptimizationParsingTest/synergyControllerDefaults`, `synergyControllerReadsTheSynergyGroups`, `torqueTutorialTracksCoordinatesAndLoads` | | ✗ | D1 |
| `TreatmentOptimizationParsingTest/missingResultsDirectoryIsReported` (was `omittedResultsDirectoryIsTheCurrentFolder`) | fixed | ✗ | B23 |
| `TreatmentOptimizationParsingTest/unknownStatesCoordinateIsReported` | fixed | ✗ | B24 |
| `TreatmentOptimizationParsingTest/*` (the other 24) | | ✗ | D2 |
| `TreatmentOptimizationTermSmokeTest/termRunsAndHasTheRightSize` for `joint_energy_generation_goal`, `joint_energy_absorption_goal`, `angular_momentum_minimization` (6: designTorque and designSynergy) | fixed | not run | B20 |
| `TreatmentOptimizationTermSmokeTest/termRunsAndHasTheRightSize` for `inverse_dynamics_shape_tracking` (2: designTorque and designSynergy) | fixed | not run | B21 |
