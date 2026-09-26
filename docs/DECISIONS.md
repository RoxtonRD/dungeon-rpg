# Decisions

> Append-only log. Each entry records **what** was decided and **why**, so
> nobody (human or agent) re-argues a settled question without new
> information. To reverse a decision, add a new entry that supersedes it;
> don't edit the old one.

---

## Open

- **O-1 · Combat v3 direction.** Draft in `docs/design/combat-v3.md`:
  class resources, cooldowns, skill forks and synergies, with stamina and
  overexertion as the alternative. Its open questions (§6) need Roxton's
  answers before the Warrior slice is briefed.
- **O-2 · pt-BR class gender.** All six class names are feminine in pt-BR
  (Guerreira, Sacerdotisa…) while English is neutral. With player-named
  heroes this reads oddly. Needs a deliberate call before Phase 2 ends.

---

## 2026-09-26 — Re-entry session

**D-001 · Cosmetics are frozen; appearance will become "identity +
outfit".**
No new skins, unlock rules or catalog entries. The skin system pulled focus
away from the game, and letting a hero fully change appearance works
against immersion. In Phase 2 it becomes: one visual identity per class,
chosen at character creation (a sub-folder per identity), with outfits as
the swappable part. Class-neutral common skins are dropped. Existing code
stays until then, because ripping it out now is work no player sees.

**D-002 · No more generated art.**
Generating pixel art was the second big distraction. Skill and item icons
come from [game-icons.net](https://game-icons.net) (CC BY 3.0, credit on the
credits screen), tinted by rarity or element; an agent can pick them by
name. UI panels, if needed, from [Kenney](https://kenney.nl) (CC0). The 11
existing backgrounds stay; no new ones. Where art is missing: flat colour,
not placeholders that nag.

**D-003 · Lore work is dropped.**
The lore focus (archived `roadmap-v3.md` Move 1 and `lore-brief.md`) stalled
the project within days. Names already in the game stay as flavour. Any
text a feature needs (an ending screen, a boss intro) is written as part of
that feature, a few lines at a time.

**D-004 · Saves can break freely until the save freeze line.**
With zero players, changing the save format costs nothing, so the big
design changes happen *before* release. The freeze line is the first
build an external tester installs. After it, every save-format change
ships with a migration step and a fixture test. Crash-safety (atomic write
and a backup copy) is built now regardless, because it protects against
Android killing the app mid-write.

**D-005 · 1.0 is the finite campaign; endless is 1.1.**
Dungeon Lv 1–4 plus an ending. Based on the archived Move 3 estimate: party
power grows about 5× over a lifetime and enemies grow `1.5^n`, so four
dungeons is the natural campaign length. The Abyssal Fissure (endless mode,
collection rewards, retirement) is the first post-launch update.

**D-006 · Phases with exit criteria, no calendar.**
Schedules haven't worked for Roxton; agentic work lands faster than
estimates. The risk to manage is *stopping*, not slowness, so the plan
optimises for cheap re-entry: the **Now** block in `PLAN.md`, tasks that
fit one sitting, and fun work first.

**D-007 · Engine is Godot 4.7.**
Upgraded from 4.6 earlier; docs caught up now.

**D-008 · Agent team: one advisor, five workers.**
Roles and collision rules are in `PLAN.md` § Team. Security, data
engineering and a dedicated docs agent were considered and dropped: the
game has no backend or user data, and the advisor keeps the docs.

**D-009 · Distribution: Google Play first, itch.io as the playtest
channel.**
The Play developer account is personal and predates 2023, so the
12-tester closed-test rule most likely doesn't apply; this still needs
confirming in the console. Android target API must be 36 (required for new
apps and updates since 31 Aug 2026). Steam and iOS are post-launch
decisions.

**D-010 · Briefs are GitHub issues; agents open PRs, Roxton merges.**
Resolves O-3. Each brief is an issue labelled with its agent role and
phase, and it includes the start prompt for the worker session. Agents
commit, push and open PRs that close their issue; only Roxton merges.

**D-011 · Editor-driving agents work in the main checkout.**
The Godot editor (and therefore the Godot MCP) has `C:\Dev\dungeon-rpg`
open, so an agent verifying changes through the editor must edit that
folder, on a feature branch. Agents that don't need the editor use
worktrees and run Godot headless.

**D-012 · CI runs headless Godot tests on every PR.**
With several agents opening PRs, a cheap automatic check catches broken
scripts and `.tres` files before they reach Roxton. It runs Godot 4.7.2
headless: everything loads, save tests pass, every i18n key has both
languages. Lint is optional and non-blocking until the codebase is clean.
