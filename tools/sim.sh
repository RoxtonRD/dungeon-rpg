#!/usr/bin/env bash
# Runs the balance sim headless and prints its Markdown report. The sim needs
# the autoloads (Party, GameState), so it runs as a scene, not a -s script.
# It never saves the game (see scripts/dev/balance_sim.gd).
#
#   tools/sim.sh all --fights 200                   # every talent build
#   tools/sim.sh tank --seed 7 --level 10           # one build, all heroes L10
#   tools/sim.sh all --fights 200 --out docs/reports/sim-warrior-talents.md
#
# Options: --fights N (per cell, default 100), --seed N (default 1),
# --level N (override LEVEL_BY_DUNGEON), --out PATH (also write the report).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/tools/godot.sh"

# A fresh worktree has no .godot/ yet: import first (a no-op import is quick).
if ! import_log="$("$GODOT" --import 2>&1)"; then
	echo "$import_log"
	echo "tools/sim.sh: import failed" >&2
	exit 1
fi

exec "$GODOT" res://scripts/dev/sim_runner.tscn -- "$@"
