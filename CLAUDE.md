# CLAUDE.md — working on the NMSM Pipeline test suite

Context for AI agents (and people) working in this repository. Read it before running, writing or changing
tests. Facts that change over time are dated; check them against the code, the docs and a test run before
relying on them.

## What this repository is

`nmsm-test` (GitHub `rcnl-org/nmsm-test`) is the automated test suite for the **NMSM Pipeline**, a MATLAB
toolkit (repository `nmsm-core`, GitHub `rcnl-org/nmsm-core`) for personalizing and optimizing OpenSim
musculoskeletal models. The suite lives in its own repository so that the **same tests can run against any
nmsm-core branch**: check out a branch of nmsm-core, run the suite against it, and compare.

It covers every tool in the pipeline:

| Abbreviation | Tool | nmsm-core folder |
|---|---|---|
| JMP | Joint Model Personalization | `src/JointModelPersonalization` |
| MTP | Muscle-Tendon Personalization (with synergy extrapolation, SynX) | `src/MuscleTendonPersonalization` |
| MTLI | Muscle-Tendon Length Initialization | `src/MuscleTendonLengthInitialization` |
| NCP | Neural Control Personalization | `src/NeuralControlPersonalization` |
| GCP | Ground Contact Personalization | `src/GroundContactPersonalization` |
| TO | Treatment Optimization: Tracking, Verification and Design Optimization | `src/TreatmentOptimization` |
| core | shared code (muscle model, parsing helpers, synergies, B-splines) | `src/core` |

**Read these, in this order, when you need detail:**

| File | What it is |
|---|---|
| `README.md` | How to run the suite, what it covers, run times. |
| `tests/README.md` | **The contributor guide**: tiers, how to add a test, checks and tolerances, the "things that have bitten us" list, test data, regression and nominal results, branches, smoke tests, the expected-failure table, deliberately untested settings, open questions. |
| `docs/test-catalog.md` | Every test class and test, with a one-line description. |
| `docs/failures.md` | Every failure found (bugs B1–B30 and the `matlab-gui-dev` diagnostic), why, whether intended, and how to fix it. |
| `docs/candidateFailures.md` | The bugs **still open**, and which bug-fix branch fixed the others. |
| `tests/data/<tool>/README.md` | Where each fixture came from, its known values, and how generated data was made. |

## The nmsm-core branches the tests are for

- **The tests are written for `candidate-1.5.4`** (pipeline version 1.5.4). That branch is the reference: on it,
  every test passes except the documented expected failures. Settings files in `tests/data` use
  `Version="1.5.4"`.
