"""SessionStart hook: prints the re-entry context every session starts with.

Prints the **Now** block of docs/PLAN.md and the open agent-labelled GitHub
issues. Output goes into the session's context, so every agent begins
knowing where the project stands. Never fails the session: any error is
reported as a one-line note instead.
"""
import os
import pathlib
import subprocess
import sys

# Windows consoles default to a legacy code page; PLAN.md is UTF-8.
sys.stdout.reconfigure(encoding="utf-8")

root = pathlib.Path(os.environ.get("CLAUDE_PROJECT_DIR", ".")).resolve()


def now_block() -> str:
    plan = root / "docs" / "PLAN.md"
    try:
        lines = plan.read_text(encoding="utf-8").splitlines()
    except OSError:
        return "(docs/PLAN.md not found)"
    out, inside = [], False
    for line in lines:
        if line.startswith("## "):
            if inside:
                break
            inside = line.strip() == "## Now"
            continue
        if inside and line.strip() != "---":
            out.append(line)
    return "\n".join(out).strip() or "(Now block is empty)"


def open_briefs() -> str:
    try:
        result = subprocess.run(
            ["gh", "issue", "list", "--state", "open", "--limit", "15",
             "--json", "number,title,labels",
             "--template",
             '{{range .}}#{{.number}} {{.title}} [{{range .labels}}{{.name}} {{end}}]\n{{end}}'],
            cwd=root, capture_output=True, text=True, timeout=8,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "(could not reach GitHub — run `gh issue list` manually)"
    if result.returncode != 0:
        return "(gh issue list failed — is gh logged in?)"
    return result.stdout.strip() or "(no open issues)"


print("=== Dungeons of Praesidium — where we are (docs/PLAN.md § Now) ===")
print(now_block())
print()
print("=== Open briefs (GitHub issues) ===")
print(open_briefs())
