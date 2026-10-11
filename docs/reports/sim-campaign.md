# Sim: campaign bot

Generated output: `tools/sim.sh campaign --runs 100 --seed 1 --out docs/reports/sim-campaign.md`. Don't edit by hand.

- **Seed:** 1 (one seed for the whole batch)
- **Sample:** 100 campaigns, each dungeons 1-4 with one party
- **Party:** warrior, cleric, rogue, mage, level 1, starter items
- **XP:** real, split as the game does (share = total / 4, half for downed heroes; mirrored from `combat_screen.gd`)
- **Warrior SP:** spent in the city by the `executioner` build order (#56)
- **Gear:** best droppable item one tier behind the depth, reset in the city (D1 none, D2 common, D3 uncommon, D4 rare)
- **Policy:** every reachable room in BFS order, stairs last, boss last; fights by balance_sim `_player_turn` with HP/MP carried over; rest rooms rest; events and shrines left; full heal in the city
- **Rounds** count from 1 here (a fight won in its first round is 1). The talent-build report (#56) counts from 0: add 1 to compare.

## Headline

| Dungeon | Level at boss | Fights | Rounds / fight | Est. minutes | TPK % |
|---|---|---|---|---|---|
| D1 | 2.2 (2-3) | 6.3 (5-7) | 3.9 (p10 2, p90 7) | 8.6 (5.5-10.6) | 97% |
| D2 | - | - | 3.8 (p10 1, p90 7) | - | 100% |
| D3 | not reached | | | | |
| D4 | not reached | | | | |

Level: mean hero level (lowest-highest single hero). Fights and minutes: mean over the campaigns that beat that dungeon. TPK %: of the campaigns that entered it. Target: 15-20 minutes per dungeon (D-013).

## Level curve

| Dungeon | Campaigns in | Level at entry | Level at boss | Warrior SP earned |
|---|---|---|---|---|
| D1 | 100 | 1.0 (1-1) | 2.2 (2-3) | 0.6 (0-1) |
| D2 | 3 | 2.2 (2-3) | - | 1.0 (1-1) |

Warrior SP earned: total by the end of that dungeon (talent SP comes at even levels), mean (min-max); it is spent in the city before the next one.

## Run length and attrition

| Dungeon | Fights | Party actions | Enemy actions | Est. minutes | Room moves | Rests | HP % entering boss |
|---|---|---|---|---|---|---|---|
| D1 | 6.3 (5-7) | 88.7 (60-108) | 46.7 (20-65) | 8.6 (5.5-10.6) | 43.3 (33-51) | 2.7 (2-3) | 64% |

Mean (min-max) over the campaigns that beat that dungeon. Est. minutes = 5 s per party action + 1.5 s per enemy action, combat only: walking, menus, the city and reading events are not counted, so real play is longer. HP % entering the boss: party HP / party max HP (downed heroes count 0), over every campaign that reached the boss.

## TPKs

| Dungeon | Campaigns in | TPK % | F1 | F2 | F3 | F4 | Boss |
|---|---|---|---|---|---|---|---|
| D1 | 100 | 97% | 0 | 22 | 52 | 17 | 6 |
| D2 | 3 | 100% | 0 | 1 | 0 | 2 | 0 |

A TPK ends the campaign. Campaigns finished: 0 of 100 (100% TPK overall). Rooms left after 10 fled or stalled fights in a row: 0.

## Warrior talents after dungeon 4

No campaign finished.

## Limitations

- Loot and the market are out: gear is the model above, treasure and drops
  are ignored, and no potions are bought.
- The fight policy never uses consumables, so the starter items go unused.
- Only the Warrior spends SP. The Cleric, Rogue and Mage bank theirs, so
  their skills stay at tier 1 and party power is understated at depth.
- Events and shrines are always left, so their risks and rewards are out.
- Rest rooms are used when first reached, whatever the party's HP.
- The bot stops at the first TPK; the game would revive the party in the
  city (25% HP, -20% gold) and let it retry.

