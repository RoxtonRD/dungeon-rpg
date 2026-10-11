# Sim: campaign bot

Generated output: `tools/sim.sh campaign --runs 100 --seed 1 --xp-mult 1 --out docs/reports/balance-encounters.md`. Don't edit by hand.

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
| D1 | 6.0 (4-8) | 14.6 (10-18) | 2.3 (p10 1, p90 3) | 8.4 (5.7-13.0) | 0.77 | 0% |
| D2 | 8.1 (7-10) | 14.8 (13-19) | 1.9 (p10 1, p90 3) | 8.1 (5.9-10.9) | 0.04 | 0% |
| D3 | 9.9 (9-10) | 14.5 (12-17) | 2.2 (p10 1, p90 3) | 9.4 (7.5-11.9) | 0.12 | 0% |
| D4 | 10.0 (10-10) | 13.8 (11-16) | 2.5 (p10 1, p90 4) | 10.2 (7.5-13.5) | 2.12 | 60% |

Level: mean hero level (lowest-highest single hero) at the boss, from the latest attempt that reached it. Fights and minutes: mean over the campaigns that beat that dungeon (the clearing run only). Wipes: mean per campaign that entered it. Stuck: % of those that wiped out of the dungeon for good. Rounds / fight covers every fight, wiped runs included. Target: 15-20 minutes per dungeon (D-013).

## Encounter targets

| Dungeon | Rounds: normal | elite | boss | Boss first-try win | Wipes | Level at boss | Combat min | Warrior skills / fight | Warrior top skill |
|---|---|---|---|---|---|---|---|---|---|
| **Target** | 3-5 | 5-7 | 8-10 | 70-85% | 0.3-1.5 / campaign | 4 / 6 / 8 / 10 | 8-12 | 3+ | <= 50% |
| D1 | 2.2 [1-3] (2079) | 2.9 [2-5] (143) | 2.2 [2-3] (110) | 90% (90/100) | 0.77 | 6.0 | 8.4 | 1.3 | slash 76% |
| D2 | 1.8 [1-3] (1294) | 2.7 [2-4] (145) | 2.2 [2-3] (102) | 98% (98/100) | 0.04 | 8.1 | 8.1 | 1.3 | slash 63% |
| D3 | 2.1 [1-3] (1365) | 3.0 [2-5] (153) | 2.7 [2-3] (110) | 90% (90/100) | 0.12 | 9.9 | 9.4 | 1.6 | slash 52% |
| D4 | 2.3 [1-4] (2855) | 3.3 [2-5] (283) | 4.3 [2-8] (62) | 66% (37/56) | 2.12 | 10.0 | 10.2 | 1.8 | slash 36% |

**Wipes per campaign: 3.05** (all dungeons, 100 campaigns). Rounds: mean [p10-p90] (fights), every attempt. Boss first-try win: share of the campaigns that reached that boss whose first boss fight was a win. Combat min: clearing run. Warrior: distinct skills per fight he acted in, and his most used skill's share of his skill actions (potions not counted).

## Elite rooms

| Dungeon | Met | Taken | Skipped | Won | Rooms cut off by a skip |
|---|---|---|---|---|---|
| D1 | 282 | 51% (143/282) | 49% (139/282) | 99% (141/143) | 41 |
| D2 | 175 | 83% (145/175) | 17% (30/175) | 100% (145/145) | 3 |
| D3 | 194 | 79% (153/194) | 21% (41/194) | 100% (153/153) | 9 |
| D4 | 397 | 71% (283/397) | 29% (114/397) | 94% (266/283) | 33 |
| **All** | 1048 | 69% (724/1048) | 31% (324/1048) | 97% (705/724) | 86 |

Every attempt counted. Policy: take an elite room when party HP is at least 70% and nobody is downed, else skip it for good. Won is out of taken.

## Telegraphs

