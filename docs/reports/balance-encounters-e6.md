# Balance: encounters E6b (#96)

The balance loop with E6a's per-dungeon tables (#95): `DUNGEON_MULT` and
`ELITE_MULT`, then boss numbers, then enemy `.tres`. It also gives the orc a
brute identity. 8 iterations, one lever each; iteration 8 was reverted.

**Conditions for every number below:**
- Command: `tools/sim.sh campaign --runs 100 --seed 1 --xp-mult 1`.
- Base: `origin/main` at 038120e (E6a #99, and #100, under which mana classes
  pay the upgraded skill cost).
- Party: warrior, cleric, rogue, mage. They start at level 1 with starter
  items. The Warrior uses the `executioner` build order, and XP is the
  game's own (×1).
- Gear: one tier behind the depth (D1 none, D2 common, D3 uncommon, D4 rare).
- Sample: 100 campaigns of dungeons 1–4, with wipes retried. Every iteration
  replays seed 1.
- The full generated output for the final state is in
  [`sim-campaign.md`](sim-campaign.md).

## Final targets table

| Metric | Target | D1 | D2 | D3 | D4 | Met? |
|---|---|---|---|---|---|---|
| Wipes per campaign | D1 ≤ 0.3 | **0.42** | 0.39 | 0.21 | 0.29 | **no** (total 1.31) |
| Stuck (campaign ends) | never | 0 | 0 | 0 | 2 | no (2 of 100) |
| Boss first-try win | 70–85% each | 75% | 84% | **89%** | 83% | D1, D2, D4 |
| Elite win when taken | 80–90% | 100% (137/137) | 96% (187/195) | 99% (196/197) | 98% (194/197) | **no** (98% overall) |
| Rounds, normal | 4–5 | 4.2 | 4.1 | 4.3 | 4.0 | yes |
| Rounds, elite | 5–7 | 6.0 | **9.3** | **9.5** | **9.3** | D1 only |
| Rounds, boss | 8–10 | 7.2 | 7.8 | 9.6 | 10.4 | D3 (D2, D4 near) |
| Level at boss | ≈ 4 / 6 / 8 / 10, ±1 | 4.7 | **7.9** | **9.9** | 10.0 | D1, D4 |
| Warrior skills per fight (D2–D4) | 3+ | 1.7 | 2.8 | 2.9 | 2.7 | no (as before) |
| Warrior top skill (D2–D4) | ≤ 50% | slash 77% | slash 36% | slash 34% | slash 32% | yes |

Rounds count from 1.

**Baseline** (origin/main, same command): wipes 0.48 / 0.00 / 0.00 / 0.03
(0.51 total), stuck 0. Boss first-try 80 / 100 / 100 / 97%. Elites
622/623 won. Rounds: normal 4.2 / 3.2 / 3.9 / 4.1, elite
6.3 / 4.9 / 6.4 / 7.1, boss 6.8 / 5.8 / 7.5 / 9.7. Level at boss
4.7 / 6.6 / 8.7 / 10.0. Warrior 1.8 / 2.2 / 2.6 / 2.7 skills per fight,
Slash 75 / 50 / 47 / 33%.

## Changes, one per iteration

