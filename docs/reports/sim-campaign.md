# Sim: campaign bot

Generated output: `tools/sim.sh campaign --runs 100 --seed 1 --out docs/reports/sim-campaign.md`. Don't edit by hand.

- **Seed:** 1 (every XP multiplier is reseeded with it)
- **Sample:** 100 campaigns per XP multiplier, each dungeons 1-4 with one party
- **Party:** warrior, cleric, rogue, mage, level 1, starter items
- **XP:** real, split as the game does (share = total / 4, half for downed heroes; mirrored from `combat_screen.gd`). The tables below are for **x1.0 XP**; the what-if section compares the multipliers (bot only, the game is untouched)
- **Skill points:** spent in the city. The Warrior by the `executioner` build order (#56); the others upgrade their skills in class order, one skill at a time
- **Gear:** best droppable item one tier behind the depth, reset in the city (D1 none, D2 common, D3 uncommon, D4 rare)
- **Policy:** every reachable room in BFS order, stairs last, boss last; fights by balance_sim `_player_turn` with HP/MP carried over; events and shrines left; full heal in the city
- **Potions:** a hero under 35% HP drinks the best heal potion when no living healer can afford a heal skill; a Mage, Cleric or Alchemist under 20% MP drinks a mana potion. Bought in the city with up to 50% of the gold on heal potions, then 25% on mana potions, from the market's limited stock
- **Rest rooms:** remembered, and used only when party HP is under 60% (the bot walks back to the nearest unused one; the moves are counted)
- **Wipes:** the game's TPK rule (revive at 25% HP, -20% gold, market restocked), then the same dungeon again on a new layout. Wipe number 3 in one dungeon ends the campaign as **stuck**
- **Rounds** count from 1 here (a fight won in its first round is 1). The talent-build report (#56) counts from 0: add 1 to compare.

## Headline

| Dungeon | Level at boss | Fights | Rounds / fight | Est. minutes | Wipes | Stuck % |
|---|---|---|---|---|---|---|
| D1 | 2.9 (2-4) | 8.5 (4-14) | 3.4 (p10 2, p90 6) | 8.1 (3.1-15.9) | 0.83 | 1% |
| D2 | 4.2 (3-5) | 9.1 (4-14) | 2.7 (p10 2, p90 4) | 7.8 (3.5-11.7) | 0.25 | 0% |
| D3 | 5.6 (4-7) | 9.1 (4-15) | 3.1 (p10 2, p90 5) | 8.7 (3.5-15.7) | 0.48 | 2% |
| D4 | 7.1 (5-9) | 8.5 (3-14) | 3.1 (p10 2, p90 5) | 8.2 (3.0-12.9) | 0.98 | 10% |

Level: mean hero level (lowest-highest single hero) at the boss, from the latest attempt that reached it. Fights and minutes: mean over the campaigns that beat that dungeon (the clearing run only). Wipes: mean per campaign that entered it. Stuck: % of those that wiped out of the dungeon for good. Rounds / fight covers every fight, wiped runs included. Target: 15-20 minutes per dungeon (D-013).

## Level curve

| Dungeon | Campaigns in | Level at entry | Level at boss | Warrior SP earned |
|---|---|---|---|---|
| D1 | 100 | 1.0 (1-1) | 2.9 (2-4) | 1.2 (1-2) |
| D2 | 99 | 3.1 (2-4) | 4.2 (3-5) | 2.0 (1-2) |
| D3 | 99 | 4.4 (3-6) | 5.6 (4-7) | 2.7 (2-3) |
| D4 | 97 | 5.8 (4-7) | 7.1 (5-9) | 3.4 (3-4) |

Warrior SP earned: total by the end of that dungeon (talent SP comes at even levels), mean (min-max); it is spent in the city before the next one.

## Run length and attrition

| Dungeon | Fights | Party actions | Enemy actions | Est. minutes | Est. min incl. wiped runs | Room moves | Rests | Potions used | Potions bought | HP % entering boss |
|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 8.5 (4-14) | 84.3 (33-161) | 44.3 (15-99) | 8.1 (3.1-15.9) | 14.3 | 56.3 (37-85) | 0.7 (0-3) | 5.3 (1-11) | 1.4 (1-4) | 75% |
| D2 | 9.1 (4-14) | 79.8 (37-121) | 44.5 (13-80) | 7.8 (3.5-11.7) | 9.9 | 56.9 (42-82) | 0.2 (0-1) | 1.9 (0-6) | 1.6 (0-6) | 75% |
| D3 | 9.1 (4-15) | 90.1 (36-158) | 46.8 (15-110) | 8.7 (3.5-15.7) | 12.5 | 55.7 (39-77) | 0.2 (0-1) | 3.2 (0-12) | 3.1 (0-11) | 76% |
| D4 | 8.5 (3-14) | 82.3 (31-126) | 53.7 (17-104) | 8.2 (3.0-12.9) | 13.8 | 55.7 (33-77) | 0.3 (0-2) | 3.4 (0-12) | 4.5 (1-11) | 79% |

Mean (min-max) over the campaigns that beat that dungeon. Actions, moves, rests and potions used are the clearing run's; potions bought are for that run's city visit. Est. minutes = 5 s per party action + 1.5 s per enemy action, combat only: walking, menus, the city and reading events are not counted, so real play is longer. "Incl. wiped runs" adds the combat time of the wiped attempts. HP % entering the boss: party HP / party max HP (downed heroes count 0), over every campaign that reached the boss.

## Wipes

| Dungeon | Campaigns in | Wipes / campaign | 0 wipes | 1 | 2 | 3 (stuck) | At F1 | F2 | F3 | F4 | Boss |
|---|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 100 | 0.83 | 29 | 60 | 10 | 1 | 0 | 4 | 32 | 33 | 14 |
| D2 | 99 | 0.25 | 76 | 21 | 2 | 0 | 0 | 0 | 4 | 9 | 12 |
| D3 | 99 | 0.48 | 61 | 30 | 6 | 2 | 0 | 0 | 1 | 22 | 25 |
| D4 | 97 | 0.98 | 36 | 37 | 14 | 10 | 0 | 0 | 19 | 38 | 38 |

Wipes counted over every attempt at that dungeon; the "At" columns say where the party died. Campaigns finished (dungeon 4 beaten): 87 of 100; stuck: 13. Rooms left after 10 fled or stalled fights in a row: 0.

## Warrior talents after dungeon 4

| Talents | Campaigns |
|---|---|
| slash_rending, cleave_heavy, execute_sunder | 57 |
| slash_rending, cleave_heavy | 14 |
| slash_rending, cleave_heavy, execute_sunder+ | 8 |
| slash_rending, execute_sunder+ | 7 |
| slash_rending, execute_sunder | 1 |

`+` = boosted. Bought in the city, so the dungeon 4 boss is fought without
the SP earned inside dungeon 4.

## XP what-if

`--xp-mult` multiplies the XP awarded after each victory, in the bot only: the game's numbers are untouched. Each row replays 100 campaigns from the same seed with the same policy, so the rows differ only by XP.

**Level 9-10 at the dungeon 4 boss: x3.0 XP** (mean hero level 9.8, over 100 campaigns that reached it).

### Level at each boss

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 2.9 | 4.2 | 5.6 | 7.1 |
| x2.0 | 3.7 | 5.4 | 6.9 | 8.7 |
| x3.0 | 4.2 | 6.2 | 8.1 | 9.8 |
| x4.0 | 4.6 | 6.9 | 9.0 | 10.0 |

### Warrior SP earned by the end of each dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 1.2 | 2.0 | 2.7 | 3.4 |
| x2.0 | 1.8 | 2.6 | 3.2 | 4.2 |
| x3.0 | 2.0 | 3.0 | 3.9 | 4.9 |
| x4.0 | 2.2 | 3.3 | 4.3 | 5.0 |

### Wipes per campaign that entered the dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0.83 | 0.25 | 0.48 | 0.98 |
| x2.0 | 0.29 | 0.02 | 0.02 | 0.23 |
| x3.0 | 0.16 | 0.00 | 0.00 | 0.06 |
| x4.0 | 0.10 | 0.00 | 0.00 | 0.01 |

### Stuck (campaign ended in that dungeon)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 1% | 0% | 2% | 10% |
| x2.0 | 0% | 0% | 0% | 0% |
| x3.0 | 0% | 0% | 0% | 0% |
| x4.0 | 0% | 0% | 0% | 0% |

### Est. minutes per dungeon (clearing run)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 8.1 | 7.8 | 8.7 | 8.2 |
| x2.0 | 9.1 | 7.1 | 7.8 | 8.2 |
| x3.0 | 8.8 | 6.4 | 7.1 | 7.4 |
| x4.0 | 8.2 | 6.0 | 6.3 | 6.9 |

### Rounds per fight

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 3.4 | 2.7 | 3.1 | 3.1 |
| x2.0 | 3.2 | 2.3 | 2.6 | 2.8 |
| x3.0 | 3.0 | 2.2 | 2.4 | 2.6 |
| x4.0 | 2.8 | 2.0 | 2.2 | 2.4 |

### Campaigns finished

| XP x | Beat dungeon 4 |
|---|---|
| x1.0 | 87 of 100 |
| x2.0 | 100 of 100 |
| x3.0 | 100 of 100 |
| x4.0 | 100 of 100 |

## Limitations

- Loot is out: gear is the model above, and treasure gold and items are taken
  but never equipped or sold. Only the market's potions are bought.
- Potions: only heal and mana potions are used. Revive items and shrines are
  left unused, and no potion is bought for dungeons the party never reaches.
- The market shelf is the game's own limited random stock, restocked when a
  run ends, so the potion supply varies by campaign.
- Skill points are spent only in the city, so the SP earned inside a
  dungeon waits for the next visit.
- Events and shrines are always left, so their risks and rewards are out.
- A wipe retries on a fresh layout, as the game starts a new run after a TPK.
- Levels at the dungeon 4 boss only count campaigns that got there, so a
  multiplier that sticks fewer campaigns earlier is not directly comparable.

