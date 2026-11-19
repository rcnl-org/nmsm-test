# Unit test gaps

Which nmsm-core functions have unit tests, which do not, why, and whether they should. Checked on 2026-11-17
against `candidate-1.5.4` at `8b881700`.

## How this was measured

- **The functions:** every `.m` file in `src/` (661 files; each holds one public function, plus any local
  functions, which are counted with their file). Three of the 661 are new, uncommitted files from work in
  progress in the `nmsm-core-candidate-1.5.4` worktree (`mtpBackwardsCompatibility`, `verifyMtpCostTermGroups`,
  `getErrorCenterOrInitialGuess`); they are left out of the recommendations below.
- **Named in a unit test:** the function's name appears in the code (not the comments) of a test in
  `tests/unit`.
- **Run by the tests:** statement coverage (MATLAB's `CodeCoveragePlugin`) of all of `src/`, once for the unit
  tier and once for the whole suite. A function counts as run if any of its statements ran.

**Caveat about MTP.** The worktree had uncommitted changes in progress (MTP and MTLI cost terms and MTP's parser,
ported from `matlab-gui-dev`) that make MTP's parser crash on every settings file (`collectedEmgChannelGroups` is
read but never set). The whole-suite run therefore did not run MTP's parsing, regression, synthetic-data and smoke
tests. The MTP functions those tests run on committed code are listed separately below (group 5), not as gaps.

## Summary

