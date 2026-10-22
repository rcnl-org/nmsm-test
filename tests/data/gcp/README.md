# GCP test fixtures

Ground Contact Personalization (GCP) fits a grid of springs under the foot (spring constants, damping, friction,
resting length) and small changes to the foot's motion, so the springs reproduce the measured ground reactions.
These fixtures are the tutorial's GCP problem, `nmsm-tutorial/Step-2-Ground-Contact-Personalization` (commit
`143acf9`).

| File or folder | What it is |
|---|---|
| `bodyModel.osim` | The tutorial's full-body model (not the MTP model): a two-segment right foot (`calcn_r`, `toes_r`, pin joint `mtp_r`) with the five markers GCP places the springs from (`R_Toe`, `R_Toe_Medial`, `R_Toe_Lateral`, `R_Heel`, `R_Midfoot_Superior`). |
| `preprocessed/GRFData/gait_1.sto` | Ground reactions for two force plates, 101 frames from 0.5 to 1.6 s. Plate 2 (`ground_force_2_*`, `ground_moment_2_*`) is the right foot: forces, moments, and the electrical center (`_px/_py/_pz`) the moments are about. |

**Shared with MTP.** The IK file (`IKData/gait_1.sto`) is byte-identical to `tests/data/mtp/preprocessed/IKData`,
so it is not repeated: `copyGcpFixtures` copies it from there. The tutorial's EMG, ID and muscle analysis files
are not needed by GCP and are not copied.

**GCP writes into the current folder:** `footModel_<n>.osim`, and a copy of the `pointKinematics` MEX file
(Windows only). Every parse or run uses its own temporary folder (`setUpGcpWorkingFolder`, `copyGcpFixtures`).

## `settings/`

GCP settings files for the parsing and regression tests (`Version="1.5.4"`, written for nmsm-core
`candidate-1.5.4`).

| File | Purpose |
|---|---|
| `settings_minimal.xml` | Only the elements the 1.5.4 parser requires. The base for every `bad_*` and `edge_*` file. |
| `settings_full.xml` | Every option, with non-default values: grid size, filter cutoff, latching velocity, every initial value and optimizer option, a 0.6 to 1.5 s window, and three tasks out of index order with one disabled; task 1 turns on every design variable and every cost term type. |
| `settings_tutorial.xml` | The tutorial's `GCPSettingsV1.xml` with the version changed and `max_iterations` 5 instead of 20 (about 3 minutes instead of 6). Used by the regression tests. |
| `settings_synthetic_*.xml` | The synthetic cases (below), plus `neighbor`: the springs data with `neighbor_spring_constant` instead of `spring_constant_mean` and no moment cost term. Used by the regression tests. |
| `bad_*.xml`, `edge_*.xml` | `settings_minimal.xml` with one change, described in the comment at the top of each file. |

## `synthetic/`

Known-truth problems for the regression tests, written by `synthetic/generateGcpSyntheticData.m` from the true
values in `gcpFixtureValues().synthetic`. Each case has the fixture IK and a GRF file whose plate 2 columns are
what GCP's own contact model gives at the true values, with the foot moving as GCP fits it to the IK
(B-spline coefficients 1). The electrical center is the floor point under the midfoot superior marker, where
GCP moves the moments anyway, and the moments are written without the resting length term GCP adds back. So
GCP's ground reaction cost terms are exactly zero at the truth. The settings use a 5 x 11 grid (37 springs inside
the foot outline), no resting length initialization, and one task with vertical force, horizontal force and
moment terms.

| Case | Truth (start: spring constant 2500 N/m, damping 1, dynamic friction 0.5, resting length 0.05 m) | What GCP must do |
|---|---|---|
| `globals/` | Damping 1.5, dynamic friction 0.7, resting length 0.045 m | Find those three values. It does, exactly. |
| `springs/` | Every spring at 3000 N/m | Find it for all 37 springs (also optimizing the three values above, which stay at the truth). The `spring_constant_mean` term, which the truth meets exactly, pins the springs that never touch the ground. GCP gets them to 5e-12 relative in 2 iterations. |
| `rotation/` | The `globals` truth, measured by a plate turned 0.05 rad about the vertical axis | Starting at the `globals` truth, find the angle. **Fails on candidate-1.5.4** (see the expected failures in `tests/README.md`). |

**Spring constants that differ from spring to spring are not recoverable.** A case with constants rising from
2000 N/m at the heel to 3500 N/m at the toe was tried and dropped: springs that never touch the ground do not
affect the cost and stay at the start, and lsqnonlin zig-zags on the rest (after 50 iterations the cost was still
about 1e4 and constants ranged from 0 to 5800 N/m).

`tests/unit/GroundContactPersonalization/GcpSyntheticDataTest.m` checks that the files still match the truth,
using GCP's own task cost. The ground reactions come from nmsm-core's own contact model, so a bug in it is built
into the truth; `SpringContactModelTest.m` checks the model separately. To regenerate (only on purpose), with the
project open: `addpath("tests/data/gcp/synthetic"); generateGcpSyntheticData()`.

## `nominal/`

Results of the regression runs that complete with a correct answer on candidate-1.5.4 (`globals`, `springs`,
`tutorial`): `<case>_bodyModel_gcp.osimx` and `<case>_bodyModel_Foot_1_optimizedGroundReactions.sto`. Two runs
agree exactly. Regenerate them only with `tests/regression/updateGcpNominal.m`.

The 5-iteration tutorial run does not converge (RMS of modeled minus experimental vertical force 64 N, against
an 810 N peak), so it is checked against its own nominal and against fit ceilings 25% above it, not against the
tutorial's published 20-iteration results.

The recorded values live in `tests/helpers/gcpFixtureValues.m`, and
`tests/unit/GroundContactPersonalization/GcpFixtureTest.m` checks that these files still match them. If you
change a fixture on purpose, update both.
