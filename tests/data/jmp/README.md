# JMP test fixtures

Copied from the 2023 tests in `legacy/tests/JointModelPersonalization/`. The model is OpenSim's
`arm26` stripped down to two bodies (`r_humerus`, `r_ulna_radius_hand`), one coordinate
(`r_elbow_flex`), and six markers. The `.vtp` geometry files are not included; OpenSim warns about them
but they are not needed.

| File | What it is |
|---|---|
| `simple_arm.osim` | The "truth" model. |
| `simple_arm.trc` | Markers generated from `simple_arm.osim`: 120 frames at 60 Hz, 0 to 1.9833 s, in meters. IK on the truth model matches them with essentially zero error. |
| `simple_arm_translated_away.osim` | `r_elbow` parent frame x-translation moved from 0.0061 m to 0.0091 m (+3 mm). IK marker error is 1.8 mm RMS. |
| `simple_arm_oriented_away.osim` | `r_elbow` parent frame x-orientation rotated from 0 to 0.5 rad. IK marker error is 45 mm RMS. |

Running JMP on either `_away` model with this marker file should move the `r_elbow` parent frame back to
its value in `simple_arm.osim`.

The exact values live in `tests/helpers/jmpFixtureValues.m`, and `tests/unit/JointModelPersonalization/JmpFixtureTest.m`
checks that these files still match them. If you change a fixture on purpose, update both.

## `settings/`

JMP settings files for the parsing and regression tests (`Version="1.5.4"`).

| File | Purpose |
|---|---|
| `settings_minimal.xml` | Only the required elements. The base for every `bad_*` and `edge_*` file. |
| `settings_full.xml` | Every supported JMP option: tasks out of index order, a disabled task, a body set, a time range, marker names, bounds, and all optimizer parameters. (`<free_markers>` and `<anatomical_markers>` are left out on purpose; see `tests/README.md`.) |
| `settings_translation.xml` | Recover the translated-away elbow. Also used by the regression tests. |
| `settings_orientation.xml` | Recover the oriented-away elbow. Also used by the regression tests. |
| `bad_*.xml`, `edge_*.xml` | `settings_minimal.xml` with exactly one change, described in the comment at the top of each file. |

## `nominal/`

Output models from `settings_translation.xml` and `settings_orientation.xml`. The regression tests compare
new runs against them. Regenerate them only with `tests/regression/updateJmpNominal.m`, and only when a
change to JMP's results is intentional (see `tests/README.md`).

| File | `r_elbow` parent frame result | True value |
|---|---|---|
| `simple_arm_translated_jmp.osim` | x-translation 0.0060999782 m | 0.0061 m |
| `simple_arm_oriented_jmp.osim` | x-orientation -1e-9 rad | 0 rad |
