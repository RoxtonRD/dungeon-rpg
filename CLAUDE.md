# CLAUDE.md

Project context for Claude Code. Read this before any task.

## What this is

A turn-based tactical dungeon-crawler RPG for Android, inspired by
Monster's Den. Built in Godot 4.6 with GDScript. Portrait orientation.
UI text is in Brazilian Portuguese (pt-BR).

This is **version 2, Fase 1**: the v1 node-map was replaced by a
room-based dungeon. The goal remains a functional, fun game with the
minimum number of systems. See `design-doc-v2.md` for the current spec
(`design-doc-v1.md` documents the v1 base that everything else reuses).

## Core loop

enter dungeon -> fight -> get loot -> grow stronger -> next dungeon

Any system that does not directly serve this loop is out of scope for v1.

## Stack & conventions

- Engine: Godot 4.6, GDScript only. No C#, no external build steps.
- Platform: Android, portrait orientation.
- Game data is **data-driven**: defined as Godot Resources (`.tres`),
  never hardcoded. Resource types: `ClassData`, `SkillData`,
  `EnemyData`, `ItemData`.
- UI: one Godot scene per screen, using `Control` nodes and signals.
- Save: file-based (JSON via `FileAccess` or `ConfigFile`), with a
  versioned save format to allow future migrations.

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

## v2 Fase 1 scope — IN

4 fixed classes (Guerreiro, Clerigo, Ladino, Mago); turn-based combat
with front/back rows; 2x2 formation grid; **room-based dungeon: 4 floors
of orthogonally connected grid rooms, fog of war (explored + adjacent
visible), stairs room per floor, boss room on floor 4**; room types
(combat, treasure, event, rest, empty, stairs, boss); 4 skills per class;
XP/levels with 1 Skill Point per level (surplus converts to +2 max MP);
equipment slots with stat modifiers; single fixed-tier shop; versioned
file-based save (v2: floor layouts, explored rooms, player position)
with a TPK rule (revive at 25% HP, lose 20% gold).

## Scope — OUT (do not build unless asked)

Cidade hub (Fase 2 — next mission); tile art for rooms (themed chips for
now); 4x3 tactical grid with distance-based accuracy; Hardcore mode;
scaling shop tiers; sound; animations beyond combat particles; loot
affixes; save migration from v1.

## Out of bounds

Do not add systems, screens, or mechanics not listed in v1 scope without
asking first. If something seems missing, ask before building it.
