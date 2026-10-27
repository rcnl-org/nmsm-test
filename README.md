# nmsm-test
Test suite for the NMSM Pipeline. It lives outside nmsm-core so the same tests can run against any
nmsm-core branch: check out the branch you want in nmsm-core, then run the suite.

## Running
Clone this repo next to nmsm-core (`GitHub/nmsm-core` and `GitHub/nmsm-test`), then in MATLAB:

```matlab
cd nmsm-test
runTests()               % unit tests
runTests("parsing")      % settings-file parsing tests
runTests("regression")   % full tool runs compared with the truth and with nominal results (slow)
runTests("all")
runTests("unit", Coverage=true)            % adds an HTML code coverage report
runTests("unit", CorePath="D:\nmsm-core")  % if nmsm-core is somewhere else
runTests("all", Tool="GCP")                % one tool's tests in every tier
runTests("regression", Tool=["MTP", "NCP"])
```

`Tool` is any of `"JMP"`, `"MTP"`, `"MTLI"`, `"NCP"`, `"GCP"`, `"Tracking"`, `"Verification"`, `"Design"`, `"TO"`
(all of Treatment Optimization: its shared tests and all three tools) and `"core"` (tests of the shared `src/core`
code, including JMP's verify functions), in any case.

`runTests` opens the nmsm-core project if needed and prints the nmsm-core branch and commit it tested.

To test a second branch without switching your main checkout, give it its own folder with a git worktree,
named after the branch it stays on:

```
git -C nmsm-core worktree add ../nmsm-core-candidate-1.5.4 candidate-1.5.4
```
```matlab
runTests("all", CorePath="../nmsm-core-candidate-1.5.4")
```

Keep that folder on its branch. Git only lets a branch be checked out in one folder at a time, so if the
worktree is switched to, say, `main`, `git switch main` in your own `nmsm-core` folder will fail.

## What it covers

| Tool | Unit | Parsing | Regression |
|---|---|---|---|
| Joint Model Personalization (JMP) | yes | yes | two known-truth runs |
| Muscle-Tendon Personalization (MTP), including synergy extrapolation | yes | yes | four synthetic known-truth runs and the tutorial problem |
| Muscle-Tendon Length Initialization (MTLI) | yes | yes | one synthetic known-truth run (inside MTP) |
| Neural Control Personalization (NCP), including fixed weights, normalization methods and MTLI | yes | yes | five synthetic known-truth runs and the tutorial problem |
| Ground Contact Personalization (GCP) | yes | yes | three synthetic known-truth runs, one crash check and the tutorial problem |
| Treatment Optimization: Tracking, Verification and Design Optimization (torque and synergy controllers), with shared tests for what they have in common | yes | yes | the tutorial's problems, prepared and compared with nominal results, and solved with checks that hold on any computer (needs GPOPS-II) |
| Shared muscle model and synergy helpers (`src/core`) | yes | | |

The tests are written for nmsm-core `candidate-1.5.4` (pipeline version 1.5.4).

A unit run takes about 80 s, a parsing run about 90 s, and a regression run about 17 minutes (1 minute of it
starting the parallel pool, 6 of it GCP and 6 Treatment Optimization). Treatment Optimization's regression tests
need a licensed GPOPS-II and are reported as not run without one. Thirty-five tests are expected to fail until
known bugs are fixed; see
[tests/README.md](tests/README.md#tests-that-are-expected-to-fail).

To add or change tests, read [tests/README.md](tests/README.md). [docs/test-catalog.md](docs/test-catalog.md) lists every
test with a one-line description, and [docs/failures.md](docs/failures.md) explains every failing test (on
`candidate-1.5.4` and `matlab-gui-dev`) and how to fix it.

## Layout
- `tests/unit`, `tests/parsing`, `tests/regression`: class-based `matlab.unittest` tests, tagged
  `Unit`, `Parsing`, or `Regression`, in folders named after the nmsm-core folder they test.
- `tests/data`: fixture models and data files, one folder per tool (see the README in each folder).
- `tests/helpers`: shared test functions.
- `legacy/`: the original 2023 tests. These are kept for reference and porting, but `runTests` does not run them.
