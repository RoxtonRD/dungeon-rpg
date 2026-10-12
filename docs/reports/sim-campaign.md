# Sim: campaign bot

Generated output: `tools/sim.sh campaign --runs 100 --seed 1 --xp-mult 1 --out docs/reports/sim-campaign.md`. Don't edit by hand.

- **Seed:** 1 (every XP multiplier is reseeded with it)
- **Sample:** 100 campaigns per XP multiplier, each dungeons 1-4 with one party
- **Party:** warrior, cleric, rogue, mage, level 1, starter items
- **XP:** real, split by `Party.distribute_combat_xp` (share = total / 4, half for downed heroes). The tables below are for **x1.0 XP**; the what-if section compares the multipliers (bot only, the game is untouched)
- **Skill points:** spent in the city. The Warrior by the `executioner` build order (#56); the others upgrade their skills in class order, one skill at a time
- **Gear:** best droppable item one tier behind the depth, reset in the city (D1 none, D2 common, D3 uncommon, D4 rare)
- **Policy:** every reachable room in BFS order, stairs last, boss last; fights by balance_sim `_player_turn` with HP/MP carried over, after the telegraph answers (see Telegraphs); elite rooms taken or skipped by party HP (see Elite rooms); events and shrines left; full heal in the city
- **Potions:** a hero under 35% HP drinks the best heal potion when no living healer can afford a heal skill; a Mage, Cleric or Alchemist under 20% MP drinks a mana potion. Bought in the city with up to 50% of the gold on heal potions, then 25% on mana potions, from the market's limited stock
- **Rest rooms:** remembered, and used only when party HP is under 60% (the bot walks back to the nearest unused one; the moves are counted)
- **Wipes:** the game's TPK rule (revive at 25% HP, -20% gold, market restocked), then the same dungeon again on a new layout. Wipe number 3 in one dungeon ends the campaign as **stuck**
- **Rounds** count from 1 here (a fight won in its first round is 1). The talent-build report (#56) counts from 0: add 1 to compare.

## Headline

| Dungeon | Level at boss | Fights | Rounds / fight | Est. minutes | Wipes | Stuck % |
|---|---|---|---|---|---|---|
| D1 | 4.6 (3-6) | 11.2 (7-13) | 4.8 (p10 3, p90 7) | 16.8 (9.4-26.0) | 0.46 | 0% |
| D2 | 6.6 (6-8) | 11.7 (10-14) | 3.8 (p10 2, p90 5) | 15.1 (10.6-20.3) | 0.03 | 0% |
| D3 | 8.7 (8-10) | 11.6 (9-14) | 4.7 (p10 2, p90 7) | 18.8 (13.7-24.5) | 0.05 | 0% |
| D4 | 10.0 (9-10) | 11.4 (9-14) | 5.1 (p10 2, p90 8) | 20.6 (15.8-29.1) | 0.33 | 1% |

Level: mean hero level (lowest-highest single hero) at the boss, from the latest attempt that reached it. Fights and minutes: mean over the campaigns that beat that dungeon (the clearing run only). Wipes: mean per campaign that entered it. Stuck: % of those that wiped out of the dungeon for good. Rounds / fight covers every fight, wiped runs included. Target: 15-20 minutes per dungeon (D-013).

## Encounter targets

| Dungeon | Rounds: normal | elite | boss | Boss first-try win | Wipes | Level at boss | Combat min | Warrior skills / fight | Warrior top skill |
|---|---|---|---|---|---|---|---|---|---|
| **Target** | 3-5 | 5-7 | 8-10 | 70-85% | 0.3-1.5 / campaign | 4 / 6 / 8 / 10 | 8-12 | 3+ | <= 50% |
| D1 | 4.3 [3-6] (1319) | 6.7 [4-10] (136) | 7.0 [4-10] (125) | 75% (75/100) | 0.46 | 4.6 | 16.8 | 1.9 | slash 74% |
| D2 | 3.4 [2-5] (953) | 5.2 [4-7] (146) | 6.0 [5-8] (103) | 97% (97/100) | 0.03 | 6.6 | 15.1 | 2.4 | slash 48% |
| D3 | 4.1 [2-5] (963) | 6.8 [5-9] (152) | 7.6 [6-10] (105) | 95% (95/100) | 0.05 | 8.7 | 18.8 | 2.7 | slash 46% |
| D4 | 4.4 [2-6] (1229) | 7.4 [5-11] (178) | 8.9 [6-12] (131) | 74% (74/100) | 0.33 | 10.0 | 20.6 | 2.9 | slash 33% |

**Wipes per campaign: 0.87** (all dungeons, 100 campaigns). Rounds: mean [p10-p90] (fights), every attempt. Boss first-try win: share of the campaigns that reached that boss whose first boss fight was a win. Combat min: clearing run. Warrior: distinct skills per fight he acted in, and his most used skill's share of his skill actions (potions not counted).

## Elite rooms

| Dungeon | Met | Taken | Skipped | Won | Rooms cut off by a skip |
|---|---|---|---|---|---|
| D1 | 270 | 50% (136/270) | 50% (134/270) | 99% (135/136) | 51 |
| D2 | 190 | 77% (146/190) | 23% (44/190) | 100% (146/146) | 9 |
| D3 | 184 | 83% (152/184) | 17% (32/184) | 100% (152/152) | 6 |
| D4 | 223 | 80% (178/223) | 20% (45/223) | 100% (178/178) | 6 |
| **All** | 867 | 71% (612/867) | 29% (255/867) | 100% (611/612) | 72 |

Every attempt counted. Policy: take an elite room when party HP is at least 70% and nobody is downed, else skip it for good. Won is out of taken.

## Telegraphs

| Dungeon | Wind-ups | Landed | Charger killed | Single-target landed | ...on the Warrior | Answer: kill | provoke | heal/shield |
|---|---|---|---|---|---|---|---|---|
| D1 | 215 | 163 | 51 | 55 | 47 | 51 | 5 | 70 |
| D2 | 159 | 114 | 45 | 44 | 36 | 46 | 6 | 75 |
| D3 | 245 | 186 | 59 | 80 | 74 | 59 | 4 | 137 |
| D4 | 346 | 277 | 69 | 124 | 101 | 65 | 24 | 228 |
| **All** | 965 | 740 | 224 | 303 | 258 | 221 | 39 | 510 |

Every attempt counted. Answers are bot actions chosen by the telegraph rule (kill the charger if this turn's expected damage can, else the Warrior Provokes a single-target telegraph, else heal or shield the threatened heroes). A wind-up that is neither landed nor killed ended with the fight.

## Warrior skill use

| Dungeon | Fights | Skills / fight | Top-skill share / fight | Mix |
|---|---|---|---|---|
| D1 | 1553 | 1.9 | 75% | slash 74%, provoke 15%, cleave 8%, execute 3% |
| D2 | 1195 | 2.4 | 57% | slash 48%, provoke 24%, execute 23%, cleave 6% |
| D3 | 1220 | 2.7 | 55% | slash 46%, execute 22%, provoke 22%, cleave 10% |
| D4 | 1535 | 2.9 | 51% | slash 33%, execute 29%, provoke 26%, cleave 13% |

Fights he acted in, every attempt. Top-skill share / fight: the mean, over fights, of his most used skill's share in that fight (a 2-action fight is at least 50%). Mix: share of all his skill actions in that dungeon.

## Deadliest encounters

| Encounter | Fights | Wipes | Wipe % | Rounds | Party HP lost / fight |
|---|---|---|---|---|---|
| D4 boss: necromancer+skeleton | 56 | 17 | 30.4% | 8.1 | 26% |
| D1 boss: dragon_hatchling | 43 | 10 | 23.3% | 8.2 | 13% |
| D1 boss: vampire+bat+bat | 39 | 9 | 23.1% | 6.5 | 7% |
| D4 boss: dragon_hatchling | 38 | 8 | 21.1% | 10.6 | 29% |
| D1 normal: orc+orc+cultist | 59 | 7 | 11.9% | 5.6 | 15% |
| D4 boss: vampire+bat+bat | 37 | 7 | 18.9% | 8.3 | 7% |
| D1 boss: necromancer+skeleton | 43 | 6 | 14.0% | 6.2 | 13% |
| D1 normal: ogre+cultist | 50 | 4 | 8.0% | 4.3 | 12% |
| D1 normal: ogre+orc+skeleton_archer | 62 | 4 | 6.5% | 5.6 | 3% |
| D1 normal: orc+cultist+cultist | 55 | 4 | 7.3% | 4.9 | 22% |
| D3 boss: necromancer+skeleton | 33 | 3 | 9.1% | 7.2 | 19% |
| D3 boss: vampire+bat+bat | 40 | 2 | 5.0% | 7.3 | 2% |
| D1 elite: ogre+orc+orc+cultist | 17 | 1 | 5.9% | 7.3 | 30% |
| D1 normal: bandit+dark_elf+dark_elf | 82 | 1 | 1.2% | 4.6 | 1% |
| D2 boss: dragon_hatchling | 39 | 1 | 2.6% | 7.0 | 14% |

The 15 encounters with the most wipes, every attempt: enemy ids in battle order, per dungeon and room kind. HP lost: party HP share before the fight minus after it (a wipe loses everything left).

## Level curve

| Dungeon | Campaigns in | Level at entry | Level at boss | Warrior SP earned |
|---|---|---|---|---|
| D1 | 100 | 1.0 (1-1) | 4.6 (3-6) | 2.3 (1-3) |
| D2 | 100 | 4.8 (3-6) | 6.6 (6-8) | 3.1 (3-4) |
| D3 | 100 | 6.8 (6-8) | 8.7 (8-10) | 4.1 (4-5) |
| D4 | 100 | 8.9 (8-10) | 10.0 (9-10) | 5.0 (5-5) |

Warrior SP earned: total by the end of that dungeon (talent SP comes at even levels), mean (min-max); it is spent in the city before the next one.

## Run length and attrition

| Dungeon | Fights | Party actions | Enemy actions | Est. minutes | Est. min incl. wiped runs | Room moves | Rests | Potions used | Potions bought | HP % entering boss |
|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 11.2 (7-13) | 178.7 (102-271) | 78.3 (35-137) | 16.8 (9.4-26.0) | 25.2 | 51.9 (31-77) | 0.7 (0-3) | 5.1 (3-9) | 1.3 (1-3) | 64% |
| D2 | 11.7 (10-14) | 159.6 (114-213) | 73.8 (44-103) | 15.1 (10.6-20.3) | 15.6 | 54.0 (36-82) | 0.2 (0-2) | 1.2 (0-5) | 1.1 (0-4) | 66% |
| D3 | 11.6 (9-14) | 197.3 (146-255) | 93.7 (58-132) | 18.8 (13.7-24.5) | 19.8 | 55.1 (31-82) | 0.3 (0-2) | 2.4 (0-6) | 2.2 (0-6) | 67% |
| D4 | 11.4 (9-14) | 213.4 (165-299) | 111.9 (77-168) | 20.6 (15.8-29.1) | 27.3 | 54.4 (29-82) | 0.2 (0-2) | 4.0 (0-12) | 3.8 (1-11) | 73% |

Mean (min-max) over the campaigns that beat that dungeon. Actions, moves, rests and potions used are the clearing run's; potions bought are for that run's city visit. Est. minutes = 5 s per party action + 1.5 s per enemy action, combat only: walking, menus, the city and reading events are not counted, so real play is longer. "Incl. wiped runs" adds the combat time of the wiped attempts. HP % entering the boss: party HP / party max HP (downed heroes count 0), over every campaign that reached the boss.

## Wipes

| Dungeon | Campaigns in | Wipes / campaign | 0 wipes | 1 | 2 | 3 (stuck) | At F1 | F2 | F3 | F4 | Boss |
|---|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 100 | 0.46 | 54 | 46 | 0 | 0 | 0 | 0 | 1 | 20 | 25 |
| D2 | 100 | 0.03 | 97 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 3 |
| D3 | 100 | 0.05 | 95 | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 5 |
| D4 | 100 | 0.33 | 73 | 22 | 4 | 1 | 0 | 0 | 0 | 1 | 32 |

Wipes counted over every attempt at that dungeon; the "At" columns say where the party died. Campaigns finished (dungeon 4 beaten): 99 of 100; stuck: 1. Rooms left after 10 fled or stalled fights in a row: 0.

## Warrior talents after dungeon 4

| Talents | Campaigns |
|---|---|
| slash_rending, cleave_heavy, execute_sunder+ | 63 |
| slash_rending, cleave_heavy, provoke_iron_wall, execute_sunder+ | 36 |

`+` = boosted. Bought in the city, so the dungeon 4 boss is fought without
the SP earned inside dungeon 4.

## XP what-if

`--xp-mult` multiplies the XP awarded after each victory, in the bot only: the game's numbers are untouched. Each row replays 100 campaigns from the same seed with the same policy, so the rows differ only by XP.

**Level 9-10 at the dungeon 4 boss: x1.0 XP** (mean hero level 10.0, over 100 campaigns that reached it).

### Level at each boss

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 4.6 | 6.6 | 8.7 | 10.0 |

### Warrior SP earned by the end of each dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 2.3 | 3.1 | 4.1 | 5.0 |

### Wipes per campaign that entered the dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0.46 | 0.03 | 0.05 | 0.33 |

### Stuck (campaign ended in that dungeon)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0% | 0% | 0% | 1% |

### Est. minutes per dungeon (clearing run)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 16.8 | 15.1 | 18.8 | 20.6 |

### Rounds per fight

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 4.8 | 3.8 | 4.7 | 5.1 |

### Campaigns finished

| XP x | Beat dungeon 4 |
|---|---|
| x1.0 | 99 of 100 |

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

