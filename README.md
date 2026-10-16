# nmsm-test
Test suite for the NMSM Pipeline. It lives outside nmsm-core so the same tests can run against any
nmsm-core branch: check out the branch you want in nmsm-core, then run the suite.

## Running
Clone this repo next to nmsm-core (`GitHub/nmsm-core` and `GitHub/nmsm-test`), then in MATLAB:

```matlab
cd nmsm-test
runTests()               % unit tests (fast)
runTests("parsing")      % settings-file parsing tests
runTests("regression")   % full tool runs compared against nominal results (slow)
runTests("all")
runTests("unit", Coverage=true)            % adds an HTML code coverage report
runTests("unit", CorePath="D:\nmsm-core")  % if nmsm-core is somewhere else
```

`runTests` opens the nmsm-core project if needed and prints the nmsm-core branch and commit it tested.

The suite currently covers Joint Model Personalization only. A unit run takes about 10 s, a parsing run
about 10 s, and a regression run about 2–3 minutes (most of it starting the parallel pool). Three tests
are expected to fail until known bugs are fixed; see [tests/README.md](tests/README.md#tests-that-are-expected-to-fail).

To add or change tests, read [tests/README.md](tests/README.md).

## Layout
- `tests/unit`, `tests/parsing`, `tests/regression`: class-based `matlab.unittest` tests, tagged
  `Unit`, `Parsing`, or `Regression`.
- `tests/data`: small fixture models and data files (see the README in each folder).
- `tests/helpers`: shared test functions.
- `legacy/`: the original 2023 tests. These are kept for reference and porting, but `runTests` does not run them.
