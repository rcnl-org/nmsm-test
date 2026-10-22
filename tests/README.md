# Writing and maintaining tests

This guide is for anyone adding to or changing the test suite. For how to *run* the suite, see the
[root README](../README.md).

## The three tiers

| Tier | Tag | Folder | What it checks | Time | Run it |
|---|---|---|---|---|---|
| Unit | `Unit` | `unit/` | One function at a time, against values worked out by hand | seconds | while coding |
| Parsing | `Parsing` | `parsing/` | Settings XML → the `inputs`/`params` structs a tool builds | seconds | before every commit/PR |
| Regression | `Regression` | `regression/` | Full tool runs, compared with the truth and with stored nominal results | minutes | before merging, and when testing a new nmsm-core branch |

Most tests should be unit tests. A bug that a unit test can catch should not depend on a 3-minute
regression run to find it.

A few unit tests read the fixture files or parse a settings file (e.g. `MtpFixtureTest`,
`MtpSyntheticDataTest`). They check that the test data itself is right, so they belong with the unit tests
that depend on it.

## Running part of the suite

```matlab
runTests("unit")                       % one tier
runTests("all")
```

To run a single file or a single test while you work on it, you need the nmsm-core project open (running
`runTests` once leaves it open) and `tests/helpers` on the path. From the nmsm-test folder:

```matlab
addpath("tests/helpers")
runtests("tests/unit/core/OrderByIndexTest.m")
runtests("tests/unit/core/OrderByIndexTest.m", "ProcedureName", "missingIndexThrows")
```

## Adding a test

1. **Pick the tier and folder.** Put tests under the tier, then the nmsm-core folder the code lives in, e.g.
   `unit/JointModelPersonalization/`. Cost term tests go in a `CostTerms/` folder under their tool, e.g.
   `unit/MuscleTendonPersonalization/CostTerms/`.
   - **Prefix the class name with the tool** (`MtpCostTermsTest`, `MtliCostTermsTest`), at least wherever another
     tool could want the same name. Test classes share one MATLAB path, so two `CostTermsTest` classes in
     different folders would shadow each other.
2. **Copy the shape of an existing test.** `unit/ExampleTest.m` is the smallest example:

   ```matlab
   classdef (TestTags = {'Unit'}) MyFunctionTest < matlab.unittest.TestCase
       methods (Test)
           function describesTheBehavior(testCase)
               actual = myFunction(2);
               testCase.verifyEqual(actual, 4);
           end
       end
   end
   ```

   - The file name and class name must match and end in `Test`.
   - Every class needs a `TestTags` tier tag. Without one, `runTests("unit")` and the other tier commands skip it.
   - Name each test method for the behavior it checks, e.g. `outOfOrderTasksAreSorted`, so a failure
     report explains itself.
3. **Work out the expected value independently.** Get it by hand, from a known physical fact, or from the
   fixture files. Do not run the code and paste its output into the test: that only checks the code
   still does what it did, including any bugs. (Nominal results in regression tests are the one exception,
   and they are paired with a check against the truth.)
4. **See it fail once.** Before trusting a new test, break the code (or the expected value) and make sure the
   test fails with a readable message, then undo it.

### Checks to use

| To check | Use |
|---|---|
| Two values are equal | `testCase.verifyEqual(actual, expected)` |
| Two decimal values are equal | `testCase.verifyEqual(actual, expected, "AbsTol", 1e-12)` (never compare decimals exactly) |
| Code runs without error | `testCase.verifyWarningFree(@() myFunction(x))` |
| An error with an identifier | `testCase.verifyError(@() myFunction(x), "component:errorId")` |
| An error **without** an identifier (most nmsm-core errors) | `verifyErrorMessage(testCase, @() myFunction(x), "part of the message")` |

`verify*` records a failure and keeps going. `assert*` stops the current test. Prefer `verify*` unless the
lines after it would crash anyway.

Do not check an error with `verifyError(fn, ?MException)`. It accepts *any* error, including an unrelated
crash. That is how a broken check in `verifyJointModelPersonalizationFunctionsArgs` passed unnoticed.
Use `verifyErrorMessage` instead.

### Tolerances

| Kind of value | Typical `AbsTol` |
|---|---|
| Pure arithmetic | `1e-12` |
| Values read back through OpenSim | `1e-9` to `1e-12` |
| Optimizer results vs. the truth | what a correct run should achieve (e.g. 0.01 mm, 0.006°) |
| Optimizer results vs. nominal | much tighter (e.g. `1e-7`), to catch any change |

