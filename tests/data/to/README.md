# Treatment Optimization test fixtures

Treatment Optimization (Tracking, Verification and Design Optimization) solves an optimal control problem with
GPOPS-II: it finds joint motions and controls (torque controls, or synergy activations that drive muscles) that
minimize a set of cost terms while meeting constraint terms. These fixtures are the tutorial's two kick problems,
from `nmsm-tutorial` commit `143acf9` (`git archive`, so the tutorial's local edits and untracked files are
not included):

| Folder | What it is |
|---|---|
| `preprocessed/` | IK and ID data for one kick (`drive_kick1`): 63 frames at 200 Hz, 0 to 0.31 s, 41 coordinates and 41 loads. Byte-identical in Steps 6 and 8, so it is kept once and copied into each problem. |
| `torque/` | Step 6 (torque driven). `KickingModel.osim` is the full-body model (86 muscles, which a torque-driven run disables). `published/TorqueTOResultsV1/` (Tracking) and `published/TorqueVOResultsV2/` (Verification) are the tutorial's published results, which its Verification and Design settings start from. |
| `synergy/` | Step 8 (synergy driven). `KickingModel.osim` has only the nine right-leg muscles. `ncpResults/` is the NCP solution Tracking starts from: `KickingModel_ncp.osimx` (synergy group `RightLeg`, 4 synergies), synergy weights, commands and activations. `published/SynergyTOResultsV1/` and `published/SynergyVOResultsV2/` are published results. `surrogateMuscles.mat` is the tutorial's fitted surrogate model, loaded from the current folder when `<load_surrogate_model>` is true. |
| `synergy/surrogateData/` | The part of the tutorial's 28 MB surrogate model data that Treatment Optimization reads (about 3 MB): the 1,575-row sampled IK (63 frames x 25 Latin hypercube samples), the muscle-tendon lengths, and the moment arms about the six surrogate coordinates. The other 93 MuscleAnalysis files are never opened. The kept files are unchanged, with every sample, so a surrogate fitted from them is the tutorial's. Made by `synergy/selectSurrogateData.m`. |
| `userFunctions/` | `footSpeedCost.m` and `footSpeedConstraint.m`, the tutorial's user-defined Design Optimization terms (identical in Steps 6 and 8). Copied into the working folder, which puts them on the path. |
| `settings/` | Settings files (see below). |

**GPOPS-II solver settings** (`settings/gpops_*.xml`):

| File | Purpose |
|---|---|
| `gpops_torque_tutorial.xml` | Step 6's `GpopsSettings.xml` with only the version changed: 25 intervals x 4 points, no mesh refinement, 100 IPOPT iterations. The tutorial's settings files name it `gpopsSettings.xml`, which only works on case-insensitive file systems; these fixtures use the real names. |
| `gpops_synergy_tutorial.xml` | Step 8's `gpopsSettings.xml` with only the version changed: 1 interval x 50 points, 300 IPOPT iterations. Kept as published, including its empty elements (which parse as NaN, not the default) and `<integral_bounds>`, an element candidate-1.5.4 does not read (it reads `<integral_bound>`, so the value 10 is ignored). |
| `gpops_small.xml` | For the regression runs: the torque tutorial settings with 8 intervals x 3 points and at most 50 IPOPT iterations. Provisional until timed with a licensed GPOPS-II. |
| `gpops_synergy_metabolic.xml` | For the metabolic cost regression runs: `gpops_synergy_tutorial.xml` with at most 50 IPOPT iterations. Its 1 x 50 point grid is the one the published Verification results (51 rows, the initial guess) were solved on, which the metabolic cost goals currently need (B29 in `docs/failures.md`). |

**Metabolic cost goal settings:** `settings_design_synergy_{relative,absolute}_metabolic.xml` and
`settings_design_synergy_{relative,absolute}_metabolic_high.xml` are `settings_design_synergy_tutorial.xml` with one
enabled metabolic cost per time goal each, below and above the published Verification solution's 858: relative error
center 0.7 and 1.3, absolute error center 600 and 1200. Used by `DesignOptimizationMetabolicRegressionTest`.

**GPOPS-II is needed to prepare inputs, not just to solve.** On candidate-1.5.4, `makeTreatmentOptimizationInputs`
calls `gpops2` to find the collocation times before anything else, so every test that prepares inputs or runs a
tool assumes `gpopsIsLicensed()` and reports itself as not run without a license.

**No ground truth for full runs.** IPOPT gives different solutions on different computers, so the regression
tests check only what holds on any machine: a run completes, writes its files, and its solution meets its own
bounds and enabled constraints. Nominal results are kept only for the deterministic steps before solving
(prepared inputs, and the cost and constraint functions evaluated at a stored solution). The tutorial's only
recorded solve, Step 6 Tracking V1, took 8 IPOPT iterations (11.9 s) to an optimal solution.

**Treatment Optimization writes into the current folder** (`commandWindowOutput.txt`, and `surrogateMuscles.mat`
when `<save_surrogate_model>` is true) and next to the model (`KickingModel_inactiveMuscles.osim`, and Design
Optimization's `KickingModelDesignOpt.osim`). Every parse or run uses its own temporary folder
(`setUpToWorkingFolder`, `copyToFixtures`).

The recorded values live in `tests/helpers/toFixtureValues.m`, and
`tests/unit/TreatmentOptimization/TreatmentOptimizationFixtureTest.m` checks that these files still match them,
reading the data with `readStoFile`. If you change a fixture on purpose, update both.
