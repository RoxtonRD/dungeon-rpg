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
| D1 | 4.7 (4-6) | 11.3 (9-14) | 4.6 (p10 2, p90 7) | 16.2 (8.1-25.1) | 0.42 | 0% |
| D2 | 7.9 (6-10) | 11.6 (10-14) | 5.0 (p10 2, p90 8) | 19.6 (13.5-27.0) | 0.39 | 0% |
| D3 | 9.9 (9-10) | 11.7 (9-14) | 5.4 (p10 2, p90 9) | 22.0 (13.5-31.9) | 0.21 | 0% |
| D4 | 10.0 (10-10) | 11.7 (9-14) | 5.2 (p10 2, p90 10) | 21.5 (13.3-30.2) | 0.29 | 2% |

Level: mean hero level (lowest-highest single hero) at the boss, from the latest attempt that reached it. Fights and minutes: mean over the campaigns that beat that dungeon (the clearing run only). Wipes: mean per campaign that entered it. Stuck: % of those that wiped out of the dungeon for good. Rounds / fight covers every fight, wiped runs included. Target: 15-20 minutes per dungeon (D-013).

## Encounter targets

| Dungeon | Rounds: normal | elite | boss | Boss first-try win | Wipes | Level at boss | Combat min | Warrior skills / fight | Warrior top skill |
|---|---|---|---|---|---|---|---|---|---|
| **Target** | 3-5 | 5-7 | 8-10 | 70-85% | 0.3-1.5 / campaign | 4 / 6 / 8 / 10 | 8-12 | 3+ | <= 50% |
| D1 | 4.2 [2-6] (1286) | 6.0 [3-9] (137) | 7.2 [4-10] (125) | 75% (75/100) | 0.42 | 4.7 | 16.2 | 1.7 | slash 77% |
| D2 | 4.1 [2-5] (1254) | 9.3 [6-13] (195) | 7.8 [6-11] (116) | 84% (84/100) | 0.39 | 7.9 | 19.6 | 2.8 | slash 36% |
| D3 | 4.3 [2-6] (1110) | 9.5 [5-13] (197) | 9.6 [8-12] (112) | 89% (89/100) | 0.21 | 9.9 | 22.0 | 2.9 | slash 34% |
| D4 | 4.0 [2-6] (1185) | 9.3 [4-14] (197) | 10.4 [7-13] (119) | 83% (83/100) | 0.29 | 10.0 | 21.5 | 2.7 | slash 32% |

**Wipes per campaign: 1.31** (all dungeons, 100 campaigns). Rounds: mean [p10-p90] (fights), every attempt. Boss first-try win: share of the campaigns that reached that boss whose first boss fight was a win. Combat min: clearing run. Warrior: distinct skills per fight he acted in, and his most used skill's share of his skill actions (potions not counted).

## Elite rooms

| Dungeon | Met | Taken | Skipped | Won | Rooms cut off by a skip |
|---|---|---|---|---|---|
| D1 | 242 | 57% (137/242) | 43% (105/242) | 100% (137/137) | 28 |
| D2 | 247 | 79% (195/247) | 21% (52/247) | 96% (187/195) | 17 |
| D3 | 236 | 83% (197/236) | 17% (39/236) | 99% (196/197) | 19 |
| D4 | 221 | 89% (197/221) | 11% (24/221) | 98% (194/197) | 5 |
| **All** | 946 | 77% (726/946) | 23% (220/946) | 98% (714/726) | 69 |

Every attempt counted. Policy: take an elite room when party HP is at least 70% and nobody is downed, else skip it for good. Won is out of taken.

## Telegraphs

| Dungeon | Wind-ups | Landed | Charger killed | Single-target landed | ...on the Warrior | Answer: kill | provoke | heal/shield |
|---|---|---|---|---|---|---|---|---|
| D1 | 209 | 157 | 52 | 37 | 25 | 51 | 7 | 76 |
| D2 | 425 | 351 | 74 | 154 | 111 | 73 | 38 | 267 |
| D3 | 455 | 386 | 69 | 200 | 158 | 67 | 38 | 321 |
| D4 | 522 | 445 | 76 | 199 | 159 | 73 | 37 | 414 |
| **All** | 1611 | 1339 | 271 | 590 | 453 | 264 | 120 | 1078 |

