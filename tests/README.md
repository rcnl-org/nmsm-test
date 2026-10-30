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
runTests("all", Tool="GCP")            % one tool, every tier
runTests("all")
```

`Tool` finds a tool's tests by name: everything under `unit/<ToolName>/` (e.g.
`unit/GroundContactPersonalization/`) and the parsing and regression classes whose names start with
`<ToolName>`. Put new tests there, or `Tool` will not find them; tests of shared code go in `unit/core/`
(`Tool="core"`). Tests shared by the three Treatment Optimization tools go in `unit/TreatmentOptimization/` and
classes named `TreatmentOptimization*`; `Tool="TO"` runs them with all three tools' tests.

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
- **GPOPS-II is needed before Treatment Optimization solves anything.** `makeTreatmentOptimizationInputs`
  calls `gpops2` for the collocation times, so preparing inputs needs a licensed GPOPS-II (installed
  separately from nmsm-core). GPOPS-dependent test classes assume `gpopsIsLicensed()` in `TestClassSetup`
  and are reported as not run without it.
- **Treatment Optimization's caches.** Several functions keep `persistent` variables and globals between
  calls (see `helpers/clearToCaches.m`), and its MEX functions keep the model loaded. Call `clearToCaches`
  between problems and before deleting a working folder.
- **Term structs need a `type`.** Many term helpers build their error messages from `term.type` even when
  nothing is wrong, and parsed term fields are char, not string. Build hand-made terms the same way.
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
| Treatment Optimization | `helpers/toFixtureValues.m` | `unit/TreatmentOptimization/TreatmentOptimizationFixtureTest.m` |

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
- **When the optimizer itself is not reproducible, test what is.** IPOPT, which Treatment Optimization's
  GPOPS-II uses, gives different solutions on different computers, so its full runs have no truth or nominal
  solution. They are checked only for what any converged run must satisfy (it completes, stays within its
  bounds, meets its constraints, writes its files), and everything before the solve, which is
  deterministic, is compared with nominal results (`TreatmentOptimizationSetupRegressionTest`).

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
  2. Run `updateJmpNominal()`, `updateMtpNominal()`, `updateNcpNominal()`, `updateGcpNominal()` or
     `updateToNominal()`, after
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

### MTP results on `matlab-gui-dev`

On `matlab-gui-dev` (commit `6e7fc4e7`), `saveMtpMuscleModelParameters` writes the activation time constants and
electromechanical delays to `muscleModelParameters.sto` in MTP's internal units (100 and 10 times seconds)
instead of seconds, so `MuscleTendonPersonalizationRegressionTest` finds them 100 and 10 times too large. It
came in with the candidate merges into dev, and `plotMtpHillTypeMuscleParams` now divides the delay by 10
itself; whether the file's units were meant to change is for the developers to decide.

### Treatment Optimization on `matlab-gui-dev`

Treatment Optimization changed a great deal on `matlab-gui-dev` (muscle and user-defined controllers, CasADi,
jerk and filtered controls, new terms, pipeline version 1.6.0). The candidate tests were run there on
2026-10-22 (commit `6e7fc4e7`): 119 of 230 pass, and the 111 failures sort into these groups.

**All 42 regression tests pass.** The candidate settings files still run there (with a version warning), and
the setup of every case matches candidate's nominal results.

**Expected on dev (the interface changed on purpose), about 100 failures:**

- `generateCostTermStruct(type, tool)` and `generateConstraintTermStruct(type, "torque", tool)` now take a
  logical `controllerTypes` vector ([torque synergy muscle user]) and return more outputs:
  `ToTermRegistryTest`, `DoCostTermsTest` (in its setup), and `ToCostTermsTest`'s `makeMaxAllowableError` tests.
- `inputs.controllerType` became `inputs.controllerTypes`, and hand-built inputs need new fields (`useJerk`,
  `numIndividualMuscles`, `numUserDefinedControls`, `collocationTimeOriginalWithEnd`, ...):
  `ToDesignVariablesTest`, `ToSynergyModelTest`, `ToConstraintTermsTest`, `ToScalingAndDynamicsTest`,
  `ToCostTermsTest`.
- The parser no longer sets `controllerType` or `loadSurrogate` (the surrogate model always loads from
  `<surrogate_model_file_name>` if it exists): `TrackingOptimizationParsingTest`, `DesignOptimizationParsingTest`.
- `updateSystemFromUserDefinedFunctions` reads `inputs.systemFns` instead of `inputs.auxdata.systemFns`:
  `DoModelFunctionsTest`.

**Worse on dev:** without `<results_directory>`, parsing now crashes in `getUniqueResultsDirectory`, which
fails `TreatmentOptimizationParsingTest` in its setup (its minimal file leaves the element out). See the
expected-failure table.

**Unchanged:** every Treatment Optimization bug in the expected-failure table is still in the dev code.

**Tests to add for dev** (once the dev interface is settled):

- Rewrite the registry, design variable and term unit tests for `controllerTypes` and the new inputs fields,
  keeping the same hand-worked values.
- Muscle controller (`<RCNLMuscleController>`): `muscle_list`, combined synergy and individual activations,
  the order of `setupMuscleActivations`' initial controls (it uses `intersect` without `'stable'`).
- User-defined controller (`<RCNLUserDefinedController>`): labels, bounds, initial values (file,
  `initial_control_file`, values), controller terms, `_userDefinedControls.sto`.
- CasADi (`<CasadiSettings>`): parsing and defaults, `calcCasadiCollocationPointTimes`,
  `integrateRadauQuadrature`, `calcCasadiDynamicConstraint`; the same terms evaluated symbolically and
  numerically; the regression problems solved with CasADi (which needs no GPOPS-II license).
- New terms: body angular velocity terms, controller and acceleration terminal terms,
  `controller_load_tracking`, `muscle_activation_shape_tracking`, and `limit_muscle_activation` (allowed
  but with no calculation).
- Jerk controls, the first-order control filter, activation saturation, per-coordinate range lists,
  `<surrogate_model_file_name>`, unique results directories.
- Likely dev bugs found by reading the code, each worth a test: `calcRootSegmentResidualsPeriodicity` asserts
  on an undefined `useJerk`; `calcSynergyBasedModeledValues` calls `calcBhargavaMetabolicCost` with 6 of its 8
  arguments; the OpenSim 4.6 branch of `inverseDynamics` never sets its body angular velocities;
  `generalized_speed_minimization` was dropped from the allowed cost terms; `saveDesignOptimizationResults`
  saves the model before the model functions changed it; CasADi's `convertFromCasadiOutputs` reads
  `solution.parameter` instead of `solution.phase.parameter`.
- The reference XML documents `use_control_derivatives` and `use_jerk`, but the code reads
  `use_first_order_control_dynamics_filter` and `use_jerk_controls`.

## Term smoke tests

`MtpTermSmokeTest`, `MtliTermSmokeTest`, `NcpTermSmokeTest`, `GcpTermSmokeTest` (unit tier) and
`TreatmentOptimizationTermSmokeTest` (regression tier, needs GPOPS-II) run **every cost and constraint term
each tool has**, one at a time, on a real problem, and check only that it runs and gives finite values of the
right size. They catch a term that crashes as soon as it is enabled, which tests with hand-worked values only
catch for the terms they happen to cover. Correct values remain the job of the unit tests.

- **The term lists come from the code.** MTP, MTLI, NCP and GCP read the `case` labels of their cost function's
  `switch` (`costTermTypes`); Treatment Optimization asks its registries. A new term is tested automatically,
  and needs fixture data only if it reads something the fixtures lack.
- **Real inputs without optimizing.** The tool's own steps run on a fixture settings file, with its optimizer
  replaced by a stand-in that records its arguments and returns the starting values (`stubOptimizer`,
  `optimizerCalls`). The objective is then called with one term at a time. For GCP the stand-in is
  `lsqnonlin`, and the cost function's fixed arguments come from the recorded handle (`functions(f).workspace`).
- **Treatment Optimization prepares the terms disabled.** Preparing evaluates every enabled term, so one broken
  term would stop a whole case; the tutorial's own terms stay enabled (preparing needs at least one), and the
  test sets the angular momentum and metabolic flags an enabled term would set.
- **Not run, on purpose.** Treatment Optimization terms that need contact surfaces (external forces and moments,
  center of pressure, braking and propulsive impulse; 94 tests) report "needs contact surfaces" and count as
  *incomplete*, not failed: the kick fixtures have no GCP contact surfaces or ground reaction data. Muscle terms
  run in the synergy cases only.
- **Time:** the four unit-tier classes take a few seconds each; `TreatmentOptimizationTermSmokeTest` about 65 s.

## Tests that are expected to fail

These tests describe correct behavior and fail on purpose because they found real bugs that are not fixed
yet. When a bug is fixed, its test should pass. Remove it from this table then. "Also on `matlab-gui-dev`"
and "Fixed on `matlab-gui-dev`" record what that branch did as of October 2026.

| Test | Bug |
|---|---|
| `MuscleModelTest/commonDelayShiftsEmgLater` | On `candidate-1.5.4`, a single shared electromechanical delay only works with one multi-muscle EMG spline per trial (the form synergy extrapolation builds), not the per-muscle splines from `makeEmgSplines` that the MTP parser builds. MTP on 1.5.4 always uses per-muscle delays, so it is not reached there; `matlab-gui-dev` fixes it in `calcEmgDataWithCommonTimeDelay`. |
| `MtpCostComputationsTest/groupsWithoutFirstMuscleCompareTheRightMuscles` | Muscle group indices are shifted down by (lowest grouped index − 1) before use, so when no group of a setting contains the first muscle, the grouped terms compare the wrong muscles (e.g. dropping `HamsNormalizedFiberLengthGroupR` from the tutorial shifts every fiber length group by two muscles). The same shift is in `calcDifferencesInEmgGroups`, `calcNormalizedFiberLengthGroupedSimilarityCost`, `calcSynergyExtrapolationMuscleActivationCost` and SynX's `updateEmgSignals`. Also on `matlab-gui-dev`. |
| `MtpCostTermsTest/maximumFiberLengthPenaltyStartsAtTheLimit`, `MtpCostTermsTest/minimumFiberLengthPenaltyStartsAtTheLimit` | The MTP min/max normalized fiber length terms penalize the whole length of a muscle past its limit, not the amount past it, so the cost jumps from 0 to about 450 (max, 1.05 → 1.06) or 140 (min, 0.6 → 0.59) when the limit is crossed. Also on `matlab-gui-dev`. |
| `MtliCostTermsTest/passiveMomentTrackingWorksForAnyTrialLength` | `calcPassiveMomentTrackingCost` assumes every passive trial has exactly 101 frames (`repmat(..., 1, 1, 101)`); any other length crashes with "The logical indices contain a true value outside of the array bounds". Also on `matlab-gui-dev`. |
| `NeuralControlPersonalizationRegressionTest/iliacusHiddenPredictsIliacus`, `mtliRunCompletesAndFits`, `writesExpectedResultFiles(run=iliacusHidden)`, `writesExpectedResultFiles(run=mtli)` | **NCP crashes whenever a muscle has no MTP activations**, which is the case NCP exists for: `stackMtpActivations` in `prepareNcpInitialValues` reshapes the MTP activations as if every modeled muscle had them ("Number of elements must not change"). The tutorial only runs because all nine of its muscles have MTP results. This also means MTLI inside NCP, which only updates muscles without MTP results, can never do anything useful. Also on `matlab-gui-dev`. The tolerances in these tests are provisional until a run completes. |
| `DesignOptimizationMetabolicRegressionTest/higherGoalRaisesTheMetabolicCost(goal=absolute)` | Absolute metabolic goals read GPOPS-II's metabolic integral in scaled time, so they see a value 1 / (maxTime − minTime) times too large and push the cost down for any target (B30 in `docs/failures.md`). |

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
- **Tracking Optimization's torque `controller_tracking` tracks zero.** `TrackingOptimizationTool` never calls
  `setupTorqueControls` (Verification and Design do), so there are no torque control splines and
  `findSplinedControlsByLabels` returns zeros: the term acts as `controller_minimization`. Only reachable
  through GPOPS-II's preparation, which builds the splined controls.
- **Design Optimization's parameter file is offset when synergy weights are also optimized.**
  `printUserDefinedVariablesToXml` (local to `saveDesignOptimizationResults`) reads user-defined parameters
  from the start of the parameter vector, but the synergy weights come first.
- **`<MocoSettings>` cannot work:** `parseOptimalControlSolverSettings` calls `parseMocoSolverSettings`,
  which does not exist, and `solveOptimalControlProblem` always calls GPOPS-II.
- **Saved tracked data uses the solution's times.** `saveTreatmentOptimizationResults` writes the tracked
  positions against the solution's time column; with a free final time (Design) they are labeled with the
  wrong times.
- **Treatment Optimization is effectively Windows-only**: off Windows, `inverseDynamics` never assigns its body
  orientation output, and the `calculate*` flags are only set for `mexw64`.
- **Harmless as far as the tests can tell:** the `x = index` overwrite in four `find*DataByLabels` helpers (the
  parser splits lists, so they only see one label), the dead `synergy_weight_sum` branch in
  `makeTerminalConstraintBounds`, and the `||` in `makeMaxAllowableError`'s last branch (always true there,
  which is what it needs).

## Open questions

Behavior the tests record as it is, because whether it is intended is not clear:

| Test | Question |
|---|---|
| `NcpCostTest/groupedFiberLengthsGroupActivationsByFiberLengthGroup` | NCP's `grouped_fiber_lengths` cost term compares **activations**, grouped by the normalized fiber length muscle groups, not fiber lengths. NCP's fiber lengths do not change during its optimization, so a cost on the lengths themselves would be constant. Is "activation similarity within fiber length groups" the intent? If so, the name is misleading; if not, the term does nothing useful. Unchanged on `matlab-gui-dev`. |
| `GroundContactPersonalizationRegressionTest/matchesNominalResult(nominalRun=tutorial)` | GCP's resting spring length initialization (`initializeRestingSpringLength`) uses a different vertical force formula from the one GCP optimizes with (`calcModeledVerticalGroundReactionForce`): smoothing constant 5e-4 instead of 1e-3, damping as (1 + d·v) instead of (1 − d·v), and no 0.7·tanh limit on the spring height. Is the initialization meant to use a simpler model, or should the two match? The tutorial run uses the initialization, so its nominal records the current behavior. |
