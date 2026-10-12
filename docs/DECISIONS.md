# Decisions

> Append-only log. Each entry records **what** was decided and **why**, so
> nobody (human or agent) re-argues a settled question without new
> information. To reverse a decision, add a new entry that supersedes it;
> don't edit the old one.

---

## Open

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

**D-002 · No more generated art.** *(Superseded by D-037, 2026-10-11.)*
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

**D-013 · Combat v3 direction for the Warrior slice.**
Resolves O-1. The Warrior is rebuilt first under v3-A: Rage on a 0–100
scale, cooldowns on big skills only, A-or-B skill forks, and one
cross-class synergy with the Rogue. Stamina with overexertion (v3-B) is
the fallback if Rage feels flat. Fork choices can be reset in the city
for gold plus a semi-rare ingredient item, built with the rollout rather
than the slice. A dungeon run should last 15–20 minutes on a phone. The
design is in `docs/design/combat-v3.md`; we choose by prototyping, so
what the slice shows can override the doc.

**D-014 · Dev tooling: enforce rules with tools, not instructions.**
Adopted from the dev-experience research (2026-09-26). Rules that must
hold are enforced by permissions, hooks and CI; how-to knowledge lives in
skills that load only when relevant, keeping `CLAUDE.md` short. Tests use
**gdUnit4** in `test/`: it runs headless and has an official GitHub
Action. The Godot AI plugin's own runner was ruled out because it only
runs inside the editor. Formatting uses gdtoolkit. Recommended against for
now: Claude's GitHub app reviewing every PR (API cost; the advisor
reviews with `/code-review`), third-party Godot skill packs, and one
`CLAUDE.md` per folder.

**D-015 · Dev cheat panel for debug builds only.**
It exists so Roxton can test a feel change in minutes instead of a full
run, and so agents can set up game states through `game_eval`. It is
compiled out of release builds (`OS.is_debug_build()`) and is dev-only
UI, so it is **English-only with hardcoded strings**: the i18n rule
applies to player-facing text. It is not a player feature and never ships.

---

## 2026-09-26 — Phase 0 reviews (#33, #34)

**D-016 · A save from a newer build stops the load; there's no fallback
to the backup.**
If `save.json` has a version above `SAVE_VERSION`, `load_game()` returns
false and leaves every file untouched. Falling back to the backup would let
an old build play on and then overwrite the newer save. This was the #28
engineer's call where the brief was silent, and it is accepted. It's only
half the protection, though: the main menu still starts a new game, which
overwrites that save. That fix is scheduled before the save freeze line
(`PLAN.md` Phase 3).

**D-017 · Only the advisor edits `PLAN.md` and `DECISIONS.md`.**
Workers report status, findings and brief problems in their final message
and PR; the advisor folds them into the docs. This keeps the planning docs
out of every worker's diff, which avoids merge conflicts between parallel
PRs.

---

## 2026-09-26 — Reviews of #40 (save tests) and #41 (dev panel)

**D-018 · Agents that run the game back up Roxton's save and restore it.**
During #32, the dev-panel session's `quick_party()` overwrote Roxton's
real save and its backup. The #32 brief was written before the
checksum-the-real-save rule existed. Every editor-driving task now backs
up `save*.json` before running the game and restores it afterwards, with
MD5s shown in the PR (agent role files and the `write-brief` skill). A
code safety net follows: DevTools copies the save aside before its first
state-changing call (`PLAN.md` Phase 0). Parallel sessions share the same
`user://` folder: the #35 guard caught the #32 session saving mid-run.
The save tests themselves are isolated in `user://test_saves/`.

---

## 2026-09-27 — Warrior slice 1/3 (#43, reviewed after merge)

**D-019 · Cooldown semantics: "cooldown N" = usable again on your Nth turn
after using it.**
The counter is set to N when the skill is used and drops by 1 at the start
of each of the caster's turns, so the skill is locked for N−1 turns (the
#43 engineer flagged this). We keep the mechanic and tune the numbers, not
the rule: Execute's `cooldown = 3` means locked for 2 Warrior turns. If
the playtest wants it locked longer, raise the number.

