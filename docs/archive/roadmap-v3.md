# Roadmap v3 — World, Pressure, Ending, Place

> Not new systems. The v2 build is mechanically complete; this is the pass
> that makes it *a game about something*. Order matters: each move feeds
> the next. Lore decides the encounter pools; encounter pools decide the
> pressure tuning; pressure decides where the ending sits; the ending
> decides what the map has to depict.

---

## Move 1 — The world (author: Roxton · editor: Claude)

**Why first:** it costs no code, and every later move needs its answers.
Floor themes come out of §5 of the brief. The ending comes out of §1.

| Step | Owner | Output |
|---|---|---|
| 1a | You | Fill `lore-brief.md` — fragments, names, one-liners |
| 1b | Claude | `lore-bible.md` — your answers made consistent and cross-referenced to systems |
| 1c | Claude | Naming/text patch: ~40–60 new or rewritten `i18n` keys |

**1c is where lore hits the screen.** Concretely, it touches:

- Room labels: `ROOM_COMBAT` "Battle" → named rooms per floor theme
- The 4 events rewritten as recurring entities, not popups
- Boss intros and the defeat screen (the death rule)
- Enemy names with a place to belong to
- Market / city framing text

**Open decision blocking this move:** is "Dungeon Lv 2" *a second dungeon*
or *the same place, deeper*? The UI currently says both things at once.
Answer §1 and this resolves itself.

---

## Move 2 — Pressure in the dungeon

The problem measured in the playtest: two full floors, zero combat rooms;
free revisiting; no resource clock. The dungeon can be optimised into a
staircase hunt. Proposals, each independently yes/no-able:

- **P1 · Combat quota per floor.** Replace the pure weighted roll with a
  minimum: floor 1 → 2 combats, floor 2 → 3, floor 3 → 4, floor 4 → 3 +
  boss. Remaining rooms roll on today's weights. Also a *ceiling*, so a
  bad roll can't produce a grind floor.
- **P2 · Rests stop being a full reset.** Currently rest = full HP + full
  MP + statuses cleared, at ~10% of rooms. Options: (a) 50% HP / 25% MP,
  (b) full HP but no MP, (c) full but once per run.
  **Rec: (a)** — it keeps the potion economy meaningful.
- **P3 · The Fountain event calls `resolve_rest()`** — i.e. a free full
  party heal, strictly better than any potion. Same treatment as P2.
- **P4 · Close the walk-back regen loop** your own design doc flags:
  either tick statuses only when entering an unexplored room, or let
  durations tick everywhere but suppress regen in explored rooms.
- **P5 · A per-floor clock (torch / supplies).** *Recommend skipping.*
  It buys pressure at the direct cost of the cozy register. Named here
  so the decision is deliberate rather than accidental.

**Depends on Move 1:** P1's quota is worth nothing if all four floors
still draw from the same five-enemy pool. The encounter-pool rewrite
(floors 2–4 currently share one pool; `cultist` and `ogre` are authored
but never spawn) is part of this move and needs §5 of the brief.

---

## Move 3 — The ending  ·  DECIDED (2026-08-09)

**Structure: a finite campaign that unlocks a separate endless dungeon.**
Same shape Monster's Den used — campaigns plus an Endless Dungeon — and
it does not require roguelike mechanics.

### Why the campaign is ~4 dungeons

A hero's total lifetime power growth is roughly **5×**: stats from level
1→10, plus skill tiers (`get_upgraded_skill` caps at ×2.0 power), plus a
full gear set. Enemies grow `1.5^(dungeon-1)` forever, and `1.5^4 ≈ 5.06`.

The whole progression is worth about four dungeons. The Dungeon-5 wall
isn't a tuning accident, it's the same number arriving from the other
side. So the finite half of the plan costs almost nothing — the campaign
is already the right length; it needs an ending, not a redesign.

*(Order-of-magnitude estimate, not a measurement. `scripts/dev/balance_sim.gd`
can produce the real curve on request.)*

### The endless half needs a growth axis — OPEN

`1.5^n` against a capped party buys maybe two extra dungeons. Endless
needs a gentler curve or something that keeps growing. Candidates:

- **Retirement / legacy.** A capped hero retires into the city and leaves
  a small permanent bonus for the next party. Monster's Den's answer, and
  stronger here because heroes are *player-named* — retiring Vex after
  six descents is a real event, and she stays somewhere you can see her.
  Cost: a hall screen and a legacy stat.
- **Flatten and raise.** `DUNGEON_GROWTH` ~1.15 in endless, lift
  `LEVEL_CAP`. Nearly free (constants), but it only moves the wall and it
  breaks a good piece of design: cap 10 = 10 SP = exactly enough to max
  every skill. A patch, not an answer.
- **Collection instead of power.** The party plateaus; endless becomes a
  depth score-attack paying out skins and records. The machine already
  exists — `catalog.tres`, `owned_skins`, gold/level/event unlocks, the
  Shrine. No power inflation, no new math.

**Rec: collection as the reward track, retirement as the slow
ceiling-raise.** Endless asks "how deep can we get", each attempt pays
cosmetics, retirement moves the ceiling across many runs so the answer
keeps changing. One new screen rather than a new progression system.

> **Scope note:** this exceeds the v2 scope rules in `CLAUDE.md` and needs
> explicit sign-off before anything is built.

### What this hands back to Move 1

Two dungeons now exist in the fiction, not one: a place with a bottom
that you reach, and a place with no bottom. **Why the difference?** That
question is a gift to `lore-brief.md` §1.1 and §1.3 — it turns an
abstract "the dungeon" into two named locations with different natures.

---

## Move 4 — The map as a place

The most-viewed screen in the game currently reads as a debug view:
labelled rectangles floating over an unrelated corridor photo.

- Room chips → framed tiles, per-floor palette, showing the **room's
  name** rather than its type
- Draw the passages (today they're connector nubs)
- Distinct silhouettes for stairs, boss, shrine
- Stays data-driven: art drops in the way `HeroArt` and `Backdrop` already
  work, no scene surgery

**Depends on Moves 1 and 3:** floor themes and the number of floors that
exist are the art brief.

---

## Also worth deciding, any time

- **pt-BR class gender.** All six class names went feminine (Guerreira,
  Sacerdotisa, Ladina, Feiticeira, Conjuradora, Alquimista) while English
  stayed neutral. With player-named heroes, class-neutral common skins and
  drop-in art, this will read oddly. Settle it deliberately.
- **Conjurer and Alchemist ship undressed** — no portraits (orange
  placeholder rect), no skill icons (grey squares). Two of six classes.
- **Turn order is invisible in combat.** No initiative display, no round
  counter. Pure readability win for a tactical game.
- **Loot has no Diablo in it yet.** One shared pool of 26 items; by
  Dungeon 2 you have seen everything. Affixes are explicitly out of v2
  scope — flagging it as the gap between the stated influence and the
  build, not proposing it now.
