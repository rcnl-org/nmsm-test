# Unresolved failures on candidate

The failures from [failures.md](failures.md) that are still open: not fixed on `candidate-1.5.4`, `gcp-bug-fixes`,
`treatment-optimization-bug-fixes` or `mtp-bug-fixes`. Four bugs are open, with 7 failing tests. One more known bug is
left as is on purpose and has no test.

Checked on 2026-11-02, by reading the code on the branches and running the tests:

| Branch | Commit | What was run |
|---|---|---|
| `candidate-1.5.4` | `2e8a7719` | Code only (the branches below are built on it) |
| `gcp-bug-fixes` | `07101331` | Unit tier. Its GCP regression tests passed 21 of 21 on 2026-10-29 at this commit. |
| `treatment-optimization-bug-fixes` | `137ff8c1` | Unit and parsing tiers; NCP and Design Optimization regression tests |
| `mtp-bug-fixes` | `ffb1b026` plus uncommitted B5 fix | MTP unit, parsing and regression tests; unit and parsing tiers and NCP regression tests for B4 |

JMP, Tracking and Verification regression tests were not rerun for this list.

**Summary**

| Bug | Tool | Failing tests | Where it acts | Size of fix | Status |
|---|---|---|---|---|---|
| [B3](#b3-a-shared-electromechanical-delay-does-not-work-with-per-muscle-emg) | MTP | 1 | Optimization | Small; dev has it | Ready to port |
| [B10](#b10-passive-moment-tracking-only-works-for-101-frame-trials) | MTLI | 1 | Optimization | One expression, twice | Open |
| [B12](#b12-ncp-crashes-when-a-muscle-has-no-mtp-activations) | NCP | 4 | Before the optimization | Medium; needs a decision | With other team members |
| [B30](#b30-absolute-metabolic-goals-see-the-metabolic-cost-in-gpops-iis-scaled-time) | Design Optimization | 1 | Optimization | Small; a few files | Open |

---

## Open bugs

### B3. A shared electromechanical delay does not work with per-muscle EMG

- **Test:** `MuscleModelTest/commonDelayShiftsEmgLater`
- **What happens:** with one delay for all muscles, the EMG is not shifted correctly when each muscle has its own
  EMG spline, which is the form MTP's parser builds.
- **Why:** `calcEmgDataWithCommonTimeDelay.m` (`src/MuscleTendonPersonalization/Modeling/`) evaluates one spline per
  trial, `ppval(interpTime - timeDelay, emgSplines{trial})`. `makeEmgSplines` builds one spline per trial and muscle.
- **Who it affects:** runs with a shared delay. MTP on candidate always uses per-muscle delays, so the tool does not
  reach this on candidate; it matters once the shared delay is used.
- **Fix:** bring `matlab-gui-dev`'s version over, which loops over the muscles:
  ```matlab
  for muscle = 1:size(emgSplines, 2)
      emg(trial, muscle, :) = ppval(interpTime - timeDelay, ...
          emgSplines{trial, muscle})';
  end
  ```
- **On `matlab-gui-dev`:** fixed.

### B10. Passive moment tracking only works for 101-frame trials

- **Test:** `MtliCostTermsTest/passiveMomentTrackingWorksForAnyTrialLength`
- **What happens:** the `passive_joint_moment` term fails for a passive trial that does not have exactly 101 frames.
- **Why:** `calcPassiveMomentTrackingCost.m` (lines 35 and 37) hard-codes the frame count:
  `repmat(~columnsWithAllZeros, 1, 1, 101)`.
- **Fix:** use the data's frame count:
  `repmat(~columnsWithAllZeros, 1, 1, size(experimentalData.passiveData.inverseDynamicsMoments, 3))`.
- **On `matlab-gui-dev`:** still there.

### B12. NCP crashes when a muscle has no MTP activations

- **Tests:** `NeuralControlPersonalizationRegressionTest/iliacusHiddenPredictsIliacus`, `mtliRunCompletesAndFits`,
  `writesExpectedResultFiles(run=iliacusHidden)`, `writesExpectedResultFiles(run=mtli)`
- **What happens:** "Number of elements must not change", in exactly the case NCP exists for: predicting muscles
  without MTP results. MTLI inside NCP only updates such muscles, so it can never run.
- **Why:** `stackMtpActivations` in `prepareNcpInitialValues.m` (line 284) reshapes the MTP activations to
  `inputs.numMuscles` columns, as if every modeled muscle had them. `inputs.mtpActivations` holds only the muscles
  with MTP data. The NNMF starting values also take each synergy group's muscles as a contiguous column range, and
  the fixed-weights path uses the same stack.
- **Status:** handed to other team members on 2026-10-28.
- **Fix:** stack only the muscles with MTP data and match them to each group by name. Run NNMF on those, and fall
  back to the constant initial guess for a group with no MTP data. Bilateral symmetry needs the same matching, or a
  clear error when the legs' MTP muscles differ.
- **Decision needed:** the starting weight for muscles without MTP data: a constant (the old unused function used
  0.1) or the mean of the group's other weights.
- **After the fix:** the rest of NCP (cost, saving, MTLI's update) already works by muscle name, but that can only be
  confirmed once runs get past the starting values.
- **On `matlab-gui-dev`:** the same reshape is still in the code; not rerun there.

### B30. Absolute metabolic goals see the metabolic cost in GPOPS-II's scaled time

- **Test:** `DesignOptimizationMetabolicRegressionTest/higherGoalRaisesTheMetabolicCost(goal=absolute)`
- **What happens:** an absolute metabolic goal aims at a target off by a factor of 1 / (maxTime − minTime). In the
  synergy tutorial problem (final time range up to 0.36 s) the term sees 2384 where the metabolic cost per unit time
  is 858. Targets of 600 and 1200 both pull the cost down: the runs end at 564 and 540.
- **Why:** GPOPS-II solves in scaled time, so the integral the endpoint function reads
  (`setup.phase.integral(end - counter)` in `computeGpopsEndpointFunction.m`, line 57) is the energy divided by
  (maxTime − minTime): 739 instead of 266 J here. `calcAbsoluteMetabolicCostPerTimeGoalDiscrete` divides that by the
  real final time as if it were the energy. Relative goals are not affected, because they divide by the initial
  guess's integral, which is scaled the same way.
- **Fix:** multiply by (maxTime − minTime) where the endpoint function reads the integral, and where the initial
  guess's integral is stored (`computeCollocationPointTimes`, `convertToGpopsInputs`), so the relative goals stay
  consistent.
- **Check while fixing:** `calcAbsoluteMetabolicCostPerDistanceGoalDiscrete` has the same scale. The braking and
  propulsive impulse goals read their integrals the same way and probably need the same correction (not checked: the
  fixtures have no contact surfaces).
- **On `matlab-gui-dev`:** the same line is still there.
- **Note:** only `treatment-optimization-bug-fixes` has B26's fix. Without it, the absolute goals have no effect at
  all, and `lowerGoalLowersTheMetabolicCost(goal=absolute)` fails too.

---

## Left as is

**B29. Metabolic cost goals fail to set up unless the initial guess was solved on the same grid.** No test. Decided
on 2026-10-30: the initial guess for a metabolic goal is in practice a previous run's output on the same grid, so the
case is not expected to come up. If it does, the error is `Unrecognized field name "initialMetabolicCost"`, which
does not name the cause. An `assert` with a clear message in `checkInitialGuess` would be the cheap improvement.

---

## Open questions

These are not test failures, but they are unresolved on all of these branches. The first two come from reading the
code and have not been run.

- **NCP's grouped terms index by model position.** `calcGroupedActivationCost` and
  `calcGroupedNormalizedFiberLengthCost` index activations, which are in synergy group order, with `params` groups
  that are positions in the model (B4's fix left NCP's call unchanged). Each is inside a `try`/`catch` that hides
  out-of-range errors, so a mismatch is silently wrong or skipped. Passing the modeled muscle names to
  `groupNamesToGroups` would be the likely fix.
- **MTP's fiber length limits are only set with synergy extrapolation.** `MuscleTendonPersonalization.m` (lines 60 to
  63) copies `maxNormalizedMuscleFiberLength` and `minNormalizedMuscleFiberLength` into `taskParams` only in the
  synergy extrapolation branch, but `calcMtpCost` uses them in both. With synergy extrapolation off, enabling either
  term should crash with `Unrecognized field name`. `MtpTermSmokeTest` runs with it on, so it does not catch this.
- **Which muscles count as crossing a coordinate.** `getMusclesFromCoordinates` keeps a muscle if one of its path points
  is on a body that the listed coordinate moves, not if it spans that joint. In the MTP fixture, `<coordinate_list>` of
  `ankle_angle_r` alone gives no muscles, and `knee_angle_r` includes `soleus_r` and `tibant_r` but not `gasmed_r`.
- **Metabolic and angular momentum flags are Windows-only.** In `parseTreatmentOptimizationInputs.m`,
  `calculateMetabolicCost`, `calculateAngularMomentum` and the impulse flags are only set inside
  `if isequal(mexext, 'mexw64')`. On macOS and Linux those terms never get their values computed.
- **GCP needs `nmsm-core` in its install path.** `copyMexFunction` in `prepareGroundContactPersonalizationInputs.m`
  finds the MEX folder by looking for a path component containing `nmsm-core`. In a folder named anything else, GCP
  fails with "Array indices must be positive integers or logical values." Found on 2026-11-02 by running the tests
  on a copy in a differently named folder.
- **`<is_enabled>` is not read for `<RCNLParameterTerm>`.** Every parameter term is a design variable.
- **Model functions and parameters** (`<model_functions>`, `<RCNLParameterTermSet>`) are to be reviewed by the team,
  along with `calcGoalBeltSpeedDiscrete`, which is not in the cost term registry.

---

## Resolved, for reference

These fixes are on the branches below. `gcp-bug-fixes`, `treatment-optimization-bug-fixes` and `mtp-bug-fixes` are not merged into
`candidate-1.5.4` or each other, so until they are, each branch still fails the others' tests. For example,
`gcp-bug-fixes` fails the Design Optimization tests, and `treatment-optimization-bug-fixes` fails B14 and B18.

| Branch | Bugs |
|---|---|
| `candidate-1.5.4` | B1, B2, B6, B7, B8, B9, B11, B13, B15, B16, B23, B24 |
| `gcp-bug-fixes` | B14, B17, B18, B27 |
| `treatment-optimization-bug-fixes` | B19, B20, B21, B22, B25, B26, B28 |
| `mtp-bug-fixes` | B4, and B5 (uncommitted) |
