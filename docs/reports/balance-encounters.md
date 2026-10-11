# Balance: encounters E4 (#80)

The bot learned the elite and telegraph choices, then the balance loop ran
its 6 iterations against the encounter targets (D-034, D-036, D-038).

**Conditions for every number below:**
- Command: `tools/sim.sh campaign --runs 100 --seed 1 --xp-mult 1`.
- Party: warrior, cleric, rogue, mage. They start at level 1 with the starter
  items, the Warrior uses the `tank` build order, and the game's own XP
  applies (×1 in the bot, D-036 thresholds).
- Gear: one tier behind the depth (D1 none, D2 common, D3 uncommon, D4 rare).
- Sample: 100 campaigns of dungeons 1–4, wipes retried. Each iteration
  replays the same seed.
- The full generated output for the final state is in
  [`sim-campaign.md`](sim-campaign.md).

## Final targets table

| Metric | Target | D1 | D2 | D3 | D4 | Met? |
|---|---|---|---|---|---|---|
| Rounds, normal fight | 3–5 | 2.7 | 2.0 | 2.3 | 2.5 | no |
| Rounds, elite fight | 5–7 | 3.7 | 3.2 | 3.6 | 3.9 | no |
| Rounds, boss fight | 8–10 | 6.1 | 6.3 | 7.2 | 8.8 | D4 only |
| Boss first-try win | 70–85% | 80% | 98% | 99% | 78% | D1, D4 |
| Wipes per campaign | 0.3–1.5 | 0.90 | 0.02 | 0.01 | 0.33 | **1.26 total: yes** |
| Stuck (campaign ends) | never | 0% | 0% | 0% | 3% | no (3 of 100) |
| Level at boss | ≈4 / 6 / 8 / 10 | 6.1 | 8.2 | 9.9 | 10.0 | no (XP, out of scope) |
| Combat minutes | 8–12 | 11.4 | 11.1 | 12.8 | 14.8 | D1, D2 |
| Warrior skills per fight | 3+ | 1.6 | 1.6 | 1.7 | 2.0 | no |
| Warrior top skill | ≤ 50% | slash 70% | slash 62% | slash 63% | slash 46% | D4 only |

Rounds count from 1. Elites taken: 690 of 912 met (76%); skipped 222 (24%).
690 of the 690 taken were won.

## Bot policy (new in `scripts/dev/campaign_bot.gd`)

- **Elites:** the bot takes an elite room when party HP is at least 70% and
  nobody is downed. Otherwise it skips the room for good, along with any
  rooms only reachable through it (44 rooms in total).
- **Telegraphs:** while an enemy is Charging, the acting hero answers in this
  order: (1) **kill** the charger if this turn's expected damage can do it;
  (2) the Warrior uses **Provoke** if the telegraph is single-target; (3)
  **heal or shield** the threatened heroes (a barrier first, or a heal on
  a hero under 80% HP). If the hero has no answer, the shared
  `_player_turn` acts.

Telegraph answers in the final state (every attempt):

| Wind-ups | Landed | Charger killed first | Answer: kill | Provoke | Heal/shield |
|---|---|---|---|---|---|
| 679 | 373 | 304 | 299 | 28 | 309 |

## Changes, one per iteration

Iteration 0 is the baseline with the new bot policy and no data changes.
Before the policy (elites always fought) the baseline was 3.75 wipes per
campaign.

| # | Lever | Change | Why | Before → after |
|---|---|---|---|---|
| 1 | Boss HP | necromancer 60→150, vampire 48→120, dragon 90→225 (×2.5) | boss fights lasted 2.2–4.3 rounds against 8–10 | boss rounds D1 2.2→3.7, D4 4.3→6.3; wipes 3.05→3.68; D4 boss first-try 66%→31% |
| 2 | Ogre ATK | 12→9 | the deadliest F4 groups had an ogre in them (D4 `ogre+orc+skeleton_archer` wiped 58% of the time) | wipes 3.68→3.34; that group 58%→36% |
| 3 | `DUNGEON_GROWTH` | 1.5→1.4 | D4 F4 at ×4.9 against a level-capped party left 72% of campaigns stuck | wipes 3.34→1.03; D4 stuck 72%→0%; D4 boss first-try 37%→81% |
| 4 | Enemy HP, all | every `max_hp` ×1.5 | normal fights at 1.7–2.3 rounds | normal rounds D1 2.3→2.7, D4 2.0→2.5; wipes 1.03→2.60 |
| 5 | Enemy ATK/MAG, all | every `atk` and `mag` ×0.75 (rounded) | step 4 pushed wipes out of range | wipes 2.60→0.94; rounds unchanged (D1 2.7→2.8) |
| 6 | Boss HP | ×1.5 again: dragon 338→507, necromancer 225→338, vampire 180→270 | boss rounds 4.5–6.5; D2–D4 bosses won 89–100% first try | boss rounds D1 4.8→6.1, D4 6.5→8.8; D4 first-try 89%→78%; wipes 0.94→1.26 |