Write down in the test why a tolerance has the value it has. For an optimizer result, say what a correct run
achieves and, where it matters, what a run that should *not* pass would give. For example,
`twoTrialsIdentifiesParameters` uses tolerances about three times what a correct run reaches, but smaller than
what the one-trial case misses by, so it can only pass if the second trial adds information.

### Things that have bitten us

- **Files written to the current folder.** Tool parsers and runs read and write relative to the current
  folder. Any test that parses a settings file or runs a tool must call `setUpJmpWorkingFolder` or
  `setUpMtpWorkingFolder` (or an equivalent), which moves the test into a temporary folder that is deleted
  afterwards. To run several cases in one test class, give each its own folder (`copyMtpFixtures`).
- **GCP's MEX copies.** GCP copies a `pointKinematics` MEX file into the current folder and MATLAB keeps it
  loaded, so the folder cannot be deleted until it is cleared. Add `clearGcpMexFiles` as a teardown after
  creating the folder (teardowns run in reverse order, so it runs before the folder is deleted).
- **`persistent` variables.** Some nmsm-core functions remember values between calls
  (`computeInnerOptimization`, `calculateFrameSquaredError`, `computeInverseKinematicsSquaredError`).
  Clear them in `TestMethodSetup`, or one test's leftovers change the next test's result.
- **`import org.opensim.modeling.*`.** It makes `Model(...)` refer to OpenSim's own class instead of
  nmsm-core's `Model.m` wrapper, which also initializes the model. Import only the classes you need.
- **The parallel pool and `opensim.log`.** JMP's, MTP's, MTLI's and GCP's optimizers use the parallel pool. Call
  `startQuietParallelPool()` in `TestClassSetup` before any test enters a temporary folder, or the
  workers keep `opensim.log` open there and the folder cannot be deleted. Scripts that work in a temporary
  folder without the pool should call `org.opensim.modeling.Logger.removeFileSink()` for the same reason.
- **Empty `commandWindowOutput.txt`.** Running a tool inside `evalc` (to keep the test report readable)
  stops its `diary` from capturing anything, so the copied log is empty. Check that it exists, not what
  it says.
- **`tic` inside the tools.** The tools call `tic`, which resets MATLAB's default timer. To time a run,
  use `t = tic; ...; toc(t)`.
- **An open `diary` after a crash.** NCP turns `diary` on and does not turn it off when it errors, so its
  log stays open and the folder cannot be deleted. Call `diary off` after catching a tool's error.
- **String or char settings file names.** Pass settings file names as strings (`"file.xml"`). Some
  helpers loop over their file name argument, and NCP's tool only works with strings (see the expected
  failures).
- **Errors count twice.** A test that errors (rather than failing a check) shows as both *Failed* and
  *Incomplete*, so `nnz([r.Incomplete])` is not a count of extra problems.
- **nmsm-core folders saved in `pathdef.m`.** If `savepath` was ever run with the project open, every
  MATLAB session starts with that checkout's `src` on the path. Tests could then call code from the wrong
  branch, and opening that project can fail. `runTests` takes other checkouts' folders off the path for
  the run and puts them back afterwards; plain `runtests` does not.
- **Thread-based parallel pools.** With a `Threads` default profile, `gcp` starts thread workers, which
  cannot hold OpenSim's Java objects or run `pctRunOnAll`. `startQuietParallelPool` always starts a
  `Processes` pool.
- **Silent skips.** A test file with a syntax error used to be skipped without warning. `runTests` now
  stops with an error instead. If you call `runtests` directly, check the run did not say
  "was excluded".

## Test data

Fixtures live in `data/<tool>/`, with a README explaining where each file came from and its known values.
Those values are in `helpers/<tool>FixtureValues.m` and checked by a fixture test:

| Tool | Values | Checked by |
|---|---|---|
| JMP | `helpers/jmpFixtureValues.m` | `unit/JointModelPersonalization/JmpFixtureTest.m` |
| MTP and MTLI | `helpers/mtpFixtureValues.m` | `unit/MuscleTendonPersonalization/MtpFixtureTest.m` and `MtpSyntheticDataTest.m` |
| NCP | `helpers/ncpFixtureValues.m` (shared values from `mtpFixtureValues`) | `unit/NeuralControlPersonalization/NcpFixtureTest.m` and `NcpSyntheticDataTest.m` |
| GCP | `helpers/gcpFixtureValues.m` | `unit/GroundContactPersonalization/GcpFixtureTest.m` and `GcpSyntheticDataTest.m` |

If you change a fixture on purpose, update the README, the values file and the test together. Fixture tests
read data files with `helpers/readStoFile.m`, not nmsm-core, so they do not depend on the code being tested.

