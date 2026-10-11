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
| D1 | 6.1 (4-7) | 14.5 (12-17) | 3.0 (p10 2, p90 5) | 11.4 (7.2-19.1) | 0.90 | 0% |
| D2 | 8.2 (7-9) | 14.7 (12-17) | 2.4 (p10 1, p90 4) | 11.1 (8.3-13.5) | 0.02 | 0% |
| D3 | 9.9 (9-10) | 14.8 (13-18) | 2.7 (p10 1, p90 5) | 12.8 (9.4-17.0) | 0.01 | 0% |
| D4 | 10.0 (10-10) | 15.0 (13-17) | 3.0 (p10 1, p90 5) | 14.8 (11.6-19.0) | 0.33 | 3% |

Level: mean hero level (lowest-highest single hero) at the boss, from the latest attempt that reached it. Fights and minutes: mean over the campaigns that beat that dungeon (the clearing run only). Wipes: mean per campaign that entered it. Stuck: % of those that wiped out of the dungeon for good. Rounds / fight covers every fight, wiped runs included. Target: 15-20 minutes per dungeon (D-013).

## Encounter targets

| Dungeon | Rounds: normal | elite | boss | Boss first-try win | Wipes | Level at boss | Combat min | Warrior skills / fight | Warrior top skill |
|---|---|---|---|---|---|---|---|---|---|
| **Target** | 3-5 | 5-7 | 8-10 | 70-85% | 0.3-1.5 / campaign | 4 / 6 / 8 / 10 | 8-12 | 3+ | <= 50% |
| D1 | 2.7 [1-4] (2217) | 3.7 [2-6] (169) | 6.1 [4-9] (120) | 80% (80/100) | 0.90 | 6.1 | 11.4 | 1.6 | slash 70% |
| D2 | 2.0 [1-3] (1251) | 3.2 [2-5] (150) | 6.3 [5-8] (102) | 98% (98/100) | 0.02 | 8.2 | 11.1 | 1.6 | slash 62% |
| D3 | 2.3 [1-3] (1237) | 3.6 [2-5] (153) | 7.2 [6-10] (101) | 99% (99/100) | 0.01 | 9.9 | 12.8 | 1.7 | slash 63% |
| D4 | 2.5 [1-4] (1618) | 3.9 [2-6] (218) | 8.8 [6-12] (130) | 78% (78/100) | 0.33 | 10.0 | 14.8 | 2.0 | slash 46% |

**Wipes per campaign: 1.26** (all dungeons, 100 campaigns). Rounds: mean [p10-p90] (fights), every attempt. Boss first-try win: share of the campaigns that reached that boss whose first boss fight was a win. Combat min: clearing run. Warrior: distinct skills per fight he acted in, and his most used skill's share of his skill actions (potions not counted).

## Elite rooms

| Dungeon | Met | Taken | Skipped | Won | Rooms cut off by a skip |
|---|---|---|---|---|---|
| D1 | 299 | 57% (169/299) | 43% (130/299) | 100% (169/169) | 28 |
| D2 | 189 | 79% (150/189) | 21% (39/189) | 100% (150/150) | 9 |
| D3 | 184 | 83% (153/184) | 17% (31/184) | 100% (153/153) | 5 |
| D4 | 240 | 91% (218/240) | 9% (22/240) | 100% (218/218) | 2 |
| **All** | 912 | 76% (690/912) | 24% (222/912) | 100% (690/690) | 44 |

Every attempt counted. Policy: take an elite room when party HP is at least 70% and nobody is downed, else skip it for good. Won is out of taken.

## Telegraphs

| Dungeon | Wind-ups | Landed | Charger killed | Single-target landed | ...on the Warrior | Answer: kill | provoke | heal/shield |
|---|---|---|---|---|---|---|---|---|
| D1 | 176 | 99 | 75 | 28 | 23 | 75 | 2 | 38 |
| D2 | 124 | 52 | 72 | 30 | 25 | 70 | 2 | 53 |
| D3 | 128 | 69 | 59 | 42 | 29 | 61 | 6 | 70 |
| D4 | 251 | 153 | 98 | 86 | 65 | 93 | 18 | 148 |
| **All** | 679 | 373 | 304 | 186 | 142 | 299 | 28 | 309 |