**D-020 · Rage classes have no out-of-combat casts.**
The Characters screen hides Cast for Rage skills (Provoke would have paid
from MP). Rage only exists in a fight. This was the #43 engineer's call,
and it is accepted.

**D-021 · Feel gate 1 passed: v3-A (Rage) stays, and stamina is shelved.**
Roxton's playtest (2026-09-27): Rage feels "much better than mana", and
its pace is good in fights with 2+ enemies. Execute was used only as the
last blow, so its cooldown never mattered. Warrior 2/3 therefore gives it
a mid-fight option (the *Sunder* fork). Choices were "sometimes obvious,
sometimes real", which is what forks and synergy target. His strongest
finding was that combat is hard to read (who hit whom, what effect
landed), so readability (#45) goes before 2/3.

**D-022 · Warrior talents: forks + boosts, 5 SP for 8 nodes.**
Roxton accepted the proposed forks (Slash Rending/Momentum, Cleave Wide
Arc/Heavy Arc, Provoke Iron Wall/Vengeance, Execute Reaper/Sunder) and
**Option 2, scarce SP**: talent classes get +1 SP at levels
2/4/6/8/10. This answers his original complaint that everything ends
maxed. Non-talent classes keep tiers until the rollout (step 1.3).
Details: `combat-v3.md` §4b; build: #47.

**D-023 · Depth through passives and reactions, not more active skills;
reactions are automatic.**
Roxton proposed more utility, passive and defensive abilities, including
auto-triggering defenses with a trade-off. Adopted with one change:
reactions trigger by chance, cost the class's own resource, and the player
controls them with a per-hero on/off toggle on the talent screen, not with
mid-turn prompts (mobile flow). All of them share the talent screen and SP
pool. One passive and one reaction (Warrior *Parry*) are prototyped in
3/3 before any rollout.

**D-024 · Ascension (a raised level cap, then Master / Grand Master /
subclass) is post-1.0.**
Roxton's Kru Dark Ages idea (level 99 → Master or Grand Master, or a
subclass restarting at level 1) is a strong candidate for the endless
mode's growth axis (Phase 4), alongside or instead of retirement. The
guard for now is to keep `LEVEL_CAP` and the SP schedule data-driven, so
raising them later is cheap. An online/MMO version is explicitly a
separate, after-release dream, not part of this project's scope.

---

## 2026-09-27 — Warrior 2a review (PR #51)

**D-025 · Talent rules settled during implementation (the #47 engineer's
calls, accepted).**
- The *effective* skill cost applies only to talent classes. Mana classes
  keep paying base costs in combat, exactly as before (the tier discount
  stays outside-combat only).
- An old save converts only when it has **no `talents` key**, so SP from
  a Tome of Mastery is never wiped on later loads.
- Talents are keyed by the skill's `.tres` basename (e.g.
  `warrior_execute`), like `sp_spent`. `DevTools.set_talent` accepts
  either the id or the basename.
- Reaper's refund has no log line yet; the Rage bar shows it. A popup can
  come with 3/3 if the playtest asks for it.

---

## 2026-09-27 — Feel gate 2 (Warrior talents)