| # | Lever | Change | Why | Before → after |
|---|---|---|---|---|
| 1 | `DUNGEON_MULT` | [1.0, 1.6, 2.56, 4.096] → [1.0, 1.95, 3.1, 4.4] | D2–D4 bosses won 97–100% with ~0 wipes | Boss first-try D2/D3/D4 100/100/97 → 100/90/83%. Normal rounds D2 3.2 → 3.7. Level at D3 boss 8.7 → 9.4 |
| 2 | `DUNGEON_MULT` D2 | 1.95 → 2.35 | D2 boss still 100%, 0.01 wipes | D2 boss 100 → 83%, wipes 0.01 → 0.22. Normal rounds 3.7 → 4.4. Level at D2 boss 7.0 → 7.5 |
| 3 | `ELITE_MULT` | [1, 1, 1, 1] → [1.0, 1.35, 1.35, 1.35] | elites won 100% in D2–D4 | Elite win D2/D3/D4 100/100/100 → 94/96/94%. Elite rounds 7.1/7.3/7.6 → 9.9/9.8/10.9. Total wipes 0.77 → 1.61, D4 stuck 0 → 3 |
| 4 | Orc `.tres` | `max_hp` 108 → 72, `atk` 3 → 5 | brute identity: hit hard, die fast | D1 F4 wipes 26 → 13. Total wipes 1.61 → 1.30. D4 elite ogre+orc+orc+cultist 17.9 → 15.0 rounds |
| 5 | Necromancer boss | `mag` 6 → 5 | the top boss killer: D4 39% and D1 28% of its fights wiped | Necromancer wipe rate D1 27.7 → 12.5%, D4 38.9 → 12.5%. Boss first-try D4 79 → 84% |
| 6 | `DUNGEON_MULT` D3 | 3.1 → 3.5 | D3 boss 93% | D3 boss 93 → 79%. D3 wipes 0.18 → 0.46, stuck D3 0 → 2 (D4 3 → 1). Total wipes 1.37 → 1.51 |
| 7 | `ELITE_MULT` D3/D4 | 1.35 → 1.2 | the four-enemy elites in D3/D4 ran 12–16 rounds and caused the stuck campaigns | Stuck 3 → 2. Total wipes 1.51 → 1.31. Elite rounds D3/D4 10.8/10.9 → 9.5/9.3. Elite win D3/D4 94/95 → 99/98%. D3 boss 79 → 89% |
| 8 | `DUNGEON_MULT` D3 | 3.5 → 3.7 | D3 boss back at 89% | D3 boss 89 → 75%, but D3 stuck 0 → 3 and total wipes 1.31 → 1.53. **Reverted** to 3.5: three stuck campaigns are worse than a boss 4 points over |