Every attempt counted. Answers are bot actions chosen by the telegraph rule (kill the charger if this turn's expected damage can, else the Warrior Provokes a single-target telegraph, else heal or shield the threatened heroes). A wind-up that is neither landed nor killed ended with the fight.

## Warrior skill use

| Dungeon | Fights | Skills / fight | Top-skill share / fight | Mix |
|---|---|---|---|---|
| D1 | 2376 | 1.6 | 78% | slash 70%, provoke 18%, execute 8%, cleave 4% |
| D2 | 1314 | 1.6 | 77% | slash 62%, provoke 18%, execute 17%, cleave 2% |
| D3 | 1313 | 1.7 | 74% | slash 63%, execute 19%, provoke 16%, cleave 2% |
| D4 | 1752 | 2.0 | 65% | slash 46%, provoke 25%, execute 23%, cleave 7% |

Fights he acted in, every attempt. Top-skill share / fight: the mean, over fights, of his most used skill's share in that fight (a 2-action fight is at least 50%). Mix: share of all his skill actions in that dungeon.

## Deadliest encounters

| Encounter | Fights | Wipes | Wipe % | Rounds | Party HP lost / fight |
|---|---|---|---|---|---|
| D4 boss: dragon_hatchling | 37 | 18 | 48.6% | 10.7 | 41% |
| D1 normal: ogre+cultist | 122 | 14 | 11.5% | 3.0 | 8% |
| D1 normal: ogre+orc+skeleton_archer | 105 | 14 | 13.3% | 3.6 | 2% |
| D1 normal: orc+cultist+cultist | 94 | 13 | 13.8% | 3.2 | 14% |
| D4 boss: necromancer+skeleton | 37 | 12 | 32.4% | 8.8 | 37% |
| D1 boss: necromancer+skeleton | 48 | 10 | 20.8% | 5.8 | 21% |
| D1 normal: orc+orc+cultist | 83 | 10 | 12.0% | 3.8 | 10% |
| D1 boss: vampire+bat+bat | 40 | 6 | 15.0% | 5.2 | 2% |
| D1 normal: orc+orc+skeleton_archer | 78 | 5 | 6.4% | 3.6 | -1% |
| D1 boss: dragon_hatchling | 32 | 4 | 12.5% | 7.5 | 21% |
| D1 normal: bandit+dark_elf+dark_elf | 157 | 4 | 2.5% | 3.0 | -1% |
| D1 normal: bandit+bandit+cultist | 151 | 3 | 2.0% | 3.3 | 9% |
| D1 normal: skeleton+skeleton+skeleton_archer | 154 | 3 | 1.9% | 2.7 | -1% |
| D4 boss: vampire+bat+bat | 56 | 3 | 5.4% | 7.6 | -1% |
| D1 normal: bandit+bandit+dark_elf | 153 | 2 | 1.3% | 3.3 | 0% |

The 15 encounters with the most wipes, every attempt: enemy ids in battle order, per dungeon and room kind. HP lost: party HP share before the fight minus after it (a wipe loses everything left).

## Level curve

| Dungeon | Campaigns in | Level at entry | Level at boss | Warrior SP earned |
|---|---|---|---|---|
| D1 | 100 | 1.0 (1-1) | 6.1 (4-7) | 2.9 (2-3) |
| D2 | 100 | 6.3 (4-7) | 8.2 (7-9) | 3.9 (3-4) |
| D3 | 100 | 8.3 (7-9) | 9.9 (9-10) | 5.0 (4-5) |
| D4 | 100 | 10.0 (9-10) | 10.0 (10-10) | 5.0 (5-5) |

Warrior SP earned: total by the end of that dungeon (talent SP comes at even levels), mean (min-max); it is spent in the city before the next one.

## Run length and attrition

| Dungeon | Fights | Party actions | Enemy actions | Est. minutes | Est. min incl. wiped runs | Room moves | Rests | Potions used | Potions bought | HP % entering boss |
|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 14.5 (12-17) | 123.4 (81-201) | 43.2 (19-94) | 11.4 (7.2-19.1) | 23.1 | 55.1 (31-90) | 0.4 (0-2) | 5.0 (4-8) | 1.1 (1-2) | 67% |
| D2 | 14.7 (12-17) | 119.3 (89-145) | 45.8 (30-64) | 11.1 (8.3-13.5) | 11.3 | 53.3 (34-82) | 0.1 (0-1) | 0.6 (0-4) | 0.8 (0-3) | 71% |
| D3 | 14.8 (13-18) | 137.2 (103-180) | 53.0 (30-80) | 12.8 (9.4-17.0) | 12.9 | 54.7 (34-90) | 0.1 (0-1) | 1.1 (0-8) | 1.5 (0-6) | 75% |
| D4 | 15.0 (13-17) | 153.8 (121-196) | 77.7 (53-106) | 14.8 (11.6-19.0) | 18.6 | 55.6 (35-78) | 0.1 (0-2) | 2.7 (0-10) | 2.1 (0-7) | 71% |

Mean (min-max) over the campaigns that beat that dungeon. Actions, moves, rests and potions used are the clearing run's; potions bought are for that run's city visit. Est. minutes = 5 s per party action + 1.5 s per enemy action, combat only: walking, menus, the city and reading events are not counted, so real play is longer. "Incl. wiped runs" adds the combat time of the wiped attempts. HP % entering the boss: party HP / party max HP (downed heroes count 0), over every campaign that reached the boss.

## Wipes

| Dungeon | Campaigns in | Wipes / campaign | 0 wipes | 1 | 2 | 3 (stuck) | At F1 | F2 | F3 | F4 | Boss |
|---|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 100 | 0.90 | 10 | 90 | 0 | 0 | 0 | 0 | 14 | 56 | 20 |
| D2 | 100 | 0.02 | 98 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 2 |
| D3 | 100 | 0.01 | 99 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| D4 | 100 | 0.33 | 78 | 14 | 5 | 3 | 0 | 0 | 0 | 0 | 33 |

Wipes counted over every attempt at that dungeon; the "At" columns say where the party died. Campaigns finished (dungeon 4 beaten): 97 of 100; stuck: 3. Rooms left after 10 fled or stalled fights in a row: 0.

## Warrior talents after dungeon 4

| Talents | Campaigns |
|---|---|
| slash_rending, cleave_heavy, provoke_iron_wall, execute_sunder+ | 93 |
| slash_rending, cleave_heavy, execute_sunder+ | 4 |

`+` = boosted. Bought in the city, so the dungeon 4 boss is fought without
the SP earned inside dungeon 4.

## XP what-if

`--xp-mult` multiplies the XP awarded after each victory, in the bot only: the game's numbers are untouched. Each row replays 100 campaigns from the same seed with the same policy, so the rows differ only by XP.

**Level 9-10 at the dungeon 4 boss: x1.0 XP** (mean hero level 10.0, over 100 campaigns that reached it).

### Level at each boss

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 6.1 | 8.2 | 9.9 | 10.0 |

### Warrior SP earned by the end of each dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 2.9 | 3.9 | 5.0 | 5.0 |

### Wipes per campaign that entered the dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0.90 | 0.02 | 0.01 | 0.33 |

### Stuck (campaign ended in that dungeon)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0% | 0% | 0% | 3% |

### Est. minutes per dungeon (clearing run)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 11.4 | 11.1 | 12.8 | 14.8 |

### Rounds per fight

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 3.0 | 2.4 | 2.7 | 3.0 |

### Campaigns finished

| XP x | Beat dungeon 4 |
|---|---|
| x1.0 | 97 of 100 |

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

