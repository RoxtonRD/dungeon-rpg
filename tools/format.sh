#!/usr/bin/env bash
# Formats every project GDScript file (never addons/) with the pinned
# gdtoolkit, keeps LF line endings, then runs the same check CI runs.
# Run it before every push: the PostToolUse hook only formats files edited
# through Claude's Edit/Write tools, and only when Python is found.
#
#   tools/format.sh          # format + check
#   tools/format.sh --check  # check only (what CI does)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if ! python -c "import gdtoolkit" 2>/dev/null; then
	echo "tools/format.sh: gdtoolkit missing. Install: python -m pip install -r tools/requirements-dev.txt" >&2
	exit 2
fi
if [ "${1:-}" != "--check" ]; then
	python -m gdtoolkit.formatter scripts test
	# gdformat writes CRLF on Windows; the repo stores LF.
	python - <<'PY'
import pathlib
for p in list(pathlib.Path("scripts").rglob("*.gd")) + list(pathlib.Path("test").rglob("*.gd")):
    b = p.read_bytes()
    if b"\r\n" in b:
        p.write_bytes(b.replace(b"\r\n", b"\n"))
PY
fi
python -m gdtoolkit.formatter --check scripts test
