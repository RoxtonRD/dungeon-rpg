# Combat v3 — design draft

> **Status: direction agreed for the Warrior slice (D-013).** Nothing is
> built yet. We choose by *prototyping*: step 1.2 of `PLAN.md` builds one
> class under v3-A, and we keep what feels good. Numbers are placeholders
> for the sim to tune.

---

## 1 · Pillars

What Roxton's favourite games have in common (Monster's Den, Diablo 2,
Path of Exile, Tree of Savior, Baldur's Gate 3, heavily modded Skyrim).
Every mechanic below is judged against these.

1. **Builds are yours** (D2, PoE, ToS). Two heroes of the same class can
   end up playing differently, and the choice is felt when you level up.
2. **Every turn is a decision** (BG3, Monster's Den). There is no best
   skill to press every turn; the right action depends on resources,
   cooldowns, statuses and what your allies just set up.
3. **The dungeon wears you down** (immersive Skyrim). What you spend in
   fight 1 matters in fight 5, and resting is a choice.
4. **Mechanics match the fiction.** A warrior fights with fury and
   fatigue, not mana.

**Mobile constraint (the anti-pillar):** one glance shows the state of
all four heroes. That means **at most two bars per hero** (HP + one
resource) and two or three taps per turn.

---

## 2 · The menu of mechanics

| Mechanic | Pillars | Code cost | Save impact | UI cost |
|---|---|---|---|---|
| **Class resource** (Mana / Rage / Energy) | 2, 4 | Medium | None: Rage and Energy exist only during a fight | Low: bar colour and label |
| **Cooldowns** on strong skills | 2 | Small | None | Low: a number on the skill button |
| **Stamina for every hero** as a second resource | 3, 4 | Medium | Small | **High: a third bar per hero** |
| **Stamina with overexertion**, replacing Rage/Energy for physical classes | 2, 3, 4 | Medium | Small | Low |
| **Skill forks**: each upgrade is an A-or-B choice | 1 | Medium | Small: one choice per skill per hero | Medium: the upgrade screen |
| **Synergies**: one skill sets up a status, another pays off on it | 2 | Small to medium, mostly content | None | Low |
| **Passive talent tree** | 1 | Large | Medium | High |

---

## 3 · Candidate to prototype (v3-A)

- **One resource per class that fits the fiction:**
  - **Mana** for Mage, Cleric, Alchemist and Conjurer. Works as today:
    it lasts the whole run and is restored by rests and potions.
  - **Rage** for the Warrior. Starts each fight at 0, filled by hitting
    and by being hit, spent on skills.
  - **Energy** for the Rogue. A small pool, full at the start of each
    fight, refilling a fixed amount every turn.
- **Cooldowns on the big skills only** (Execute, Assassinate, Fireball…),
  2–3 turns. Basic attacks are always free and never cool down.
- **Skill forks:** each skill has 2 upgrade ranks, and each rank is an
  A-or-B choice that changes *what the skill does*, not just its
  numbers. Still 1 SP per level. The city offers a **reset of choices
  for gold plus one semi-rare ingredient item** (a new consumable that
  drops occasionally), so experimenting is possible but not free.
- **Synergies:** every class gets at least one *setup* skill and one
  *payoff* skill, designed as a cross-class table (§5).
- **Stamina is not in v3-A.** The third bar breaks the mobile constraint,
  and pillar 3 is better served first by the dungeon pressure work
  (partial rests, a fight quota per floor, PLAN step 1.5). If the Rage
  slice feels flat, **stamina with overexertion (v3-B)** is the first
  alternative to try.

### v3-B, the alternative: stamina with overexertion

Physical classes spend **Stamina** instead of Rage or Energy. It refills
a little every turn. You may spend more than you have: the skill still
fires, but the hero becomes **Exhausted** (the skill goes on a long
cooldown, or the hero loses DEF or SPD for a few turns). It's riskier and
closer to Skyrim; the cost is that it is harder to balance and to read.

---

## 4 · The Warrior slice (PLAN step 1.2)

One class, end to end, to find out whether this is more fun. The numbers
are placeholders for the sim to tune; the fork options are examples.

**Rage:** 0–100. Starting values to tune: +10 when dealing damage, +20
when taking a hit. Resets at the end of each fight. (Energy for the Rogue
will use the same 0–100 scale.)

| Skill | Today | v3-A |
|---|---|---|
| Slash | 0 MP, 1.0× | Free. The Rage builder |
| Cleave | 6 MP, 0.45× on all | Costs Rage. AOE |
| Provoke | 6 MP, taunt | Costs Rage. Taunt, so the incoming hits refill it |
| Execute | 10 MP, 2.5×, finisher | Big Rage cost, **3-turn cooldown**, finisher |

**Example forks:**
- Cleave: **A · Wide Arc**, which also lowers DEF on everything it hits;
  or **B · Heavy Arc**, more power at a higher cost.
- Provoke: **A · Iron Wall**, +DEF while taunting; or **B · Vengeance**,
  triple Rage gain from hits while taunting.
- Execute: **A · Reaper**, which refunds Rage if it kills; or **B ·
  Sunder**, which leaves a DEF break on the target.

**One cross-class synergy to test:** Rogue's Backstab deals +50% against
targets with a DEF debuff, which Wide Arc and Sunder set up. It needs a
small new `SkillData` field such as "bonus against status X".

**The slice is a success if:**
- in the sim, the Warrior uses at least 3 different skills per fight on
  average, and no single skill makes up more than half of its actions;
- Roxton plays it and it *feels like a warrior*.

---

## 5 · Synergy table (to fill in after the slice)

| Class | Sets up | Pays off on |
|---|---|---|
| Warrior | DEF break (Wide Arc, Sunder) | Being hit (Rage) |
| Rogue | … | DEF break (Backstab) |
| Mage | Chill? | … |
| Cleric | … | … |
| Alchemist | Acid (DEF down)? | … |
| Conjurer | … | … |

---

## 6 · Answered (2026-09-26)

1. **Warrior first, with Rage (v3-A).** Stamina with overexertion (v3-B)
   is the fallback if Rage feels flat.
2. **Large numbers:** resources run 0–100.
3. **Paid reset: yes,** costing gold plus a semi-rare ingredient item.
   The reset itself isn't part of the Warrior slice; it comes with the
   rollout (step 1.3).
4. **A dungeon run targets 15–20 minutes** on a phone. The autoplay bot
   (step 1.4) measures this, as a number of actions or turns per run.