**D-026 · Feel gate 2 passed: talents and scarce SP stay.**
Roxton played the Tank and Executioner builds: they play differently (one
defensive and Rage-building, one attack-oriented), though "not very
different" yet. The permanent pick made him hesitate, which is the goal.
Sunder made Execute a mid-fight decision. 5 SP for 8 nodes "was good",
given the 10-level cap. Part 3/3 (passive, reaction, synergy) is expected
to widen the gap between builds; the sim report (#56) measures it.

**D-027 · Replacing a skill: add a new resource, keep the old one.**
Roxton's idea: when a skill changes into something very different, don't
rewrite A into B. Author B as a new `.tres`, point the class's `skills`
list at it, and keep A's file untouched, so switching back is a one-line
data change. No in-game enable/disable system is needed: the class's list
*is* the switch. Runtime A/B testing gets a dev command,
`DevTools.swap_skill(class_id, slot, skill_id)` (part 3/3). Saves
reference skills by basename, so after the save freeze line a swap needs
a migration step (D-004).

---

## 2026-09-27 — Sim report (#56 → PR #60) and the Android build (#55 → PR #59)

**D-028 · The sim says fights are too short, and the level curve is
unmeasured. After Warrior 3/3, encounters come before any rollout.**
`docs/reports/sim-warrior-talents.md`, 200 fights per cell, seed 1:
- Normal fights end in **0.7–3 rounds** with ~100% wins; only bosses last
  4–6. The Warrior acts 2–3 times per fight and Rage starts at 0, so Slash
  is 62–65% of his actions and he averages ~1.7 distinct skills per
  fight. The slice criterion (3+ distinct, none >50%) fails **because of
  fight length, not the talent design**. It is likely a root of the
  original "testing is boring".
- The sim *assumes* heroes are level 2–5 across dungeons 1–4. If that's
  true, the Warrior has 1–2 SP in the 1.0 campaign, and the tree Roxton
  played at level 10 is mostly unreachable. The campaign bot (#61)
  measures the real curve.
- The difficulty curve is uneven: the dungeon 3 boss wins 50–62%, the
  dungeon 4 boss ~84%.

So once 3/3 is in, the next lever is **encounter design and dungeon
pressure (PLAN 1.5)**, guided by the #61 numbers, before rolling talents
out to other classes. The SP schedule (D-022) may be revisited once real
levels are known.

**D-029 · Bloodlust is the Warrior's first passive, in a pick-one list.**
Roxton picked Bloodlust (+2% damage per 10 Rage held, placeholder).
Passives are modelled as a pick-one list per class, so more options
(Thick Hide, Unstoppable, …) can be added later as data.

**D-030 · Android debug builds are reproducible (`tools/export_android.sh`,
API 36).**
The export excludes `test/` and `addons/gdUnit4/`. The Godot AI plugin
already strips its `_mcp_game_helper` autoload from exports. Shipping it
would leak memory on a phone, because it queues logs until an editor
attaches. Follow-up (Phase 3): also exclude `addons/godot_ai/*`, and add a
CI boot check of the exported pack so a stripped-but-missing autoload
can't slip through.

---

## 2026-09-28 — Campaign bot v1 (#61 → PR #64), Warrior 3/3 (#62 → PR #65)

**D-031 · The campaign reaches only level ~4–5 by design. The level
curve is Roxton's call; bot v2 measures the options.**
Bot v1 (full clear, real XP split four ways) puts heroes at **level ~2.2
at the dungeon 1 boss**, from ~6 fights. With `xp_for_next = 20·L^1.5`,
level 10 needs ~2,200 XP per hero, about 250 average fights for a party
of 4, against ~25–30 fights in the whole campaign. So in 1.0 the Warrior
earns ~2 of his 5 talent SP, and the tree Roxton played at level 10 is out
of reach. v1's 97% dungeon-1 wipe rate is **not** trusted: the bot never
used consumables, rested at the first rest room it found, and stopped at
the first wipe. Bot v2 (#66) plays sensibly and runs an XP-multiplier
what-if. The options, for Roxton:
- **(A) faster XP**, so the campaign ends near level 9–10: the whole tree
  by the finale, with ascension continuing in the endless mode (D-024).
  *Advisor's recommendation.*
- **(B) keep the slow XP; SP every level** from level 2: 5 SP by level
  ~6; levels 7–10 belong to the endless mode.
- **(C) lower the 1.0 cap to ~6**, with SP every level, and raise it via
  ascension later.

**D-032 · Warrior 3/3 rules settled during implementation (accepted).**
- "Single-target physical" = aimed at one target and dealing physical
  damage. A multi-hit on one chosen target can be parried; random-target
  multi-hits can't.
- Bloodlust reads Rage **after** the skill's cost is paid, so spending on
  Execute lowers that same hit's bonus (the hold-versus-spend tension).
- `ReactionData.rage_cost` is paid from the class's own resource; rename
  it to `cost` when a non-Rage reaction arrives.
- The talent screen's fork, passive and reaction cards now share one card
  builder and one confirm dialog.

**D-033 · Godot ignores `.claude/`.** `.claude/.gdignore` stops the
editor from scanning agent worktrees (full project copies), which had put
~888 errors in the editor log.

---

## 2026-10-11 — Campaign bot v2 (#66 → PR #68)

**D-034 · Measured: ×3 XP puts the party at level ~10 at the final boss.**
`docs/reports/sim-campaign.md`: 100 campaigns per multiplier, seed 1. A
sensible bot (potions, rests when hurt, buys potions, retries after a
wipe):

| XP × | Level at boss D1/D2/D3/D4 | Wipes/campaign D1..D4 | Beat D4 |
|---|---|---|---|
| 1 | 2.9 / 4.2 / 5.6 / 7.1 | 0.83 / 0.25 / 0.48 / 0.98 | 87% |
| 2 | 3.7 / 5.4 / 6.9 / 8.7 | 0.29 / 0.02 / 0.02 / 0.23 | 100% |
| 3 | 4.2 / 6.2 / 8.1 / 9.8 | 0.16 / 0 / 0 / 0.06 | 100% |
| 4 | 4.6 / 6.9 / 9.0 / 10.0 | 0.10 / 0 / 0 / 0.01 | 100% |

- Combat time is ~6–9 min per dungeon (walking and menus not counted),
  against the 15–20 min target.
- Fights are still short (2–3.4 rounds), and more XP makes them shorter
  and wipes rarer.
- Wipes cluster on F3, F4 and the boss, never F1.

So faster XP (option A of D-031) also **lowers difficulty**: the
encounter work (1.5) has to bring the challenge back, through longer and
more tactical fights. The level-curve choice is still Roxton's.

**D-035 · `tools/format.sh` before every push.** PR #68 failed CI's
format check because the format hook didn't run in that session. The
hook only formats files edited through Claude's tools, and only when
Python resolves. Every role now runs `tools/format.sh` before pushing; CI
remains the backstop.

**D-036 · Level curve: option A at ×3 XP.**
Roxton chose A (2026-10-11): the XP thresholds are divided by 3
(`xp_for_next = (20/3)·L^1.5`), so the party reaches level ~10 at the
dungeon 4 boss (bot v2: 4.2 / 6.2 / 8.1 / 9.8 at the bosses). The whole
talent tree is reachable by the finale, and ascension continues it after
1.0 (D-024). Enemy XP rewards are unchanged. Because faster levelling
makes the campaign easier (wipes ≈ 0), the encounter work (1.5) has to
restore the challenge. Build: #71, which also moves the XP split out of
the combat screen into `Party` so the game and the bot share one rule.

---

## 2026-10-11 — Art direction, encounter choices, background agents

**D-037 · Art direction for 1.0: flat vector, drawn in code (replaces the
blanket ban in D-002).**
Roxton asked whether art can be produced if needed, for a simple launch
look; he doesn't want to make art himself now. The advisor and agents
can't paint images (no image generator), but they can produce a coherent
**flat vector** look entirely inside Godot:
- a Godot Theme of StyleBoxes for panels, frames and buttons;
- **game-icons.net** SVGs (CC BY 3.0) for skills, items, statuses, and
  hero/monster silhouettes in framed medallions;
- **shader backgrounds** tinted per floor;
- a small fixed palette.

An Asset Store survey (2026-10-11) confirmed the route and found licensed
pieces that fit: **TaleTone fantasy vector frames** (free, CC BY 4.0, SVG,
9-slice) and **Fancy StyleBoxes** (MIT). Pixel-art packs are out (they'd
clash with vector). The store has no suitable painted portraits or
backgrounds. Rules:
- no art work in Phase 1;
- the Phase 2 art pass starts with a written style guide, and every asset
  follows it;
- painted or generated raster art is allowed only if it matches the style
  guide and is time-boxed (the existing AI portraits and backgrounds are
  re-evaluated against the style guide then);
- every source is credited on the credits screen.

Tools noted for later: Loc Audit Lite (MIT; flags strings not wrapped in
`tr()`, which our tests don't catch), Simple GUI Transitions (MIT), and
Dialogue Manager (MIT) if events grow.

**D-038 · Encounters v3 choices.**
Roxton (2026-10-11): **telegraphed attacks: yes**, **optional elite rooms:
yes**, **rest rooms restore 50% HP + 25% MP**. The rest of the encounter
design (authored groups per floor, the enemy roles brute / skirmisher /
caster / support with role AI, fight-length targets of normal 3–5 rounds,
elite 5–7, boss 8–10, and a minimum number of fights per floor) is in the
encounter briefs (E1–E4).

**D-039 · The advisor launches worktree tasks as background agents.**
Approved by Roxton, as long as the advisor session's context stays
manageable. Worktree-only tasks (qa-balance, content-data,
release-engineer, research) are launched by the advisor as background
agents in isolated worktrees, and the advisor receives only their final
reports. Editor-driving tasks (gameplay-engineer and ui-assets with the
Godot MCP) stay as sessions Roxton starts, since they need the main
checkout and can collide with his playtesting. Roxton still merges every
PR. When the advisor's context grows long, a fresh advisor session takes
over; the docs and the session-start hook make that cheap. Roxton chose to
skip generic Godot skill packs for now; project-specific skills are
preferred.

---

## 2026-10-11 — Feel gate 3, E1 review (PR #81)

**D-040 · Feel gate 3 passed: the Warrior prototype is done.**
Roxton played Bloodlust and Parry. Holding Rage versus spending it "felt a
decision"; both effects were noticeable; the talent screen "was okay",
with nothing to change now. The Warrior slice (1/3, 2a, 2b, 3/3) is
complete. Rolling talents out to other classes (1.3) waits until
encounters (E1–E4) give fights room for skills to matter (D-028).

**D-041 · E1 calls (accepted).**
- Elite groups exist for F2–F4 only, matching where elite rooms appear.
- Encounter groups load by scanning `resources/encounters/` (handling the
  `.tres.remap` names in exports), with a hardcoded `FALLBACK_IDS` list
  behind it. E2 keeps that list in sync, and a test enforces it.
- Elite placement could fall back to the required path to the stairs on
  cramped floors; E3 makes elites strictly optional.
- The bot needed a two-line change to enter elite rooms; E4 gives it a
  real elite policy.
- The bot's first numbers after E1 (20 campaigns): 85% beat D4; D4 stuck
  15%; 7.4–8.8 combat minutes per dungeon. Difficulty is up (Smash hit
  22 per hero on F3); E4 tunes it.

---

## 2026-10-11 — E2 (#84) and E3 (#83, #85) merged

**D-042 · Encounter content and dungeon pressure are in; tuning is next.**
- **E2:** goblin_shaman, wolf_alpha (SUPPORT), skeleton_archer
  (SKIRMISHER), orc_warlord (elite BRUTE with a telegraphed Crushing Blow);
  the cultist now appears, with a second AOE; 5 normal groups per floor
  and 2 elite groups on F2–F4.
- **E3:** rests restore 50% HP + 25% MP; revived heroes come back at 25%
  HP + 25% MP; the Fountain heals 30% HP; the fight quota is min
  2/3/4/3, max min+2, and REST rooms are converted last; no status ticks
  on revisits; elites are never on the only path to the stairs.
- **Bot after both** (the E2 and E3 runs): fights are still 2.1–2.5 rounds
  (target 3–5); ~15 fights per dungeon; F4 spikes (cultist AOE, ogres in
  normal groups).
- **E4 (#80)** tunes this with the `balance-loop` skill.
- Merge-order note: #83 merged before its follow-up commit, so #85 carried
  it; #84's conflict was only the generated `.translation` binaries,
  which were rebuilt from the merged CSV.

---

## 2026-10-11 — E4 (#88) and the encounters feel gate

**D-043 · Feel gate 4 (encounters) passed; direction: fewer, longer
fights.**
E4 (#88) tuned enemy numbers. Wipes per campaign went 3.05 → 1.26, and
the D1/D4 bosses are on target (80% / 78% first-try wins). But it showed
that ~15 fights per dungeon can't coexist with 3–5 round fights, and the
extra fights over-level the party by ~2 levels (6/8/10/10 at the bosses).
Roxton then played floors 1–3:
- "let's try the longer fights";
- roles readable and changing his targeting: yes;
- telegraphs with a real answer: yes;
- elites "tempting, as something different";
- rests "feel good this way";
- nothing confusing.

Next round:
- **E5a (#89):** fight quota cut to ~9–10 per dungeon; Provoke now
  redirects single-target telegraphs (an E4-found bug).
- **E5b (#90):** re-tune for normal fights of 4–5 rounds, elites the bot
  wins only 80–90% (E4: 690/690), D1 wipes ≤ 0.3, and all bosses at
  70–85%.

---

## 2026-10-12 — E5 results, dungeon length, the next priority

**D-044 · A dungeon runs ~23 minutes, and that's accepted (revises
D-013's 15–20 target).**
After E5a (#92) and E5b (#94):
- normal fights last ~4.3 rounds and elites 5–7;
- the Warrior uses 2.4–2.9 skills per fight from D2 on, with no skill
  above 50%;
- the level curve is within ±1 of plan (4.6 / 6.6 / 8.7 / 10).

Roxton timed a full dungeon at about **23 minutes**, said fight length
"feels right", and that stopping anytime "feels good" (the game saves
after every room). So the per-dungeon target becomes **~20–25 minutes**,
and combat minutes stop being a balance target.

What remains is structural. One growth rate can't make D1 gentle, D2/D3
tense and D4 beatable at once, and elites can't get harder without
hurting D1. Hence **E6a (#95)**, per-dungeon and elite multiplier tables,
then **E6b (#96)** to tune them (also the orc's brute identity).

**D-045 · Next big lever: the talent rollout to the other five classes
(1.3).**
Roxton: "combat for characters other than the warrior feels a little
repetitive". The Warrior has a resource, forks, a passive, a reaction and
a synergy; the others still play like v2. The order is **Rogue (Energy)**,
then Mage, Cleric, Conjurer, Alchemist. Each class gets a design pass with
Roxton (forks, passive, reaction), then one build brief. Live numbers in
descriptions (#97) go first, so the new content is written as templates.

---

## 2026-10-12 — The cost rule and the Rogue design

**D-046 · What a description says is what you pay; the Rogue design is
approved.**
- **Costs (supersedes part of D-025):** every class pays its *effective*
  (upgraded) skill cost in combat, the same cost the live description
  shows (#100) and the out-of-combat cast charges. Before this, mana
  classes paid the base cost in combat but the upgraded cost outside it.
  Tiers go away in the talent rollout, so this is the consistent rule
  going forward.
- **The Rogue design** (approved by Roxton as proposed):
  - **Energy:** 100 at the start of each fight, +25 per Rogue turn,
    for burst play;
  - **costs:** Stab 0 / Backstab 35 / Relentless 50 / Assassinate 70
    (cooldown 3);
  - **forks:** Poisoned Blade or Quick Strike; Exploit Weakness or
    Ambush; Flurry or Focus; Mark for Death (+25% damage taken from
    everyone) or Shadowstep (untargetable by single-target attacks);
  - **passives (pick one):** Opportunist or Assassin's Focus;
  - **reaction:** Dodge (25% for a full evade, 20 Energy);
  - `ReactionData.rage_cost` becomes `cost`.

  Build: #101.

