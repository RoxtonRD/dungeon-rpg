#!/usr/bin/env bash
# Builds the Android debug APK from the command line, headless, via
# tools/godot.sh. Works from a fresh worktree: it imports the project and
# installs the Gradle build template (/android/, gitignored) when missing.
#
#   tools/export_android.sh
#
# Output: build/praesidium-debug.apk, signed with the editor's debug
# keystore. Install it with the adb command in docs/release/android.md.
# The first run downloads Gradle and its dependencies, so it needs network
# and takes a few minutes; later runs are faster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/tools/godot.sh"
# The preset's name in export_presets.cfg (its platform is Android).
PRESET="Dungeons of Praesidium"
APK="build/praesidium-debug.apk"

cd "$ROOT"
mkdir -p build

# 1. Import. A fresh worktree has no .godot/ cache, and the export needs it.
echo "== Importing project"
"$GODOT" --import

# 2. The Gradle build template must match the engine version exactly, or
#    the export fails with a version-mismatch error.
engine_version="$("$GODOT" --version | tr -d '\r' | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z]+' | head -n 1)"
extra_args=()
if [ ! -f android/.build_version ]; then
	echo "== No Android build template; installing $engine_version"
	extra_args+=(--install-android-build-template)
else
	template_version="$(tr -d '\r\n' < android/.build_version)"
	if [ "$template_version" != "$engine_version" ]; then
		echo "tools/export_android.sh: android/ holds the $template_version build" >&2
		echo "template, but the engine is $engine_version. Delete android/ and run" >&2
		echo "this script again to reinstall it (see docs/release/android.md)." >&2
		exit 1
	fi
fi

# 3. Export. The old APK goes first, so a failed export can't leave a
#    stale file that looks like a fresh one.
rm -f "$APK"
echo "== Exporting debug APK (preset \"$PRESET\")"
"$GODOT" "${extra_args[@]}" --export-debug "$PRESET" "$APK"

if [ ! -f "$APK" ]; then
	echo "tools/export_android.sh: export finished but $APK is missing" >&2
	exit 1
fi

size_bytes="$(wc -c < "$APK" | tr -d ' ')"
echo
echo "APK:  $ROOT/$APK"
echo "Size: $((size_bytes / 1024 / 1024)) MB ($size_bytes bytes)"
