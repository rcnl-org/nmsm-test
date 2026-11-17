# MTP test fixtures

Copied from the reduced-muscle tutorial problem in
`nmsm-tutorial/Step-4-Muscle-Tendon-Personalization` (nmsm-tutorial commit `143acf9`). The `Geometry/`
folder and `preprocessed/GRFData/` are not included: MTP does not need them, and OpenSim's warnings about
missing `.vtp` files are hidden by `runTests`.

| File or folder | What it is |
|---|---|
| `UF_Subject_3_reduced_muscles.osim` | Full-body model with only nine muscles, all on the right leg: `bflh_r bfsh_r gasmed_r glmax2_r iliacus_r recfem_r soleus_r tibant_r vasmed_r`. Each spans at least one of `hip_flexion_r knee_angle_r ankle_angle_r`. The model also holds the muscle groups (ObjectGroups) the settings files refer to. |
| `preprocessed/` | One gait trial, `gait_1`, in the layout the data preprocessing tool writes: `IKData`, `IDData` and `MAData/gait_1` (muscle-tendon lengths, velocities and moment arms) with 101 frames from 0.5 s to 1.6 s, and `EMGData` with 28 channels and the same time step, padded by 19 frames on each side (0.291 s to 1.809 s). |
| `passive_moment_data/` | Twelve passive trials (hip, knee and ankle, four each) for Muscle-Tendon Length Initialization: `IDData` with passive moments for six right-leg coordinates, `IKData`, and `MAData/<trial>` with muscle-tendon lengths and moment arms, 101 frames each. |

EMG is collected for eight channels (`GlutMaxLat RecFem BicFemLong BicFemShort VastMed GasMed Sol TibAnt`),
each mapped to one muscle. `iliacus_r` has no EMG; it is in `HipFlexorsMissingEMGChannelGroup`, and synergy
extrapolation estimates its excitation.

## `settings/`

MTP settings files for the parsing and regression tests (`Version="1.5.4"`, written for nmsm-core
`candidate-1.5.4`, which uses the older cost term names such as `emg_scale_factor`).

| File | Purpose |
|---|---|
| `settings_minimal.xml` | Only the elements the 1.5.4 parser requires (the muscle group lists are required but empty). Synergy extrapolation and Muscle-Tendon Length Initialization disabled. The base for every `bad_*` and `edge_*` file. |
| `settings_full.xml` | Every option, mostly with non-default values: trial prefixes, optimizer settings, MTLI with every cost term, synergy extrapolation, and three tasks listed out of index order with one disabled. |
| `settings_tutorial.xml` | The tutorial's `MTPSettingsV1.xml` with only the version changed. Used by the regression tests. |
| `settings_synthetic_emg_scale.xml`, `settings_synthetic_all.xml`, `settings_synthetic_two_trials.xml` | The synthetic known-truth MTP cases (below): synthetic model and data, moment tracking only, no synergy extrapolation or MTLI. `emg_scale` optimizes only EMG scale factors; `all` and `two_trials` all six parameter types, on one and two trials. Used by the regression tests. |
| `settings_synthetic_passive.xml` | The synthetic known-truth MTLI case (below): passive moment tracking only, maximum isometric force and muscle stress fixed. MTP then runs for one iteration without optimizing lengths, so the lengths it reports are MTLI's. Used by the regression tests. |
| `bad_*.xml`, `edge_*.xml` | `settings_minimal.xml` with one change, described in the comment at the top of each file. (`edge_synergy_extrapolation_enabled` and `edge_mtli_enabled` add the elements that enabling the section requires; `edge_mtli_without_passive_data` is `edge_mtli_enabled` with an empty passive data folder.) |

On 1.5.4, `<input_osimx_file/>` and each task's `<muscle_specific_electromechanical_delays>` are required even
though the first may be empty and the second is not used.

## `synthetic/`

Known-truth problems for the regression tests. Real gait data has no true muscle parameters, so these are
made up: pick "true" parameters, compute the joint moments MTP's own forward model (`calcMtpModeledValues`)
gives at them, and use those as the inverse dynamics moments. MTP started from its usual starting values
(delay 0.5, activation time constant 1.5, nonlinearity 0.05, EMG scale 0.5, length scale factors 1) should
then find the true parameters again. All of it is written by `synthetic/generateMtpSyntheticData.m`.

