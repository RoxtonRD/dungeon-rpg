# Sim: Warrior talent builds

Generated output: `tools/sim.sh all --fights 200 --seed 1 --out docs/reports/sim-warrior-talents.md`. Don't edit by hand.

- **Seed:** 1 (each build reseeded)
- **Sample:** 200 fights per cell, each from full HP
- **Party:** warrior, cleric, rogue, mage
- **Levels by dungeon 1-4:** [2, 3, 4, 5] (Warrior SP [1, 1, 2, 2])
- **Gear:** best droppable item one tier behind the depth (offset -1)
- **Policy:** balance_sim `_player_turn` (Warrior Provoke rule included)

## Talents taken

| Build | D1 (L2) | D2 (L3) | D3 (L4) | D4 (L5) |
|---|---|---|---|---|
| none | 1 SP unspent | 1 SP unspent | 2 SP unspent | 2 SP unspent |
| tank | slash_momentum | provoke_vengeance | provoke_vengeance+ | provoke_vengeance+ |
| executioner | slash_rending | slash_rending | slash_rending, cleave_heavy | execute_sunder+ |

`+` = boosted.

## Win % (average rounds)

| Cell | none | tank | executioner |
|---|---|---|---|
| D1_F1 | 100% (0.7) | 100% (0.7) | 100% (0.7) |
| D1_F2 | 100% (1.6) | 100% (1.6) | 100% (1.7) |
| D1_F3 | 100% (2.2) | 100% (2.2) | 100% (2.1) |
| D1_F4 | 100% (2.8) | 100% (2.8) | 99% (2.7) |
| D1_BOSS | 86% (5.3) | 86% (5.3) | 93% (4.0) |
| D2_F1 | 100% (0.8) | 100% (0.8) | 100% (0.7) |
| D2_F2 | 100% (1.9) | 100% (1.9) | 100% (1.8) |
| D2_F3 | 100% (2.5) | 100% (2.5) | 100% (2.4) |
| D2_F4 | 100% (3.0) | 100% (3.0) | 100% (2.8) |
| D2_BOSS | 93% (3.8) | 93% (3.8) | 96% (3.3) |
| D3_F1 | 100% (1.1) | 100% (1.1) | 100% (1.1) |
| D3_F2 | 100% (2.9) | 100% (2.6) | 100% (2.6) |
| D3_F3 | 98% (3.8) | 100% (3.6) | 99% (3.4) |
| D3_F4 | 91% (4.8) | 93% (5.0) | 90% (4.6) |
| D3_BOSS | 50% (6.3) | 52% (6.2) | 62% (5.6) |
| D4_F1 | 100% (0.7) | 100% (0.7) | 100% (0.8) |
| D4_F2 | 100% (1.6) | 100% (1.5) | 100% (1.6) |
| D4_F3 | 98% (1.9) | 99% (1.8) | 99% (2.0) |
| D4_F4 | 95% (2.8) | 94% (2.5) | 94% (2.7) |
| D4_BOSS | 83% (3.2) | 85% (3.3) | 84% (3.0) |

## Warrior skill usage (% of his actions)

| Build | Dungeon | slash | cleave | provoke | execute | Actions | Distinct skills / fight |
|---|---|---|---|---|---|---|---|
| none | D1 (L2) | 90% | 10% | 0% | 0% | 2690 | 1.16 |
| none | D2 (L3) | 62% | 11% | 28% | 0% | 2656 | 1.78 |
| none | D3 (L4) | 59% | 15% | 26% | 0% | 3690 | 1.96 |
| none | D4 (L5) | 47% | 0% | 26% | 27% | 2137 | 1.85 |
| none | **all** | 65% | 10% | 20% | 5% | 11173 | 1.69 |
| tank | D1 (L2) | 90% | 10% | 0% | 0% | 2690 | 1.16 |
| tank | D2 (L3) | 62% | 11% | 28% | 0% | 2656 | 1.78 |
| tank | D3 (L4) | 61% | 16% | 23% | 0% | 3652 | 1.97 |
| tank | D4 (L5) | 44% | 0% | 25% | 30% | 2055 | 1.79 |
| tank | **all** | 65% | 10% | 19% | 6% | 11053 | 1.68 |
| executioner | D1 (L2) | 89% | 11% | 0% | 0% | 2583 | 1.16 |
| executioner | D2 (L3) | 62% | 10% | 28% | 0% | 2522 | 1.74 |
| executioner | D3 (L4) | 49% | 24% | 27% | 0% | 3436 | 2.00 |
| executioner | D4 (L5) | 48% | 0% | 25% | 26% | 2073 | 1.79 |
| executioner | **all** | 62% | 13% | 20% | 5% | 10614 | 1.67 |

Slice target (combat-v3 §4): 3+ distinct skills per fight, no skill above 50% of actions.

