---
name: write-brief
description: Write a task brief for a worker agent as a GitHub issue in Dungeons of Praesidium. Use when the advisor turns a PLAN.md step into work for gameplay-engineer, qa-balance, content-data, ui-assets or release-engineer.
---

# Writing a brief

A brief is the worker's **entire scope**. A good one lets a fresh session
finish without asking anything; a vague one produces improvisation.

## Before writing

1. Re-read the **Now** block and the relevant phase in `docs/PLAN.md`,
   and every `D-NNN` the task touches in `docs/DECISIONS.md`.
2. **Read the code the task touches**, and cite it as `file:line` in
   *Context*. Never brief from memory.
3. Pick **one** owner role. If the task needs two roles, split it into two
   briefs and state the order.
4. Check the collision rules (`PLAN.md` § Team):
   - Editor drivers (`gameplay-engineer`, `ui-assets`) run **one at a
     time**. Is another editor-driver issue in progress?
   - Does another open branch touch the same `.tscn` or the same file?
     (`gh pr list`, then `gh pr diff <n> --name-only`.)
   - Does it depend on an unmerged PR? Say so at the top: "Start after
     #N is merged."
5. Size it to **one sitting** that ends with something visible. If it
   doesn't fit, split it.

## Writing it

Use the sections in `.github/ISSUE_TEMPLATE/brief.md`:

- **Goal**: the outcome, not the implementation.
- **Required behaviour**: numbered, each one testable.
- **Out of scope**: name the tempting neighbours explicitly (save format,
  UI, balance numbers, other classes…).
- **How to verify**: exact steps and the tool to use (MCP `game_eval`,
  `tools/godot.sh`, a test, the smoke-test skill).
- **Start prompt**: always begins with "Read `.claude/agents/<role>.md`.
  That is your role…". Say **worktree or not**: editor drivers work in
  `C:\Dev\dungeon-rpg` without a worktree; everyone else uses a worktree.
  (There is no agent picker in Claude Desktop.)

## Publishing

1. Write the body to a file in the scratchpad.
2. Create the issue with its labels:
   `gh issue create --title "…" --label "agent:<role>" --label "phase:<n>" --body-file <file>`
3. Replace `<N>` in the start prompt with the real number, then
   `gh issue edit <N> --body-file <file>`.
4. Update the **Now** block in `docs/PLAN.md` so the issue appears in
   *Next up*.
5. Give Roxton the issue link and the start prompt, and say whether it
   can run now or must wait for something.
