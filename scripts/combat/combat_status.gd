## A single active status effect on a battler: buff, debuff, DoT, or barrier.
## Created and owned by CombatState; never persisted.
class_name CombatStatus
extends RefCounted

enum Kind { BUFF, DEBUFF, DOT, BARRIER, REGEN }

var kind: Kind = Kind.BUFF
## Display name of the skill that applied this status — used in log lines.
var source_name: String = ""

## Stat modifiers (buff/debuff only). Sign carries direction.
var mod_atk: int = 0
var mod_def: int = 0
var mod_mag: int = 0
var mod_spd: int = 0

## Per-turn damage (DoT only).
var dot_damage: int = 0

## Per-turn healing (REGEN only).
var heal_per_turn: int = 0

## Turns remaining. 99 means "until consumed" (used by barrier).
var duration: int = 0

## Forces enemies to target the bearer.
var taunt: bool = false


## Builds every status a buff/heal skill grants: an optional barrier, an optional
## stat buff, and an optional regen. Shared by in-combat resolution and
## out-of-combat casting so the two paths cannot drift apart.
##
## Barrier and stat mods are separate statuses because Battler.effective_stats
## only reads BUFF/DEBUFF mods — a skill granting both needs one of each.
static func build_for_skill(skill: SkillData) -> Array[CombatStatus]:
	var out: Array[CombatStatus] = []
	if skill.barrier:
		var bar := CombatStatus.new()
		bar.kind = Kind.BARRIER
		bar.source_name = skill.display_name
		bar.duration = skill.mod_duration
		out.append(bar)
	var has_mods := skill.mod_atk != 0 or skill.mod_def != 0 \
		or skill.mod_mag != 0 or skill.mod_spd != 0 or skill.taunt
	if has_mods or not skill.barrier:
		var st := CombatStatus.new()
		st.kind = Kind.BUFF
		st.source_name = skill.display_name
		st.mod_atk = skill.mod_atk
		st.mod_def = skill.mod_def
		st.mod_mag = skill.mod_mag
		st.mod_spd = skill.mod_spd
		st.duration = skill.mod_duration
		st.taunt = skill.taunt
		out.append(st)
	if skill.heal_over_time > 0 and skill.hot_duration > 0:
		var hot := CombatStatus.new()
		hot.kind = Kind.REGEN
		hot.source_name = skill.display_name
		hot.heal_per_turn = skill.heal_over_time
		hot.duration = skill.hot_duration
		out.append(hot)
	return out


# ── Persistence ───────────────────────────────────────────────────────────────
# Party statuses outlive a fight (they live on the Hero), so they are saved.

func to_dict() -> Dictionary:
	return {
		"kind": int(kind),
		"source": source_name,
		"atk": mod_atk, "def": mod_def, "mag": mod_mag, "spd": mod_spd,
		"dot": dot_damage, "hot": heal_per_turn,
		"dur": duration, "taunt": taunt,
	}


static func from_dict(d: Dictionary) -> CombatStatus:
	var st := CombatStatus.new()
	st.kind = d.get("kind", 0) as Kind
	st.source_name = str(d.get("source", ""))
	st.mod_atk = int(d.get("atk", 0))
	st.mod_def = int(d.get("def", 0))
	st.mod_mag = int(d.get("mag", 0))
	st.mod_spd = int(d.get("spd", 0))
	st.dot_damage = int(d.get("dot", 0))
	st.heal_per_turn = int(d.get("hot", 0))
	st.duration = int(d.get("dur", 0))
	st.taunt = bool(d.get("taunt", false))
	return st