Every attempt counted. Answers are bot actions chosen by the telegraph rule (kill the charger if this turn's expected damage can, else the Warrior Provokes a single-target telegraph, else heal or shield the threatened heroes). A wind-up that is neither landed nor killed ended with the fight.

## Warrior skill use

| Dungeon | Fights | Skills / fight | Top-skill share / fight | Mix |
|---|---|---|---|---|
| D1 | 1522 | 1.7 | 79% | slash 77%, provoke 14%, cleave 7%, execute 3% |
| D2 | 1547 | 2.8 | 50% | slash 36%, provoke 26%, execute 25%, cleave 13% |
| D3 | 1417 | 2.9 | 52% | slash 34%, execute 27%, provoke 25%, cleave 14% |
| D4 | 1500 | 2.7 | 55% | slash 32%, execute 29%, provoke 26%, cleave 14% |

Fights he acted in, every attempt. Top-skill share / fight: the mean, over fights, of his most used skill's share in that fight (a 2-action fight is at least 50%). Mix: share of all his skill actions in that dungeon.

## Deadliest encounters

| Encounter | Fights | Wipes | Wipe % | Rounds | Party HP lost / fight |
|---|---|---|---|---|---|
| D1 boss: dragon_hatchling | 46 | 12 | 26.1% | 8.6 | 9% |
| D1 boss: vampire+bat+bat | 37 | 8 | 21.6% | 6.5 | 5% |
| D4 boss: necromancer+skeleton | 35 | 8 | 22.9% | 9.8 | 17% |
| D1 normal: orc+cultist+cultist | 61 | 7 | 11.5% | 4.2 | 19% |
| D2 boss: vampire+bat+bat | 45 | 7 | 15.6% | 7.3 | -2% |
| D4 boss: dragon_hatchling | 46 | 7 | 15.2% | 11.9 | 16% |
| D4 boss: vampire+bat+bat | 38 | 6 | 15.8% | 9.2 | -2% |
| D1 boss: necromancer+skeleton | 42 | 5 | 11.9% | 6.3 | 9% |
| D2 boss: dragon_hatchling | 40 | 5 | 12.5% | 9.2 | 13% |
| D2 elite: ogre+orc+orc+cultist | 25 | 5 | 20.0% | 10.5 | 31% |
| D3 boss: vampire+bat+bat | 37 | 5 | 13.5% | 8.3 | 0% |
| D2 boss: necromancer+skeleton | 31 | 4 | 12.9% | 6.7 | 10% |
| D3 boss: dragon_hatchling | 34 | 4 | 11.8% | 11.7 | 22% |
| D1 normal: ogre+orc+skeleton_archer | 58 | 3 | 5.2% | 4.8 | 2% |
| D2 normal: ogre+cultist | 53 | 3 | 5.7% | 4.6 | 4% |

The 15 encounters with the most wipes, every attempt: enemy ids in battle order, per dungeon and room kind. HP lost: party HP share before the fight minus after it (a wipe loses everything left).

## Level curve

| Dungeon | Campaigns in | Level at entry | Level at boss | Warrior SP earned |
|---|---|---|---|---|
| D1 | 100 | 1.0 (1-1) | 4.7 (4-6) | 2.3 (2-3) |
| D2 | 100 | 4.8 (4-6) | 7.9 (6-10) | 3.8 (3-5) |
| D3 | 100 | 8.1 (6-10) | 9.9 (9-10) | 4.9 (4-5) |
| D4 | 100 | 9.9 (9-10) | 10.0 (10-10) | 5.0 (5-5) |

Warrior SP earned: total by the end of that dungeon (talent SP comes at even levels), mean (min-max); it is spent in the city before the next one.

## Run length and attrition

| Dungeon | Fights | Party actions | Enemy actions | Est. minutes | Est. min incl. wiped runs | Room moves | Rests | Potions used | Potions bought | HP % entering boss |
|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 11.3 (9-14) | 172.1 (88-264) | 73.5 (29-135) | 16.2 (8.1-25.1) | 23.5 | 52.6 (26-77) | 0.7 (0-3) | 4.7 (1-8) | 1.2 (1-2) | 62% |
| D2 | 11.6 (10-14) | 204.0 (143-277) | 105.5 (63-156) | 19.6 (13.5-27.0) | 27.0 | 54.1 (36-83) | 0.3 (0-2) | 1.8 (0-8) | 1.7 (0-6) | 73% |
| D3 | 11.7 (9-14) | 229.6 (142-328) | 116.4 (64-184) | 22.0 (13.5-31.9) | 27.3 | 54.6 (34-77) | 0.3 (0-2) | 2.3 (0-10) | 2.4 (0-6) | 75% |
| D4 | 11.7 (9-14) | 222.2 (139-308) | 118.6 (69-180) | 21.5 (13.3-30.2) | 26.8 | 54.3 (39-78) | 0.2 (0-1) | 3.1 (0-13) | 3.5 (1-11) | 75% |

Mean (min-max) over the campaigns that beat that dungeon. Actions, moves, rests and potions used are the clearing run's; potions bought are for that run's city visit. Est. minutes = 5 s per party action + 1.5 s per enemy action, combat only: walking, menus, the city and reading events are not counted, so real play is longer. "Incl. wiped runs" adds the combat time of the wiped attempts. HP % entering the boss: party HP / party max HP (downed heroes count 0), over every campaign that reached the boss.

## Wipes

| Dungeon | Campaigns in | Wipes / campaign | 0 wipes | 1 | 2 | 3 (stuck) | At F1 | F2 | F3 | F4 | Boss |
|---|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 100 | 0.42 | 58 | 42 | 0 | 0 | 0 | 0 | 4 | 13 | 25 |
| D2 | 100 | 0.39 | 64 | 33 | 3 | 0 | 0 | 0 | 6 | 17 | 16 |
| D3 | 100 | 0.21 | 80 | 19 | 1 | 0 | 0 | 0 | 0 | 9 | 12 |
| D4 | 100 | 0.29 | 78 | 17 | 3 | 2 | 0 | 0 | 0 | 8 | 21 |

Wipes counted over every attempt at that dungeon; the "At" columns say where the party died. Campaigns finished (dungeon 4 beaten): 98 of 100; stuck: 2. Rooms left after 10 fled or stalled fights in a row: 0.

## Warrior talents after dungeon 4

| Talents | Campaigns |
|---|---|
| slash_rending, cleave_heavy, provoke_iron_wall, execute_sunder+ | 91 |
| slash_rending, cleave_heavy, execute_sunder+ | 7 |

`+` = boosted. Bought in the city, so the dungeon 4 boss is fought without
the SP earned inside dungeon 4.

## XP what-if

`--xp-mult` multiplies the XP awarded after each victory, in the bot only: the game's numbers are untouched. Each row replays 100 campaigns from the same seed with the same policy, so the rows differ only by XP.

**Level 9-10 at the dungeon 4 boss: x1.0 XP** (mean hero level 10.0, over 100 campaigns that reached it).

### Level at each boss

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 4.7 | 7.9 | 9.9 | 10.0 |

### Warrior SP earned by the end of each dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 2.3 | 3.8 | 4.9 | 5.0 |

### Wipes per campaign that entered the dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0.42 | 0.39 | 0.21 | 0.29 |

### Stuck (campaign ended in that dungeon)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0% | 0% | 0% | 2% |

### Est. minutes per dungeon (clearing run)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 16.2 | 19.6 | 22.0 | 21.5 |

### Rounds per fight

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 4.6 | 5.0 | 5.4 | 5.2 |

### Campaigns finished

| XP x | Beat dungeon 4 |
|---|---|
| x1.0 | 98 of 100 |

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