### Known-truth data

A regression test is most useful when it checks a run against a known right answer. Real data has none, so
the suite makes some:

- **Generate the data from known values.** JMP's markers were generated from the "truth" model. MTP's
  synthetic data (`data/mtp/synthetic`) uses MTP's and MTLI's own forward models to compute the moments
  that true parameters would give. Keep the script that generates the data next to it
  (`generateMtpSyntheticData.m`), so it can be regenerated and reviewed.
- **The truth then depends on the forward model.** A bug in the model is built into the data. Unit-test the
  forward model against hand-worked values, so the two checks support each other.
- **Make sure the truth can be found.** Check that it is inside the optimizer's bounds and constraints
  (the synthetic MTP model had to be adjusted for this), and that the starting values are far enough from
  it that finding it means something (`MtpSyntheticDataTest`).
- **Make sure it is identifiable.** One gait trial with moment tracking alone does not determine all six MTP
  parameter types: they trade off, and MTP fits the moments with the wrong parameters (`all` case). Before
  writing a "recovers the truth" test, run the case and compare with the truth. If it is not identifiable,
  add information (a second trial, passive data) or test the fit instead, and say so in the test. GCP had
  the same problem with a different spring constant for each spring (springs that never touch the ground do
  not affect the cost); its synthetic cases use one spring constant for every spring instead.

Settings files for parsing tests are in `data/<tool>/settings/`:

- `settings_*.xml`: valid files.
- `bad_*.xml` and `edge_*.xml`: copies of `settings_minimal.xml` with **exactly one** change, described in
  the comment at the top. Keeping it to one change means a failure can only come from that change.

Settings files must use the `Version` of the nmsm-core branch they target (currently `1.5.4`). Find out which
elements a parser requires by trying it: remove one element at a time from a working file and see which
removals fail. That is how `data/mtp/settings/settings_minimal.xml` was made.

## Regression tests and nominal results

Each regression test checks a full run two ways:

