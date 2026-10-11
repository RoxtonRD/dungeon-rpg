---
name: balance-loop
description: Tune Dungeons of Praesidium's difficulty with the campaign bot. Measure, compare against the targets, change one lever, re-measure, and report. Use for any balance task, so numbers change because of data rather than guesses.
---

# The balance loop

## Targets (current: D-034, D-036, D-038)

| Metric | Target |
|---|---|
| Level at the D1/D2/D3/D4 boss | ≈ 4 / 6 / 8 / 10 (the ×3 curve; don't break it) |
| Rounds per fight | normal 3–5, elite 5–7, boss 8–10 |
| Boss first-try win (bot) | 70–85% per dungeon |
| Wipes per campaign (bot, with retries) | 0.3–1.5, never "stuck" |
| Combat minutes per dungeon | 8–12 (walking and menus add the rest of the 15–20 min target) |
| Warrior | 3+ distinct skills per fight; no skill above 50% of actions |

## The loop

1. **Measure:**
   `tools/sim.sh campaign --runs 100 --seed 1 --xp-mult 1 --out docs/reports/<topic>.md`.
   Use `tools/sim.sh all` too when per-fight detail helps.
2. **Compare** every metric with the targets. Write the gap down.
3. **Change one lever,** the smallest that addresses the biggest gap, in
   this order of preference:
   1. enemy numbers in `resources/enemies/*.tres` (HP first, then ATK);
   2. group composition or weights;
   3. the scaling constants in `dungeon_run.gd` (`FLOOR_SCALE`,
      `DUNGEON_GROWTH`).

   **Don't touch hero-side numbers** (classes, skills, talents, XP)
   without the advisor's OK.
4. **Re-measure with the same seed.** Keep a before → after table for each
   change.
5. **Stop** when all metrics are in range, after 6 iterations, or when one
   lever fights another (e.g. longer fights push wipes out of range).
   Report what's left.

## Report

- The final table against the targets, plus one line per change (lever,
  before → after, why).
- Anything **mechanically fine but boring** the bot shows: one skill
  spammed, a group always ignored, an elite never worth taking.
- **Run `tools/format.sh` before pushing** if any `.gd` changed.
