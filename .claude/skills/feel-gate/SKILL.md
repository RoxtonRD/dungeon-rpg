---
name: feel-gate
description: Run a feel gate in Dungeons of Praesidium. The advisor prepares a short scripted playtest for Roxton after a gameplay slice merges, then turns his answers into a recorded go / adjust / revise decision. Use whenever a change affects how the game plays.
---

# Feel gates

The bot measures numbers; only Roxton can say whether it's **fun**. A
feel gate is cheap: one sitting of 10–20 minutes, with the dev panel doing
the setup.

## Preparing it (advisor)

1. **Setup in 3 steps or fewer,** using the dev panel: `quick_party(level)`,
   `start_run`, `start_fight([...])`, `set_talent`, `swap_skill`. Name the
   exact fights, so his time goes into playing, not getting there.
2. **What to play:** 2–3 short scenarios. Where a choice is being tested,
   include a contrast ("first with X, then with Y").
3. **3–5 questions,** each answerable in a few words, and each tied to a
   pillar (`combat-v3.md` §1) or to the slice's own success criterion.
   Always end with "Anything confusing on screen?".
4. **A reminder:** quick party starts a new game and overwrites his save
   (D-018); tell him if that matters.

## Recording it (advisor)

Add a `D-NNN · Feel gate N …` entry to `DECISIONS.md`:
- **Passed:** what stays; any numbers he flagged go to the next tuning
  pass.
- **Adjust:** a short list of changes, then a quick re-check.
- **Revise:** the design changes before any rollout (the D-013 go/no-go).

Quote his own words for the key findings; they're the evidence. Then
update the **Now** block.

## Rules

- **Never roll out** (other classes, more content) past a failed or
  untaken gate.
- **One gate per slice,** so the questions stay focused.
- If he hasn't played yet, the gate stays open in the Now block. **Don't
  chase it within a session**; mention it once.
