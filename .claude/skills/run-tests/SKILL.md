---
name: run-tests
description: Run the Dungeons of Praesidium gdUnit4 test suite headless (all of it, one suite, or one test) with tools/test.sh, and read the failures. Use before opening any PR, after touching .tres/.gd/translations, or when CI's "Tests" check is red. Safe to run alongside the editor session.
---

# Run tests

The suite lives in `test/` (files named `*_test.gd`, gdUnit4 v6.2.1
vendored in `addons/gdUnit4/`). It runs headless through
`tools/godot.sh`, so it never touches the open editor or the Godot MCP.
It loads files and reads the CSV only; it never reads or writes a save.

## Commands

Run from the repo root (Git Bash on Windows, or any bash).

| What | Command |
|---|---|
| Everything | `tools/test.sh` |
| One suite | `tools/test.sh test/i18n_test.gd` |
| One test | `tools/test.sh test/i18n_test.gd:test_no_duplicate_keys` |
| Several | `tools/test.sh test/i18n_test.gd test/resources_load_test.gd` |
| Raw gdUnit4 flags | `tools/test.sh -a res://test -i i18n_test` (first arg starts with `-`) |

`tools/test.sh` always runs `--import` first (a few seconds; needed in a
fresh worktree or CI checkout, harmless otherwise). Set `GODOT_BIN` if
Godot isn't at the Steam path in `tools/godot.sh`.

Exit code: `0` all passed; `100` a test failed; `101` orphan nodes
(treated as a failure here and in CI); `103`-`105` runner or script
errors (a test file didn't compile, bad arguments). `2` is `test.sh`
itself rejecting a target that doesn't exist.

## Reading the output

Each test prints `STARTED` then `PASSED` or `FAILED`. Under a failure,
`Report:` shows one problem per line, e.g.

```
res://test/i18n_test.gd > test_every_row_has_pt_br_and_en FAILED
  Report:
  Incomplete CSV rows (1):
  line 271 SKIN_SERAPH: empty pt_BR
```

- Ignore the per-suite `Statistics: ... PASSED` timing word; the counts
  and the final `Overall Summary` line are what matter.
- The `ERROR:` blocks with GDScript backtraces above a failure are the raw
  engine log for the same problem. The `Report:` lines are the summary.
- A broken `.tres` shows up for itself *and* for every `.tres` that
  references it (e.g. a broken skill also fails its class). Fix the first
  file in the chain.
- A script parse error shows up for that script and for every script that
  uses its `class_name` ("Could not resolve class X"). Fix the one with the
  real parse error.
- HTML and JUnit XML reports land in `.godot/test-reports/report_N/`
  (git-ignored). Open `index.html` for a browsable view.

## What the suites check

- `resources_load_test.gd`: every `.tres` under `resources/` and every
  `.gd` under `scripts/` loads (cache bypassed) with no engine error.
- `i18n_test.gd`: CSV header is `keys,pt_BR,en`; every row has non-empty
  `pt_BR` and `en`; no duplicate or empty keys; every `display_name` /
  `description` key in a `.tres` exists in the CSV.

## CI

`.github/workflows/tests.yml` runs the same `test/` folder on every PR and
on pushes to `main` with Godot 4.7.2, via `gdUnit4-action` using the
vendored gdUnit4. The JUnit report appears as the `gdunit4-report` check
on the PR, and the full report is uploaded as a workflow artifact. If CI
is red, run `tools/test.sh` locally first: it should fail the same way.

## Adding a test

New file `test/<thing>_test.gd`, `extends GdUnitTestSuite`, functions
named `test_*`. Shared helpers go in `test/support/` (not picked up as
suites). Never touch `user://save.json`: build throwaway objects instead
(see the SAFETY note in `scripts/dev/balance_sim.gd`).