| File or folder | What it is |
|---|---|
| `UF_Subject_3_reduced_muscles_synthetic.osim` | The fixture model with the optimal fiber and tendon slack lengths of 7 muscles changed. With the fixture model's own lengths, `gasmed_r`, `recfem_r` and `soleus_r` reach normalized fiber lengths of 1.45 to 1.53, past the 1.3 MTP allows, so no truth near the starting values could be found again. Each muscle whose range is outside 0.45 to 1.15 got lengths that center its range on 0.8 and make it at most 0.7 wide. Forces, pennation angles and geometry are unchanged. |
| `emg_scale/` | `preprocessed/` with the three tracked ID moments replaced: true EMG scale factors, every other parameter at the starting values. Starting values miss these moments by 18, 10 and 13 Nm RMS (hip, knee, ankle). |
| `all/` | The same with true values for all six parameter types. Starting values miss by 12, 5 and 18 Nm RMS. |
| `two_trials/` | `rebuilt/preprocessed/` (two gait trials, below) with the tracked ID moments replaced, at the same true values as `all/`. With one trial the parameters trade off against each other; a second movement pins most of them down. |
| `passive/` | `passive_moment_data/` with every passive ID moment replaced by what MTLI's forward model (`calcMuscleTendonLengthInitializationModeledValues`) gives for the fixture model at true optimal fiber and tendon slack length scale factors, with maximum isometric force fixed. Starting values miss by 18 Nm RMS. |

The true values are in `tests/helpers/mtpFixtureValues.m` (`synthetic`), and
`tests/unit/MuscleTendonPersonalization/MtpSyntheticDataTest.m` checks that the files still match them: the
model only changed lengths and stays within the limits, only the replaced moments changed, and the forward
model at the truth reproduces them.

Things to know:
- **`iliacus_r` is not identifiable** in these cases: without synergy extrapolation it has no EMG, so its
  activation parameters stay at the starting values in the truth too.
- **The truth comes from nmsm-core's own forward model**, so a bug in that model is built into it. The unit
  tests in `tests/unit/core` and `tests/unit/MuscleTendonPersonalization` check the model against values
  worked out by hand.
- **To regenerate** (only if a fixture or true value changes on purpose), with the project open:
  `addpath("tests/data/mtp/synthetic"); generateMtpSyntheticData()`, then run `MtpSyntheticDataTest` and
  commit the regenerated files.

## `rebuilt/`

Two consecutive gait cycles, `gait_1` (0.5 to 1.6 s) and `gait_2` (1.6 to 2.7 s), for the two-trial synthetic
case. The tutorial's data preprocessing script defines both trials, but only `gait_1` was kept for its MTP step,
and the IK, ID and muscle analysis results it starts from are not in the tutorial repository.
`rebuilt/rebuildGaitTrials.m` makes them from the tutorial's raw data
(`nmsm-tutorial/Step-3-Data-Preprocessing/input_data`): OpenSim IK, ID and muscle analysis with the tutorial's
settings files and the fixture model over 0 to 4 s, then the tutorial's preprocessing steps. Rerunning it gives
the same files byte for byte.

These are **not identical to `preprocessed/`** (the tutorial's own `gait_1`): muscle-tendon lengths and moment
arms agree to about 1 mm, but EMG is normalized over these 4 s instead of the full 60 s recording, and IK and ID
differ. That does not matter for the synthetic case, which needs both trials from one consistent pipeline, and
whose moments are replaced anyway. `MtpSyntheticDataTest` checks the two trials' time grids.

## `nominal/`

Results of the five regression runs (`emgScale`, `all`, `twoTrials`, `passive`, `tutorial`):
`<case>_muscleModelParameters.sto` and, per trial, `<case>_<trial>_modelJointMoments.sto`, copied from MTP's
`Analysis` folder. The regression tests compare new runs
against them; two runs on the same machine agree exactly. Regenerate them only with
`tests/regression/updateMtpNominal.m`, and only when a change to MTP's results is intentional (see
`tests/README.md`).

What the runs give (nmsm-core `main` at v1.5.4, same MTP as `candidate-1.5.4`):

| Case | Result |
|---|---|
| `emgScale` | All 8 EMG scale factors within 1e-4 of the truth; moment RMS 0.0003–0.001 Nm. |
| `all` | Moment RMS 0.16, 0.11, 0.09 Nm, but parameters off the truth by up to 0.15 (length scale factors), 0.1 (EMG scale factors) and 0.08 (nonlinearity): with one trial and moment tracking alone they trade off against each other. fmincon stops at the same point with a step tolerance of 1e-10. |
| `twoTrials` | Moment RMS about 0.09 Nm on both trials. Largest misses from the truth, against `all`'s: activation time constant 0.0006 s (0.0036), nonlinearity 0.006 (0.077), delay 0.0009 s (0.0125), EMG scale 0.016 (0.10), optimal fiber length scale 0.039 (0.15), tendon slack length scale 0.059 (0.13). |
| `passive` | All 18 length scale factors within 2.3e-4 of the truth; passive moment RMS 3e-5 Nm. |
| `tutorial` | The tutorial's published parameters exactly; moment RMS 5.78, 6.52, 7.45 Nm with the synergy model (18.8, 11.7, 9.3 Nm without). Several parameters end on a bound (activation time constant 0.0075 s, nonlinearity 0, delay 0). |

The recorded values (muscle names and properties, groups, frame counts, time ranges) live in
`tests/helpers/mtpFixtureValues.m`, and `tests/unit/MuscleTendonPersonalization/MtpFixtureTest.m` checks that
these files still match them. That test reads the data with `tests/helpers/readStoFile.m`, not with
nmsm-core, so it does not depend on the code being tested. If you change a fixture on purpose, update both.