All enemy numbers are in `resources/enemies/*.tres`, and `DUNGEON_GROWTH`
is in `scripts/dungeon/dungeon_run.gd`. No hero-side, XP or talent numbers
changed. The encounter groups are unchanged too, so `FALLBACK_IDS` is
still in step.

## Targets missed, and why

- **Normal and elite fights are still short (2.0–2.7 and 3.2–3.9 rounds).**
  Rounds respond weakly to HP: ×1.5 HP gave only ×1.2 rounds, because many
  fights end on overkill in round 1–2. Reaching 3+ rounds needs about ×1.7
  more HP, but two other targets push back:
  - **Combat minutes.** At ~15 fights per dungeon (E3's quota), every
    0.5 rounds per fight adds about 2.5 combat minutes. D3 and D4 are
    already at 12.8 and 14.8. **Rounds 3–5 and 8–12 minutes are
    incompatible at 15 fights per dungeon**: 3 rounds means about 15
    minutes. One of them has to give: fewer fights per floor (the E3
    minimums), or a longer minutes target.
  - **Wipes.** Longer fights mean more damage taken. In step 4, wipes went
    from 1.03 to 2.60 for +0.4 rounds.
- **Level curve 6.1 / 8.2 / 9.9 / 10 (target ≈4/6/8/10).** E3 raised fights
  from ~10 to ~15 per dungeon, and elites pay ×1.5 XP, so ×3 XP now
  over-levels by about two levels. XP is out of scope for this brief.
  Step 3 lowered D2–D4 XP slightly, and levels barely moved.
- **D2 and D3 bosses are won 98–99% of the time, with ~0 wipes.** The party
  arrives two levels above the design level. Tuning D2–D3 up now would be
  double-counted once XP is fixed, so I left them alone.
- **D4: 3 of 100 campaigns stuck,** all at the D4 boss (the dragon wins 49%
  of its fights).
- **Warrior 1.6–2.0 skills per fight, Slash 62–70% in D1–D3.** This follows
  from fight length (2–3 Warrior turns per fight) and from the shared
  policy, which picks the highest damage score.

## Mechanically fine but boring

- **Elites are never lost: 690 of 690 won.** With the 70% HP gate, taking
  an elite is free XP and loot, so the choice is trivial: always take it
  when healthy. Elite fights are also only 3.2–3.9 rounds. They need more
  bite (an extra member, or a stronger leader) before skipping one means
  anything.
- **D2 and D3 have almost no tension:** 0.02 and 0.01 wipes, and the boss is
  won 98–99% of the time.
- **D1 wipes once in 90% of campaigns,** at F3, F4 or the boss. The party
  enters at level 1, and attrition across 4 floors does the work (the
  fights that wipe it cost only 2–14% HP). After the wipe the run is
  retried with the XP kept. For a new player this reads as "the first
  dungeon always kills you once", which is a feel-gate question.
- **The Warrior spams Slash.** He averages 1.6 distinct skills per fight in
  D1–D3, and Cleave is 2–7% of his actions.
- **A Provoke answer to a telegraph does nothing in the current game.**
  `CombatState._continue_wind_up` keeps the target chosen at wind-up, so a
  Provoke cast during the wind-up doesn't pull the hit. In the bot, 142 of
  186 single-target telegraphs that landed hit the Warrior, but only
  because he was already taunting at wind-up. The design-encounter skill
  lists "Provoke it onto the tank" as an answer, so this is a gameplay gap
  for the advisor to route (combat_state.gd is outside qa-balance's
  files).
- **Only two telegraphs exist** (ogre Smash, area; orc warlord Crushing
  Blow, single-target, elites only). Single-target telegraphs are rare, so
  the Provoke answer came up only 28 times in 100 campaigns.

## Suggestions for the advisor

1. Decide between rounds 3–5 and 8–12 combat minutes at 15 fights per
   dungeon. Either lower the E3 fight minimums (about 10 fights fit both)
   or raise the minutes target. Then a further enemy HP ×1.5 with ATK
   ×0.85 should land normal fights at about 3 rounds.
2. Revisit the XP divisor (×3 → about ×2) now that E3 added fights. It
   would also make D2–D3 tense again without enemy changes.
3. Make Provoke retarget a Charging single-target telegraph (a
   gameplay-engineer task), or drop it from the list of answers.
4. Give elite groups more bite so skipping one is a real choice.
