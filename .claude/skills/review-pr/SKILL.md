---
name: review-pr
description: Review a worker agent's pull request against its brief in Dungeons of Praesidium, then give Roxton a merge / fix-first verdict. Use when a worker reports "PR N is ready" or Roxton asks for a review. Never merges.
---

# Reviewing a worker PR

The question is not only "is the code good" but "**did it do the brief,
only the brief, and prove it**".

## Steps

1. **Load both sides.**
   - `gh pr view <N>` (description, linked issue, checks)
   - `gh issue view <issue>` (the brief)
   - `gh pr diff <N>` (the change)
2. **CI:** `gh pr checks <N>`. Red CI means fix-first, full stop.
3. **Brief compliance:**
   - Every *Required behaviour* item is implemented.
   - Every *How to verify* step is reported **with results**, not "should
     work".
   - Nothing from *Out of scope* crept in. Unrequested refactors and
     "while I was here" fixes count as scope creep.
4. **Project rules:**
   - **Saves (D-004):** does anything change what `to_dict()` or
     `save_game()` writes? Is it declared in the PR checklist? After the
     save freeze line, is there a migration and a fixture test?
   - **i18n:** no hardcoded user-facing strings; new keys have both
     `pt_BR` and `en`. (Dev-only UI is exempt: D-015.)
   - **Data-driven:** content lives in `.tres` files, not code.
   - **Scenes:** `.tscn` files touched, and does any other open PR touch
     the same ones?
   - **Balance:** changed numbers are listed before → after.
5. **Code quality:** run the built-in `/code-review` on the PR for
   correctness bugs. Keep only findings that matter; the codebase values
   readable over clever.
6. **Feel changes:** if the change affects how the game *plays*, the
   verdict includes "Roxton should play-test X before merging", naming
   exactly what to try (the dev panel makes this quick).

## Verdict

Reply to Roxton with one of:

- **Merge**: one line on what it does, anything to play-test first.
- **Fix first**: a numbered list of the required fixes. Post the same list
  as a PR comment (`gh pr comment <N> --body-file …`) so the worker
  session can pick it up.

Then update the **Now** block after he merges. Never run `gh pr merge`
(it is denied in `.claude/settings.json` anyway).
