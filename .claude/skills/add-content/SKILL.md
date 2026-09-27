---
name: add-content
description: Add or change game content in Dungeons of Praesidium — a skill, item, enemy or class as a .tres resource, with its translation keys, icon and registration. Use for any data authoring so nothing is left half-wired.
---

# Adding content

Content is data-driven: a `.tres` resource, text as translation keys, an
optional icon, and **registration** wherever the game lists content. Most
"it doesn't show up" bugs are a missed registration step.

## Common rules

- **Ids are save data.** The `id` field and the `.tres` file basename are
  stored in saves and used as lookup keys. Never rename an existing one
  without flagging it in the PR.
- **Text fields hold keys**, never literal text. Add every key to
  `i18n/translations.csv` (`"keys","pt_BR","en"`, all fields quoted),
  pt-BR first. Keep the CSV sorted in its existing groups.
- **`.tres` syntax:** copy an existing file of the same type as the
  template. Keep `[ext_resource … id="…"]` ids consistent with their
  `ExtResource("…")` uses. Don't hand-write a `uid=`; Godot adds it.
- **Icons are optional** and come from game-icons.net (D-002). Missing
  icons fall back gracefully.

## Replacing a skill (D-027)

If a skill changes into something very different, **don't edit it in
place**. Create a new `.tres` with a new basename and id, point the class's
`skills` array at it, and leave the old file untouched, so switching back
is a one-line change. Rename or delete the old one only after Roxton has
decided. After the save freeze line, a swap also needs a save migration
(saves key skills by basename).

## Skill (`SkillData`, `scripts/data/skill_data.gd`)

1. `resources/skills/<class>_<name>.tres`, using a sibling as the
   template. The file basename is the skill key used by saves and upgrades
   (`Party._skill_key`).
2. Keys: `SKILL_<CLASS>_<NAME>` (name) and `SKILLD_<CLASS>_<NAME>`
   (description).
3. Register it in the class's `skills` array
   (`resources/classes/<class>.tres`); order is the unlock order. Enemy
   skills live in `resources/skills/enemy/` and are referenced from the
   enemy's `.tres`.
4. Optional icon: `assets/icons/skills/<basename>.png`.

## Item (`ItemData`)

1. `resources/items/<id>.tres` (the basename must equal `id`).
2. Key: `ITEM_<ID>` (and a description key if the type uses one).
3. Register it where it should appear:
   - market random stock: `MARKET_EQUIPMENT_POOL` in `scripts/game_state.gd`
   - market potions: `MARKET_POTIONS` in `scripts/game_state.gd`
   - combat drops: `DROPPABLE` in `scripts/util/loot.gd`
4. Optional icon: `assets/icons/items/<id>.png`.

## Enemy (`EnemyData`)

1. `resources/enemies/<id>.tres`.
2. Name key following the existing `ENEMY_*` pattern.
3. Register it in `ENCOUNTER_POOLS` in `scripts/dungeon/dungeon_run.gd`
   (per floor). An enemy that isn't in a pool never spawns; `cultist` and
   `ogre` are examples of that today.

## Verify

- Every new key exists with both `pt_BR` and `en`.
- The resource loads: `tools/godot.sh` headless check, or CI's
  "everything loads" test.
- In a PR, list balance-relevant numbers so `qa-balance` can run the sim.
