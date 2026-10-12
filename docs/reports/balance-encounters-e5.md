# Balance: encounters E5b (#90)

The balance loop for fewer, longer fights (D-043). E5a (#92) cut the fight
quota; this pass re-tuned enemy numbers and the scaling constants against
the E5b targets in 8 iterations.

**Conditions for every number below:**
- Command: `tools/sim.sh campaign --runs 100 --seed 1 --xp-mult 1`.
- Party: warrior, cleric, rogue, mage. They start at level 1 with the starter
  items, the Warrior uses the `executioner` build order, and the game's own
  XP applies (×1 in the bot).
- Gear: one tier behind the depth (D1 none, D2 common, D3 uncommon, D4 rare).
- Sample: 100 campaigns of dungeons 1–4, wipes retried. Each iteration
  replays the same seed.
- The full generated output for the final state is in
  [`sim-campaign.md`](sim-campaign.md).

## Final targets table

| Metric | Target | D1 | D2 | D3 | D4 | Met? |
|---|---|---|---|---|---|---|
| Fights (clearing run, incl. elites and boss) | ~10 required + elites (#90 correction) | 11.2 | 11.7 | 11.6 | 11.4 | yes (quota unchanged) |
| Rounds, normal fight | 4–5 | 4.3 | 3.4 | 4.1 | 4.4 | D1, D3, D4 |
| Rounds, elite fight | 5–7 | 6.7 | 5.2 | 6.8 | 7.4 | D1–D3 (D4 just over) |
| Rounds, boss fight | 8–10 | 7.0 | 6.0 | 7.6 | 8.9 | D4 only |
| Boss first-try win | 70–85% | 75% | 97% | 95% | 74% | D1, D4 |
| Wipes per campaign | 0.3–1.5 total, D1 ≤ 0.3 | 0.46 | 0.03 | 0.05 | 0.33 | **0.87 total: yes**; D1 no |
| Stuck (campaign ends) | never | 0% | 0% | 0% | 1% | 1 of 100 |
| Elite win when taken | 80–90% | 99% (135/136) | 100% | 100% | 100% | no |
| Level at boss | ≈ 4 / 6 / 8 / 10 (±1) | 4.6 | 6.6 | 8.7 | 10.0 | **yes** |
| Combat minutes | 8–12 | 16.8 | 15.1 | 18.8 | 20.6 | no |
| Warrior skills per fight | 3+ | 1.9 | 2.4 | 2.7 | 2.9 | no (D4 close) |
| Warrior top skill | ≤ 50% | slash 74% | slash 48% | slash 46% | slash 33% | D2–D4 |

Rounds count from 1. Elites: 612 taken of 867 met (71%); 611 won.

## Changes, one per iteration

Iteration 0 is E5a as merged: normal rounds 2.9 / 2.1 / 2.3 / 2.3, boss
first-try 58 / 96 / 99 / 87%, wipes 0.82 / 0.04 / 0.01 / 0.15 (1.02 total),
elites 683 / 684 won, level at boss 5.7 / 7.6 / 9.4 / 10.0, combat minutes
10.7 / 9.6 / 11.3 / 12.0.

| # | Lever | Change | Why | Before → after |
|---|---|---|---|---|
| 1 | Enemy HP, non-boss | every `max_hp` ×2 | normal fights 2.1–2.9 rounds against 4–5 | normal rounds 2.9/2.1/2.3/2.3 → 4.3/3.3/3.7/3.9; elite rounds → 5.5–7.0; wipes 1.02 → 3.28 (D1 0.82 → 1.67); minutes → 14–18 |
| 2 | Enemy ATK/MAG, non-boss | every `atk`, `mag` ×0.8 (rounded) | pull wipes back down after step 1 | wipes 3.28 → 2.26 (D1 1.67 → 1.45); D4 stuck 22% → 6% |
| 3 | `FLOOR_SCALE` | 0.15 → 0.08 | D1 wipes sit at F3/F4 and the boss | wipes 2.26 → 1.33 (D1 1.45 → 1.06); level at D1 boss 6.2 → 5.5 |
| 4 | F4 damage dealers | cultist `mag` 4 → 3, orc `atk` 5 → 4 | the top D1 killers were F4 orc/cultist groups | D1 wipes 1.06 → 0.95; total 1.33 → 1.15 |
| 5 | `DUNGEON_GROWTH` | 1.4 → 1.6 | D2–D4 bosses won 91–96% with ~0 wipes | boss first-try D2/D3/D4 96/94/91 → 82/64/13%; D4 stuck 0 → 73%; normal rounds D3/D4 3.6/3.6 → 4.2/4.9 |
| 6 | `FLOOR_SCALE` | 0.08 → 0 | ease D1 F4 and every boss; the groups already ramp by floor | D1 wipes 0.96 → 0.62; D4 stuck 73 → 12%; total 4.10 → 1.58; level at bosses 5.4/7.6/9.7 → 4.9/6.8/8.9 |
| 7 | Boss ATK/MAG | dragon `atk` 9 → 7, `mag` 8 → 6; necromancer `atk` 3 → 2, `mag` 7 → 6 | they did 63 of the 72 D4 boss wipes and 17 of 23 at D1 | D4 boss first-try 58 → 74%, stuck 12 → 2%; D1 wipes 0.62 → 0.54; D3 boss 85 → 98% |
| 8 | Orc ATK | 4 → 3 | D1 F4 orc groups still the top normal-fight killers | D1 wipes 0.54 → 0.46 (F4 wipes 31 → 20); total 1.01 → 0.87 |

Enemy numbers are in `resources/enemies/*.tres`; `FLOOR_SCALE` and
`DUNGEON_GROWTH` are in `scripts/dungeon/dungeon_run.gd`. No hero-side
numbers, XP, talents, quota, groups or elite reward multipliers changed, so
`FALLBACK_IDS` is still in step.

## Targets missed, and why

- **D1 wipes 0.46 (target ≤ 0.3).** Of the 46 D1 wipes, 20 happen at F4 and 25 at the
  boss. Fights that wipe the party cost it only 7–15% HP, and the party
  enters the boss at 64% HP: this is attrition. A level 1–5 party with no
  gear and **no SP spent inside the dungeon** (the bot spends SP only in the
  city) plays 11 fights of 4+ rounds. Every lever that eases D1 also eases
  D2–D4, because the floor groups and bosses are shared and D1 is the
  1.0 baseline.
- **D2 and D3 are too easy (boss 95–97%, 0.03–0.05 wipes).** The difficulty curve the
  heroes need is not geometric. D1 → D2 needs a big step: the party gains
  gear, spends its D1 SP and is ~2 levels up. D3 → D4 needs a small one:
  level cap 10. `DUNGEON_GROWTH` is a constant ratio, so 1.6 broke D4 (73%
  stuck) before D2 reached 82%. Fixing D2/D3 needs a per-dungeon
  multiplier (e.g. `[1.0, 1.7, 2.6, 3.5]` instead of `pow`). That is a code
  change, outside the brief's levers.
- **Combat minutes 15–21 (target 8–12).** With the minutes model (5 s per
  party action), 12 minutes at ~11.5 fights is ~10 party actions per fight,
  about **3 rounds**. Normal fights of 4–5 rounds give 16–20 minutes. As in
  E4, the two targets conflict at this fight count, and this pass chose
  rounds (D-043, "let's try the longer fights"). Roxton's re-check should
  say which one gives.
- **Elites are still free: 611 of 612 won.** The bot takes an elite only at ≥ 70% HP,
  and at that HP normal fights in D2–D4 never kill either. Elite-only
  difficulty (the warlord, extra members) also lands in D1's F2–F4, where
  every lost elite is a D1 wipe. 80–90% elites and D1 ≤ 0.3 can't both
  hold with shared groups. An elite-only scale that grows by dungeon (e.g.
  `ELITE_SCALE = [1.0, 1.15, 1.25, 1.3]`) would decouple them.
- **Boss rounds D1–D3 6.0–7.6 (target 8–10).** Boss HP was left alone, because more HP
  pushes the D1 boss out of range.
- **Warrior 1.9–2.9 skills per fight; Slash 74% in D1.** Longer fights helped
  (1.6–2.0 → 1.9–2.9, Slash in D2–D4 now ≤ 48%). D1 stays Slash-heavy
  because the Warrior has no upgrades and no Rage-heavy skills early.

## Mechanically fine but boring

- **Elites remain a free reward** (611/612), so taking one is never a decision when healthy.
- **D2 and D3 have no tension:** 3 and 5 wipes in 100 campaigns, bosses won
  95–97% first try.
- **Orcs are now damage sponges:** 108 HP and 3 ATK (were 54 / 6). They
  last long and barely hurt. Already in iteration 6 (orc ATK 4), D1
  `orc+orc+skeleton_archer` cost 0% party HP per fight. An orc should pose
  a threat. A better long-term fix is an orc
  skill with a telegraph, rather than a low ATK.
- **Telegraphs land more often.** 740 of 965 wind-ups landed (E5a: 367 of 672),
  because twice the HP makes "kill the charger first" rarely possible. The
  answer shifts from "focus it" to "heal/shield" (510 heal/shield answers
  against 221 kills).
- **D1 elites are skipped half the time** (134 of 270), because the party is
  under 70% HP. In D1 the elite room is mostly a locked door.
- **The Warrior in D1** is Slash 74%, Provoke 15%, with 1.9 distinct skills per fight.

## Suggestions for the advisor

1. Pick between normal fights of 4–5 rounds and 8–12 combat minutes at ~11.5 fights
   (see above). Roxton's re-check of fight length is the deciding data.
2. Replace `pow(DUNGEON_GROWTH, d-1)` with a per-dungeon multiplier table
   (gameplay-engineer). That lets D2/D3 harden without breaking D4.
3. Add an elite-only, per-dungeon scale, so elites can bite in D2–D4
   without adding D1 wipes.
4. Let the bot spend SP inside a dungeon if the game allows it. Otherwise,
   D1 wipes are overstated against a real player.