| Dungeon | Wind-ups | Landed | Charger killed | Single-target landed | ...on the Warrior | Answer: kill | provoke | heal/shield |
|---|---|---|---|---|---|---|---|---|
| D1 | 93 | 35 | 57 | 13 | 8 | 59 | 2 | 14 |
| D2 | 81 | 22 | 59 | 15 | 10 | 56 | 4 | 23 |
| D3 | 123 | 47 | 76 | 22 | 21 | 72 | 1 | 46 |
| D4 | 319 | 228 | 87 | 75 | 37 | 85 | 12 | 185 |
| **All** | 616 | 332 | 279 | 125 | 76 | 272 | 19 | 268 |

Every attempt counted. Answers are bot actions chosen by the telegraph rule (kill the charger if this turn's expected damage can, else the Warrior Provokes a single-target telegraph, else heal or shield the threatened heroes). A wind-up that is neither landed nor killed ended with the fight.

## Warrior skill use

| Dungeon | Fights | Skills / fight | Top-skill share / fight | Mix |
|---|---|---|---|---|
| D1 | 2100 | 1.3 | 86% | slash 76%, provoke 18%, execute 3%, cleave 3% |
| D2 | 1299 | 1.3 | 85% | slash 63%, provoke 24%, execute 11%, cleave 2% |
| D3 | 1348 | 1.6 | 74% | slash 52%, provoke 26%, execute 19%, cleave 4% |
| D4 | 2420 | 1.8 | 69% | slash 36%, provoke 32%, execute 25%, cleave 7% |

Fights he acted in, every attempt. Top-skill share / fight: the mean, over fights, of his most used skill's share in that fight (a 2-action fight is at least 50%). Mix: share of all his skill actions in that dungeon.

## Deadliest encounters

| Encounter | Fights | Wipes | Wipe % | Rounds | Party HP lost / fight |
|---|---|---|---|---|---|
| D4 normal: ogre+orc+skeleton_archer | 110 | 60 | 54.5% | 4.4 | 38% |
| D4 normal: ogre+cultist | 101 | 42 | 41.6% | 3.7 | 32% |
| D4 normal: orc+cultist+cultist | 112 | 30 | 26.8% | 4.4 | 28% |
| D4 normal: orc+orc+cultist | 116 | 23 | 19.8% | 4.3 | 20% |
| D4 normal: orc+orc+skeleton_archer | 108 | 16 | 14.8% | 3.9 | 7% |
| D4 boss: dragon_hatchling | 23 | 14 | 60.9% | 5.0 | 27% |
| D1 normal: ogre+cultist | 91 | 13 | 14.3% | 2.2 | 8% |
| D4 elite: ogre+orc+orc+cultist | 14 | 13 | 92.9% | 4.7 | 76% |
| D1 normal: orc+cultist+cultist | 90 | 12 | 13.3% | 2.6 | 12% |
| D1 normal: ogre+orc+skeleton_archer | 82 | 10 | 12.2% | 2.9 | 4% |
| D1 normal: orc+orc+cultist | 84 | 10 | 11.9% | 2.6 | 9% |
| D1 normal: orc+orc+skeleton_archer | 99 | 8 | 8.1% | 2.8 | 1% |
| D4 boss: necromancer+skeleton | 23 | 7 | 30.4% | 3.3 | 17% |
| D1 boss: dragon_hatchling | 31 | 6 | 19.4% | 2.5 | 12% |
| D1 normal: bandit+bandit+cultist | 137 | 4 | 2.9% | 2.9 | 9% |

The 15 encounters with the most wipes, every attempt: enemy ids in battle order, per dungeon and room kind. HP lost: party HP share before the fight minus after it (a wipe loses everything left).

## Level curve

| Dungeon | Campaigns in | Level at entry | Level at boss | Warrior SP earned |
|---|---|---|---|---|
| D1 | 100 | 1.0 (1-1) | 6.0 (4-8) | 2.8 (2-4) |
| D2 | 100 | 6.1 (4-8) | 8.1 (7-10) | 3.9 (3-5) |
| D3 | 100 | 8.3 (7-10) | 9.9 (9-10) | 5.0 (4-5) |
| D4 | 100 | 9.9 (9-10) | 10.0 (10-10) | 5.0 (5-5) |

Warrior SP earned: total by the end of that dungeon (talent SP comes at even levels), mean (min-max); it is spent in the city before the next one.

## Run length and attrition

| Dungeon | Fights | Party actions | Enemy actions | Est. minutes | Est. min incl. wiped runs | Room moves | Rests | Potions used | Potions bought | HP % entering boss |
|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 14.6 (10-18) | 90.8 (60-136) | 33.4 (10-73) | 8.4 (5.7-13.0) | 15.5 | 54.7 (24-77) | 0.5 (0-3) | 4.6 (2-8) | 1.2 (1-2) | 64% |
| D2 | 14.8 (13-19) | 86.2 (63-115) | 36.2 (23-53) | 8.1 (5.9-10.9) | 8.5 | 54.7 (37-81) | 0.2 (0-2) | 0.5 (0-3) | 0.6 (0-2) | 68% |
| D3 | 14.5 (12-17) | 99.8 (79-126) | 44.8 (31-59) | 9.4 (7.5-11.9) | 10.6 | 55.1 (34-83) | 0.4 (0-2) | 1.4 (0-6) | 1.5 (0-4) | 67% |
| D4 | 13.8 (11-16) | 102.3 (77-135) | 65.8 (42-91) | 10.2 (7.5-13.5) | 17.5 | 51.6 (32-77) | 1.1 (0-3) | 2.9 (0-9) | 3.3 (1-8) | 47% |

Mean (min-max) over the campaigns that beat that dungeon. Actions, moves, rests and potions used are the clearing run's; potions bought are for that run's city visit. Est. minutes = 5 s per party action + 1.5 s per enemy action, combat only: walking, menus, the city and reading events are not counted, so real play is longer. "Incl. wiped runs" adds the combat time of the wiped attempts. HP % entering the boss: party HP / party max HP (downed heroes count 0), over every campaign that reached the boss.

## Wipes

| Dungeon | Campaigns in | Wipes / campaign | 0 wipes | 1 | 2 | 3 (stuck) | At F1 | F2 | F3 | F4 | Boss |
|---|---|---|---|---|---|---|---|---|---|---|---|
| D1 | 100 | 0.77 | 24 | 75 | 1 | 0 | 0 | 0 | 12 | 55 | 10 |
| D2 | 100 | 0.04 | 96 | 4 | 0 | 0 | 0 | 0 | 0 | 2 | 2 |
| D3 | 100 | 0.12 | 88 | 12 | 0 | 0 | 0 | 0 | 0 | 2 | 10 |
| D4 | 100 | 2.12 | 17 | 14 | 9 | 60 | 0 | 0 | 2 | 188 | 22 |

Wipes counted over every attempt at that dungeon; the "At" columns say where the party died. Campaigns finished (dungeon 4 beaten): 40 of 100; stuck: 60. Rooms left after 10 fled or stalled fights in a row: 0.

## Warrior talents after dungeon 4

| Talents | Campaigns |
|---|---|
| slash_rending, cleave_heavy, provoke_iron_wall, execute_sunder+ | 40 |

`+` = boosted. Bought in the city, so the dungeon 4 boss is fought without
the SP earned inside dungeon 4.

## XP what-if

`--xp-mult` multiplies the XP awarded after each victory, in the bot only: the game's numbers are untouched. Each row replays 100 campaigns from the same seed with the same policy, so the rows differ only by XP.

**Level 9-10 at the dungeon 4 boss: x1.0 XP** (mean hero level 10.0, over 56 campaigns that reached it).

### Level at each boss

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 6.0 | 8.1 | 9.9 | 10.0 |

### Warrior SP earned by the end of each dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 2.8 | 3.9 | 5.0 | 5.0 |

### Wipes per campaign that entered the dungeon

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0.77 | 0.04 | 0.12 | 2.12 |

### Stuck (campaign ended in that dungeon)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 0% | 0% | 0% | 60% |

### Est. minutes per dungeon (clearing run)

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 8.4 | 8.1 | 9.4 | 10.2 |

### Rounds per fight

| XP x | D1 | D2 | D3 | D4 |
|---|---|---|---|---|
| x1.0 | 2.3 | 1.9 | 2.2 | 2.5 |

### Campaigns finished

| XP x | Beat dungeon 4 |
|---|---|
| x1.0 | 40 of 100 |

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

