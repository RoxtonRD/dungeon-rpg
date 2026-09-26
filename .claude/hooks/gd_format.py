"""PostToolUse hook (Write|Edit): formats and syntax-checks the .gd file just saved.

Runs gdformat, then gdparse, on the edited file so every agent's diffs look
the same and syntax errors come back in seconds (D-014). Skips anything that
isn't a .gd file, anything under addons/ (vendored third-party code) and
anything outside a Godot project (no project.godot above it).

Exit codes (Claude Code hook protocol):
  0  nothing to report: formatted, skipped, or gdtoolkit not installed
     (then an install hint goes to the agent as extra context)
  2  gdparse (or gdformat) rejected the file; stderr goes back to the agent

gdtoolkit is called as `python -m gdtoolkit.<tool>` with the same Python that
runs this hook, so it works even when pip's Scripts folder isn't on PATH.
Install: python -m pip install -r tools/requirements-dev.txt

Pipe test (from the repo root):
  echo '{"tool_input": {"file_path": "scripts/party.gd"}}' | python .claude/hooks/gd_format.py
"""
import importlib.util
import json
import os
import pathlib
import subprocess
import sys

INSTALL_HINT = (
    "gd_format hook: gdtoolkit is not installed, so this .gd file was not "
    "formatted or syntax-checked. Install it with: "
    "python -m pip install -r tools/requirements-dev.txt"
)
MAX_ERROR_LINES = 30


def project_root(path: pathlib.Path) -> pathlib.Path | None:
    """Nearest folder above path with a project.godot (works in worktrees)."""
    for folder in path.parents:
        if (folder / "project.godot").is_file():
            return folder
    return None


def edited_gd_file() -> tuple[pathlib.Path, pathlib.Path] | None:
    """(file, project root) for the .gd file this tool call wrote, or None."""
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return None
    file_path = (event.get("tool_input") or {}).get("file_path")
    if not file_path or not file_path.endswith(".gd"):
        return None
    path = pathlib.Path(file_path)
    if not path.is_absolute():
        path = pathlib.Path(event.get("cwd") or os.getcwd()) / path
    path = path.resolve()
    root = project_root(path)
    if root is None or not path.is_file():
        return None  # outside a Godot project, or deleted
    if path.relative_to(root).parts[0] == "addons":
        return None  # vendored code: never format
    return path, root


def run_tool(module: str, path: pathlib.Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, "-m", f"gdtoolkit.{module}", str(path)],
        capture_output=True, text=True, encoding="utf-8", timeout=25,
    )


def keep_lf(path: pathlib.Path) -> None:
    """gdformat writes CRLF on Windows; the repo stores .gd files as LF."""
    data = path.read_bytes()
    if b"\r\n" in data:
        path.write_bytes(data.replace(b"\r\n", b"\n"))


def fail(tool: str, name: str, result: subprocess.CompletedProcess) -> None:
    lines = (result.stderr or result.stdout).strip().splitlines()
    if len(lines) > MAX_ERROR_LINES:
        lines = lines[:MAX_ERROR_LINES] + ["..."]
    print(f"{tool} rejected {name}:", *lines, sep="\n", file=sys.stderr)
    sys.exit(2)


def main() -> None:
    edited = edited_gd_file()
    if edited is None:
        return
    path, root = edited
    name = path.relative_to(root).as_posix()
    if importlib.util.find_spec("gdtoolkit") is None:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PostToolUse", "additionalContext": INSTALL_HINT,
        }}))
        return
    had_crlf = b"\r\n" in path.read_bytes()
    formatted = run_tool("formatter", path)
    if not had_crlf:
        keep_lf(path)
    parsed = run_tool("parser", path)
    if parsed.returncode != 0:
        fail("gdparse", name, parsed)
    if formatted.returncode != 0:
        fail("gdformat", name, formatted)


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.TimeoutExpired) as error:
        # Never block an edit because the hook itself broke.
        print(f"gd_format hook skipped: {error}", file=sys.stderr)
