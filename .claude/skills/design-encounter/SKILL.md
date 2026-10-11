---
name: design-encounter
description: Design or author enemy encounters for Dungeons of Praesidium: enemy AI roles, encounter groups per floor, elites, telegraphed attacks and fight-length targets. Use when adding or changing enemies, enemy skills or encounter tables, so every fight asks for a decision.
---

# Designing encounters (encounters v3, D-028, D-038)

The aim: **every fight asks for more than one obvious move.** Random piles
of enemies dying in 2 rounds are the failure mode this replaces.

## Enemy AI roles (`EnemyData.ai_role`)

| Role | Plays like | Targeting (the AI does this) |
|---|---|---|
| `BRUTE` | lots of HP, hits hard, front row | front-row heroes; respects taunt |
| `SKIRMISHER` | fast, fragile | the **lowest HP %** hero, any row; respects taunt |
| `CASTER` | area damage and debuffs, back row | AOE when 3+ heroes alive, else a debuff or the strongest hit |
| `SUPPORT` | heals or buffs allies, back row | heals an ally under 50% HP, else buffs, else attacks. **The kill-first target** |

Bosses use their own skill list, but still pick a role for targeting.

## Telegraphed attacks (`SkillData.telegraph_turns`)

- A telegraphed skill takes **one turn to wind up**. The enemy gets a
  visible *Charging* status, and the banner reads "*Ogre* is winding up
  *Smash*". It lands on that enemy's **next** turn.
- If the enemy dies while charging, the attack is lost. The player's
  answers: kill it, Provoke it onto the tank, shield, heal ahead, or
  spread out the damage.
- Use them on brutes, elites and bosses. **At most one telegraph user per
  normal group.** Bosses may have one on a cooldown.
- A telegraph must be worth answering: roughly 1.5–2× a normal hit, or
  an AOE.

## Encounter groups (`EncounterGroupData`)

- Fields: `id`, `members` (enemy ids), `floor_min`, `floor_max`, `weight`,
  `elite`.
- **Normal groups:** 2–4 enemies, at least one front-row enemy, a mix of
  roles, **at most one SUPPORT**.
- **Elite groups:** 3–5 enemies, or a normal group plus a leader; they
  always contain a telegraph or a support. They appear only in elite
  rooms.
- Each floor should have **4–6 normal groups and 1–2 elite groups**, with
  enemies that belong together (a goblin camp, a wolf pack, a crypt
  patrol). New enemy kinds come in as you go deeper; don't put the whole
  roster on floor 1.
- Group names are internal (not shown); keep ids descriptive
  (`f2_goblin_camp`).

## Fight-length targets (the bot measures these, see `balance-loop`)

| Fight | Rounds | Notes |
|---|---|---|
| Normal | 3–5 | the Warrior gets to use 3+ distinct skills |
| Elite | 5–7 | worth skipping when hurt; that's the choice |
| Boss | 8–10 | 70–85% first-try win for the bot |

## Authoring checklist

1. New enemies and skills follow the `add-content` skill (`.tres`,
   pt-BR + en keys, registration).
2. Every enemy has an `ai_role`; every group follows the rules above.
3. Numbers are placeholders until a `balance-loop` pass. Note them as such
   in the PR.
4. `tools/test.sh` passes (everything loads, every key exists).
