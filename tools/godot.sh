#!/usr/bin/env bash
# Headless Godot for tests, the balance sim and scripted checks.
# Never talks to the open editor, so it is safe to run alongside the
# session that drives the Godot MCP.
#
#   tools/godot.sh --version
#   tools/godot.sh --import                 # first run in a fresh worktree
#   tools/godot.sh -s res://path/to/script.gd
#
# Set GODOT_BIN to override the executable (CI does this).
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec "$GODOT_BIN" --headless --path "$PROJECT_DIR" "$@"
