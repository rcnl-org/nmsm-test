# Test catalog

Every test class in `tests/`, with a one-line description of each test. The suite has 65 test classes and 583
test methods; with parameterized tests expanded, a full run is 1,199 tests.

- **Tiers.** Each class is tagged `Unit` (one function at a time, values worked out by hand), `Parsing`
  (settings file → `inputs`/`params`) or `Regression` (full tool runs). Run a tier with `runTests("unit")`,
  `runTests("parsing")` or `runTests("regression")`, and one tool with `Tool=` (for example
  `runTests("all", Tool="TO")`).
- **Expected failures.** ⚠ marks a test that fails on purpose on `candidate-1.5.4` because it found a bug. See
  [failures.md](failures.md) for each failure and how to fix it.
- **Parameterized tests** run once per listed value; the values are given after the test name.
- **Setup methods.** Methods in `TestClassSetup`/`TestMethodSetup` blocks and helper methods are not tests, so
  they are not listed.

Contents: [Shared core](#shared-core-srccore) ·
[Joint Model Personalization](#joint-model-personalization-jmp) ·
[Muscle-Tendon Personalization](#muscle-tendon-personalization-mtp) ·
[Muscle-Tendon Length Initialization](#muscle-tendon-length-initialization-mtli) ·
[Neural Control Personalization](#neural-control-personalization-ncp) ·
[Ground Contact Personalization](#ground-contact-personalization-gcp) ·
[Treatment Optimization](#treatment-optimization) ·
[Example](#example)

---

## Shared core (`src/core`)

### `MuscleCurvesTest` — Unit
`tests/unit/core/MuscleCurvesTest.m`. The normalized muscle curves MTP, MTLI, NCP and Treatment Optimization
build on: `activeForceLengthCurve`, `forceVelocityCurve`, `passiveForceLengthCurve`.

| Test | Description |
|---|---|
| `activeForceIsOneAtOptimalLength` | Active force-length curve is 1 at normalized length 1. |
| `activeForcePeaksNearOptimalLength` | Its peak is within 0.1% of 1, at optimal length. |
| `activeForceIsSmallFarFromOptimalLength` | Active force is near zero at very short and very long fibers. |
| `forceIsOneAtZeroVelocity` | Force-velocity curve is exactly 1 when isometric. |
| `forceIsZeroAtMaximumShorteningVelocity` | Force-velocity curve is 0 at normalized velocity −1. |
| `forceIncreasesWithLengtheningVelocity` | Shortening lowers force, lengthening raises it. |
| `passiveForceIsSoftplus` | Passive curve matches its softplus formula. |
| `passiveForceAtCurveCenterIsE1Log2` | Passive force at the curve center is e1·log 2. |
| `passiveForceIsNearZeroAtOptimalLength` | Passive force only matters once the fiber is stretched. |
| `passiveForceGrowsWithSlopeE1E2WhenStretched` | Far into stretch the passive curve's slope is e1·e2. |
| `curveKeepsInputShape` (each curve) | Every curve returns an array the shape of its input. |

### `MuscleModelTest` — Unit
`tests/unit/core/MuscleModelTest.m`. The Hill-type model MTP uses from EMG to joint moments: delays, scaling,
activation dynamics, nonlinearity, fiber lengths, forces and moments.

| Test | Description |
|---|---|
| ⚠ `commonDelayShiftsEmgLater` | One shared electromechanical delay shifts every muscle's EMG later by that delay. |
| `muscleSpecificDelaysShiftEachMuscle` | Per-muscle delays shift each muscle by its own delay. |
| `scaleFactorsMultiplyEachMuscle` | EMG scale factors multiply each muscle's excitation. |
| `constantExcitationIsReachedExactly` | A constant excitation gives the same steady activation. |
| `activationRisesWithActivationTimeConstant` | A step to 1 rises as 1 − exp(−t/τa). |
| `deactivationIsFourTimesSlower` | Deactivation follows τd = 4·τa. |
| `eachTrialUsesItsOwnTimeStep` | Trials with different frame spacing integrate with their own time step. |
| `paddingFramesAreRemoved` | EMG padding frames are dropped from the activations. |
| `undershootBelowZeroIsSetToZero` | Numerical undershoot below 0 activation is clipped to 0. |
| `zeroNonlinearityLeavesActivationUnchanged` | Nonlinearity 0 leaves activation as neural activation. |
| `nonlinearityKeepsZeroAndOneFixed` | Activations 0 and 1 are unchanged by any nonlinearity. |
| `nonlinearityRaisesLowActivations` | The nonlinear curve lies above the line. |
| `nonlinearityBlendsLinearAndNonlinearCurves` | Activation = (1 − A)·linear + A·fully nonlinear. |
| `nonlinearityIsAppliedPerMuscle` | Each muscle uses its own nonlinearity constant. |
| `normalizedFiberLengthAndVelocity` | Normalized fiber length and velocity, with and without pennation. |
| `scaleFactorsScaleOptimalAndSlackLengths` | Length scale factors scale optimal fiber and tendon slack lengths. |
| `missingLengthOrVelocityGivesEmpty` | Missing length or velocity data gives an empty result. |
| `passiveForceIncludesPennation` | Passive force is F0·cos(pennation)·passive curve. |
| `muscleForceAtOptimalLengthAndZeroVelocity` | Muscle force at optimal length and rest is F0·a plus passive. |
| `passiveMomentIsMomentArmTimesPassiveForce` | Passive moment is moment arm × passive force. |
| `jointMomentSumsMusclesWithMomentArmSigns` | Joint moment sums muscles with the signs of their moment arms. |
| `maxIsometricForceFromVolumeAndStress` | F0 = volume / optimal length × stress. |

### `OrderByIndexTest` — Unit
`tests/unit/core/OrderByIndexTest.m`. `orderByIndex`, which orders `<JMPTask>` elements by `<index>`.

| Test | Description |
|---|---|
| `preorderedTasksKeepOrder` | Tasks already in order stay in order. |
| `outOfOrderTasksAreSorted` | Tasks out of order are sorted by index. |
| `multiDigitIndicesSortNumerically` | "10" comes after "9" (numeric, not text, sort). |
| `duplicateIndicesKeepFileOrder` | Tasks with the same index keep their file order. |
| `singleTaskIsReturnedUnchanged` | A single task (a struct, not a cell) is returned as is. |
| `missingIndexThrows` | A task without `<index>` is an error. |

### `SynergyGroupsTest` — Unit
`tests/unit/core/SynergyGroupsTest.m`. The synergy-group helpers NCP's parser uses to choose and order its
muscles.

| Test | Description |
|---|---|
| `separateGroupsAreAccepted` | Groups with no muscle in common are accepted. |
| `duplicateMuscleIsNamed` | A muscle in two groups is reported by name. |
| `musclesFollowSynergyGroupOrder` | Muscles are ordered as in the synergy groups, not the model. |
| `groupMusclesNotCrossingCoordinatesAreDropped` | Group muscles that cross none of the coordinates are left out. |
| `muscleOutsideEverySynergyGroupIsNamed` | A modeled muscle in no synergy group is reported by name. |

### `JmpVerifyFunctionsTest` — Unit
`tests/unit/core/JmpVerifyFunctionsTest.m`. The `src/core/verify` functions JMP uses to check its inputs.

| Test | Description |
|---|---|
| `verifyCharAcceptsTextOnly` | `verifyChar` accepts text and rejects anything else. |
| `verifyNumericAcceptsNumbersOnly` | `verifyNumeric` accepts numbers only. |
| `verifyLengthChecksExactLength` | `verifyLength` requires the exact length. |
| `verifyModelArgAcceptsFileOrModel` | A model may be given as a file name or a Model. |
| `verifyMarkersReferenceArgNeedsReadableFile` | A markers reference needs a readable file. |
| `functionsArgsAcceptValidParameters` | Valid `{joint, isParent, isTranslation, coordinate}` parameters are accepted. |
| `functionsArgsRejectCoordinateOutOfRange` | A coordinate outside 0–2 is rejected. |

---

## Joint Model Personalization (JMP)

### `JmpFixtureTest` — Unit
`tests/unit/JointModelPersonalization/JmpFixtureTest.m`. The `simple_arm` fixtures still match
`jmpFixtureValues`.

| Test | Description |
|---|---|
| `parentFrameMatchesRecordedValues` (truth, translatedAway, orientedAway) | Each model's r_elbow parent frame has its recorded offset. |
| `modelHasExpectedMarkers` | The models have the six expected markers. |
| `markerFileWasGeneratedFromTruthModel` | IK on the truth model reproduces the marker file. |
| `markerFileHasExpectedTimeRange` | The marker file covers its recorded frames and times. |
| `roundedTimesFileDiffersOnlyInItsTimes` | `simple_arm_rounded_times.trc` is `simple_arm.trc` with its times rounded to 5 decimals. |

### `AdjustFunctionsTest` — Unit
`tests/unit/JointModelPersonalization/AdjustFunctionsTest.m`. The `adjust*` functions JMP uses to change one
model parameter; each must change exactly that value.

| Test | Description |
|---|---|
| `adjustFrameChangesOnlyThatValue` (4 frame parameters × 3 axes) | Adjusting a parent/child translation/orientation changes only that value. |
| `adjustMarkerPositionChangesOnlyThatAxis` (x, y, z) | Moving a marker changes only that axis. |
| `adjustBodyScalingSetsScaleFactor` | Body scaling sets the body's scale factor. |
| `adjustBodyScalingIsAbsoluteNotCumulative` | Scaling twice to the same value does not compound. |
| `adjustBodyScalingKeepsMarkerLocations` | Markers keep their body-frame location when the body is scaled. |

### `MakeFunctionsTest` — Unit
`tests/unit/JointModelPersonalization/MakeFunctionsTest.m`. The factories that turn parsed JMP parameters into
functions, and `adjustModelFromOptimizerOutput`.

| Test | Description |
|---|---|
| `jointFunctionAdjustsMatchingFrameValue` (4 joint parameters × 3 axes) | A joint function adjusts the matching frame value. |
| `markerFunctionAdjustsMatchingAxis` (x, y, z) | A marker function adjusts the matching axis. |
| `scalingFunctionSetsScaleFactor` | A scaling function sets the body's scale factor. |
| `optimizerOutputIsAppliedToCopy` | Applying the true values to the away models restores the truth, on a copy. |
| `optimizerOutputIsRoundedToTenDecimals` | Applied values are rounded to 10 decimals. |

### `InverseKinematicsErrorTest` — Unit
`tests/unit/JointModelPersonalization/InverseKinematicsErrorTest.m`. The IK error JMP minimizes, against
hand-worked values.

| Test | Description |
|---|---|
| `usesEveryFrameInMarkerFile` | The IK error uses all 120 marker frames. |
| `usesEveryFrameWhenTimesAreRounded` | It still uses all 120 frames when the file's times are rounded to 5 decimals. |
| `timeRangeLimitsTheFrames` | A start and finish time limit the IK error to the frames between them. |
| `truthModelHasZeroError` | The truth model has zero marker error. |
| `fixedBodyMarkerOffsetGivesExactError` | Moving a marker by a known offset gives exactly that error. |
| `desiredErrorScalesOutput` | The error is divided by the desired error. |
| `selectedMarkersOnlyAreUsed` | Only the selected markers count. |
| `innerOptimizationIsZeroAtTruth` | JMP's objective is zero at the true parameter. |
| `innerOptimizationMatchesKnownStartingError` | At the translated-away value the RMS error is the known 1.8 mm. |
| `failureReturnsLargeErrorInsteadOfThrowing` | A failed IK returns a large error instead of throwing (current behavior). |

### `MarkerFrameTimesTest` — Unit
`tests/unit/JointModelPersonalization/MarkerFrameTimesTest.m`. The marker frames JMP's IK runs on
(`getMarkerFrameTimes`), and the per-marker error report (`reportDistanceErrorByMarker`) that uses them. Tests
marked (exact, rounded) run once on `simple_arm.trc` and once on `simple_arm_rounded_times.trc`.

| Test | Description |
|---|---|
| `everyFrameIsUsedByDefault` (exact, rounded) | With no time range, all 120 frames are used. |
| `timeRangeIncludesBothEndFrames` (exact, rounded) | 0.5–1.0 s gives the 31 frames from 0.5 s to 1.0 s. |
| `timeRangeEndsMatchTheNearestFrame` (exact, rounded) | Ends typed to 4 decimals, just past a frame, still include that frame. |
| `timeRangeWithoutFramesIsReported` | A time range with no frames gives a clear error. |
| `nonNumericTimeRangeIsReported` | A non-numeric time range (parsed as NaN) gives the same clear error. |
| `errorReportHasEveryFrame` (exact, rounded) | The per-marker error `.sto` has a row for every frame. |
| `errorReportUsesTheTimeRange` | With a time range, the error report has only that range's frames. |

### `JointModelPersonalizationParsingTest` — Parsing
`tests/parsing/JointModelPersonalizationParsingTest.m`. JMP settings files → `outputFile`, `inputs`, `params`.

| Test | Description |
|---|---|
| `minimalSettingsUseDefaults` | The minimal file gets every default. |
| `fullSettingsOutputAndParams` | The full file sets the output file and every optimizer option. |
| `fullSettingsOrdersTasksAndDropsDisabled` | Tasks are ordered by index and disabled tasks are dropped. |
| `fullSettingsJointAndBodyTask` | A task's joint and body parameters are read. |
| `fullSettingsOrientationTaskWithTimeRangeAndMarkers` | A task's time range and marker list are read. |
| `translationSettingsStartFromAwayModel` | The translation file starts from the translated-away model. |
| `orientationSettingsStartFromAwayModel` | The orientation file starts from the oriented-away model. |
| `majorVersionMismatchIsRejected` | A different major version is rejected. |
| `settingsForAnotherToolAreRejected` | Another tool's settings file is rejected. |
| `missingOutputModelFileIsReported` | A missing `<output_model_file>` is reported. |
| `missingTaskListIsReported` | A missing task list is reported. |
| `translationWithTwoValuesIsReported` | A translation parameter with the wrong number of values is reported. |
| `missingModelFileIsNamed` | A missing model file is named in the error. |
| `misspelledJointIsNamed` | A misspelled joint is named in the error. |
| `allTasksDisabledIsReported` | Disabling every task gives a clear message. |

### `JointModelPersonalizationRegressionTest` — Regression
`tests/regression/JointModelPersonalizationRegressionTest.m`. Full JMP runs from models with r_elbow's parent
frame moved away from the truth.

| Test | Description |
|---|---|
| `recoversTruthAndChangesNothingElse` (translation, orientation) | JMP finds the true frame and changes nothing else. |
| `matchesNominalResult` (translation, orientation) | The output model matches the stored nominal result. |
| `writesExpectedResultFiles` (translation, orientation) | The output model and log are written. |

---

## Muscle-Tendon Personalization (MTP)

### `MtpFixtureTest` — Unit
`tests/unit/MuscleTendonPersonalization/MtpFixtureTest.m`. The MTP fixtures still match `mtpFixtureValues`.

| Test | Description |
|---|---|
| `modelHasOnlyTheExpectedMuscles` | The reduced model has exactly the nine expected muscles. |
| `musclePropertiesMatchRecordedValues` | Each muscle's properties match the recorded values. |
| `modelHasMuscleGroups` (4 group settings) | Every muscle group used by the settings exists. |
| `everyMuscleSpansATrackedCoordinate` | Each muscle crosses a tracked coordinate. |
| `gaitFilesShareOneTimeGrid` | IK, ID and MA files share one time grid. |
| `inverseDynamicsHasTrackedMoments` | ID data has the tracked coordinates' moments. |
| `muscleAnalysisMatchesGaitTimeAndMuscles` (5 files) | Each MuscleAnalysis file matches the gait times and muscles. |
| `emgIsPaddedOnTheGaitTimeGrid` | EMG is padded around the gait frames on the same grid. |
| `emgHasCollectedChannels` | EMG has every collected channel. |
| `passiveTrialsAreComplete` | All 12 passive trials have their IK, ID and MA files. |

### `MtpSyntheticDataTest` — Unit
`tests/unit/MuscleTendonPersonalization/MtpSyntheticDataTest.m`. The synthetic known-truth MTP data is
consistent with its truth.

| Test | Description |
|---|---|
| `syntheticModelOnlyChangesMuscleLengths` | The synthetic model differs only in muscle lengths. |
| `syntheticModelFiberLengthsAreWithinLimits` | At the start, every fiber length is inside MTP's limits. |
| `rebuiltTrialsAreConsecutiveGaitCycles` | The rebuilt `gait_1`/`gait_2` are consecutive cycles on matching grids. |
| `onlyReplacedMomentsDifferFromSource` (emgScale, all, twoTrials, passive) | Each case changes only the moments it replaces. |
| `truthReproducesItsMoments` (emgScale, all, twoTrials) | MTP's model at the truth reproduces the case's moments. |
| `startingValuesDoNotReproduceMoments` (emgScale, all, twoTrials) | At the starting values the moment error is large. |
| `passiveTruthReproducesItsMoments` | MTLI's model at the truth reproduces the passive moments. |
| `passiveStartingValuesDoNotReproduceMoments` | At the starting values the passive error is large. |

### `MtpCostComputationsTest` — Unit
`tests/unit/MuscleTendonPersonalization/CostTerms/MtpCostComputationsTest.m`. The building blocks of MTP's
cost terms.

| Test | Description |
|---|---|
| `trackingCostIsMeanSquaredScaledError` | Tracking cost is the mean of (error / allowable)². |
| `trackingCostSubtractsErrorCenter` | Tracking cost is measured from the error center. |
| `trackingCostIgnoresNaNButCountsIt` | A NaN adds nothing but still counts in the mean. |
| `deviationCostIsMeanSquaredScaledDeviation` | Deviation cost is the mean of (deviation / allowable)². |
| `deviationCostOfMatrixUsesEveryElement` | A matrix deviation averages every element. |
| `groupDifferencesAreFromEachGroupMean` | Group differences are from each group's mean. |
| ⚠ `groupsWithoutFirstMuscleCompareTheRightMuscles` | Groups that leave out the first muscle still compare the right muscles. |
| `groupIndicesArePositionsInMuscleList` | Group indices are positions in the muscle list. |
| `magnitudeDeviationIsChangeInTrialMean` | Magnitude deviation is the change in each trial's mean. |
| `shapeDeviationIgnoresAConstantShift` | Shape deviation ignores a constant shift. |
| `meanDeviationIsChangeRelativeToGroup` | Mean deviation is a muscle's change relative to its group. |
| `meanShapeDeviationIsFromGroupMeanShape` | Shape deviation is from the group's mean shape. |

### `MtpCostTermsTest` — Unit
`tests/unit/MuscleTendonPersonalization/CostTerms/MtpCostTermsTest.m`. Each MTP cost term on small hand-worked
values, with candidate-1.5.4's names.

| Test | Description |
|---|---|
| `activationTimeConstantDefaults` | Time constant term with its default center and allowable error (stored ×100). |
| `activationTimeConstantWithParsedZeroCenter` | The same with the parsed center of 0. |
| `activationNonlinearityDefaults` | Nonlinearity term with its defaults. |
| `emgScaleFactorDefaults` | EMG scale factor term with its defaults. |
| `electromechanicalDelayIsChangeFromTaskStart` | Delay term measures the change from the task's start. |
| `optimalFiberLengthIsChangeInMeters` | Optimal fiber length term measures the change in meters. |
| `tendonSlackLengthIsChangeInMeters` | Tendon slack length term measures the change in meters. |
| `groupedEmgScaleFactorUsesActivationGroups` | Grouped EMG scale factor term groups by activation groups. |
| `groupedElectromechanicalDelayDefaults` | Grouped delay term with its defaults. |
| `groupedFiberLengthComparesChangesWithinGroup` | Grouped fiber length term compares changes within a group. |
| `momentTrackingDefaultAllowableError` | Moment tracking with its default allowable error (2.5 Nm). |
| `synergyMomentTrackingDefaultAllowableError` | Synergy moment tracking with its default (2 Nm). |
| `passiveForceDefaults` | Passive force term with its default allowable error. |
| `fiberLengthDeviationIsMagnitudePlusShape` | Fiber length deviation adds magnitude and shape parts. |
| ⚠ `maximumFiberLengthPenaltyStartsAtTheLimit` | The maximum fiber length penalty grows from 0 at the limit. |
| ⚠ `minimumFiberLengthPenaltyStartsAtTheLimit` | The minimum fiber length penalty grows from 0 at the limit. |
| `fiberLengthPenaltiesAreZeroWithinLimits` | Both penalties are 0 inside the limits. |
| `excitationPenaltySkipsPaddingAndMissingMuscles` | The excitation penalty skips padding and missing-EMG muscles. |
| `residualActivationComparesMeasuredMuscles` | The residual activation term compares measured muscles. |
| `extrapolatedActivationPenalizesMissingMuscles` | The extrapolated activation term penalizes only missing-EMG muscles. |

### `MtpCostTest` — Unit
`tests/unit/MuscleTendonPersonalization/CostTerms/MtpCostTest.m`. `calcMtpCost`, which adds up the enabled
terms.

| Test | Description |
|---|---|
| `sumsOnlyEnabledTerms` | Only enabled terms are added. |
| `noEnabledTermsCostsZero` | No enabled terms cost 0. |
| `synergyOnlyTermsAddNothingWithoutSynergies` | Synergy-only terms add nothing without synergy extrapolation. |
| `synergyRunUsesSynergyModeledFiberLengths` | With synergies, the passive term uses the synergy model's lengths. |
| `unknownTermIsReported` | An unknown term type is reported. |
| `infiniteCostIsCapped` | An infinite cost is replaced by a large finite one. |

### `MtpTermSmokeTest` — Unit
`tests/unit/MuscleTendonPersonalization/MtpTermSmokeTest.m`. Every cost term type `calcMtpCost` handles (read
from its switch statement) runs on its own in MTP's objective, at the starting values of `settings_full.xml`
(with synergy extrapolation and MTLI) prepared by the tool's own steps. The optimizers are replaced by
stand-ins that record their arguments (`stubOptimizer`).

| Test | Description |
|---|---|
| `termGivesOneFiniteCost` (every MTP cost type, 18 on candidate) | The term runs and the cost is one finite number. |

### `DesignVariablesTest` — Unit
`tests/unit/MuscleTendonPersonalization/DesignVariablesTest.m`. How MTP packs its seven parameter sets into
fmincon's design vector and back.

| Test | Description |
|---|---|
| `includedSetsAreLaidOutInOrder` | Included sets are laid out in order in the design vector. |
| `synergyWeightsComeLast` | Synergy weights come last. |
| `valuesComeFromDesignVectorOnlyWhenIncluded` | Only optimized sets come from the design vector. |
| `synergyWeightsAreReadOnlyWithSynergies` | Synergy weights are read only with synergy extrapolation. |
| `updateCopiesOptimizedSetsBack` | Optimized sets are copied back into the primary values. |
| `updateDropsSynergyWeightsWhenNotOptimized` | Without synergies there is no synergy weight set. |
| `packingAndUnpackingRoundTrips` | Packing then unpacking returns the original values. |

### `NonLinearConstraintsTest` — Unit
`tests/unit/MuscleTendonPersonalization/NonLinearConstraintsTest.m`. The smooth fiber length limits (0.3–1.3)
MTP's optimizer must meet.

| Test | Description |
|---|---|
| `constraintsApproximateMaxAndMinFiberLength` | The constraints approximate max − 1.3 and 0.3 − min. |
| `lengthsWithinLimitsAreFeasible` | Lengths inside the limits satisfy the constraints. |
| `lengthsOutsideLimitsAreInfeasible` | Lengths outside the limits violate them. |

### `SynergyExtrapolationTest` — Unit
`tests/unit/MuscleTendonPersonalization/SynergyExtrapolationTest.m`. MTP's synergy extrapolation setup.

| Test | Description |
|---|---|
| `pcaWeightCountForTutorialSettings` | The tutorial's settings optimize the expected number of weights. |
| `weightCountGrowsWithCategory` | Extrapolating by trial needs more weights than by task or subject. |
| `nmfHasNoConstantTerm` | NMF synergies have no constant term. |
| `trialsAreGroupedByTaskName` | Trials are grouped by their task name. |
| `subjectCategorizationGroupsAllTrials` | Subject categorization groups every trial together. |
| `pcaCommandsAreUncorrelatedAndCentered` | PCA commands have zero mean and are uncorrelated. |
| `commandsIgnoreEmgAmplitude` | Scaling a channel's EMG does not change the commands. |
| `taskCommandsSpanAllTrialsOfTheTask` | Trials of one task share one command set. |
| `constraintsBoundExtrapolatedExcitation` | The linear constraints keep extrapolated excitation in [0, 1]. |
| `constraintsUseSynergyCommands` | The constraints are built from the synergy commands. |

### `MuscleTendonPersonalizationParsingTest` — Parsing
`tests/parsing/MuscleTendonPersonalizationParsingTest.m`. MTP settings files → `inputs` and `params`.

| Test | Description |
|---|---|
| `musclesComeFromCoordinateList` | The muscles are those crossing `<coordinate_list>`. |
| `muscleModelPropertiesComeFromModel` | Muscle properties come from the model. |
| `inverseDynamicsMomentsMatchFile` | ID moments match the file, in coordinate order. |
| `muscleTendonLengthsAndVelocitiesMatchFiles` | Lengths and velocities match the files, in muscle order. |
| `momentArmsMatchFiles` | Moment arms match the files. |
| `emgKeepsCollectedChannelsInSettingsOrder` | EMG channels keep the settings' order. |
| `emgIsCopiedToEachMuscleOfItsChannel` | Each muscle gets its channel group's EMG. |
| `minimalUsesDefaults` | The minimal file gets every default. |
| `fullReadsToolLevelOptions` | The full file sets every tool-level option. |
| `groupsAreMusclePositionsInSettingsOrder` | Groups become muscle positions in settings order. |
| `tasksAreOrderedByIndexAndDisabledTaskIsDropped` | Tasks are ordered by index; the disabled task is dropped. |
| `taskOptimizeFlagsAndLimits` | Each task's optimize flags and limits are read. |
| `costTermsKeepFileOrderAndValues` | Cost terms keep their file order and values. |
| `omittedErrorCenterParsesAsZero` | An omitted `<error_center>` parses as 0. |
| `synergyExtrapolationSettings` | Synergy extrapolation settings are read. |
| `synergyChannelsAreMusclePositionsInSettingsOrder` | Synergy channels become muscle positions. |
| `tutorialSynergyWeightCount` | The tutorial's synergy weight count matches the hand count. |
| `synergyExtrapolationCanBeEnabled` | Synergy extrapolation can be turned on. |
| `sharedDelaySettingIsRead` | The shared-delay setting is read (but not used on candidate). |
| `allTasksDisabledIsReported` | Disabling every task gives a clear message. |
| `wrongMajorVersionIsRejected` | A different major version is rejected. |
| `wrongToolIsRejected` | Another tool's settings file is rejected. |
| `missingDataDirectoryIsReported` | A missing data directory is reported. |
| `missingMuscleSpecificDelaysIsReported` | A missing muscle-specific delays setting is reported. |
| `unknownMuscleGroupIsReported` | An unknown muscle group is reported. |
| `missingResultsDirectoryIsReported` | A missing `<results_directory>` is named in the error. |
| `unknownCoordinateIsReported` | A misspelled coordinate is named in the error. |
| `emgChannelMissingFromDataIsReported` | An EMG channel not in the data is named in the error. |

### `MuscleTendonPersonalizationRegressionTest` — Regression
`tests/regression/MuscleTendonPersonalizationRegressionTest.m`. Full MTP runs: four synthetic known-truth cases
and the tutorial.

| Test | Description |
|---|---|
| `emgScaleRecoversTruth` | MTP finds the true EMG scale factors and leaves the rest alone. |
| `allFitsMomentsButCannotIdentifyParameters` | With every parameter optimized, the moments fit (parameters are not identifiable). |
| `twoTrialsIdentifiesParameters` | With two trials, the parameters are found within tolerance. |
| `passiveRecoversTrueLengths` | MTLI finds the true lengths from passive data. |
| `tutorialFitsAsWellAsPublishedRun` | The tutorial fits within 10% of its published moment errors. |
| `matchesNominalResult` (5 cases) | Results match the stored nominal results. |
| `writesExpectedResultFiles` (5 cases) | The osimx, parameters, moments and settings copy are written. |

---

## Muscle-Tendon Length Initialization (MTLI)

### `MtliValuesTest` — Unit
`tests/unit/MuscleTendonLengthInitialization/MtliValuesTest.m`. How MTLI unpacks its design vector, computes
maximum isometric force, and hands results to MTP and NCP.

| Test | Description |
|---|---|
| `scaleFactorLayout` | Scale factors are laid out per group and ungrouped muscle. |
| `stressScaleIsOneWhenNotOptimized` | The stress scale is 1 when not optimized. |
| `absoluteLengthsReplaceModelLengths` | With absolute lengths, the design values are the lengths. |
| `maxForceIsUnchangedAtInitialValues` | F0 is unchanged at the initial values. |
| `longerFibersOfSameVolumeAreWeaker` | The same volume over longer fibers gives less force. |
| `maxForceScalesWithMuscleStress` | F0 scales with muscle stress. |
| `maxForceIsKeptWhenNotOptimized` | F0 is kept when stress is not optimized. |
| `mtpStartsFromScaledLengths` | MTP starts from MTLI's scaled lengths. |
| `ncpUpdatesOnlyMusclesWithoutMtpResults` | In NCP, MTLI only replaces muscles without MTP results. |
| `ncpWithoutMtpResultsUpdatesEveryMuscle` | Without MTP results, NCP takes every muscle from MTLI. |
| `mtpStartsFromAbsoluteLengths` | MTP starts from MTLI's absolute lengths. |

### `MtliCostTermsTest` — Unit
`tests/unit/MuscleTendonLengthInitialization/CostTerms/MtliCostTermsTest.m`. MTLI's cost terms and
`calcMuscleTendonLengthInitializationCost`.

| Test | Description |
|---|---|
| `deviationResidualsGiveMeanSquare` | Deviation residuals give the mean square. |
| `trackingResidualsGiveMeanSquare` | Tracking residuals give the mean square. |
| `optimalFiberLengthScaleDefaults` | Optimal fiber length scale term with its defaults. |
| `tendonSlackLengthScaleDefaults` | Tendon slack length scale term with its defaults. |
| `absoluteLengthDeviationsFromInitialLengths` | Absolute length terms measure change from the initial lengths. |
| `muscleStressDefaults` | Muscle stress term with its defaults. |
| `passiveForceDefaults` | Passive force term with its defaults. |
| `minimumFiberLengthPenalizesShortfall` | Minimum fiber length term penalizes the shortfall below the limit. |
| `maximumFiberLengthTracksItsDesignValue` | Each muscle's longest fiber tracks its maximum-length design value. |
| `groupedMaximumFiberLengthTracksSetting` | Grouped muscles share a maximum-length design value. |
| `groupedFiberLengthsPenalizeLargestDifference` | Grouped fiber lengths penalize their largest difference. |
| `passiveMomentTrackingSkipsEmptyCoordinates` | Coordinates without passive data are skipped. |
| ⚠ `passiveMomentTrackingWorksForAnyTrialLength` | Passive moment tracking works with trials that are not 101 frames. |
| `enabledTermsAreStacked` | Enabled terms are stacked in order. |
| `absoluteLengthsSwitchTheLengthTerms` | Absolute lengths switch to the absolute length terms. |
| `passiveMomentTermNeedsPassiveData` | The passive moment term needs passive data. |
| `unknownTermIsReported` | An unknown term type is reported by name. |

### `MtliTermSmokeTest` — Unit
`tests/unit/MuscleTendonLengthInitialization/MtliTermSmokeTest.m`. Every cost term type
`calcMuscleTendonLengthInitializationCost` handles runs on its own in MTLI's objective, at the starting values
of MTP's `settings_full.xml`, prepared as for `MtpTermSmokeTest`.

| Test | Description |
|---|---|
| `termGivesFiniteCosts` (every MTLI cost type, 9 on candidate) | The term runs and gives a nonempty column of finite costs. |

### `MuscleTendonLengthInitializationParsingTest` — Parsing
`tests/parsing/MuscleTendonLengthInitializationParsingTest.m`. The `<MuscleTendonLengthInitialization>` section
of MTP settings files.

| Test | Description |
|---|---|
| `disabledSectionGivesFalse` | A disabled section parses as off. |
| `tutorialSettings` | The tutorial's MTLI settings are read. |
| `fullSettingsOverrideDefaults` | The full file overrides every default. |
| `defaultsWhenOptionsAreOmitted` | Omitted options get their defaults. |
| `muscleVolumeComesFromForceStressAndLength` | Muscle volume = F0 / stress × optimal length. |
| `eachMuscleMapsToItsGroupOrItsOwnSlot` | Each muscle maps to its group's or its own design value. |
| `withoutGroupsEveryMuscleHasItsOwnSlot` | Without groups, each muscle has its own design value. |
| `passiveTrialsAreFound` | The passive trials are found. |
| `passiveMomentsMatchFiles` | Passive moments match the files. |
| `passiveLengthsAndMomentArmsMatchFiles` | Passive lengths and moment arms match the files. |
| `emptyPassiveFolderMeansNoPassiveData` | An empty passive folder means no passive data. |

---

## Neural Control Personalization (NCP)

### `NcpFixtureTest` — Unit
`tests/unit/NeuralControlPersonalization/NcpFixtureTest.m`. The NCP fixtures still match `ncpFixtureValues`.

| Test | Description |
|---|---|
| `synergyGroupIsEveryMuscle` | The synergy group holds every modeled muscle. |
| `gaitFilesShareOneTimeGrid` | The gait files share one time grid. |
| `emgIsPaddedOnTheGaitTimeGrid` | EMG is padded on the same grid. |
| `muscleAnalysisMatchesGaitTimeAndMuscles` (5 files) | Each MuscleAnalysis file matches the gait times and muscles. |
| `mtpActivationsCoverEveryMuscleOnGaitTime` | MTP activations cover every muscle on the gait times. |
| `osimxHasRecordedMuscleValues` | The osimx file has the recorded muscle values. |
| `osimxNamesTheFixtureModel` | The osimx file names the fixture model. |

### `NcpSyntheticDataTest` — Unit
`tests/unit/NeuralControlPersonalization/NcpSyntheticDataTest.m`. The synthetic known-truth NCP data is
consistent with its truth.

| Test | Description |
|---|---|
| `trueActivationsArePlausible` | The true activations are between 0 and 1 and not all near 0. |
| `onlyTrackedMomentsDifferFromSource` (all_tracked, iliacus_hidden, fixed_weights) | Each case changes only the tracked moments. |
| `mtpActivationsAreTheTruth` (3 cases) | The MTP activations are the true activations. |
| `fixedWeightsFileHoldsTheTrueWeights` | The fixed-weights file holds the true weights. |
| `truthReproducesItsMoments` (3 cases) | The muscle model at the truth reproduces the moments. |

### `SynergyModelTest` — Unit
`tests/unit/NeuralControlPersonalization/SynergyModelTest.m`. NCP's synergy model: design vector layout,
B-spline commands, activations.

| Test | Description |
|---|---|
| `bSplineRowsSumToOne` | Each B-spline row sums to 1. |
| `bSplineNodesCanBeRecovered` | Nodes can be recovered from the spline (full column rank). |
| `bSplineReproducesAStraightLine` | A cubic B-spline reproduces a straight line exactly. |
| `weightsAreBlockDiagonalByGroup` | Weights are block-diagonal by synergy group. |
| `commandsComeFromNodesPerTrialAndSynergy` | Commands come from each trial's and synergy's nodes. |
| `repackIsTheInverseOfUnpack` | Repacking undoes unpacking. |
| `activationsAreCommandsTimesWeights` | Activations are commands × weights. |
| `activationsUseTheBSplineCommands` | Activations use the B-spline commands. |
| `maximumWeightNormalizationKeepsActivations` | Normalizing weights to a maximum of 1 keeps the activations. |
| `mtpActivationSubsetSplitsByName` | MTP activations are split by muscle name. |

### `NcpDesignVariablesTest` — Unit
`tests/unit/NeuralControlPersonalization/NcpDesignVariablesTest.m`. How NCP rebuilds its full design vector
from fmincon's.

| Test | Description |
|---|---|
| `fixedWeightsArePutBackInFront` | Fixed weights are put back in front of the command nodes. |
| `bilateralSymmetryCopiesFirstGroupWeights` | With bilateral symmetry, the first group's weights are copied. |
| `otherwiseTheVectorIsUsedAsIs` | Otherwise the vector is used as is. |

### `NcpInitialValuesTest` — Unit
`tests/unit/NeuralControlPersonalization/NcpInitialValuesTest.m`. NCP's starting design vector.

| Test | Description |
|---|---|
| `magnitudeGivesEachSynergyTheTargetNorm` | Magnitude normalization gives each synergy the target norm. |
| `sumGivesEachSynergyTheTargetSum` | Sum normalization gives each synergy the target sum. |
| `commandsStartAtTheGroupConstant` | Command nodes start at their group's constant. |
| `withoutTargetEverythingStartsAt015` | Without a target, everything starts at 0.15. |
| `fixedWeightsFitCommandsToMtpActivations` | With fixed weights, commands are fitted to the MTP activations. |
| `bilateralSymmetryNeedsTwoGroups` | Bilateral symmetry needs exactly two groups. |
| `bilateralSymmetryNeedsEqualGroups` | Bilateral symmetry needs groups of equal size. |

### `NcpCostTest` — Unit
`tests/unit/NeuralControlPersonalization/CostTerms/NcpCostTest.m`. NCP's cost function, `calcNcpCost`.

| Test | Description |
|---|---|
| `momentTrackingIsMeanSquaredScaledError` | Moment tracking is the mean of (error / allowable)². |
| `activationTrackingUsesOnlyMusclesWithMtpData` | Activation tracking uses only muscles with MTP activations. |
| `activationTrackingWithoutMtpDataCostsNothing` | Without MTP data, activation tracking costs nothing. |
| `activationMinimizationUsesMusclesWithoutMtpData` | Activation minimization uses muscles without MTP data. |
| `synergyActivationMinimizationUsesCommands` | Synergy activation minimization uses the commands. |
| `groupedActivationsPenalizeDifferenceFromGroupMean` | Grouped activations penalize differences from the group mean. |
| `groupedFiberLengthsGroupActivationsByFiberLengthGroup` | `grouped_fiber_lengths` compares activations within fiber length groups (open question). |
| `enabledTermsAddUp` | Enabled terms add up. |
| `unknownTermIsReported` | An unknown term type is reported. |

### `NcpTermSmokeTest` — Unit
`tests/unit/NeuralControlPersonalization/NcpTermSmokeTest.m`. Every cost term type `calcNcpCost` handles runs
on its own in NCP's objective, at the starting values of `settings_full.xml` prepared by the tool's own steps
(optimizers replaced by recording stand-ins).

| Test | Description |
|---|---|
| `termGivesOneFiniteCost` (every NCP cost type, 5 on candidate) | The term runs and the cost is one finite number. |

### `NeuralControlPersonalizationParsingTest` — Parsing
`tests/parsing/NeuralControlPersonalizationParsingTest.m`. NCP settings files → `inputs` and `params`.

| Test | Description |
|---|---|
| `synergyGroupGivesMusclesAndOrder` | The synergy group gives the muscles and their order. |
| `dataMatchesFiles` | The data matches the files. |
| `mtpActivationsAreReadForEveryMuscle` | MTP activations are read for every muscle. |
| `mtpLengthsAndForcesComeFromOsimx` | Lengths and forces come from the MTP osimx. |
| `tutorialSettingsAndDefaults` | The tutorial's settings and the defaults are read. |
| `tutorialCostTermsAndGroups` | The tutorial's cost terms and groups are read. |
| `withoutMtpResultsModelValuesAreUsed` | Without MTP results, the model's values are used. |
| `minimalUsesDefaultOptimizerSettings` | The minimal file gets the default optimizer settings. |
| `fullReadsEveryOption` | The full file sets every option. |
| `fullUsesNcpCostTermsNotMtlis` | NCP's own cost terms are read, not MTLI's. |
| `fullAlsoParsesMtli` | The full file's MTLI section is parsed too. |
| `emptyNormalizationValueMeansTen` | An empty normalization value means 10. |
| `bilateralSymmetryIsCheckedWhenNcpRuns` | Bilateral symmetry is checked when NCP runs. |
| `duplicateMusclesAreRejectedWhenNcpRuns` | Duplicate muscles are rejected when NCP runs. |
| `mtliCanBeEnabled` | MTLI can be turned on inside NCP. |
| `fixedWeightsAreReadInMuscleOrder` | Fixed weights are reordered to the muscle order. |
| `fixedWeightsMissingAMuscleAreReported` | Fixed weights missing a muscle are reported. |
| `fixedWeightsWithAnExtraMuscleAreReported` | Fixed weights with an extra muscle are reported. |
| `fixedWeightsWithWrongSynergyCountAreReported` | Fixed weights with the wrong synergy count are reported. |
| `wrongMajorVersionIsRejected` | A different major version is rejected. |
| `wrongToolIsRejected` | Another tool's settings file is rejected. |
| `missingSynergySetIsReported` | A missing synergy set is reported. |
| `unknownSynergyGroupIsReported` | An unknown synergy group is reported. |
| `muscleOutsideSynergyGroupsIsReported` | A muscle outside every synergy group is reported. |
| `osimxWithoutMusclesIsReported` | An osimx without muscles is reported. |
| `fixedWeightsWithoutFileAreReported` | Fixed weights without a weights file are reported. |
| `missingResultsDirectoryIsReported` | A missing `<results_directory>` is named in the error. |

### `NeuralControlPersonalizationRegressionTest` — Regression
`tests/regression/NeuralControlPersonalizationRegressionTest.m`. Full NCP runs: synthetic known-truth cases
and the tutorial.

| Test | Description |
|---|---|
| `allTrackedRecoversActivations` | With every muscle tracked, NCP reproduces the true activations. |
| ⚠ `iliacusHiddenPredictsIliacus` | Without iliacus_r's activations, NCP predicts them from the synergies. |
| `fixedWeightsKeepWeightsAndRecoverCommands` | With fixed weights, the weights stay and the commands are found. |
| `sumNormalizationRecoversActivations` | With sum normalization, NCP reproduces the activations. |
| ⚠ `mtliRunCompletesAndFits` | NCP with MTLI completes and fits the moments. |
| `tutorialFitsAsWellAsPublishedRun` | The tutorial fits within 10% of its published run. |
| `optimizedWeightsAreNormalizedToMaximumOne` | Each synergy's largest weight is 1. |
| `combinedActivationsUseMtpWhereAvailable` | Saved activations are MTP's where MTP has them. |
| `matchesNominalResult` (allTracked, fixedWeights, sum, tutorial) | Results match the stored nominal results. |
| `writesExpectedResultFiles` (6 cases; ⚠ for iliacusHidden and mtli) | The weights, commands, activations, moments and osimx are written. |
| `acceptsCharacterSettingsFileName` | The tool accepts a single-quoted (char) settings file name. |

---

## Ground Contact Personalization (GCP)

### `GcpFixtureTest` — Unit
`tests/unit/GroundContactPersonalization/GcpFixtureTest.m`. The GCP fixtures still match `gcpFixtureValues`.

| Test | Description |
|---|---|
| `footIsTwoSegmentsJoinedByAPinJoint` | The foot is a hindfoot and toes joined by a one-coordinate joint. |
| `footMarkersAreOnTheFoot` | The five foot markers are on the expected bodies. |
| `grfAndIkShareOneTimeGrid` | GRF and IK share one time grid. |
| `grfHasTheRightFootColumns` | The GRF file has the right foot's force, moment and center columns. |
| `rightFootHasAStancePhase` | The right foot has one stance phase in the trial. |

### `GcpSyntheticDataTest` — Unit
`tests/unit/GroundContactPersonalization/GcpSyntheticDataTest.m`. The synthetic known-truth GCP data is
consistent with its truth.

| Test | Description |
|---|---|
| `onlyPlateTwoColumnsDiffer` (globals, springs, rotation) | Each case changes only plate 2's columns. |
| `motionIsTheFixtureMotion` (3 cases) | Each case uses the fixture motion unchanged. |
| `electricalCenterIsUnderTheMidfoot` (3 cases) | The electrical center is under the midfoot marker. |
| `footHasTheExpectedSprings` (3 cases) | The foot has the expected 37 springs. |
| `truthHasZeroCost` (3 cases) | GCP's own cost is zero at the truth. |
| `startingValuesHaveLargeCost` (3 cases) | GCP's cost is large at the starting values. |

### `SpringContactModelTest` — Unit
`tests/unit/GroundContactPersonalization/SpringContactModelTest.m`. GCP's foot–ground contact model.

| Test | Description |
|---|---|
| `noForceOneCentimeterAboveRestingLength` | No force 1 cm above the resting length. |
| `almostNoForceWhenAboveTheGround` | Almost no force above the ground. |
| `compressedSpringHasStiffnessK` | A compressed spring has stiffness K. |
| `stifferSpringPushesHarder` | Force scales with K deep in compression. |
| `dampingScalesByVerticalVelocity` | Damping scales force by (1 − d·v). |
| `verticalForceSumsSprings` | Vertical force sums the springs. |
| `frictionOpposesSlipIncludingBeltSpeed` | Friction opposes slip, including belt speed. |
| `noFrictionWithoutSlip` | No slip, no friction. |
| `momentsAreAboutProjectedMidfoot` | Moments are about the projected midfoot marker. |
| `plateRotationIsAboutVerticalAxis` | Force plate rotation is about the vertical axis. |

### `FootKinematicsTest` — Unit
`tests/unit/GroundContactPersonalization/FootKinematicsTest.m`. How GCP represents the foot's motion and places
its springs.

| Test | Description |
|---|---|
| `unitCoefficientsReproduceTheBSplineFit` | B-spline coefficients of 1 reproduce the fitted motion. |
| `coefficientsScaleTheFittedNodes` | Doubling a coordinate's coefficients doubles it. |
| `normalizedGridCoversTheFoot` | The normalized spring grid covers the foot. |
| `leftFootGridIsMirrored` | The left foot's grid is mirrored. |
| `rotate2DTurnsCounterclockwise` | 2-D rotation turns counterclockwise. |
| `markersAreNormalizedByFootSize` | Marker positions are normalized by foot size. |

### `GcpCostTermsTest` — Unit
`tests/unit/GroundContactPersonalization/CostTerms/GcpCostTermsTest.m`. GCP's cost terms and how a task's
result is merged back.

| Test | Description |
|---|---|
| `markerErrorsAreAbsoluteDifferences` | Marker errors are absolute differences. |
| `periodicityComparesFirstAndLastFrame` | Periodicity compares the first and last frames. |
| `bSplineCoefficientErrorIsDeviationFromOne` | Coefficient error is the deviation from 1. |
| `springConstantErrorFromMean` | Spring constant error from the mean. |
| `springConstantErrorFromWeightedNeighbors` | Spring constant error from weighted neighbors. |
| `electricalCenterErrorIsTheShift` | Electrical center error is the shift. |
| `electricalCenterErrorCanSkipAxes` | Axes can be left out of the electrical center error. |
| `forcePlateRotationErrorIsTheAngle` | Force plate rotation error is the angle. |
| `wallErrorIsScaledPower` | The wall error is a scaled power. |
| `forceErrorsAreExperimentalMinusModeled` | Force errors are experimental − modeled. |
| `mergedResultFollowsDesignVariableOrder` | A task's result is merged back in design variable order. |
| `mergedResultWithoutRestingLengthFollowsOrder` | The same, without the resting length. |
| `excludedVariablesAreLeftAlone` | Variables not optimized are left alone. |

### `GcpTermSmokeTest` — Unit
`tests/unit/GroundContactPersonalization/GcpTermSmokeTest.m`. Every cost term type
`calcGroundContactPersonalizationTaskCost` handles runs on its own in GCP's task cost, at the starting values of
`settings_full.xml` prepared by the tool's own steps, for the task with the most design variables. `lsqnonlin`
is replaced by a recording stand-in, and the cost function's fixed arguments are read from the recorded call.

| Test | Description |
|---|---|
| ⚠ `termGivesFiniteCosts` (every GCP cost type, 15 on candidate; ⚠ for neighbor_spring_constant) | The term runs and gives a nonempty column of finite costs. |

### `GroundContactPersonalizationParsingTest` — Parsing
`tests/parsing/GroundContactPersonalizationParsingTest.m`. GCP settings files → `inputs` and `params`.

| Test | Description |
|---|---|
| `contactSurfaceDescribesTheRightFoot` | The contact surface describes the right foot. |
| `groundReactionsMatchFile` | Forces, moments and electrical center match the file. |
| `timeWindowSelectsFramesInsideIt` | The time window selects the frames inside it. |
| `dataPathsUseInputDirectory` | Data paths use `<input_directory>`. |
| `tutorialSettings` | The tutorial's settings are read. |
| `tutorialTasks` | The tutorial's three tasks are read. |
| `minimalUsesDefaults` | The minimal file gets every default. |
| `fullReadsEveryOption` | The full file sets every option. |
| `fullTasksAreOrderedAndDisabledDropped` | Tasks are ordered; the disabled task is dropped. |
| `allTasksDisabledGivesNoTasks` | Disabling every task gives no tasks. |
| `timeWindowIsClippedToTheData` | A time window past the data is clipped. |
| `pathsAreRelativeToCurrentFolderWithoutInputDirectory` | Without `<input_directory>`, paths are relative to the current folder. |
| `noEnabledSurfaceIsReported` | No enabled contact surface gives a clear message. |
| `wrongMajorVersionIsRejected` | A different major version is rejected. |
| `wrongToolIsRejected` | Another tool's settings file is rejected. |
| `missingContactSurfaceSetIsReported` | A missing contact surface set is reported. |
| `legacyToesCoordinateIsExplained` | The old toes coordinate setting is explained. |
| `unknownMarkerIsReportedWhenPreparingInputs` | An unknown marker is reported when preparing inputs. |
| `hindfootMustStartATwoSegmentFoot` | A hindfoot body that is not a two-segment foot is reported. |
| `misspelledForceColumnIsReported` | A misspelled force column is reported. |
| `missingResultsDirectoryIsReported` | A missing `<results_directory>` is named in the error. |

### `GroundContactPersonalizationRegressionTest` — Regression
`tests/regression/GroundContactPersonalizationRegressionTest.m`. Full GCP runs: four synthetic cases, one crash
check and the tutorial.

| Test | Description |
|---|---|
| `globalsRecoversContactValues` | GCP finds the true damping, friction and resting length. |
| `springsRecoversSpringConstants` | GCP finds the true spring constant for every spring. |
| `syntheticRunFitsGroundReactions` (globals, springs) | The synthetic runs fit their ground reactions. |
| `rotationFindsForcePlateAngle` | GCP finds the force plate's rotation. |
| `laterTasksKeepTheForcePlateAngle` | A later task that does not optimize the rotation still uses the angle found earlier. |
| `neighborTermWorksWithoutMomentTerms` | The neighbor spring term runs without a moment term. |
| `tutorialFitsGroundReactions` | The tutorial fits within 25% of its recorded run. |
| `tutorialValuesArePhysical` | The tutorial's values are physically plausible. |
| `matchesNominalResult` (all 6 cases) | Results match the stored nominal results. |
| `writesExpectedResultFiles` (6 cases) | The osimx, kinematics, ground reactions and settings copy are written. |

---

## Treatment Optimization

Tests shared by Tracking, Verification and Design Optimization are in `unit/TreatmentOptimization/` and the
classes named `TreatmentOptimization*`; tool-specific tests are in `unit/DesignOptimization/` and the classes
named after each tool. Run them all with `runTests("all", Tool="TO")`. Tests that need GPOPS-II (input
preparation and solving) are in the regression tier and are reported as not run without a license.

### `TreatmentOptimizationFixtureTest` — Unit
`tests/unit/TreatmentOptimization/TreatmentOptimizationFixtureTest.m`. The Treatment Optimization fixtures still
match `toFixtureValues`.

| Test | Description |
|---|---|
| `motionCoversTheKick` | The kick's IK covers 63 frames at 200 Hz from 0 to 0.31 s. |
| `inverseDynamicsMatchesMotion` | The ID data matches the IK times and has the states' loads. |
| `userFunctionsArePresent` | The user-defined cost and constraint functions are present. |
| `torqueModelHasItsMuscles` | The torque model has its 86 muscles. |
| `synergyModelHasTheNineMuscles` | The synergy model has the nine right-leg muscles, in order. |
| `modelsHaveTheStatesCoordinates` (torque, synergy) | Each model has the three states coordinates. |
| `osimxHasTheSynergyGroup` | The osimx has the `RightLeg` group and its muscles. |
| `ncpSynergiesMatchTheGroup` | NCP's weights and commands match the group (4 synergies × 9 muscles). |
| `surrogateDataHasEverySample` | The surrogate data has every sample and only the files used. |
| `fittedSurrogateIsPresent` | The tutorial's fitted surrogate model is present. |
| `publishedResultsSolveTheStatesCoordinates` (4 published results) | Each published result has the expected states, controls and data. |

### `ToScalingAndDynamicsTest` — Unit
`tests/unit/TreatmentOptimization/ToScalingAndDynamicsTest.m`. Scaling between GPOPS-II's variables and real
values, and the dynamic constraint.

| Test | Description |
|---|---|
| `boundsScaleToPlusMinusOneHalf` | Values scale to [−0.5, 0.5] across their bounds. |
| `scalingIsPerColumn` | Each column has its own bounds. |
| `scaleToOriginalUndoesScaling` | Unscaling undoes scaling. |
| `scaledZeroIsTheMidpoint` | Scaled 0 is the bounds' midpoint. |
| `dynamicConstraintIsScaledDerivatives` | The dynamic constraint is the scaled derivatives. |
| `correctStatesPicksABlockOfColumns` | `getCorrectStates` picks the position or velocity block. |
| `subsetKeepsTheRequestedOrder` | Coordinate subsets keep the requested order. |
| `subsetReportsAMissingCoordinate` | A missing coordinate is reported. |
| `transferredMomentAddsLeverArmCrossForce` | Moving a moment's point adds r × F. |

### `ToSynergyModelTest` — Unit
`tests/unit/TreatmentOptimization/ToSynergyModelTest.m`. The synergy-driven muscle model.

| Test | Description |
|---|---|
| `sumNormalizationMakesEachRowSumToTheValue` | Sum normalization makes each synergy sum to the value. |
| `magnitudeNormalizationMakesEachRowNormTheValue` | Magnitude normalization gives each synergy that norm. |
| `normalizationKeepsTheActivations` | Normalization leaves commands × weights unchanged. |
| `normalizationRecordsTheInitialWeights` | The normalized weights are kept as the initial weights. |
| `unknownNormalizationIsReported` | An unknown normalization method is reported. |
| `torqueControllerIsLeftAlone` | A torque-driven problem is left alone. |
| `inactiveMuscleGivesOnlyPassiveMoment` | An inactive muscle gives only its passive moment. |
| `activeMuscleAddsActiveForce` | An active muscle adds a·fL·fV. |
| `momentsSumOverMuscles` | Muscle moments add. |
| `surrogateIndexSelectsTheCoordinates` | The surrogate index selects the coordinates returned. |

### `ToDesignVariablesTest` — Unit
`tests/unit/TreatmentOptimization/ToDesignVariablesTest.m`. The layout of GPOPS-II's variables and their bounds.

| Test | Description |
|---|---|
| `torqueValuesAreUnscaled` | Time, states, accelerations and torques are unscaled correctly. |
| `stateCoordinatesReplaceTheSplinedData` | States coordinates take the optimized values; others keep the data. |
| `synergyActivationsComeBeforeTorqueControls` | Controls are [accelerations, synergies, torques]. |
| `optimizedSynergyWeightsComeFromParameters` | Optimized synergy weights come from the parameters. |
| `designVariablesFollowSynergyWeights` | Design's user-defined variables come after the synergy weights. |
| `stateBoundsExtendTheDataRange` | State bounds extend the data's range by the multiple. |
| `minimumRangeWinsWhenDataBarelyMoves` | The minimum range is used when the scaled range is smaller. |
| `controlBoundsCoverAccelerationsAndTorques` | Control bounds cover accelerations and torques. |
| `synergyActivationsAreBoundedByTheMaximum` | Synergy activations are bounded by 0 and the maximum. |
| `optimizedSynergyWeightsAreBoundedByTheNormalization` | Optimized weights are bounded by the normalization value. |
| `designVariableBoundsAreAppended` | Design variable bounds are appended. |

### `ToTermRegistryTest` — Unit
`tests/unit/TreatmentOptimization/ToTermRegistryTest.m`. Which cost and constraint terms each tool and controller
allows, and that each can be computed.

| Test | Description |
|---|---|
| `everyAllowedCostTypeHasACalculation` (3 tools × continuous/discrete) | Every allowed cost type calls an existing function. |
| `everyAllowedConstraintTypeHasACalculation` (3 tools × path/terminal × torque/synergy) | Every allowed constraint type calls an existing function. |
| `allowedTypesAreListedOnce` (3 tools × 2 kinds) | No cost type is listed twice. |
| `verificationHasNoDiscreteCostTerms` | Verification has no discrete cost terms. |
| `verificationTracksButDoesNotMinimize` | Verification can track but not minimize. |
| `designOnlyCostTerms` | Design-only cost terms are not allowed in Tracking. |
| `designGoalsAreDiscrete` | Design's goals are discrete terms. |
| `unknownToolIsReported` | An unknown tool name is reported. |
| `muscleActivationConstraintsNeedSynergies` (3 tools) | Muscle activation constraints need the synergy controller. |
| `synergyVectorConstraintsAreNotVerified` | Synergy vector constraints are not in Verification. |
| `designOnlyConstraints` (torque, synergy) | Fiber length limits and user-defined constraints are Design only. |
| `centerOfPressureIsNotVerified` (torque, synergy) | Center of pressure constraints are not in Verification. |
| `kineticConsistencyIsEverywhere` (3 tools × 2 controllers) | Kinetic consistency is allowed everywhere. |

### `ToCostTermsTest` — Unit
`tests/unit/TreatmentOptimization/CostTerms/ToCostTermsTest.m`. Continuous cost terms, how they combine, and
their allowable errors.

| Test | Description |
|---|---|
| `coordinateTrackingIsExperimentalMinusModeled` | Coordinate tracking is experimental − modeled. |
| `errorsAreDividedByFinalTimeByDefault` | Errors are divided by the final time by default. |
| `trackingRemembersItsColumn` | A term remembers its data column. |
| `speedMinimizationIsDistanceFromErrorCenter` | Speed minimization is the distance from the error center. |
| `inverseDynamicsTrackingUsesTheLoad` | ID load tracking uses the named load and scale factor. |
| `timeRangesZeroTheOtherPoints` | `<time_ranges>` zero the points outside them. |
| `torqueControllerMinimizationIsTheControl` | Torque controller minimization is the control. |
| `synergyControllerMinimizationIsTheActivation` | Synergy controller minimization is the activation. |
| `unknownControllerIsReported` | An unknown controller is reported. |
| `activationMinimizationAppliesTheExponent` | Activation minimization applies its exponent. |
| `costArrayTermsSelectColumns` | The cost array helpers select columns. |
| `enabledTermsAreConcatenatedInOrder` | Enabled terms are concatenated in order. |
| `integrandIsSquaredScaledError` | The integrand is (error / allowable)². |
| `allowableErrorsAreSplitByKind` | Allowable errors are split into continuous and discrete. |
| `costTypeNotInTheToolIsReported` | A cost type not in the tool is reported. |
| `userDefinedTermNeedsAKind` | A user-defined term needs `cost_term_type`. |

### `ToConstraintTermsTest` — Unit
`tests/unit/TreatmentOptimization/ConstraintTerms/ToConstraintTermsTest.m`. Constraint terms, how they combine,
and their bounds.

| Test | Description |
|---|---|
| `kineticConsistencyIsInverseDynamicsMinusTorque` | Kinetic consistency is ID load − torque control. |
| `kineticConsistencyAddsMuscleMoments` | With synergies, muscle moments are added to the torque. |
| `uncontrolledLoadIsReported` | A load with no controller is reported. |
| `periodicityIsLastMinusFirst` | Periodicity is last − first. |
| `synergyWeightSumAndMagnitude` | Synergy weight sum and magnitude for a named synergy. |
| `enabledConstraintsAreConcatenated` | Enabled constraints are concatenated. |
| `boundsComeFromEnabledTermsOnly` | Constraint bounds come from enabled terms only. |

### `ToTermHelpersTest` — Unit
`tests/unit/TreatmentOptimization/TermHelpers/ToTermHelpersTest.m`. The helpers the terms share.

| Test | Description |
|---|---|
| `timeRangesKeepThePointsInside` | Time ranges keep the points inside them. |
| `timeRangesUseNormalizedTime` | Time ranges use normalized time. |
| `badTimeRangesAreReported` | Odd-length, decreasing and out-of-range time ranges are reported. |
| `relativeErrorDividesByAtLeastTheMinimum` | Relative error divides by at least the minimum reference. |
| `finalTimeNormalizationDefaultsOnAndIsRecorded` | Final-time normalization defaults on and is recorded. |
| `finalTimeNormalizationCanBeTurnedOff` | Final-time normalization can be turned off. |
| `centerOfPressureAlongX` | Center of pressure along x. |
| `centerOfPressureAlongZ` | Center of pressure along z. |
| `centerOfPressureHasNoYAxis` | Center of pressure has no y axis. |
| `xyzAnglesAreUnchanged` | xyz angles are unchanged. |
| `singleAxisRotationKeepsItsAngle` | A single-axis rotation keeps its angle in any sequence. |
| `unknownSequenceIsReported` | An unknown rotation sequence is reported. |
| `dataIndicesFollowTheTargetOrder` | Data indices follow the requested order. |
| `optionalIndicesAreMinusOneWhenMissing` | Optional indices are −1 when missing. |
| `loadNamesMapToCoordinates` | Load names map to coordinates. |
| `synergyNamesCountAcrossGroups` | Synergy names count across groups (`B_2` is the fourth). |
| `synergyNamesNeedAGroupAndNumber` | Synergy names need `<group>_<number>`. |
| ⚠ `synergyWeightColumnsAreTheGroupsMuscles` | Each synergy's weight columns are its group's muscles. |

### `DoCostTermsTest` — Unit
`tests/unit/DesignOptimization/DoCostTermsTest.m`. Design-only cost terms, called through the registry.

| Test | Description |
|---|---|
| `walkingSpeedGoalIsScaledSquaredDifference` | The walking speed goal is ((speed − center) / allowable)². |
| ⚠ `jointEnergyGenerationRewardsPositivePower` | The joint energy generation goal runs and rewards positive power. |
| ⚠ `jointEnergyAbsorptionRuns` | The joint energy absorption goal runs. |
| ⚠ `angularMomentumMinimizationIsTheAxis` | Angular momentum minimization returns the chosen axis. |
| ⚠ `inverseDynamicsShapeIgnoresScale` | ID shape tracking ignores a constant scale. |
| `userDefinedTermCallsTheNamedFunction` | A user-defined term calls its function, for its own kind only. |

### `DoGaitMeasuresTest` — Unit
`tests/unit/DesignOptimization/DoGaitMeasuresTest.m`. The gait measures Design's goals are built on.

| Test | Description |
|---|---|
| `brakingAndPropulsiveForcesSplitTheAnteriorForce` | Braking and propulsive forces split the anterior force. |
| `restingMetabolicPowerIsBasalPlusMinimumHeat` | Resting metabolic power is basal plus each muscle's minimum heat. |
| `activeMusclesCostMore` | More activation costs more. |

### `DoModelFunctionsTest` — Unit
`tests/unit/DesignOptimization/DoModelFunctionsTest.m`. Design's model functions.

| Test | Description |
|---|---|
| `noModelFunctionsChangeNothing` | No model functions change nothing. |
| `userModelFunctionChangesTheSetup` | A user model function changes the problem. |
| ⚠ `beltSpeedParameterSetsTheBeltSpeed` | The built-in belt speed function sets the belt speed. |

### `TreatmentOptimizationParsingTest` — Parsing
`tests/parsing/TreatmentOptimizationParsingTest.m`. The parsing all three tools share, on Tracking settings files.

| Test | Description |
|---|---|
| `trialDataIsRead` | The trial's IK, ID and times are read. |
| `anglesAreConvertedToRadians` | IK angles are converted to radians. |
| `statesCoordinatesAreFoundInTheData` | The states coordinates are found in the data. |
| `modelMassIsRead` | The model's mass is read. |
| `minimalUsesDefaults` | The minimal file gets every default. |
| `missingResultsDirectoryIsReported` | A missing `<results_directory>` is named in the error. |
| `fullReadsEveryOption` | The full file sets every option. |
| `listsAreSplitIntoOneTermEach` | `*_list` elements are split into one term each. |
| `axesAreSplitIntoOneTermEach` | `<axes>` are split into one term each. |
| `termElementsAreConverted` | Term elements become numbers, logicals and lists. |
| `disabledTermsAreKeptButMarked` | Disabled terms are kept, marked disabled. |
| `zeroAllowableErrorIsReported` | An enabled term with allowable error 0 is reported. |
| `constraintsAreSortedIntoPathAndTerminal` | Constraints are sorted into path and terminal. |
| `valueBoundsBecomeErrorBounds` | `<max_value>`/`<min_value>` become the error bounds. |
| `constraintNotInTheToolIsReported` | A constraint not in the tool is reported. |
| `gpopsSettingsAreRead` | GPOPS-II settings are read. |
| `gpopsSettingsHaveDefaults` | An empty `<GpopsSettings>` takes every default. |
| `unsupportedSolverIsReported` | An unsupported solver is reported. |
| `wrongMajorVersionIsRejected` | A different major version is rejected. |
| `differentMinorVersionOnlyWarns` | A different minor version only warns. |
| `wrongToolIsRejected` | Another tool's settings file is rejected. |
| `missingControllerIsReported` | A missing controller is reported. |
| `missingCostTermSetIsReported` | A missing cost term set is reported. |
| `missingInitialGuessDirectoryIsReported` | A missing initial guess directory is reported. |
| `missingSolverSettingsFileIsReported` | A missing solver settings file is named. |
| `unknownStatesCoordinateIsReported` | A misspelled states coordinate is named in the error. |

### `TrackingOptimizationParsingTest` — Parsing
`tests/parsing/TrackingOptimizationParsingTest.m`. The tutorial's Tracking files and the synergy controller.

| Test | Description |
|---|---|
| `torqueTutorialTracksCoordinatesAndLoads` | The torque tutorial tracks coordinates and loads under kinetic consistency. |
| `synergyControllerReadsTheSynergyGroups` | The synergy controller reads the groups, synergies and muscles. |
| `synergyControllerDefaults` | Synergy controller defaults. |
| `synergyStartingValuesComeFromNcp` | Synergy weights, commands and activations come from NCP. |
| `surrogateDataHasEverySample` | The surrogate data is read with every sample. |
| `muscleParametersComeFromTheOsimx` | Muscle lengths come from the osimx. |
| ⚠ `muscleParametersFollowTheModeledMuscles` | Each modeled muscle gets its own max force and pennation. |
| `synergyControllerNeedsAnOsimx` | The synergy controller needs an osimx. |

### `VerificationOptimizationParsingTest` — Parsing
`tests/parsing/VerificationOptimizationParsingTest.m`. The tutorial's Verification file.

| Test | Description |
|---|---|
| `dataComeFromThePublishedTracking` | The initial guess and tracked data are the published Tracking results. |
| `torqueControlsStartFromTracking` | Torque controls start from Tracking's. |
| `controllerTrackingAndEndConditions` | Controller tracking and the initial and final conditions are read. |
| `synergyVectorsCannotBeOptimized` | Optimizing synergy vectors is rejected. |

### `DesignOptimizationParsingTest` — Parsing
`tests/parsing/DesignOptimizationParsingTest.m`. Design-only settings.

| Test | Description |
|---|---|
| `finalTimeRangeIsRead` | `<final_time_range>` is read. |
| `emptyFinalTimeRangeIsLeftOut` | An empty `<final_time_range/>` is left out. |
| `modelFunctionsAreRead` | `<model_functions>` are read. |
| `parametersHaveValuesAndBounds` | User-defined parameters have values and bounds. |
| `noParametersGiveAnEmptyList` | No parameters give an empty list. |
| `userDefinedTermsKeepTheirSettings` | User-defined terms keep their own elements. |
| `tutorialUserDefinedFilesParse` | The tutorial's user-defined files parse. |
| `synergyDesignStartsFromPublishedVerification` | Synergy Design starts from the published Verification. |
| ⚠ `metabolicGoalTurnsOnMetabolicCost` | A metabolic goal turns on the metabolic calculation. |

### `TreatmentOptimizationSetupRegressionTest` — Regression
`tests/regression/TreatmentOptimizationSetupRegressionTest.m`. Each case prepared up to the solve, compared with
nominal results. Cases: trackingTorque, trackingSynergy, verificationTorque, designTorqueV3, designTorqueV5,
designSynergy.

| Test | Description |
|---|---|
| `matchesNominalResult` (6 cases) | Collocation times, bounds, guess and functions at the guess match the nominal results. |
| `initialGuessIsWithinBounds` (6 cases) | The initial guess is within its bounds. |
| `collocationPointsFollowTheSolverSettings` | Collocation points follow the GPOPS-II settings. |
| `publishedSolutionsTrackThemselves` | Published solutions have zero tracking cost against themselves. |
| `publishedVerificationMeetsItsEndConditions` | The published Verification meets its end conditions. |
| `userDefinedConstraintMatchesBuiltInTerm` | The user-defined toe speed matches the built-in toe velocity. |

### `TreatmentOptimizationTermSmokeTest` — Regression
`tests/regression/TreatmentOptimizationTermSmokeTest.m`. Every cost and constraint term the registries
(`generateCostTermStruct`, `generateConstraintTermStruct`) allow, for five cases: Tracking, Verification and
Design with the torque controller (Step 6 kick) and Tracking and Design with the synergy controller (Step 8
kick, synergy vectors optimized). Each case is prepared once from its tutorial settings with one disabled term
of every allowed type added, and each term is enabled on its own and evaluated at the initial guess. Muscle
terms run in the synergy cases only. Contact-surface terms (external forces and moments, center of pressure,
braking and propulsive impulse) are reported as not run: the kick fixtures have no contact surfaces. Needs
GPOPS-II.

| Test | Description |
|---|---|
| ⚠ `termRunsAndHasTheRightSize` (one per case, kind and type: 416 on candidate; ⚠ for the B20 and B21 terms in both Design cases) | The term runs and gives finite values: one per collocation point for continuous and path terms, one for discrete and terminal terms. |

### `TrackingOptimizationRegressionTest` — Regression
`tests/regression/TrackingOptimizationRegressionTest.m`. Full Tracking runs (torque, synergy).

| Test | Description |
|---|---|
| `ipoptDoesNotFail` (torque, synergy) | IPOPT converges or reaches its limit; it does not fail. |
| `writesExpectedResultFiles` (torque, synergy) | The states, controls, data and settings copy are written. |
| `solutionIsWithinBounds` (torque, synergy) | The solution stays within its bounds. |
| `torqueSolutionIsKineticallyConsistent` | ID loads equal torque controls within 0.1 Nm. |

### `VerificationOptimizationRegressionTest` — Regression
`tests/regression/VerificationOptimizationRegressionTest.m`. A full Verification run (torque).

| Test | Description |
|---|---|
| `ipoptDoesNotFail` | IPOPT converges or reaches its limit; it does not fail. |
| `writesExpectedResultFiles` | The result files are written. |
| `solutionIsWithinBounds` | The solution stays within its bounds. |
| `solutionIsKineticallyConsistent` | The solution is kinetically consistent. |
| `solutionStartsAtTheTrackedState` | The solution starts within its initial-state constraints. |

### `DesignOptimizationRegressionTest` — Regression
`tests/regression/DesignOptimizationRegressionTest.m`. Full Design runs (torque V3, torque V4, synergy).

| Test | Description |
|---|---|
| `ipoptDoesNotFail` (3 cases) | IPOPT converges or reaches its limit; it does not fail. |
| `writesExpectedResultFiles` (3 cases) | The result files are written. |
| `solutionIsWithinBounds` (3 cases) | The solution stays within its bounds. |
| `finalTimeIsInTheAllowedRange` (3 cases) | The final time is within `<final_time_range>`. |
| `torqueSolutionIsKineticallyConsistent` (V3, V4) | The torque solutions are kinetically consistent. |

---

## Example

### `ExampleTest` — Unit
`tests/unit/ExampleTest.m`. A template showing the structure every test file follows; it tests nothing in the
pipeline.

| Test | Description |
|---|---|
| `additionIsCorrect` | Shows an exact check. |
| `floatingPointNeedsTolerance` | Shows a check with a tolerance. |
| `errorIsThrown` | Shows a check that an error is thrown. |
