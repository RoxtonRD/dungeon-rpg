#!/usr/bin/env bash
# Runs the gdUnit4 test suite (test/*_test.gd) headless via tools/godot.sh.
# Exits non-zero when anything fails (gdUnit4 exit codes: 100 test failures,
# 101 orphan-node warnings, 103-105 runner/script errors).
#
#   tools/test.sh                                          # everything in test/
#   tools/test.sh test/i18n_test.gd                        # one suite
#   tools/test.sh test/i18n_test.gd:test_no_duplicate_keys # one test
#   tools/test.sh -a res://test -i i18n_test               # raw gdUnit4 args
#
# Targets may be repeated. If the first argument starts with "-", all
# arguments go straight to gdUnit4's GdUnitCmdTool (see its -help).
# Reports (HTML + JUnit XML) go to .godot/test-reports/, which git and the
# editor both ignore.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/tools/godot.sh"

# Build the gdUnit4 arguments from the targets.
args=()
if [ $# -eq 0 ]; then
	args=(-a res://test)
elif [[ "$1" == -* ]]; then
	args=("$@")
else
	for target in "$@"; do
		target="${target#res://}"
		suite="${target%%:*}"
		if [ ! -f "$ROOT/$suite" ]; then
			echo "tools/test.sh: no such suite: $suite" >&2
			exit 2
		fi
		args+=(-a "res://$suite")
		if [[ "$target" == *:* ]]; then
			# gdUnit4 can't select one test, but it can ignore the others.
			only="${target#*:}"
			if ! grep -qE "^func $only\(" "$ROOT/$suite"; then
				echo "tools/test.sh: no test $only in $suite" >&2
				exit 2
			fi
			for other in $(sed -nE 's/^func (test_[A-Za-z0-9_]+)\(.*/\1/p' "$ROOT/$suite"); do
				[ "$other" != "$only" ] && args+=(-i "res://$suite:$other")
			done
		fi
	done
fi

# Always import first: a fresh worktree (or CI checkout) has no .godot/ yet,
# and gdUnit4 needs the global class cache to be current. A no-op import
# takes a few seconds.
if ! import_log="$("$GODOT" --import 2>&1)"; then
	echo "$import_log"
	echo "tools/test.sh: import failed" >&2
	exit 1
fi

"$GODOT" -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	--ignoreHeadlessMode -c -rd res://.godot/test-reports "${args[@]}"
code=$?
echo "tools/test.sh: exit code $code"
exit $code
