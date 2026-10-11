# Sim: campaign bot

Generated output: `tools/sim.sh campaign --runs 100 --seed 1 --xp-mult 1 --out docs/reports/sim-campaign.md`. Don't edit by hand.

- **Seed:** 1 (every XP multiplier is reseeded with it)
- **Sample:** 100 campaigns per XP multiplier, each dungeons 1-4 with one party
- **Party:** warrior, cleric, rogue, mage, level 1, starter items
- **XP:** real, split by `Party.distribute_combat_xp` (share = total / 4, half for downed heroes). The tables below are for **x1.0 XP**; the what-if section compares the multipliers (bot only, the game is untouched)
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
| D1 | 4.3 (3-6) | 9.5 (4-16) | 2.9 (p10 2, p90 4) | 8.7 (3.7-14.0) | 0.15 | 0% |
| D2 | 6.2 (5-7) | 9.5 (4-16) | 2.2 (p10 1, p90 3) | 6.5 (2.1-11.7) | 0.00 | 0% |
| D3 | 8.0 (7-9) | 9.3 (4-16) | 2.4 (p10 1, p90 3) | 6.8 (3.1-11.6) | 0.00 | 0% |
| D4 | 9.8 (8-10) | 9.3 (3-17) | 2.5 (p10 1, p90 4) | 7.3 (1.8-14.8) | 0.00 | 0% |

Level: mean hero level (lowest-highest single hero) at the boss, from the latest attempt that reached it. Fights and minutes: mean over the campaigns that beat that dungeon (the clearing run only). Wipes: mean per campaign that entered it. Stuck: % of those that wiped out of the dungeon for good. Rounds / fight covers every fight, wiped runs included. Target: 15-20 minutes per dungeon (D-013).

## Level curve

| Dungeon | Campaigns in | Level at entry | Level at boss | Warrior SP earned |
|---|---|---|---|---|
| D1 | 100 | 1.0 (1-1) | 4.3 (3-6) | 2.0 (1-3) |
| D2 | 100 | 4.5 (3-6) | 6.2 (5-7) | 3.0 (2-4) |
| D3 | 100 | 6.5 (5-8) | 8.0 (7-9) | 4.0 (3-5) |
| D4 | 100 | 8.3 (7-10) | 9.8 (8-10) | 4.9 (4-5) |

Warrior SP earned: total by the end of that dungeon (talent SP comes at even levels), mean (min-max); it is spent in the city before the next one.

## Run length and attrition

| Dungeon | Fights | Party actions | Enemy actions | Est. minutes | Est. min incl. wiped runs | Room moves | Rests | Potions used | Potions bought | HP % entering boss |
|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 9.5 (4-16) | 91.3 (40-145) | 45.4 (10-87) | 8.7 (3.7-14.0) | 9.8 | 56.5 (39-82) | 0.6 (0-2) | 3.8 (1-7) | 1.1 (1-3) | 69% |
| D2 | 9.5 (4-16) | 68.0 (22-121) | 33.6 (9-65) | 6.5 (2.1-11.7) | 6.5 | 54.6 (34-80) | 0.0 (0-1) | 0.7 (0-4) | 1.1 (0-3) | 76% |
| D3 | 9.3 (4-16) | 71.7 (33-119) | 33.9 (14-68) | 6.8 (3.1-11.6) | 6.8 | 56.5 (37-75) | 0.0 (0-1) | 0.7 (0-3) | 1.9 (0-4) | 79% |
| D4 | 9.3 (3-17) | 74.0 (19-151) | 45.4 (10-89) | 7.3 (1.8-14.8) | 7.3 | 53.9 (34-75) | 0.1 (0-1) | 1.1 (0-7) | 2.8 (0-6) | 80% |

Mean (min-max) over the campaigns that beat that dungeon. Actions, moves, rests and potions used are the clearing run's; potions bought are for that run's city visit. Est. minutes = 5 s per party action + 1.5 s per enemy action, combat only: walking, menus, the city and reading events are not counted, so real play is longer. "Incl. wiped runs" adds the combat time of the wiped attempts. HP % entering the boss: party HP / party max HP (downed heroes count 0), over every campaign that reached the boss.

## Wipes

| Dungeon | Campaigns in | Wipes / campaign | 0 wipes | 1 | 2 | 3 (stuck) | At F1 | F2 | F3 | F4 | Boss |
|---|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 100 | 0.15 | 87 | 11 | 2 | 0 | 0 | 3 | 2 | 5 | 5 |
| D2 | 100 | 0.00 | 100 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| D3 | 100 | 0.00 | 100 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| D4 | 100 | 0.00 | 100 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

Wipes counted over every attempt at that dungeon; the "At" columns say where the party died. Campaigns finished (dungeon 4 beaten): 100 of 100; stuck: 0. Rooms left after 10 fled or stalled fights in a row: 0.

## Warrior talents after dungeon 4

| Talents | Campaigns |
|---|---|
| slash_rending, cleave_heavy, execute_sunder+ | 94 |
| slash_rending, cleave_heavy, execute_sunder | 3 |
| slash_rending, execute_sunder+ | 2 |
| slash_rending, cleave_heavy, provoke_iron_wall, execute_sunder+ | 1 |

`+` = boosted. Bought in the city, so the dungeon 4 boss is fought without
the SP earned inside dungeon 4.

## XP what-if

`--xp-mult` multiplies the XP awarded after each victory, in the bot only: the game's numbers are untouched. Each row replays 100 campaigns from the same seed with the same policy, so the rows differ only by XP.

**Level 9-10 at the dungeon 4 boss: x1.0 XP** (mean hero level 9.8, over 100 campaigns that reached it).

### Level at each boss

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 4.3 | 6.2 | 8.0 | 9.8 |

### Warrior SP earned by the end of each dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 2.0 | 3.0 | 4.0 | 4.9 |

### Wipes per campaign that entered the dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0.15 | 0.00 | 0.00 | 0.00 |

### Stuck (campaign ended in that dungeon)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0% | 0% | 0% | 0% |

### Est. minutes per dungeon (clearing run)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 8.7 | 6.5 | 6.8 | 7.3 |

### Rounds per fight

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 2.9 | 2.2 | 2.4 | 2.5 |

### Campaigns finished

| XP x | Beat dungeon 4 |
|---|---|
| x1.0 | 100 of 100 |

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