The final state is iteration 7: `DUNGEON_MULT = [1.0, 2.35, 3.5, 4.4]`,
`ELITE_MULT = [1.0, 1.35, 1.2, 1.2]`, orc 72 HP / 5 ATK, necromancer MAG 5.
Re-running the command on the final tree reproduces iteration 7 exactly.
`test/difficulty_tables_test.gd` pinned the table to `pow(1.6, level-1)`
(E6a's "no value changes" check). Now it checks that D1 is 1.0 and each
dungeon is harder than the one before. Groups, hero numbers, XP, talents
and the quota are unchanged.

## Read the numbers with their noise

D1 never changed after iteration 4 (and its table entry never changed at
all). Even so, D1's boss first-try ranged **72–92%** and its wipes
**0.37–0.59** across iterations. The campaigns share one random stream, so
a change in D2–D4 reshuffles D1's rolls. At 100 campaigns, a per-dungeon
rate moves ±5–10 points on noise alone. For example, the D4 boss went 83 → 96%
in iteration 2, which changed only D2. Treat single-point misses (D3 boss 89%) as
inside the noise, and use `--runs 300` or several seeds before a final
call.

## Targets missed, and why

- **D1 wipes 0.42 (target ≤ 0.3).** From iteration 4 on (orc and necromancer
  done), the mean is 0.42 and the range 0.37–0.45. In the final run the
  wipes split 4 at F3, 13 at F4 and 25 at the boss, with the party
  entering the boss at 62% HP. The tables can't touch D1. D1 is 1.0, and
  `_scale_enemy` returns the base enemy for any multiplier ≤ 1.0, so a
  D1 entry of 0.9 does nothing. Every `.tres` lever that eases D1 also
  eases D2–D4. The D1 killers now are the dragon (26%) and vampire (22%)
  bosses. Easing them would push the D2/D3 bosses (84/89%) out of range.
- **Elites 96–99% won (target 80–90%), and they now take 9–10 rounds.**
  `ELITE_MULT` scales HP and ATK alike, and enemy damage is
  `atk × power − DEF`. Most of the multiplier goes into HP, which makes
  long fights, not dangerous ones. At 1.35 the elites were still won
  94–96%, ran 10–11 rounds and caused 3 stuck campaigns. Nearly every
  lost elite is one of the two four-enemy groups (`f4_ogre_chieftain`,
  `f4_warlord_horde`), and the rest are free. The bot also takes elites
  only at ≥ 70% HP. Hitting 80–90% needs an elite factor on ATK only, or
  elite groups that hit harder with fewer bodies.
- **Level at boss 4.7 / 7.9 / 9.9 / 10.0 (D2 and D3 about 1 over).**
  `_scale_enemy` multiplies `xp_reward` by the same factor as the stats.
  Raising D2 from 1.6 to 2.35 gives 47% more XP per D2 enemy, so the
  party reaches D3 at level 8.1 instead of 6.8. The level drift comes from
  the brief's own lever. XP itself is off-limits, so I left it and am
  reporting it.
- **Stuck 2 of 100 (D4).** These are D4 boss and F4 wipes. The baseline
  had 0, because D2–D4 were nearly free then.
- **Warrior 1.7–2.9 skills per fight.** No hero levers. D1 is still 77%
  Slash, because he has no upgrades yet.
- **Boss rounds D1/D2 7.2/7.8 (8–10).** Boss HP was left alone (more HP
  adds D1 boss wipes). D4 sits at 10.4.

## Orc identity

The orc goes from 108 HP / 3 ATK (sponge) to 72 HP / 5 ATK (brute). With
subtractive DEF, +2 ATK is far more than +67% damage against a level-4
party. At D1 F4, wipes halved (26 → 13). The orc dies in two-thirds the
time, so its groups cost less attrition overall while each hit lands
harder. D1 `orc+cultist+cultist` costs 19% party HP per fight (baseline
20%), with 4.2 rounds instead of 4.9. The orc is still a front-row
`BRUTE` with `e_rage`. A telegraphed orc skill would make it read as a
threat in play, not only in the numbers (content-data, if wanted).

## Mechanically fine but boring

- **Elites are still nearly free (714/726)**, and now they're slow (9–10
  rounds). A healthy party has no reason to skip one. The elite room is
  "more of the same, longer".
- **Telegraphs are answered by healing, not by play.** 1339 of 1611
  wind-ups landed. Answers: 1078 heal/shield, 264 kill, 120 provoke. The
  extra HP from the tables makes "kill the charger first" rare from D2 on.
- **Vampire boss fights are all or nothing.** Party HP lost per fight is
  −2% to 5% (the party ends healthier than it started), yet 13–22% of
  them wipe. The fight is a coin flip on entry HP, not a slope.
- **D1 elite rooms are skipped 43% of the time** (party under 70% HP), so
  in D1 the elite room is mostly a locked door.
- **The Warrior in D1** uses Slash 77% and Provoke 14%, with 1.7 distinct
  skills per fight.

## Suggestions for the advisor

1. **Let D1 go below 1.0** (gameplay-engineer): `_scale_enemy` skips any
   multiplier ≤ 1.0. With an exact-1.0 check instead, D1 could be 0.9 and
   ease D1 alone. That is the clean path to D1 ≤ 0.3.
2. **Decouple XP from `DUNGEON_MULT`**: scale `xp_reward` by the old
   `pow(1.6, level-1)` or by its own table. That keeps D-036's level curve
   while the stat tables move. Expect the D2/D3 bosses to get harder once
   levels drop by ~1, then re-run this loop.
3. **An elite factor on ATK/MAG only** (or a separate elite HP factor):
   elites that bite without 10-round fights.
4. Use `--runs 300` (or seeds 1–3) when signing off a dungeon, because
   100 campaigns move ±5–10 points on noise.
