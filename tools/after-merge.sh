#!/usr/bin/env bash
# After merging PRs on GitHub, bring the main checkout (the folder the Godot
# editor has open) up to date, safely.
#
#   tools/after-merge.sh            # do it
#   tools/after-merge.sh --dry-run  # only show what it would do
#
# Steps:
#   1. Refuses to run anywhere but the main checkout.
#   2. Local edits whose content is already identical on origin/main (e.g. a
#      plugin update that was just merged) are discarded. Any other local
#      edit stops the script and is listed, so nothing of yours is lost.
#   3. Switches to main, pulls (fast-forward only), deletes local branches
#      whose remote is gone, prunes stale worktree entries.
#   4. Says whether Godot needs a restart (project.godot or addons/ changed).
#   5. Prints the PLAN.md "Now" block and the open briefs.
set -euo pipefail

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

ROOT="${AFTER_MERGE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY" -eq 1 ]; then say "  (dry-run) $*"; else "$@"; fi; }

# 1. Main checkout only: a linked worktree has a different git dir.
if [ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ]; then
	say "after-merge: this is a linked worktree, not the main checkout. Run it in the main checkout."
	exit 1
fi

if [ "$DRY" -eq 1 ]; then
	say "== Dry run: nothing will be changed (no fetch; using the last fetched origin/main)"
else
	say "== Fetching"
	git fetch --prune -q origin
fi

# 2. Local edits.
say "== Checking local edits"
identical=()
real=()
while IFS= read -r f; do
	[ -z "$f" ] && continue
	upstream="$(git rev-parse -q --verify "origin/main:$f" 2>/dev/null || true)"
	if [ -f "$f" ] && [ -n "$upstream" ] && [ "$(git hash-object "$f")" = "$upstream" ]; then
		identical+=("$f")
	else
		real+=("$f")
	fi
done < <( { git diff --name-only; git diff --cached --name-only; } | sort -u )

if [ "${#real[@]}" -gt 0 ]; then
	say "after-merge: you have local edits that are NOT on origin/main:"
	printf '  %s\n' "${real[@]}"
	say "Commit them (or ask the advisor to), or discard them with 'git restore <file>', then run this again."
	exit 1
fi
# Untracked files that origin/main now tracks would block the pull. If a
# file is byte-identical upstream (e.g. an addon installed locally and then
# merged through a PR), it is safe to remove; anything else stops here.
untracked_same=()
while IFS= read -r f; do
	[ -z "$f" ] && continue
	upstream="$(git rev-parse -q --verify "origin/main:$f" 2>/dev/null || true)"
	[ -z "$upstream" ] && continue
	if [ "$(git hash-object "$f")" = "$upstream" ]; then
		untracked_same+=("$f")
	else
		real+=("$f (untracked, differs from origin/main)")
	fi
done < <(git ls-files --others --exclude-standard)

if [ "${#real[@]}" -gt 0 ]; then
	say "after-merge: you have local changes that are NOT on origin/main:"
	printf '  %s
' "${real[@]}"
	say "Commit them (or ask the advisor to), or discard them, then run this again."
	exit 1
fi
if [ "${#identical[@]}" -gt 0 ]; then
	say "  ${#identical[@]} local edit(s) already identical on origin/main; discarding the local copies."
	run git restore --staged --worktree -- "${identical[@]}"
fi
if [ "${#untracked_same[@]}" -gt 0 ]; then
	say "  ${#untracked_same[@]} untracked file(s) already identical on origin/main; removing the local copies."
	run rm -f -- "${untracked_same[@]}"
fi
if [ "${#identical[@]}" -eq 0 ] && [ "${#untracked_same[@]}" -eq 0 ]; then
	say "  none"
fi

# 3. Update main.
branch="$(git branch --show-current)"
if [ "$branch" != "main" ]; then
	ahead="$(git rev-list --count "origin/main..HEAD" 2>/dev/null || echo 0)"
	upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
	if [ -n "$upstream_ref" ] && git rev-parse -q --verify "$upstream_ref" >/dev/null; then
		unpushed="$(git rev-list --count "$upstream_ref..HEAD")"
	else
		unpushed="$ahead"
	fi
	if [ "$unpushed" -gt 0 ] && ! git merge-base --is-ancestor HEAD origin/main; then
		say "after-merge: branch '$branch' has $unpushed commit(s) that aren't merged or pushed. Push it or ask first."
		exit 1
	fi
	say "== Switching from '$branch' to main"
	run git switch -q main
fi

before="$(git rev-parse main)"
behind="$(git rev-list --count main..origin/main)"
say "== Pulling: main is $behind commit(s) behind origin/main"
run git merge --ff-only -q origin/main
after="$( [ "$DRY" -eq 1 ] && git rev-parse origin/main || git rev-parse main )"

say "== Deleting merged local branches"
gone="$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | awk '$2 == "[gone]" {print $1}')"
if [ -z "$gone" ]; then
	say "  none"
else
	for b in $gone; do
		if [ "$DRY" -eq 1 ]; then
			say "  (dry-run) git branch -d $b"
		elif git branch -d -q "$b" 2>/dev/null; then
			say "  deleted $b"
		else
			say "  kept $b (still checked out in a worktree, or not fully merged)"
		fi
	done
fi
run git worktree prune

# 4. Restart hint.
if [ "$before" != "$after" ] && git diff --name-only "$before" "$after" | grep -qE '^(project\.godot|addons/)'; then
	say "== RESTART GODOT: project.godot or addons/ changed in this update."
fi

# 5. Where we are.
say ""
CLAUDE_PROJECT_DIR="$ROOT" python "$ROOT/.claude/hooks/session_start.py" 2>/dev/null \
	|| say "(couldn't print the Now block: see docs/PLAN.md)"
