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
```

`runTests` opens the nmsm-core project if needed and prints the nmsm-core branch and commit it tested.

To test a second branch without switching your main checkout, give it its own folder with a git worktree:

```
git -C nmsm-core worktree add ../nmsm-core-1.5.4 candidate-1.5.4
```
```matlab
runTests("all", CorePath="../nmsm-core-1.5.4")
```

## What it covers

| Tool | Unit | Parsing | Regression |
|---|---|---|---|
| Joint Model Personalization (JMP) | yes | yes | two known-truth runs |
| Muscle-Tendon Personalization (MTP), including synergy extrapolation | yes | yes | four synthetic known-truth runs and the tutorial problem |
| Muscle-Tendon Length Initialization (MTLI) | yes | yes | one synthetic known-truth run (inside MTP) |
| Neural Control Personalization (NCP), including fixed weights, normalization methods and MTLI | yes | yes | five synthetic known-truth runs and the tutorial problem |
| Shared muscle model and synergy helpers (`src/core`) | yes | | |

The tests are written for nmsm-core `candidate-1.5.4` (pipeline version 1.5.4).

A unit run takes about 75 s, a parsing run about 50 s, and a regression run about 4.5 minutes (1 minute of it
starting the parallel pool). Eighteen tests are expected to fail until known bugs are fixed; see
[tests/README.md](tests/README.md#tests-that-are-expected-to-fail).

To add or change tests, read [tests/README.md](tests/README.md).

## Layout
- `tests/unit`, `tests/parsing`, `tests/regression`: class-based `matlab.unittest` tests, tagged
  `Unit`, `Parsing`, or `Regression`, in folders named after the nmsm-core folder they test.
- `tests/data`: fixture models and data files, one folder per tool (see the README in each folder).
- `tests/helpers`: shared test functions.
- `legacy/`: the original 2023 tests. These are kept for reference and porting, but `runTests` does not run them.