| Group | Functions | Unit test? | Should there be one? |
|---|---|---|---|
| Called by name in a unit test | 191 | Yes | — |
| Run by unit tests through other functions | 86 | Indirectly | Mostly fine (see below) |
| Run only by parsing or regression tests | 193 | No | Some: see [part 2](#part-2-run-only-by-parsing-or-regression-tests-193) |
| Not run by any test | 191 | No | See [part 1](#part-1-not-run-by-any-test-191) |

So **no: not every function has a unit test.** 277 of 661 (42%) are run by unit tests, directly or
indirectly, and 470 (71%) are run by some test. Of the 191 functions no test runs:

| Reason | Functions | Should they be tested? |
|---|---|---|
| [1. Plotting and reporting](#1-plotting-and-reporting-54) | 54 | Mostly no; one smoke test per tool's plotting entry point would be worthwhile |
| [2. Dead code: nothing calls them](#2-dead-code-nothing-calls-them-51) | 51 | No: delete them, or decide they are wanted first |
| [3. Workflows with no tests at all: Preprocessing and surrogate model creation](#3-workflows-with-no-tests-at-all-24) | 24 | **Yes** |
| [4. Treatment Optimization ground contact terms, and model functions](#4-treatment-optimization-ground-contact-and-model-functions-38) | 38 | **Yes**, needs a new fixture |
| [5. MTP functions not run only because of the work in progress](#5-mtp-functions-not-run-only-because-of-the-work-in-progress-17) | 17 | Already covered by MTP regression tests on committed code |
| [6. Other reachable code the fixtures do not exercise](#6-other-reachable-code-the-fixtures-do-not-exercise-7) | 7 | Some (listed) |

The recommendations in order of value:
1. **A Treatment Optimization fixture with ground contact** (group 4): the gait terms (external forces and
   moments, center of pressure, braking and propulsive impulse) have never been run by a test.
2. **Surrogate model creation and Preprocessing** (group 3): whole workflows with no tests; the fixtures to test
   surrogate creation are already in `tests/data/to/synergy`.
3. **Value tests for the Treatment Optimization terms that are only smoke tested** (part 2): the smoke tests
   show they run, not that their values are right.
4. **Decide about the dead code** (group 2) and delete what is not wanted.

---

## Part 1: Not run by any test (191)

### 1. Plotting and reporting (54)

Functions that draw figures or print summaries for the user. Nothing in the tools' results depends on them.

| Tool | Functions |
|---|---|
| JMP | `calculateJointError`, `plotJmpResultsFromSettingsFile`, `plotMarkerDistanceErrors`, `reportJointModelPersonalizationValues` |
| MTP | `extractMtpDataFromSto`, `plotMeanAndStd`, `plotMtpHillTypeMuscleParams`, `plotMtpHillTypeMuscleParamsCompare`, `plotMtpJointMoments`, `plotMtpMuscleExcitationsAndActivations`, `plotMtpMuscleForces`, `plotMtpNormalizedFiberLengths`, `plotMtpPassiveForceCurves`, `plotMtpPassiveMomentCurves`, `plotMtpResultsFromSettingsFile`, `printMtpJointMomentMatchingError`, `readMomentArmsForPlotting`, `reportMuscleTendonPersonalizationResults` |
| NCP | `plotMomentMatchingResults`, `plotNcpActivationRmsAndVaf`, `plotNcpResultsFromSettingsFile`, `plotNeuralControlPersonalizationActivations`, `reportNeuralControlPersonalizationResults` |
| GCP | `calcGroundReactionByMarker`, `plotGcpFootKinematicsFromFiles`, `plotGcpGroundReactionsFromFiles`, `plotGcpResultsFromSettingsFile`, `plotGcpStiffnessCoefficients`, `plotCoordinates`, `plotGroundReactionQuantities`, `plotSpringConstants` |
| Treatment Optimization | `makeLegendFromFileNames`, `makeSubplotTitles`, `parsePlottingData`, `plotNmsmGeneric`, `plotTreatmentOptimizationBounds`, `plotTreatmentOptimizationControls`, `plotTreatmentOptimizationCost`, `plotTreatmentOptimizationGroundReactions`, `plotTreatmentOptimizationJointAccelerations`, `plotTreatmentOptimizationJointAngles`, `plotTreatmentOptimizationJointLoads`, `plotTreatmentOptimizationJointVelocities`, `plotTreatmentOptimizationMuscleActivations`, `plotTreatmentOptimizationResultsFromSettingsFile`, `plotTreatmentOptimizationSynergyControls`, `plotTreatmentOptimizationTorqueControls`, `resampleTrackedData`, `reportTreatmentOptimizationResults`, `IntegratedQuantitiesPreviewTool`, `reportingGaitSpecificMeasurements` |
| Surrogate model | `SurrogateModelPreviewTool`, `reportSurrogateModel` |
| core | `getPlottingParams` |

**Why no unit tests:** a figure has no value to compare with, and the suite has focused on what the tools
compute.

**Should they have them?** Not one per function. But the `plot*ResultsFromSettingsFile` entry points read the
tools' result files, so they break silently when a result format changes. (On `matlab-gui-dev`, for example,
`plotMtpHillTypeMuscleParams` started dividing the delay by 10 when the saved units changed.) **One smoke test
per tool is worthwhile:** run its `plot*ResultsFromSettingsFile` on a regression run's results with figures
invisible, and check it does not error. Two of these need attention rather than tests:
`reportingGaitSpecificMeasurements` calls functions that do not exist (`calcStepLengthAsymmetry`,
`calcStepTimeAsymmetry`, `calcStrideLength`), and `IntegratedQuantitiesPreviewTool` is a separate user tool that
would need its own test if it is kept.

### 2. Dead code: nothing calls them (51)

No function in `src/` calls these (checked by name), and they are not entry points a user runs.

| Tool | Functions |
|---|---|
| JMP | `markerError` |
| MTP | `calcAllDeviationPenaltyCosts`, `calcGroupedMusclePenalties`, `combineCostsIntoVector`, `calcFinalModelMoments`, `calcFinalMuscleActivations`, `saveMuscleTendonOptimizationParamsOld` |
| NCP | `calcNcpModeledValues`, `calcNcpMuscleJointMoments`, `findSynergyWeightsByGroup`, `normalizeSynergyVariables`, `unpackDesignVariables`, `unpackSynergyVariables`, `calcMuscleTendonForce`, `calcActivationTrackingCost`, `prepareNonNegativeMatrixFactorizationInitialValues` (already listed in `tests/README.md`; these call only each other) |
| GCP | `splitGridPointsByToeJoint`, `calcVerticalGroundReactionForceAndSlopeError` |
| Treatment Optimization | `calcMaximizingCostArrayTerm`, `calcGoalBeltSpeedDiscrete`, `calcMinimizingControllerFrequencyIntegrand`, `calcMinimizingJointJerkIntegrand`, `calcMuscleActuatedMomentsPathConstraints`, `calcTorqueActuatedMomentsPathConstraints`, `findSplinedGroundReactionsByHindfootBodyName`, `parseGroundContactSurfaces` (defined but not in the cost or constraint term registries, or not called) |
| core | `BsplineNodes`, `applyFrameParameterValue`, `arrayStrToStringArray`, `numberArrayToArrayDouble`, `stdVectorDoubleToDoubleArray`, `getTimeSeriesTableColumnNames`, `assertException`, `assertNoException`, `assertWithinRange` (old test utilities), `getEnabledMusclesInOrder`, `getNumEnabledMuscles`, `calcMetabolicCost`, `findStorageColumn`, `getSynergyWeightsFromGroups`, `parseElementBoolean`, `parseEmgWithExpansion`, `parseGcpContactSurface`, `parseGcpStandard`, `parseRcnlMuscle`, `parseTreatmentOptimizationData`, `parseTreatmentOptimizationStandard`, `valueOrEmptyString`, `valueOrEmptyStruct`, `valueOrZero`, `verifyParam` (its callers, the `verifyParams` local functions in the JMP, MTP and NCP main functions, are never called) |

**Why no unit tests:** testing code nothing uses would lock in behavior nobody relies on, and it would still
not be exercised by the tools.

**Should they have them?** No. **Each should be deleted**, or, if it is meant to be used (for example
`calcMinimizingJointJerkIntegrand` and `calcGoalBeltSpeedDiscrete` look like unfinished terms, and
`calcMetabolicCost` duplicates `calcBhargavaMetabolicCost`), wired in first and tested then. The team should go
through this list once.

### 3. Workflows with no tests at all (24)

Two parts of the pipeline the suite does not cover:

| Area | Functions |
|---|---|
| Preprocessing (`src/Preprocessing`) | `preprocessing`, `processMotionLabData`, `processMuscleAnalysis`, `sectionDataFiles`, `splitIntoTrials`, `createMuscleTendonVelocity`; and the `src/core` pieces only it uses: `processEmg`, `processRawEmgFile`, `stringArrayToArrayStr` |
| Surrogate model creation (`src/SurrogateModelCreation`) | `SurrogateModelCreation`, `createSurrogateModel`, `createMuscleSpecificSurrogateModel`, `getDataMatrix`, `getPolynomialExpressions`, `makeSurrogateModelKinematics`, `sampleSurrogateKinematics`, `sampleSurrogateKinematicsFromSettings`, `surrogateKinematicsScript` |
| Inverse kinematics setup (`src/core/InverseKinematicsSolver`) | `makeInverseKinematicsSolver`, `makeIKSolverFromMarkersReference` (used by preprocessing-style IK runs), and the options `excludeMarkers` and `adjustMarkerWeights` (marker exclusions and weights, which no JMP fixture uses) |
| MEX build scripts | `compileInverseDynamicsMex`, `compilePointKinematicsMex` |

**Why no unit tests:** the suite was built tool by tool (JMP, MTP, MTLI, NCP, GCP, Treatment Optimization), and
these were not in that scope. Treatment Optimization's tests load the tutorial's fitted surrogate model
(`surrogateMuscles.mat`) rather than fitting one, so surrogate creation never runs.

**Should they have them?** **Yes**, except the MEX build scripts (run by developers when OpenSim changes;
checked by every test that uses the MEX files):
- **Surrogate model creation:** the data is already in `tests/data/to/synergy/surrogateData`. Fit a surrogate
  from it and compare it with the tutorial's `surrogateMuscles.mat` at the sample points (a regression test),
  and unit-test `getPolynomialExpressions` and `getDataMatrix` with small hand-worked polynomials.
- **Preprocessing:** unit tests for the pure pieces (`splitIntoTrials`, `sectionDataFiles`,
  `createMuscleTendonVelocity`, and `processEmg` with known signals: filtering, rectification, normalization),
  and one regression run of `preprocessing` on a small trial from the tutorial's Step 3 data.
- **JMP marker exclusions and weights:** add a JMP parsing fixture with `excludeMarkers`/marker weights and a
  unit test that the IK error ignores an excluded marker and scales a weighted one.

### 4. Treatment Optimization ground contact and model functions (38)

| Area | Functions |
|---|---|
| Terms that need contact surfaces | `calcTrackingExternalForcesIntegrand`, `calcTrackingExternalMomentsIntegrand`, `calcTrackingCenterOfPressureIntegrand`, `calcBrakingImpulseGoalIntegrand`, `calcPropulsiveImpulseGoalIntegrand`, `calcCenterOfPressureDeviationPathConstraint`, `calcCenterOfPressureValuePathConstraint`, `calcExternalForceDeviationPathConstraint`, `calcExternalForceValuePathConstraint`, `calcExternalMomentDeviationPathConstraint`, `calcExternalMomentValuePathConstraint`, `calcExternalForcesPeriodicity`, `calcExternalMomentsPeriodicity`, `calcInitialExternalForceDeviation`, `calcInitialExternalForceValue`, `calcInitialExternalMomentDeviation`, `calcInitialExternalMomentValue`, `calcFinalExternalForceDeviation`, `calcFinalExternalForceValue`, `calcFinalExternalMomentDeviation`, `calcFinalExternalMomentValue` |
| Their helpers | `calcFootGroundReactions`, `findGroundReactionForceDataByLabels`, `findGroundReactionMomentDataByLabels`, `findGroundReactionsByHindfootBodyName`, `findSplinedCenterOfPressureByLabels`, `findSplinedGroundReactionForcesByLabels`, `findSplinedGroundReactionMomentsByLabels`, `calcMassCenterVelocity` (walking speed), `setOsimStateBySingleFrame` |
| Design model functions (`<model_functions>`) | `applyOptimalFiberLengthParameter`, `applyTendonSlackLengthParameter`, `adjustMaxIsometricForce`, `adjustModelMaxIsometricForce`, `adjustModelOptimalFiberLength`, `adjustModelTendonSlackLength`, `adjustOptimalFiberLength`, `adjustTendonSlackLength` |

**Why no unit tests:** the Treatment Optimization fixtures are the tutorial's kick problems, which have no GCP
contact surfaces or ground reaction data. `TreatmentOptimizationTermSmokeTest` reports these terms as
*incomplete* ("needs contact surfaces") for that reason. Only the belt speed model function is tested
(`DoModelFunctionsTest`); the others are called by name from `<model_functions>`, so no code calls them
directly.

**Update (2026-11-19):** the walking fixture (`tests/data/to/walking`, from `nmsm-advanced-tutorials`
Tutorial 1) now exists, and `TreatmentOptimizationTermSmokeTest` runs every contact-surface term in it (54
tests, all passing on candidate). The terms and their helpers are now smoke tested, so they are run by a
regression test rather than by none; the counts above are from before. They still have no unit tests with
hand-worked values.

**Should they have them?** **Yes; this is the most valuable gap.** These are the gait terms Treatment
Optimization is used for in walking studies.
- ~~Add a Treatment Optimization fixture with contact surfaces.~~ Done (see above). The setup regression test
  could also get a ground contact case from it.
- Unit-test the ground reaction helpers and terms with hand-worked forces, as `ToCostTermsTest` does for the
  kinematic terms.
- Unit-test the remaining model functions the way `DoModelFunctionsTest` tests the belt speed one (each changes
  one muscle property in the model and in the problem's inputs).

### 5. MTP functions not run only because of the work in progress (17)

`getMtpResultsToSave`, `saveMtpActivationAndExcitationData`, `saveMtpJointMomentData`, `saveMtpMuscleForceData`,
`saveMtpMuscleModelParameters`, `saveMtpPassiveForceData`, `saveMtpPassiveMomentData`,
`saveMuscleTendonPersonalizationResults`, `writeMtpDataToSto`, `writeMuscleTendonPersonalizationOsimxFile`,
`buildMtpOsimxTemplate`, `calcMtpSynXModeledValues`, `calcMuscleExcitationsSynX`,
`verifyMuscleTendonPersonalizationData`, `verifyField`; and the uncommitted `mtpBackwardsCompatibility` and
`verifyMtpCostTermGroups`.

**Why:** they run in `MuscleTendonPersonalizationRegressionTest` (the full tool, with synergy extrapolation in
the tutorial case), which did not get past MTP's parser in this run (see the caveat at the top).

**Should they have unit tests?** The saving functions are checked by the regression tests' result files and
nominal results, which is enough. `calcMtpSynXModeledValues` and `calcMuscleExcitationsSynX` (synergy
extrapolation's modeled values) deserve a unit test with hand-worked values, like `MuscleModelTest` has for the
non-synergy path. Rerun this analysis once the work in progress is finished.

### 6. Other reachable code the fixtures do not exercise (7)

| Functions | Why not run | Test it? |
|---|---|---|
| `PointKinematicsMatlab`, `inverseDynamicsMatlab`, `calcBodyLocation`, `calcBodyVelocity`, `findModeledMarkerCoordinates` | The non-Windows (non-MEX) fallbacks; the suite runs on Windows, where the MEX versions are used. | Only if macOS/Linux support matters; then run the suite there. |
| `polyFourierCurves` | A branch of choosing B-spline nodes from a cutoff frequency that the fixtures do not take. | Yes, small: a unit test of `calcNumBsplNodesFromCutoffFreq` on that branch. |
| `rmsError` | Only used by an NCP plot. | No (covered if the plotting smoke test is added). |

---

## Part 2: Run only by parsing or regression tests (193)

These have no unit test, but a slower tier runs them. For most that is the right tier; for some it is not enough.

**Covered at the right tier, no unit test needed:**
- **The tools' main functions and their saving functions** (`*Tool`, `JointModelPersonalization`,
  `computeKinematicCalibration`, GCP's ten `write*`/`save*` functions, `saveNeuralControlPersonalizationResults`,
  `save*OptimizationResults`, `saveTreatmentOptimizationResults`): checked by the regression tests' result files
  and nominal results.
- **Parsers** (19 in `core/parse`, the Treatment Optimization and JMP settings tree parsers,
  `parseGpopsSolverSettings`, `parseOptimalControlSolverSettings`, `verifyVersion`, `findToolName`, ...):
  checked by the parsing tier, which is the right place.
- **osimx writing** (11 in `core/osimx`, `struct2xml`): checked through the regression tests' osimx files.
- **Treatment Optimization's GPOPS-II glue** (`convertToGpopsInputs`, `computeGpopsContinuousFunction`,
  `computeGpopsEndpointFunction`, `preSplineGpopsInputs`, `computeCollocationPointTimes`, `setup*` functions,
  `makeTreatmentOptimizationInputs` and its steps): need GPOPS-II, so they belong in the regression tier, where
  `TreatmentOptimizationSetupRegressionTest` compares their output with nominal results.
- **MEX and spline plumbing** (`inverseDynamics`, `pointKinematics`, `makeGcvSplineSet`, `evaluateGcvSplines`,
  `writeToSto`, `TrcFromMot` and its helpers): exercised constantly by the tool runs.

**Should get unit tests with hand-worked values:**
- **Treatment Optimization terms checked only by the smoke test** (about 60): the tracking and minimization
  integrands for speed, acceleration, marker position and velocity, body orientation, controller, ID slope and
  muscle activation; the path constraints (`calcGeneralized*`, `calcMarker*`, `calcBodyOrientation*`,
  `calcController*`, `calcMuscleActivation*`, `calcNormalizedFiberLengthPathConstraint`,
  `calcRootSegmentResidualsPathConstraints`); the terminal constraints (`calcInitial*`, `calcFinal*`,
  periodicity); the synergy vector terms (`calcSynergyVectorSymmetry`, `calcTrackingSynergyVectorsDiscrete`,
  `calcSynergyVectorSymmetryConstraint`); the metabolic cost goals; and the term helpers they use
  (`findSplined*ByLabels`, `findBodyAxesByLabels`, `findAngleInSequence`). The smoke test shows each runs and
  gives finite values of the right size; it does not show the values are right. Most follow a handful of
  patterns (tracking = experimental − modeled, value = modeled, deviation = modeled − experimental, initial/final
  = first/last point, periodicity = last − first), so a few parameterized tests per pattern would cover them,
  as `ToCostTermsTest` and `ToConstraintTermsTest` do for the ones they cover.
- **`calcSynergyBasedModeledValues` and `calcTorqueBasedModeledValues`** (Treatment Optimization's model): run
  only inside GPOPS-II runs. A unit test on hand-built inputs (activations → moments; positions → ID loads) would
  catch model errors without GPOPS-II.
- **The surrogate model's evaluation** (`calcSurrogateModel`, `evaluateSurrogate`,
  `getMuscleSpecificSurrogateModelData`): a unit test that the tutorial's fitted surrogate reproduces the
  surrogate data's lengths and moment arms at the sample points.
- **`initializeRestingSpringLength`** (GCP): a unit test with a known foot height and load. This is the function
  in the open question about its spring formula (`tests/README.md`).

## Part 3: Run by unit tests only through other functions (86)

These are called inside functions that have unit tests (for example `calcNormalizedMuscleFiberLengthsAndVelocities`
runs inside `MuscleModelTest`'s checks, and the term helpers inside the term tests). Their behavior is checked
through their callers' expected values, which is usually enough: a direct test adds little unless the function is
reused widely or has edge cases its callers do not reach.

## Other findings from this check

- **`NcpTermSmokeTest` cannot be built on the current `candidate-1.5.4`.** `calcNcpCost` now has a grouped case
  label (`case {"activation_minimization", "muscle_activation_minimization"}`), which `costTermTypes` (it only
  matches `case "name"`) does not read, so the test's parameter list is empty and MATLAB rejects the class. The
  run then silently leaves it out (1,211 tests instead of 1,212). Fix `costTermTypes` to also read the names
  inside `case {...}`.
- **The suite has not caught up with the latest `candidate-1.5.4`.** Besides the MTP work in progress described
  above, `MtliCostTermsTest/muscleStressDefaults` and `absoluteLengthsSwitchTheLengthTerms` fail on the
  uncommitted MTLI cost term changes (the default error center becoming the initial guess). Recheck once that work
  is committed.