- **`matlab-gui-dev` is a diagnostic target, not a reference.** Its interfaces changed on purpose (for example
  Treatment Optimization's `controllerType` became `controllerTypes`; MTP and MTLI cost terms were renamed), so
  many tests fail there by design. `docs/failures.md` (Part 2) sorts those failures into intended changes,
  possible regressions, and bugs still present. **Do not change a test just to make `matlab-gui-dev` (or any
  branch) pass.** If a test should change because the code changed on purpose, say so explicitly and keep
  the test describing correct behavior.
- **Bug-fix branches** (as of 2026-11-17): `gcp-bug-fixes`, `treatment-optimization-bug-fixes` and
  `mtp-bug-fixes`, built on `candidate-1.5.4` and not yet merged into it or into each other, so each still
  fails the others' tests. `docs/candidateFailures.md` lists which bugs each fixes.
- Other branches exist (`dev`, `jerk-controls-candidate`, ...). A failure on another branch is not
  automatically a bug: decide whether the branch is meant to behave differently before touching code or
  test.

`runTests` prints the nmsm-core path, branch and commit it tested as its first line. **Check that line before
trusting any result.**

## Environment and prerequisites

- **MATLAB** R2025a (the version the suite was built and timed on), with the Parallel Computing Toolbox (JMP,
  MTP, MTLI and GCP optimize in parallel) and the Optimization Toolbox.
- **OpenSim 4.5** MATLAB scripting set up (`org.opensim.modeling.*` must work).
- **An nmsm-core checkout** next to this repository: `GitHub/nmsm-core` and `GitHub/nmsm-test`. Other checkouts
  are passed with `CorePath=`. The checkout's folder name must contain `nmsm-core`: GCP finds its MEX files by
  looking for that string in its own path (an open question in `docs/candidateFailures.md`).
- **GPOPS-II**, installed and licensed separately from nmsm-core, **only for Treatment Optimization**: it is
  needed even to prepare a problem (`makeTreatmentOptimizationInputs` calls `gpops2` for the collocation
  times). TO test classes that need it check `gpopsIsLicensed()` in `TestClassSetup`; without a license they are
  reported as *not run* (incomplete), not failed. Everything else runs without GPOPS-II.
- **Windows**: Treatment Optimization is effectively Windows-only on candidate (MEX functions and the
  `calculate*` flags are set only for `mexw64`), and the suite has only been run on Windows.

### Several nmsm-core branches side by side: git worktrees

Keep each branch you test in its own folder, named after the branch it stays on, instead of switching your main
checkout:

```
git -C nmsm-core worktree add ../nmsm-core-candidate-1.5.4 candidate-1.5.4
```
```matlab
runTests("all", CorePath="../nmsm-core-candidate-1.5.4")
```

Git lets a branch be checked out in only one folder. If a worktree is switched to another branch (say `main`),
`git switch main` in the main checkout fails. Keep each worktree on its branch.

## Running the tests

From MATLAB, in the `nmsm-test` folder:

```matlab
runTests()                                   % unit tier (the default)
runTests("parsing")                          % one tier: "unit", "parsing", "regression" or "all"
runTests("all", Tool="GCP")                  % one tool, every tier
runTests("regression", Tool=["MTP", "NCP"])  % several tools
runTests("all", CorePath="../nmsm-core-candidate-1.5.4")
runTests("unit", Coverage=true)              % HTML coverage report in tempdir
```

`Tool` is any of `JMP`, `MTP`, `MTLI`, `NCP`, `GCP`, `Tracking`, `Verification`, `Design`, `TO` (shared TO tests
plus all three TO tools) and `core`, in any case. It selects everything under `tests/unit/<FullToolName>/` plus the
parsing and regression classes whose names start with `<FullToolName>` (see `toolTable` in `runTests.m`).

What `runTests` does for you, which plain `runtests` does not:
- removes other nmsm-core checkouts' folders from the path for the run (a `savepath` with the project open puts
  one checkout's `src` in `pathdef.m`; then tests call code from the wrong branch, and `openProject` can hang),
  and restores them afterwards;
- opens the nmsm-core project (`openProject`) if it is not already the open one;
- adds `tests/helpers`, silences OpenSim's info/warning log, and restores everything afterwards;
- stops with an error on a test file that cannot be loaded (a syntax error otherwise skips it silently).

Approximate times (2026-10-26, one computer; the suite has grown since): unit about 80 s, parsing about 90 s,
regression about 17 minutes, of which about 1 minute is starting the parallel pool, 6 minutes GCP and 6 minutes
Treatment Optimization.

### Running one file or one test

Open the project first (running `runTests` once leaves it open), then from the `nmsm-test` folder:

```matlab
addpath("tests/helpers")
runtests("tests/unit/core/OrderByIndexTest.m")
runtests("tests/unit/core/OrderByIndexTest.m", "ProcedureName", "missingIndexThrows")
```

### Running headless (agents, scripts, CI)

```
matlab -batch "r = runTests('unit', CorePath='../nmsm-core-candidate-1.5.4'); disp(table(r))"
```

- From PowerShell, quote MATLAB strings inside `-batch "..."` with **single quotes**; nested double quotes get
  mangled. For anything non-trivial, write a small `.m` script in a scratch folder (not in this repository),
  `addpath` it, and call it from `-batch`.
- **Getting the reason for a failure.** `runTests` prints diagnostics to the command window but does not store
  them in the results, and errors in `TestClassSetup` appear only in that text. To get them programmatically, run
  the suite yourself with a `matlab.unittest.TestRunner.withNoPlugins` runner plus
  `matlab.unittest.plugins.DiagnosticsRecordingPlugin`, then read `r(i).Details.DiagnosticRecord.Report`.
  (Before calling `openProject` yourself, remove stale nmsm-core folders from the path as `runTests` does, or it
  can hang.)
- **Tools hijack `diary`.** MTP, NCP, GCP and TO turn `diary` on for their own log, which ends any diary you
  started. Capture output with `evalc` or by redirecting the process output instead.
- **Counting results:** a test that errors counts as both *Failed* and *Incomplete*. A test whose assumption
  failed (for example no GPOPS-II) is *Incomplete* only.
- **The license banner and startup errors** print on every MATLAB start (GPOPS-II license info, possibly a
  user `startup.m` error). They are not test output.
- **Long runs:** the full regression tier takes 15–20 minutes. Run it in the background and wait for it to
  finish; do not poll or start a second MATLAB that competes for the parallel pool.
- If a headless MATLAB process sits for many minutes with almost no CPU time, it is probably hung (often
  `openProject` with a stale path); stop only processes you started.

## Repository layout

```
runTests.m                 entry point (tiers, Tool selection, CorePath, Coverage)
tests/unit/<Folder>/       unit tests, by nmsm-core folder; cost terms in <Folder>/CostTerms/
tests/unit/core/           tests of shared src/core code
tests/unit/TreatmentOptimization/   tests shared by the three TO tools
tests/unit/DesignOptimization/      Design-only unit tests
tests/parsing/             <ToolName>ParsingTest.m
tests/regression/          <ToolName>RegressionTest.m, update<Tool>Nominal.m
tests/helpers/             shared helpers (fixtures, working folders, readers, stubs)
tests/data/<tool>/         fixtures: models, data, settings/, nominal/, synthetic/, README.md
docs/                      test-catalog.md, failures.md, candidateFailures.md
legacy/                    the original 2023 tests, kept for reference; never run
```

`tests/data` folders: `jmp`, `mtp` (also MTLI's data), `ncp`, `gcp`, `to`.

## How the suite is built

### Three tiers

| Tier | Tag | Checks | Typical tools used |
|---|---|---|---|
| Unit | `Unit` | One function, against values worked out by hand | hand-built structs; small fixture files |
| Parsing | `Parsing` | A settings XML file → the `inputs`/`params` structs a tool builds, exactly as the tool calls its parser | `tests/data/<tool>/settings/` |
| Regression | `Regression` | Full tool runs, against a known truth and against stored nominal results | synthetic known-truth data, tutorial problems |

Every class needs `TestTags = {'Unit'}`, `{'Parsing'}` or `{'Regression'}`, or the tier commands skip it.

### Principles to keep

1. **Expected values are worked out independently**: by hand, from a known physical fact, or from the fixture
   files read with the suite's own readers (`readStoFile`, not nmsm-core). Never run the code and paste its
   output in as the expected value. The one exception is nominal results, which are always paired with a
   check against a truth.
2. **Tests describe correct behavior.** When a test finds a bug, the test stays as it is and fails on purpose
   (an *expected failure*), documented in its comment and in the docs, until the code is fixed.
3. **Known-truth data.** Where real data has no right answer, the suite generates data from known values
   (synthetic data) with the script kept next to it (`generate*SyntheticData.m`), checks the data reproduces
   its truth (`*SyntheticDataTest`), and checks the truth is identifiable before writing a "recovers the truth"
   test. See "Known-truth data" in `tests/README.md`.
4. **When the optimizer is not reproducible, test what is.** Treatment Optimization's IPOPT gives different
   solutions on different computers, so TO full runs have no truth or nominal solution. They are checked only
   for what any converged run must satisfy (completes, IPOPT does not fail, stays in bounds, meets its
   constraints, writes its files). Everything before the solve is deterministic and is compared with nominal
   results (`TreatmentOptimizationSetupRegressionTest`).
5. **Every tolerance is explained in the test**: what a correct run reaches, and where it matters, what a run
   that should not pass would give.
6. **Run once, check many.** Slow tool runs happen once per case in `TestClassSetup`, each case in its own folder,
   with its error captured, so one crashing case fails only its own tests (see
   `NeuralControlPersonalizationRegressionTest`).
7. **Term smoke tests** (`MtpTermSmokeTest`, `MtliTermSmokeTest`, `NcpTermSmokeTest`, `GcpTermSmokeTest`,
   `TreatmentOptimizationTermSmokeTest`) evaluate **every** cost and constraint term a tool has, one at a time,
   on a real problem, and check only that each runs and gives finite values of the right size. The term lists
   come from the code (`costTermTypes` reads a cost function's `switch`; TO asks its registries), so a new term is
   covered automatically. The tool is run up to its optimizer with the optimizer replaced by a recorder
   (`stubOptimizer`, `optimizerCalls`).

### Naming and placement (needed for `Tool=` and to avoid clashes)

- Put a test under its tier, then the nmsm-core folder of the code it tests (`tests/unit/MuscleTendonPersonalization/`).
- File and class names match and end in `Test`. **All test classes share one MATLAB path**, so prefix the class
  name with the tool wherever another tool could use the same name (`MtpCostTermsTest`, `GcpCostTermsTest`;
  Treatment Optimization uses `To...` for shared tests and `Do...` for Design-only ones).
- Parsing and regression classes are named `<FullToolName>ParsingTest` / `<FullToolName>RegressionTest` (or start
  with the full tool name), or `Tool=` will not find them.
- Name each test method for the behavior it checks (`outOfOrderTasksAreSorted`), so a failure report explains
  itself.

### Checks to use

| To check | Use |
|---|---|
| Equal values | `verifyEqual(actual, expected)` |
| Decimals | `verifyEqual(actual, expected, "AbsTol", 1e-12)`; never compare decimals exactly |
| An error with an identifier | `verifyError(@() f(x), "component:errorId")` |
| An error without an identifier (most nmsm-core errors) | `verifyErrorMessage(testCase, @() f(x), "part of the message")` |

Never use `verifyError(f, ?MException)`: it accepts any error, including an unrelated crash. Prefer `verify*`
(records and continues) over `assert*` (stops the test) unless later lines would crash anyway.

### Settings files

- Valid files are `settings_*.xml`. **`bad_*.xml` and `edge_*.xml` are copies of the tool's minimal settings file
  with exactly one change**, described in a comment at the top, so a failure can only come from that change.
- Settings files use the `Version` of the target branch (`1.5.4`). To move all fixtures to a new version, use
  `updateSettingsVersion("tests/data", "1.5.4", "1.5.5")` (try `DryRun=true` first). It deliberately leaves the
  files that test the version check (`bad_major_version.xml`, `edge_minor_version.xml`) alone.
- Find out which elements a parser requires by removing one element at a time from a working file and seeing
  which removals fail.
- Remember: in the NMSM settings parsers, an **omitted** numeric element gets its default, but one present and
  **empty** usually parses as NaN. Write booleans as the literal text `true`/`false`; many parsers compare the
  text, so a numeric `1` reads as false.

### Fixtures and helpers

Each tool has a values file in `tests/helpers` (`jmpFixtureValues`, `mtpFixtureValues`, `ncpFixtureValues`,
`gcpFixtureValues`, `toFixtureValues`) holding the fixtures' known values, and a fixture test
(`JmpFixtureTest`, `MtpFixtureTest`, ...) that checks the files still match them. **If you change a fixture on
purpose, update its README, its values file and its fixture test together.**

Commonly used helpers:

| Helper | Use |
|---|---|
| `testDataPath(...)` | Path into `tests/data`. |
| `setUp<Tool>WorkingFolder(testCase, ...)` | Move the test into a temporary folder holding copies of the tool's fixtures (deleted afterwards). Tools read and write relative to the current folder, so every parse or run must do this. |
| `copy<Tool>Fixtures(folder, ...)` | Copy fixtures into a folder of your own (one folder per case when a class runs several). |
| `readStoFile(file)` | Read a `.sto`/`.mot` file without nmsm-core. |
| `verifyErrorMessage(testCase, f, text)` | Check an error message. |
| `startQuietParallelPool()` | Start a `Processes` pool (not `Threads`, which cannot hold OpenSim objects) with OpenSim's file log off; call it in `TestClassSetup` before entering a temporary folder. |
| `clearGcpMexFiles(folder)` | Teardown for GCP folders (GCP copies a MEX file into the folder and MATLAB keeps it loaded). |
| `clearToCaches()` | Clear Treatment Optimization's `persistent` caches, globals and loaded MEX functions; call between TO problems and in `TestMethodSetup` of TO unit tests. |
| `parseToSettingsFile`, `prepareToProblem`, `evaluateToProblem`, `runToCase` | Treatment Optimization: parse a settings file as its tool does; prepare a problem exactly as the tool does up to `gpops2`; collect its deterministic quantities; run a whole case with the small GPOPS settings. `prepareToProblem` mirrors the tools' own step sequence: **if a tool's sequence changes, change it there too.** |
| `gpopsIsLicensed()` | Whether GPOPS-II can be used here. |
| `stubOptimizer`, `optimizerCalls`, `costTermTypes`, `smokeCostTerm` | The term smoke tests' machinery. |

### Nominal results

Regression tests also compare with stored results in `tests/data/<tool>/nominal/`, regenerated only with
`tests/regression/update<Jmp|Mtp|Ncp|Gcp|To>Nominal.m` (after `addpath("tests/regression")`, with the project
open). **Never regenerate nominal results to make a failing test pass.** Only do it when a change to the tool's
results is intentional and the truth checks pass; commit the new files on their own with a message saying what
changed and why.

## Expected failures: the workflow

An *expected failure* is a test that describes correct behavior and fails because of a real, documented bug.

**When you find a bug:**
1. Write (or keep) a test that describes the correct behavior. In its comment, say what fails and why, and point
   to the docs (for example `% Expected to fail on candidate-1.5.4: ... See docs/failures.md.`).
2. Confirm it fails **for the stated reason**, not because of a mistake in the test (record its diagnostics; see
   "Running headless").
3. Document it. Add a row to "Tests that are expected to fail" in `tests/README.md` and a numbered entry in
   `docs/failures.md` (the next free `B` number) with what happens, why (file and line), whether it is intended,
   whether it is on `matlab-gui-dev`, and how to fix it. Add it to `docs/candidateFailures.md` if it is open, and
   mark it ⚠ in `docs/test-catalog.md`.

**When a bug is fixed:** the test passes on the fixing branch. Remove its row from the expected-failure table,
mark it fixed (branch, date, commit) in `docs/failures.md` and `docs/candidateFailures.md`, remove the ⚠ in the
catalog, and update the expected-failure count in `README.md`. Update the test's comment as well (for example
"Failed on candidate-1.5.4 (fixed later)").

If behavior is odd but it is unclear whether it is wrong, do not write a failing test. Record it under "Open
questions" in `tests/README.md` (or `docs/candidateFailures.md`) and let the developers decide.

**Things decided not to test** (do not add tests for them unless asked): JMP's `<free_markers>` and
`<anatomical_markers>`; marker files with a wrong `DataRate` header or rows where every marker is NaN (JMP may
assume clean input; crashing on these is acceptable); code nothing calls (listed in `tests/README.md`).

## Tool-specific notes

- **JMP**: fixtures are the `simple_arm` models (`tests/data/jmp`): a truth model and models with `r_elbow`'s
  parent frame translated or rotated away; markers were generated from the truth. JMP's parser ignores
  `<input_directory>`; paths are relative to the current folder. Several JMP functions keep `persistent` state
  (`computeInnerOptimization`, `calculateFrameSquaredError`, `computeInverseKinematicsSquaredError`); clear them
  in `TestMethodSetup`.
- **MTP and MTLI**: fixtures are the tutorial's reduced 9-muscle model (Step 4), its gait trial and 12 passive
  trials, plus synthetic known-truth cases (`emg_scale`, `all`, `two_trials`, `passive`) and a rebuilt
  second gait trial (`tests/data/mtp/rebuilt`). With one trial, all six parameter types are not identifiable (the
  `all` case checks the fit, not the parameters); two trials identify them. Time constants are stored ×100 and
  delays ×10 internally; `muscleModelParameters.sto` is in seconds on candidate.
- **NCP**: fixtures from tutorial Step 5 (model and passive data shared with MTP); synthetic cases
  `all_tracked`, `iliacus_hidden`, `fixed_weights`. NCP leaves its `diary` on after an error: call `diary off`
  after catching one. Its tool only accepts string settings file names on unfixed branches.
- **GCP**: fixtures from tutorial Step 2 (`bodyModel.osim`, GRF data; IK shared with MTP); synthetic data
  `globals`, `springs` and `rotation`, with regression cases (`rotationKept`, `neighbor`, ...) that reuse it with
  different settings. GCP writes `footModel_<n>.osim` and copies a
  `pointKinematics` MEX file into the current folder: use `clearGcpMexFiles` as a teardown.
- **Treatment Optimization**: fixtures are tutorial Steps 6 (torque) and 8 (synergy), the "kick" problem
  (`tests/data/to`), with published results used as starting points and a 3 MB subset of the surrogate model
  data. `gpops_small.xml` keeps full runs to about a minute each. Hand-built term structs need a `type` field
  (helpers build messages from it eagerly) and char, not string, field values (as the parser gives).
  The kick fixtures have no contact surfaces, so `TreatmentOptimizationTermSmokeTest` evaluates the terms that
  need them (external forces and moments, center of pressure, impulse goals) only in its three walking cases
  (`tests/data/to/walking`, torque-driven walking with GCP contact surfaces from `nmsm-advanced-tutorials`
  Tutorial 1), and the walking cases evaluate only those terms.

## Gotchas (short list; the full list is in `tests/README.md`)

- Tools read and write in the **current folder**: always use a working folder fixture; never run a tool inside
  this repository (it leaves `footModel_*.osim`, `commandWindowOutput.txt`, `opensim.log`, results folders, MEX
  copies).
- **Parallel pool**: start it with `startQuietParallelPool()` before entering temporary folders, or workers hold
  `opensim.log` open and the folder cannot be deleted.
- **`import org.opensim.modeling.*`** shadows nmsm-core's `Model.m` wrapper; import only the classes you need.
- Tools call **`tic`**, resetting the default timer: time runs with `t = tic; ...; toc(t)`.
- Running a tool inside `evalc` leaves its copied `commandWindowOutput.txt` **empty**: check that it exists, not
  what it says.
- **Persistent caches** in nmsm-core functions carry state between tests: clear them.

## Rules for agents working here

- **Do not edit nmsm-core's code as part of test work unless the user asks for it.** Tests describe how the code
  should behave; if the code is wrong, write or keep a failing test and document the bug with a proposed fix.
- **Do not weaken a test to make it pass** (loosen a tolerance, change an expected value, delete a check,
  regenerate nominal results) without a stated, principled reason that the user agrees with. If you change a
  tolerance, say so and why.
- **Do not commit, push or open pull requests unless asked.** The maintainers stage and commit themselves. Branches
  can change between sessions: check the current branch of nmsm-test and of the nmsm-core checkout you are
  testing before relying on either.
- **Keep the docs in sync with the tests**: a new or renamed test goes in `docs/test-catalog.md`; a new failure or
  fix updates `tests/README.md`, `docs/failures.md`, `docs/candidateFailures.md` and the count in `README.md`; a
  fixture change updates its README and values file.
- **Report results faithfully**: the nmsm-core branch and commit tested, the pass/fail/incomplete counts, and for
  each failure whether it is a known expected failure (and which bug) or something new. Say when a tier or tool
  was not run.
- Put scratch scripts and temporary output **outside this repository** (or in a temporary folder), and leave no
  stray files behind.

## Code style

- **MATLAB**: lines of at most 80 characters, continued with `...`; four-space indentation; double-quoted
  strings for text. Every test class and helper starts with a comment block explaining what it covers and why;
  helper functions end that block with a type signature, e.g. `% (string, string array) -> (None)`. Comments say
  what a check means (for example, what a value represents and how it was worked out), not what the code does.
- **Markdown docs**: plain, direct sentences; tables for lists of things; lines wrapped at about 115 characters.
- Follow the surrounding file's conventions; when in doubt, copy the shape of an existing test in the same
  folder (`tests/unit/ExampleTest.m` is the smallest).

## Current state (as of 2026-11-17; verify before relying on it)

- nmsm-test `main` includes everything through PR #12 (the NCP test rewrite after a bug fix).
- **Open bugs** (`docs/candidateFailures.md`): **B3** (MTP shared electromechanical delay with per-muscle EMG;
  fixed on `matlab-gui-dev`, ready to port), **B10** (MTLI passive moment tracking assumes 101 frames), **B12**
  (NCP crashes when a muscle has no MTP activations; with other team members, needs a decision), **B30** (Design
  Optimization's absolute metabolic goals read GPOPS-II's integral in scaled time). B29 is left as is by
  decision. All other bugs (B1–B28) are fixed on `candidate-1.5.4` or one of the bug-fix branches listed there.
- The `matlab-gui-dev` diagnostic in `docs/failures.md` (Part 2) is from commit `6e7fc4e7` (2026-10-22/26);
  rerun it before quoting its numbers for a newer commit.
- The expected-failure count in `README.md` and the run times may lag behind the suite; a fresh run is the
  source of truth.
