# NCP test fixtures

Neural Control Personalization (NCP) fits muscle synergies (weights and B-spline commands) so that synergy
activations reproduce the joint moments and the activations Muscle-Tendon Personalization (MTP) found. These
fixtures are the tutorial's NCP problem, `nmsm-tutorial/Step-5-Neural-Control-Personalization`, taken from the
nmsm-tutorial commit `143acf9` (`git archive HEAD`, so local edits to the tutorial are not included).

**Shared with MTP.** The model (`UF_Subject_3_reduced_muscles.osim`) and `passive_moment_data/` are
byte-identical to the Step 5 copies, so they are not repeated here: `copyNcpFixtures` copies them from
`tests/data/mtp`. The shared values (muscles, groups, model properties) come from `mtpFixtureValues`.

| File or folder | What it is |
|---|---|
| `preprocessed/` | Step 5's gait trial `gait_1`: EMG, ID, IK, and muscle analysis (lengths, velocities, and moment arms for the three tracked coordinates only). Same trial and time grid as `tests/data/mtp/preprocessed`, but processed differently: EMG agrees to 3e-9, muscle-tendon lengths and moment arms to about 1 mm, ID moments differ by up to 6.7 Nm and IK by up to 0.13 rad. |
| `mtpResults/muscleActivations/gait_1_muscleActivations.sto` | MTP's activations for all nine muscles, which NCP tracks. |
| `mtpResults/UF_Subject_3_reduced_muscles_mtp.osimx` | MTP's optimized optimal fiber lengths, tendon slack lengths and maximum isometric forces, which NCP uses instead of the model's. |

**These MTP results came from a different MTP version than candidate-1.5.4.** The tutorial's MTP parameter
file stores activation time constants x100 (0.75 to 3.5) where 1.5.4's MTP writes seconds (0.0075 to 0.035).
NCP only reads the activations and the osimx lengths and forces, so this does not affect the NCP tests, but the
values do not match `tests/data/mtp/nominal`.

## `settings/`

NCP settings files for the parsing and regression tests (`Version="1.5.4"`, written for nmsm-core
`candidate-1.5.4`).

| File | Purpose |
|---|---|
| `settings_minimal.xml` | Only the elements the 1.5.4 parser requires (no MTP results: `mtp_results_directory` is optional). The base for every `bad_*` and `edge_*` file. |
| `settings_full.xml` | Every option, mostly with non-default values: MTP results, every optimizer option (`algorithm` and `finiteDifferenceType` are camelCase), 20 nodes, `sum` normalization, MTLI enabled with its cost terms before NCP's, every NCP cost term type. |
| `settings_tutorial.xml` | The tutorial's committed `NCPSettingsV1.xml` with only the version changed. Used by the regression tests. |
| `settings_synthetic_*.xml` | The synthetic cases (below) and two variants: `sum` (all_tracked with sum normalization) and `mtli` (iliacus_hidden with MTLI on the fixture passive data). Used by the regression tests. |
| `bad_*.xml`, `edge_*.xml` | `settings_minimal.xml` with one change, described in the comment at the top of each file. `edge_fixed_weights.xml` needs a `synergyWeights.sto` in the data folder, which the parsing tests write themselves. |

`osimx/no_muscles.osimx` is an osimx file with no muscles, for `bad_osimx_without_muscles.xml`.

## `synthetic/`

Known-truth problems for the regression tests, written by `synthetic/generateNcpSyntheticData.m` from the true
synergies in `ncpFixtureValues().synthetic`: three synergies (loading response, push-off, swing) with fixed
weights over the nine muscles, each command a bump on NCP's 26 B-spline nodes. The true activations are
B * nodes * weights (0.03 to 0.41), and the ID moments are what the muscle model gives for them with the
tutorial's MTP lengths and forces. Each case has `preprocessed/` (NCP's data with the tracked moments replaced)
and `mtpResults/muscleActivations/` (the true activations, as if MTP had found them):

| Case | What it tests |
|---|---|
| `all_tracked/` | MTP activations for all nine muscles: NCP must find synergies that reproduce them. NCP recovers them to 3e-8 (the weights differ: synergies are only unique up to scaling and recombination). |
| `iliacus_hidden/` | No MTP activation for `iliacus_r`: NCP must predict it. **Crashes on candidate-1.5.4** (see the expected failures in `tests/README.md`). |
| `fixed_weights/` | `preprocessed/synergyWeights.sto` holds the true weights; NCP fits only the commands, exactly (5e-16). |

`tests/unit/NeuralControlPersonalization/NcpSyntheticDataTest.m` checks that the files still match the truth.
The moments come from nmsm-core's own muscle model, so a bug in it is built into the truth;
`tests/unit/core/MuscleModelTest.m` checks the model separately. To regenerate (only on purpose), with the
project open: `addpath("tests/data/ncp/synthetic"); generateNcpSyntheticData()`.

## `nominal/`

Results of the regression runs that complete on candidate-1.5.4 (`allTracked`, `fixedWeights`, `sum`,
`tutorial`): `<case>_synergyWeights.sto`, `<case>_gait_1_synergyCommands.sto` and
`<case>_gait_1_modeledMomentsNcp.sto`. Two tutorial runs agree exactly. Regenerate them only with
`tests/regression/updateNcpNominal.m`, which skips cases that fail.

The tutorial run reaches NCP moment RMS 4.57, 3.40, 5.00 Nm (hip, knee, ankle) and activation RMS 0.0236 against
MTP's, close to the published run's 4.57, 3.38, 4.94 Nm and 0.0233; its synergies are the published ones in a
different order.

The recorded values live in `tests/helpers/ncpFixtureValues.m`, and
`tests/unit/NeuralControlPersonalization/NcpFixtureTest.m` checks that these files still match them, reading
them with `readStoFile` and `readstruct`, not nmsm-core. If you change a fixture on purpose, update both.