1. **Against the truth**: is the answer still correct? Where there is no truth, as for the MTP tutorial
   problem, compare with a trusted reference instead (the tutorial's published fit) and check the result
   is within the tool's bounds.
2. **Against the nominal result** in `data/<tool>/nominal/`: did the answer change at all?

When a tool run is slow, run each case once in `TestClassSetup` and let every test read its results, as
`MuscleTendonPersonalizationRegressionTest` does. Running the tool inside each test, as the JMP test does,
is simpler but multiplies the run time by the number of checks. If a case can crash on some branch, catch
its error in the setup and fail only that case's tests with it, as
`NeuralControlPersonalizationRegressionTest` does; otherwise one crash makes every test in the class
incomplete.

When a nominal check fails:

- **If you did not mean to change the tool's results**, treat it as a bug and find the change that caused it.
- **If the change is intentional**:
  1. Make sure the truth check passes.
  2. Run `updateJmpNominal()`, `updateMtpNominal()`, `updateNcpNominal()` or `updateGcpNominal()`, after
     `addpath("tests/regression")` with the project open.
  3. Run `runTests("regression")` again.
  4. Commit the new nominal files on their own, with a message saying what changed and why.

Never update nominal results just to make a failing test pass.

## Testing different nmsm-core branches

`runTests` tests whatever branch `../nmsm-core` (or `CorePath`) has checked out, and prints that branch and
commit first. Check that line before trusting a result. To keep a second branch checked out next to your
working copy, use a git worktree (see the [root README](../README.md#running)).

A failure on another branch does not have to be a bug: the branch may be *meant* to behave differently. For
example, `matlab-gui-dev` renames MTP's cost terms and their functions, so tests that call the old names
error there. Decide which it is before changing either the test or the code.

## Tests that are expected to fail

These tests describe correct behavior and fail on purpose because they found real bugs that are not fixed
yet. When a bug is fixed, its test should pass. Remove it from this table then. "Also on `matlab-gui-dev`"
and "Fixed on `matlab-gui-dev`" record what that branch did as of October 2026.

| Test | Bug |
|---|---|
| `InverseKinematicsErrorTest/usesEveryFrameInMarkerFile` | JMP's IK skips the last marker frame. The loop in `computeInverseKinematicsSquaredError` stops on `time + 1/frequency > finishTime`, which floating-point rounding makes true one frame early (119 of 120 frames). |
| `JointModelPersonalizationParsingTest/allTasksDisabledIsReported` | With every `<JMPTask>` disabled, parsing fails with `Output argument "inputs" ... not assigned` instead of a clear message. |
| `MuscleModelTest/commonDelayShiftsEmgLater` | On `candidate-1.5.4`, a single shared electromechanical delay only works with one multi-muscle EMG spline per trial (the form synergy extrapolation builds), not the per-muscle splines from `makeEmgSplines` that the MTP parser builds. MTP on 1.5.4 always uses per-muscle delays, so it is not reached there; `matlab-gui-dev` fixes it in `calcEmgDataWithCommonTimeDelay`. |
| `MtpCostComputationsTest/groupsWithoutFirstMuscleCompareTheRightMuscles` | Muscle group indices are shifted down by (lowest grouped index − 1) before use, so when no group of a setting contains the first muscle, the grouped terms compare the wrong muscles (e.g. dropping `HamsNormalizedFiberLengthGroupR` from the tutorial shifts every fiber length group by two muscles). The same shift is in `calcDifferencesInEmgGroups`, `calcNormalizedFiberLengthGroupedSimilarityCost`, `calcSynergyExtrapolationMuscleActivationCost` and SynX's `updateEmgSignals`. Also on `matlab-gui-dev`. |
| `MtpCostTermsTest/maximumFiberLengthPenaltyStartsAtTheLimit`, `MtpCostTermsTest/minimumFiberLengthPenaltyStartsAtTheLimit` | The MTP min/max normalized fiber length terms penalize the whole length of a muscle past its limit, not the amount past it, so the cost jumps from 0 to about 450 (max, 1.05 → 1.06) or 140 (min, 0.6 → 0.59) when the limit is crossed. Also on `matlab-gui-dev`. |
| `MuscleTendonPersonalizationParsingTest/allTasksDisabledIsReported` | Same as JMP: with every `<MTPTask>` disabled, parsing fails with `Output argument "output" ... not assigned`. Also on `matlab-gui-dev`. |
| `MuscleTendonPersonalizationParsingTest/missingResultsDirectoryIsReported` | Without `<results_directory>`, parsing fails with "Dot indexing is not supported for variables of this type." instead of naming the element. Also on `matlab-gui-dev`. |
| `MuscleTendonPersonalizationParsingTest/unknownCoordinateIsReported` | A misspelled coordinate in `<coordinate_list>` fails deep in EMG parsing ("Unable to perform assignment because the size of the left side is 0-by-139 ...") instead of naming the coordinate. Also on `matlab-gui-dev`. |
| `MuscleTendonPersonalizationParsingTest/emgChannelMissingFromDataIsReported` | A `<collected_emg_channel_muscle_groups>` entry that is not a column of the EMG files fails with "Index in position 1 exceeds array bounds" instead of naming the channel. Also on `matlab-gui-dev`. |
| `MtliCostTermsTest/passiveMomentTrackingWorksForAnyTrialLength` | `calcPassiveMomentTrackingCost` assumes every passive trial has exactly 101 frames (`repmat(..., 1, 1, 101)`); any other length crashes with "The logical indices contain a true value outside of the array bounds". Also on `matlab-gui-dev`. |
| `NeuralControlPersonalizationParsingTest/missingResultsDirectoryIsReported` | Same as MTP: without `<results_directory>`, parsing fails with "Dot indexing is not supported for variables of this type." Also on `matlab-gui-dev`. |
| `NeuralControlPersonalizationRegressionTest/iliacusHiddenPredictsIliacus`, `mtliRunCompletesAndFits`, `writesExpectedResultFiles(run=iliacusHidden)`, `writesExpectedResultFiles(run=mtli)` | **NCP crashes whenever a muscle has no MTP activations**, which is the case NCP exists for: `stackMtpActivations` in `prepareNcpInitialValues` reshapes the MTP activations as if every modeled muscle had them ("Number of elements must not change"). The tutorial only runs because all nine of its muscles have MTP results. This also means MTLI inside NCP, which only updates muscles without MTP results, can never do anything useful. Also on `matlab-gui-dev`. The tolerances in these tests are provisional until a run completes. |
| `NeuralControlPersonalizationRegressionTest/acceptsCharacterSettingsFileName` | `NeuralControlPersonalizationTool('file.xml')` (single quotes) crashes with "Arrays have incompatible sizes": the copied settings file name is built with `fname + fext`, which adds the character codes of two char arrays. Only double-quoted (string) names work. Also on `matlab-gui-dev`. |
| `MtliCostTermsTest/unknownTermIsReported` | An unknown MTLI cost term type gives MATLAB's "Too many output arguments." instead of the intended message, because the message uses `type` (MATLAB's built-in function) instead of `costTerm.type`. Fixed on `matlab-gui-dev`. |
| `GcpCostTermsTest/mergedResultFollowsDesignVariableOrder` | `mergeGroundContactPersonalizationRoundResults` does not advance its index after reading the resting spring length, so every later design variable is read one position early: the first kinematic B-spline coefficient becomes the resting length, and so on. Any task that optimizes the resting length together with later variables (the tutorial's task 1 does) saves shifted results. GCP-DEV-STATUS |
| `GroundContactPersonalizationParsingTest/noEnabledSurfaceIsReported` | With no enabled `<GCPContactSurface>`, parsing fails with `Output argument "output" ... not assigned` instead of a clear message. GCP-DEV-STATUS |
| `GroundContactPersonalizationParsingTest/misspelledForceColumnIsReported` | A misspelled force, moment or electrical center column parses without error and gives NaN ground reactions: the check `any([isnan(grf) isnan(moments) isnan(ec)])` applies `any` to a matrix, so it only fails if every column has a NaN. (A misspelled name of a different length fails instead with "Dimensions of arrays being concatenated are not consistent", because the names are stored as a char matrix.) GCP-DEV-STATUS |
| `GroundContactPersonalizationParsingTest/missingResultsDirectoryIsReported` | Same as MTP and NCP: without `<results_directory>`, parsing fails with "Dot indexing is not supported for variables of this type." GCP-DEV-STATUS |
| `GroundContactPersonalizationRegressionTest/rotationFindsForcePlateAngle` | **The force plate rotation design variable does nothing.** The cost rotates the ground reactions by the surface's stored rotation (`inputs.surfaces{foot}.forcePlateRotation`, 0 during the task), not by the value being optimized, so the cost never changes with it and GCP reports 0 degrees. GCP-DEV-STATUS |
| `GroundContactPersonalizationRegressionTest/neighborTermWorksWithoutMomentTerms`, `writesExpectedResultFiles(run=neighbor)` | The `neighbor_spring_constant` cost term needs the springs' x and z positions, which `calcGCPModeledValues` only fills in when a moment cost term is enabled. Without one, GCP crashes with "Unrecognized field name "xPosition"". GCP-DEV-STATUS |

## Settings that are deliberately not tested

Some settings exist in the code but are not ones the NMSM Pipeline advertises or uses. Testing them would
lock in behavior nobody relies on, so the suite leaves them out until they are wanted.

| Tool | Settings |
|---|---|
| JMP | `<free_markers>`, `<anatomical_markers>` (the unit tests pass `false`, the parser's value when the element is absent) |

The same goes for code nothing calls. On candidate-1.5.4 these NCP functions are never called, or only by each
other and by `reportNeuralControlPersonalizationResults`, which nothing calls either: `calcNcpModeledValues`,
`calcNcpMuscleJointMoments`, `normalizeSynergyVariables`, `unpackSynergyVariables`, `unpackDesignVariables`,
`findSynergyWeightsByGroup`, `calcMuscleTendonForce`, `calcActivationTrackingCost`,
`prepareNonNegativeMatrixFactorizationInitialValues`.

Suspected problems not tested yet:

- **GCP's saved ground reactions use the last task's cost terms.** The saving functions evaluate the model with
  `length(params.tasks)` as the task, and the model computes horizontal forces and moments only when that task
  has a cost term that needs them. A run whose last task tracks only vertical force may save zero horizontal
  forces and moments.

## Open questions

Behavior the tests record as it is, because whether it is intended is not clear:

| Test | Question |
|---|---|
| `NcpCostTest/groupedFiberLengthsGroupActivationsByFiberLengthGroup` | NCP's `grouped_fiber_lengths` cost term compares **activations**, grouped by the normalized fiber length muscle groups, not fiber lengths. NCP's fiber lengths do not change during its optimization, so a cost on the lengths themselves would be constant. Is "activation similarity within fiber length groups" the intent? If so, the name is misleading; if not, the term does nothing useful. Unchanged on `matlab-gui-dev`. |
| `GroundContactPersonalizationRegressionTest/matchesNominalResult(nominalRun=tutorial)` | GCP's resting spring length initialization (`initializeRestingSpringLength`) uses a different vertical force formula from the one GCP optimizes with (`calcModeledVerticalGroundReactionForce`): smoothing constant 5e-4 instead of 1e-3, damping as (1 + d·v) instead of (1 − d·v), and no 0.7·tanh limit on the spring height. Is the initialization meant to use a simpler model, or should the two match? The tutorial run uses the initialization, so its nominal records the current behavior. |
