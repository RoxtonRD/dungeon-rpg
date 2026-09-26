# Plan — Dungeons of Praesidium → 1.0 on Google Play

> Source of truth for *what we are doing and why*. Decisions and their
> reasons live in [`DECISIONS.md`](DECISIONS.md). How the current systems
> work lives in [`design-doc-v2.md`](design-doc-v2.md). Old plans are in
> [`archive/`](archive/) for reference only — they are not instructions.

---

## Now

*The advisor updates this block after every merge or decision. Workers
report back instead of editing it. It is the re-entry point: if you come
back after weeks away, this is the only thing you need to read.*

- **Phase:** 1 — Find the fun (Phase 0 runs alongside, delegated)
- **Focus:** finish the Phase 0 safety net, then the Warrior slice (D-013)
- **Done:** save hardening (#28 → PR #33), tests + CI (#30 → PR #34),
  format hook (#31 → PR #37)
- **In review:** dev cheat panel #32 → PR #41, save tests #35 → PR #40
- **Next up:**
  1. gameplay-engineer: Warrior slice 1/3, Rage + cooldowns, #38
     (editor, after #32)
  2. Roxton: play the Warrior (3 fights via the dev panel), which is the
     **feel gate** for combat v3
  3. advisor: brief Warrior slice 2/3 (skill forks) from that feedback
  4. release-engineer: target SDK 36 + a build on the phone, brief not
     written yet
  5. Roxton: branch protection on `main` (require PR + both CI checks)
- **Blocked on:** nothing

---

## North star

A short, tactical party dungeon crawl that you *want* to replay.

**The only test that matters:** after finishing a run, do you want to start
the next one? Every phase exit below is a version of that question.

## Working principles

1. **Fun before content, content before polish, polish before platforms.**
2. **Phases have exit criteria, not dates.** Work lands when it lands.
3. **Every task fits one sitting** — a 1–2 h weekday session, or one block
   of a weekend day — and ends with something you can *see or feel* in the
   game. If a task can't, it gets split.
4. **Saves can break freely until the save freeze line** (the first build
   an external tester installs). After it, every save-format change ships
   with a migration and a fixture test. See D-004.
5. **No new generated art.** Icons from game-icons.net, flat colour for
   everything else. See D-002.
6. **No lore work.** Names that already exist in the game stay as flavour.
   See D-003.

---

## Phase 0 — Safety net

Small, mostly delegated. Runs in parallel with Phase 1 so it never blocks
the fun work.

| Task | Owner |
|---|---|
| ✅ Docs restructure: this plan, decisions log, agent team, CLAUDE.md | advisor |
| Commit the `addons/godot_ai` plugin update as its own commit | Roxton |
| **DevTools save safety net:** the first state-changing DevTools call per session copies the real save to `save.pre_devtools.json`, so a playtest can never lose Roxton's progress (D-018) | gameplay-engineer |
| ✅ **Save hardening** (#28 → PR #33): atomic write via tmp + rotation, `save.bak.json` fallback, `save.corrupt.json` kept as evidence, migration chain (D-016) | gameplay-engineer |
| ✅ Dev tooling: shared `.claude/settings.json` (permissions, deny `gh pr merge` and pushes to `main`), session-start hook, issue and PR templates, skills (`write-brief`, `review-pr`, `add-content`, `smoke-test`), `tools/godot.sh` (D-014) | advisor |
| ✅ **Tests + CI** (#30 → PR #34): gdUnit4 6.2.1 in `test/`; every `.gd`/`.tres` loads, i18n complete; `tools/test.sh`; GitHub Action on every PR | qa-balance |
| **Save tests** (#35): round-trip, crash-safety, v3 fixture, isolated `user://` | qa-balance |
| ✅ **Format + syntax hook** (#31 → PR #37): gdformat pass, PostToolUse hook, CI format check; gdlint non-blocking (52 style warnings) | qa-balance |
| Branch protection on `main`: require a PR and the CI check | Roxton |
| Target SDK 34 → 36; confirm the Godot 4.7 export template; install a build on the phone | release-engineer |
| Log in to Play Console: check the account is active, identity verification is done, and note the account creation date | Roxton |

**Exit:** the game runs on your phone; a save interrupted mid-write loses
nothing (tested); tests run from the command line and on every PR.

---

## Phase 1 — Find the fun

The phase that matters. Everything else is known work; this is the
unknown.

**The problems, as measured and felt:**
- Skills are mostly single-target or AOE damage; several don't fit their
  class.
- Skill Points aren't a choice: level cap 10 gives 9 SP, and 4 skills × 2
  upgrades needs only 8. Every hero ends fully maxed and identical.
- Everyone spends mana, so a Warrior casting from a mana pool breaks
  immersion.
- Dungeon runs can have zero fights on a floor, rests fully reset the
  party, and walking back through cleared rooms is free, so there are few
  real decisions per run. (Measured in the Aug 2026 playtest; was Move 2 in
  the archived roadmap.)

| Step | What | Owner |
|---|---|---|
| 1.1 | ✅ **Combat v3 design**: `docs/design/combat-v3.md`; direction agreed (D-013) | advisor + Roxton |
| 1.2 | **Vertical slice**: the Warrior rebuilt under v3, in three parts, each ending with Roxton playing it: **1/3** Rage + cooldowns (#38); **2/3** skill forks; **3/3** the Backstab synergy. **Go/no-go gate**: if it isn't more fun, we revise the design, not roll it out | gameplay-engineer |
| 1.3 | Roll v3 out to the other five classes | gameplay-engineer + content-data |
| 1.0 | **Dev cheat panel** (debug builds only, D-015): jump floors, set levels, add gold/items, start a chosen fight, reveal the map. Also a scriptable `DevTools` API that agents call via `game_eval` | gameplay-engineer |
| 1.4 | **Autoplay bot**: extend `scripts/dev/balance_sim.gd` from single fights to whole runs, with **seeded randomness** so any run can be replayed exactly. Report: fights per floor, run length, HP/resource curve, deaths. It replaces the boring manual test runs | qa-balance |
| 1.5 | **Dungeon pressure**: combat quota per floor, rests restore partially, the Fountain stops being a free full heal, close the walk-back regen loop (P1–P4 in `archive/roadmap-v3.md`). Per-floor enemy pools (`cultist` and `ogre` exist but never spawn) | gameplay-engineer + content-data |
| 1.6 | **Combat readability**: turn-order strip, round counter, resource bars that read differently per resource | ui-assets |

**Exit:** you play three runs in a row because you want to, and the bot
report shows every floor has fights and the run length is inside the
target set in the combat v3 design.

---

## Phase 2 — Content-complete 1.0

| What | Owner |
|---|---|
| **Finite campaign**: Dungeon Lv 1–4, then an ending screen after the last boss (D-005). A handful of i18n keys; not lore work | gameplay-engineer + content-data |
| **Icons pass**: every skill and item gets a game-icons.net icon, tinted by rarity or element; attribution on the credits screen | ui-assets |
| **Appearance restructure** (D-001): one visual identity per class, chosen at character creation; skins become outfits of that identity; drop the class-neutral common skins | ui-assets + gameplay-engineer |
| Loot variety: light pass so Dungeon 2+ still drops something new (no affixes) | content-data |
| pt-BR class names: settle gender (O-2) | Roxton |

**Exit:** a new player can go from *New Adventure* to the ending with no
grey placeholder squares, fully in both languages.

---

## Phase 3 — Release

Can start once Phase 2 is underway.

| What | Owner |
|---|---|
| Upload key created and **backed up in two places** (losing it means you can never update the app); AAB export; versioning scheme | release-engineer |
| Play Console: internal testing track with friends first. If the account predates 13 Nov 2023, the 12-testers × 14-days rule does not apply; confirm in the console | Roxton + release-engineer |
| Privacy policy page (the game collects nothing, but the page is still required), Data safety form, IARC rating | release-engineer |
| Store listing in pt-BR and English: icon, feature graphic, screenshots | ui-assets + content-data |
| itch.io page (already exists) gets a web build as a public playtest channel | release-engineer |
| **Export filters:** exclude `test/`, `test/fixtures/`, `scripts/dev/` and `addons/gdUnit4/` from release exports (found in the #35 review) | release-engineer |
| **Newer-save guard:** when `load_game()` refuses a save from a newer build, the main menu must say so instead of silently starting a new game, which would overwrite that save (found in the #28 review) | gameplay-engineer + ui-assets |
| **Cross the save freeze line**: fixture saves captured; migrations mandatory from here on | gameplay-engineer + qa-balance |

**Exit:** the production release is live on Google Play.

---

## Phase 4 — After 1.0 (not planned in detail)

- **1.1 — Abyssal Fissure:** endless dungeon after the campaign; collection
  rewards (outfits) and hero retirement as the long progression
  (archived roadmap, Move 3).
- Desktop / Steam: decide after launch; a portrait game plays awkwardly on
  PC.
- iOS: needs a Mac and a paid developer account; only if Android goes well.

## Parking lot

Captured so they stop taking up headspace. Not scheduled, not promised.

- Loot affixes (procedural modifiers)
- Hardcore mode
- Tile art for rooms, city art
- Sound and music

---

## Team — how agents work on this

One expert per area. The advisor plans and reviews; workers build. Agent
definitions live in `.claude/agents/`.

| Agent | Owns | Drives the Godot editor? |
|---|---|---|
| `advisor` | This plan, `DECISIONS.md`, task briefs, PR review, CLAUDE.md | Rarely (read-only checks) |
| `gameplay-engineer` | `scripts/` game logic: combat, dungeon, party, saves | **Yes**, the main editor user |
| `qa-balance` | `scripts/dev/`, `tests/`, balance and bot reports | No, runs Godot headless from the command line |
| `content-data` | `resources/**/*.tres`, `i18n/translations.csv` | No, pure file edits, always parallel-safe |
| `ui-assets` | `scenes/`, `.tscn` layout, `assets/icons/`, theme, readability | **Yes** |
| `release-engineer` | `export_presets.cfg`, Android settings, store materials | Only for exports |

**The workflow:**

1. The advisor writes a **brief as a GitHub issue**, labelled with the
   agent role (`agent:gameplay-engineer`, …) and phase (`phase:0`, …).
2. Roxton starts a session with that agent, using the **start prompt** the
   advisor wrote in the issue.
3. The worker reads the issue with `gh issue view`, works on a branch,
   commits, pushes and opens a PR that closes the issue. **Agents never
   merge.**
4. The advisor reviews the PR against the brief. Roxton play-tests if the
   change affects how the game feels, then merges.
5. The advisor updates the **Now** block.

**Rules that keep parallel agents from colliding:**

1. **One editor, one driver.** Only one session uses the Godot MCP at a
   time, so `gameplay-engineer` and `ui-assets` never run at the same
   time.
2. **Editor drivers work in the main checkout** (`C:\Dev\dungeon-rpg`, on
   a feature branch, no worktree), because that is the folder the Godot
   editor has open. A worktree would test the wrong files.
3. **Everyone else works in a worktree** (`qa-balance`, `content-data`,
   `release-engineer`, `advisor` when editing docs). They are safe to run
   alongside the editor driver.
4. **One task, one branch, one PR.** Branch names follow
   `<type>/<short-slug>` (e.g. `fix/save-hardening`).
5. **`.tscn` files have a single owner.** Scene files merge badly; never
   have two open branches touching the same scene.
6. **The brief is the scope.** If it is wrong, the worker stops and
   reports rather than improvising.
7. **Feel changes need Roxton.** Anything that changes how the game
   *plays* is tested by hand before merge. The bot catches numbers, not
   fun.

**Headless Godot** (for tests, the sim and CI; never competes with the
editor): `tools/godot.sh <args>`. It wraps the Steam executable and runs
against the checkout it lives in; set `GODOT_BIN` to override.

**Tooling that enforces the rules** (D-014): `.claude/settings.json`
denies `gh pr merge` and pushes to `main`; a session-start hook prints
the **Now** block and open briefs; skills in `.claude/skills/` hold the
how-tos (`write-brief`, `review-pr`, `add-content`, `smoke-test`).
