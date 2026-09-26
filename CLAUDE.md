# CLAUDE.md

Project context for Claude Code. Read this before any task.

## What this is

A turn-based tactical party dungeon crawler for Android, inspired by
Monster's Den. Built in Godot 4.7 with GDScript. Portrait orientation.
Fully localized: Brazilian Portuguese (pt-BR, source language) and
English, selectable in-game.

**Goal:** ship 1.0 on Google Play: a short, tactical dungeon crawl the
player *wants* to replay.

## Read first

1. [`docs/PLAN.md`](docs/PLAN.md): current phase, the **Now** block, what
   is in and out of scope, and the agent team rules.
2. [`docs/DECISIONS.md`](docs/DECISIONS.md): settled decisions and why.
   Don't re-argue them without new information, and add an entry when a
   new decision is made.
3. [`docs/design-doc-v2.md`](docs/design-doc-v2.md): how the existing
   systems work (dungeon, city, classes, statuses, loot).

`docs/archive/` holds old plans. They are history, **not instructions**.

## Core loop

city hub -> enter dungeon -> fight -> get loot -> return to city ->
prepare (market/gear) -> deeper dungeon

Any system that does not directly serve this loop is out of scope.

## What exists (the v2 build)

- 6 classes (Guerreiro, Clérigo, Ladino, Mago, Conjurador, Alquimista),
  4 skills each, 3 upgrade tiers; XP/levels to 10, 1 SP per level.
- Character creation builds a party of 4 (max 2 of any class), with names
  and skins. **Skins are frozen** (D-001).
- Turn-based combat: front/back rows, 2x2 formation, consumables in
  combat, status effects on a global turn counter that persists outside
  combat.
- Room-based dungeon: 4 floors, fog of war, stairs, boss on floor 4; room
  types combat / treasure / event / rest / empty / stairs / boss / shrine.
- City hub: Market (fixed potions + limited random stock, restocks when a
  run ends), Characters, Formation, Enter Dungeon.
- Item rarity tiers with depth-scaled drops (`scripts/util/loot.gd`).
- Versioned JSON save; TPK rule (revive at 25% HP, lose 20% gold).
- Settings (language, combat speed) and credits screens.
- Dev tool: `scripts/dev/balance_sim.gd`, a headless combat simulator.

## Stack & conventions

- Engine: Godot 4.7, GDScript only. No C#, no external build steps.
- Platform: Android (target API 36), portrait orientation.
- Game data is **data-driven**: Godot Resources (`.tres`), never
  hardcoded. Resource types: `ClassData`, `SkillData`, `EnemyData`,
  `ItemData`.
- UI: one Godot scene per screen, using `Control` nodes and signals.
- Save: JSON via `FileAccess`, versioned. Until the save freeze line
  (D-004) the format may change freely; after it, every change needs a
  migration step and a fixture test.
- **i18n**: all user-facing text lives as keys in `i18n/translations.csv`
  (columns `keys,pt_BR,en`); resolve with `tr()` (or
  `TranslationServer.translate()` in static contexts). `.tres`
  `display_name`/`description` fields hold keys, not literal text. Never
  hardcode a Portuguese string in a scene, script or resource.
- Device settings (locale, combat speed) live in `user://settings.cfg`
  via the `Settings` autoload, separate from game saves.

## Art

- **No generated art** (D-002). Icons come from
  [game-icons.net](https://game-icons.net) (CC BY 3.0, credit on the
  credits screen). Where art is missing, use flat colour or a `ColorRect`.
- Never invent art assets and never block on missing art.

## Working style

- Work in **small, verifiable slices** that fit one sitting. After each
  slice, stop so the result can be tested in the Godot editor.
- Prefer clear, readable GDScript over clever code. This is a learning
  project as much as a shipping one.
- After completing a slice, suggest a concise commit message.
- At the end of a session, update the **Now** block in `docs/PLAN.md`.

## Multi-agent rules

Full rules are in `docs/PLAN.md` § Team. The short version:

- **One editor, one driver.** Only one session uses the Godot MCP at a
  time. Editor drivers work in the main checkout on a feature branch;
  everyone else uses a worktree and runs Godot headless.
- Briefs are GitHub issues. One branch and one PR per task; agents never
  merge. Stay inside the files your role owns.
- If a brief is wrong or incomplete, stop and report. Don't improvise
  scope.

## Out of bounds

Do not add systems, screens, or mechanics that are not in the current
phase of `docs/PLAN.md` without asking first. If something seems missing,
ask before building it.
