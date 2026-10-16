# Writing and maintaining tests

This guide is for anyone adding to or changing the test suite. For how to *run* the suite, see the
[root README](../README.md).

## The three tiers

| Tier | Tag | Folder | What it checks | Time | Run it |
|---|---|---|---|---|---|
| Unit | `Unit` | `unit/` | One function at a time, against values worked out by hand | seconds | while coding |
| Parsing | `Parsing` | `parsing/` | Settings XML → the `inputs`/`params` structs a tool builds | seconds | before every commit/PR |
| Regression | `Regression` | `regression/` | Full tool runs, compared with the truth and with stored nominal results | minutes | before merging, and when testing a new nmsm-core branch |

Most tests should be unit tests. A bug that a unit test can catch should not depend on a 2-minute
regression run to find it.

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
   `unit/JointModelPersonalization/`.
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

Write down in the test why a tolerance has the value it has.

### Things that have bitten us

- **Files written to the current folder.** Tool parsers and runs read and write relative to the current
  folder. Any test that parses a settings file or runs a tool must call `setUpJmpWorkingFolder` (or an
  equivalent), which moves the test into a temporary folder that is deleted afterwards.
- **`persistent` variables.** Some nmsm-core functions remember values between calls
  (`computeInnerOptimization`, `calculateFrameSquaredError`, `computeInverseKinematicsSquaredError`).
  Clear them in `TestMethodSetup`, or one test's leftovers change the next test's result.
- **`import org.opensim.modeling.*`.** It makes `Model(...)` refer to OpenSim's own class instead of
  nmsm-core's `Model.m` wrapper, which also initializes the model. Import only the classes you need.
- **The parallel pool and `opensim.log`.** JMP's optimizer uses the parallel pool. Call
  `startQuietParallelPool()` in `TestClassSetup` before any test enters a temporary folder, or the
  workers keep `opensim.log` open there and the folder cannot be deleted.
- **Silent skips.** A test file with a syntax error used to be skipped without warning. `runTests` now
  stops with an error instead. If you call `runtests` directly, check the run did not say
  "was excluded".

## Test data

Fixtures live in `data/<tool>/`, with a README explaining where each file came from and its known values.
For JMP, those values are in `helpers/jmpFixtureValues.m` and checked by
`unit/JointModelPersonalization/JmpFixtureTest.m`. If you change a fixture on purpose, update all three.

Settings files for parsing tests are in `data/<tool>/settings/`:

- `settings_*.xml`: valid files.
- `bad_*.xml` and `edge_*.xml`: copies of `settings_minimal.xml` with **exactly one** change, described in
  the comment at the top. Keeping it to one change means a failure can only come from that change.

Settings files must use the `Version` of the nmsm-core branch they target (currently `1.5.4`).

## Regression tests and nominal results

Each regression test checks a full run two ways:

1. **Against the truth**: is the answer still correct?
2. **Against the nominal result** in `data/<tool>/nominal/`: did the answer change at all?

When a nominal check fails:

- **If you did not mean to change the tool's results**, treat it as a bug and find the change that caused it.
- **If the change is intentional**:
  1. Make sure the truth check passes.
  2. Run `updateJmpNominal()`, after `addpath("tests/regression")` with the project open.
  3. Run `runTests("regression")` again.
  4. Commit the new nominal files on their own, with a message saying what changed and why.

Never update nominal results just to make a failing test pass.

## Testing different nmsm-core branches

`runTests` tests whatever branch `../nmsm-core` has checked out, and prints that branch and commit first.
Check that line before trusting a result. A failure on another branch does not have to be a bug: the
branch may be *meant* to behave differently. For example, it may have a different pipeline version, so the
settings files are rejected. Decide which it is before changing either the test or the code.

## Tests that are expected to fail

These tests describe correct behavior and fail on purpose because they found real bugs that are not fixed
yet. When a bug is fixed, its test should pass. Remove it from this table then.

| Test | Bug |
|---|---|
| `InverseKinematicsErrorTest/usesEveryFrameInMarkerFile` | JMP's IK skips the last marker frame. The loop in `computeInverseKinematicsSquaredError` stops on `time + 1/frequency > finishTime`, which floating-point rounding makes true one frame early (119 of 120 frames). |
| `JointModelPersonalizationParsingTest/allTasksDisabledIsReported` | With every `<JMPTask>` disabled, parsing fails with `Output argument "inputs" ... not assigned` instead of a clear message. |
| `JointModelPersonalizationParsingTest/freeMarkersWorkWithoutBodySet` | `<free_markers>` without a `<JMPBodySet>` fails with `Unrecognized field name "JMPBodySet"`. |
