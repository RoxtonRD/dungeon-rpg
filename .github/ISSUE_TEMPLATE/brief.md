---
name: Agent brief
about: A task for one agent role (written by the advisor)
title: ""
labels: []
---

<!-- Labels: exactly one `agent:<role>` and one `phase:<n>`. -->

## Goal

<!-- One or two sentences: what is true when this is done, and why it matters.
     Link the PLAN.md step and any D-NNN decisions. -->

## Context

<!-- What exists today, with file:line references. Only what the worker needs. -->

## Required behaviour

<!-- Numbered, testable statements. -->

1.

## In scope

-

## Out of scope

<!-- Name the tempting neighbours explicitly. -->

-

## How to verify

<!-- Editor via MCP, headless test, bot report or screenshot, with exact steps. -->

1.

## Done when

- [ ] Verification steps pass and are reported in the PR
- [ ] CI is green
- [ ] PR closes this issue; description covers save format / balance / i18n impact

---

## Start prompt

Start a new session in <!-- `C:\Dev\dungeon-rpg` WITHOUT a worktree (editor drivers)
OR a worktree (everyone else) --> and paste:

> Read `.claude/agents/<role>.md`. That is your role for this whole
> session; follow it as if it were your system prompt. Then get the
> latest code: editor drivers run `git switch main && git pull`; worktree
> sessions run `git fetch origin` and branch from `origin/main`. Read your
> brief with `gh issue view <N>` and follow it exactly. It is your whole
> scope. Work on branch `<type>/<slug>`, verify as the brief describes,
> then commit, push and open a PR that closes the issue. Don't merge.
> When you're done, report the PR link, the verification results, and
> anything in the brief that was wrong or unclear.
