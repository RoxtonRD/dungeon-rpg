# CLAUDE.md

Project context for Claude Code. Read this before any task.

## What this is

A turn-based tactical dungeon-crawler RPG for Android, inspired by
Monster's Den. Built in Godot 4.6 with GDScript. Portrait orientation.
Fully localized: Brazilian Portuguese (pt-BR, source language) and
English, selectable in-game.

This is **version 2 (Fases 1 e 2)**: a room-based dungeon replaced the
v1 node-map, and the city hub is the home base between dungeons. The
goal remains a functional, fun game with the minimum number of systems.
See `design-doc-v2.md` for the current spec (`design-doc-v1.md`
documents the v1 base that everything else reuses).

## Core loop

city hub -> enter dungeon -> fight -> get loot -> return to city ->
prepare (market/gear) -> deeper dungeon

Any system that does not directly serve this loop is out of scope.

## Stack & conventions

- Engine: Godot 4.6, GDScript only. No C#, no external build steps.
- Platform: Android, portrait orientation.
- Game data is **data-driven**: defined as Godot Resources (`.tres`),
  never hardcoded. Resource types: `ClassData`, `SkillData`,
  `EnemyData`, `ItemData`.
- UI: one Godot scene per screen, using `Control` nodes and signals.
- Save: file-based (JSON via `FileAccess` or `ConfigFile`), with a
  versioned save format to allow future migrations.
- **i18n**: all user-facing text lives as keys in `i18n/translations.csv`
  (columns `keys,pt_BR,en`); resolve with `tr()` (or
  `TranslationServer.translate()` in static contexts). `.tres`
  `display_name`/`description` fields hold keys, not literal text — never
  hardcode a Portuguese string in a scene, script or resource.
- Device settings (locale, combat speed) live in `user://settings.cfg`
  via the `Settings` autoload — separate from game saves.

## Working style

- Work in **small, verifiable slices**. One screen or one system at a
  time. After each slice, stop so the result can be tested in the Godot
  editor before continuing.
- Use **explicit placeholders for art**: `ColorRect` or generic icons
  wherever a hand-drawn portrait (character / item / enemy) will go.
  Never block on missing art and never invent art assets.
- Prefer clear, readable GDScript over clever code. This is a learning
  project as much as a shipping one.
- After completing a slice, suggest a concise commit message.

## v2 scope — IN (Fases 1 e 2)

4 classes (Guerreiro, Clerigo, Ladino, Mago); **customizable party:
character creation on New Adventure builds all four heroes, each with a
typed name, chosen class and chosen skin, with at most 2 heroes of any
one class; heroes can be renamed and reskinned (cosmetic only, class
fixed) from the city Characters screen; hero skins are drop-in via
`HeroArt` and `assets/full_body/README.md`**; turn-based combat
with front/back rows; 2x2 formation grid; **room-based dungeon: 4 floors
of orthogonally connected grid rooms, fog of war (seen rooms persist),
stairs room per floor, boss room on floor 4**; room types (combat,
treasure, event, rest, empty, stairs, boss); **city hub between dungeons
(Mercado, Personagens, Formação, Entrar na Masmorra); Mercado with fixed
potions + limited-stock random equipment, restocking when a run ends
(complete/abandon/TPK); leaving a dungeon abandons the run**; 4 skills
per class; XP/levels with 1 Skill Point per level (surplus converts to
+2 max MP); equipment slots with stat modifiers; versioned file-based
save (run layouts, explored rooms, player position, market stock) with
a TPK rule (revive at 25% HP, lose 20% gold); **pt-BR/English
localization; settings screen (language + combat speed) and credits
screen from the main menu**.

## Scope — OUT (do not build unless asked)

Tile art for rooms and city art (themed chips / placeholder backgrounds
for now); 4x3 tactical grid with distance-based accuracy; Hardcore mode;
scaling shop tiers; sound; animations beyond combat particles; loot
affixes; save migration from v1.

## Out of bounds

Do not add systems, screens, or mechanics not listed in the current
scope without asking first. If something seems missing, ask before
building it.
