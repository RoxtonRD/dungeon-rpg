## A combat-side wrapper around a Hero or an EnemyData. Owns the active
## status list and current HP for enemies; hero HP/MP live on the Hero
## itself (so damage taken in battle persists between encounters).
class_name Battler
extends RefCounted

enum Side { PARTY, ENEMY }

## Rage cap for rage classes (see ClassData.ResourceType.RAGE).
const RAGE_MAX := 100
## Rage gained once per action that deals at least 1 damage, however many
## targets it hits.
const RAGE_PER_DAMAGING_ACTION := 10
## Rage gained each time a rage class takes a hit that deals at least 1 damage.
const RAGE_PER_HIT_TAKEN := 20

var side: Battler.Side = Battler.Side.PARTY
## Set when side == PARTY; null otherwise.
var hero: Hero = null
## Set when side == ENEMY; null otherwise.
var enemy_data: EnemyData = null
## Current HP for enemies. Heroes read/write hero.hp directly.
var enemy_hp: int = 0
## Max HP cached at battle start (heroes: from Hero.max_hp at that moment,
## enemies: from EnemyData.max_hp).
var max_hp: int = 0
var statuses: Array[CombatStatus] = []
## Slot index within its own side (0..3 for party, 0..N for enemies).
var index: int = 0
## Rage for rage classes. Starts at 0 every fight and is never saved.
var rage: int = 0
## Turns left before a skill is usable again, keyed by cooldown_key().
## Combat-only, never saved.
var cooldowns: Dictionary = {}


static func for_hero(h: Hero, idx: int) -> Battler:
	var b := Battler.new()
	b.side = Battler.Side.PARTY
	b.hero = h
	b.max_hp = h.max_hp()
	b.index = idx
	# Share the hero's status list by reference rather than copying: buffs and
	# debuffs persist outside combat, so what combat applies/ticks/reads here IS
	# the hero's persistent list. Enemies keep their own per-fight array.
	b.statuses = h.statuses
	return b


static func for_enemy(data: EnemyData, idx: int) -> Battler:
	var b := Battler.new()
	b.side = Battler.Side.ENEMY
	b.enemy_data = data
	b.enemy_hp = data.max_hp
	b.max_hp = data.max_hp
	b.index = idx
	return b


func get_hp() -> int:
	return hero.hp if side == Battler.Side.PARTY else enemy_hp


func set_hp(value: int) -> void:
	var clamped := clampi(value, 0, max_hp)
	if side == Battler.Side.PARTY:
		hero.hp = clamped
	else:
		enemy_hp = clamped


func is_alive() -> bool:
	return get_hp() > 0


func display_name() -> String:
	# class/enemy display_name holds a translation key.
	return hero.display_name() if side == Battler.Side.PARTY else tr(enemy_data.display_name)


## Returns true when this battler is in the front row.
## For party members this reads hero.row (set by the formation screen);
## for enemies it falls back to the EnemyData default role.
func is_front_row() -> bool:
	if side == Battler.Side.PARTY:
		return hero.row == 0  # 0 = ClassData.Role.FRONT
	return enemy_data.role == EnemyData.Role.FRONT


## Raw {atk, def, mag, spd} before any status effects.
func base_stats() -> Dictionary:
	if side == Battler.Side.PARTY:
		return {
			"atk": hero.atk(),
			"def": hero.def(),
			"mag": hero.mag(),
			"spd": hero.spd(),
		}
	return {
		"atk": enemy_data.atk,
		"def": enemy_data.def,
		"mag": enemy_data.mag,
		"spd": enemy_data.spd,
	}


## Base stats with active buff/debuff statuses folded in. Floor at 0.
func effective_stats() -> Dictionary:
	var s := base_stats()
	for st in statuses:
		if st.kind == CombatStatus.Kind.BUFF or st.kind == CombatStatus.Kind.DEBUFF:
			s["atk"] = maxi(0, int(s["atk"]) + st.mod_atk)
			s["def"] = maxi(0, int(s["def"]) + st.mod_def)
			s["mag"] = maxi(0, int(s["mag"]) + st.mod_mag)
			s["spd"] = maxi(0, int(s["spd"]) + st.mod_spd)
	return s


## True when an active DEBUFF lowers this battler's DEF (Wide Arc, Sunder), the
## setup SkillData.bonus_vs_def_debuff pays off on.
func has_def_debuff() -> bool:
	for st in statuses:
		if st.kind == CombatStatus.Kind.DEBUFF and st.mod_def < 0:
			return true
	return false


func has_taunt() -> bool:
	for st in statuses:
		if st.taunt:
			return true
	return false


## Pops the first barrier status off, returning true if one was consumed.
func consume_barrier() -> bool:
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i].kind == CombatStatus.Kind.BARRIER:
			statuses.remove_at(i)
			return true
	return false


## True for a party hero whose class spends Rage instead of MP.
func uses_rage() -> bool:
	return (
		side == Battler.Side.PARTY and hero.class_data.resource_type == ClassData.ResourceType.RAGE
	)


## Adds Rage, clamped to 0..RAGE_MAX. No-op for anyone who doesn't use it.
func gain_rage(amount: int) -> void:
	if uses_rage():
		rage = clampi(rage + amount, 0, RAGE_MAX)


## Rage gained from one hit taken: RAGE_PER_HIT_TAKEN times the strongest
## active multiplier (Vengeance's taunt triples it).
func rage_per_hit_taken() -> int:
	var mult := 1.0
	for st in statuses:
		mult = maxf(mult, st.rage_taken_mult)
	return roundi(RAGE_PER_HIT_TAKEN * mult)


## Multiplier from the hero's passive on the damage it deals right now
## (Bloodlust: +2% per 10 Rage held). 1.0 for enemies and heroes without one.
func passive_damage_mult() -> float:
	if side != Battler.Side.PARTY:
		return 1.0
	var passive := Party.get_passive(hero)
	return passive.damage_mult(rage) if passive != null else 1.0


## The reaction this battler would use against a hit from `skill` resolving as
## `dmg_kind`, or null: it must be learned, switched on, apply to that hit, and
## be affordable. The chance roll is the caller's.
func reaction_for(skill: SkillData, dmg_kind: SkillData.SkillType) -> ReactionData:
	if side != Battler.Side.PARTY:
		return null
	var reaction := Party.get_active_reaction(hero)
	if reaction == null or not reaction.applies(skill, dmg_kind):
		return null
	if resource_amount() < reaction.rage_cost:
		return null
	return reaction


## The amount of this battler's class resource available to pay skill costs.
func resource_amount() -> int:
	if uses_rage():
		return rage
	return hero.mp if side == Battler.Side.PARTY else 0


## Pays a skill cost from Rage or MP.
func spend_resource(amount: int) -> void:
	if uses_rage():
		rage = clampi(rage - amount, 0, RAGE_MAX)
	elif side == Battler.Side.PARTY:
		hero.mp -= amount


## Puts a skill on its cooldown (no-op when it has none). `turns` overrides
## the skill's own cooldown: a talent variant cools down under its base skill's
## key, for as long as the variant says.
func start_cooldown(skill: SkillData, turns: int = -1) -> void:
	var length := skill.cooldown if turns < 0 else turns
	if length > 0:
		cooldowns[cooldown_key(skill)] = length


## Makes a skill usable again right away.
func reset_cooldown(skill: SkillData) -> void:
	cooldowns.erase(cooldown_key(skill))


## Turns left on a skill's cooldown (0 = ready).
func cooldown_left(skill: SkillData) -> int:
	return int(cooldowns.get(cooldown_key(skill), 0))


## Counts every cooldown down by one. Called at the start of this battler's turn.
func tick_cooldowns() -> void:
	for key in cooldowns:
		cooldowns[key] = maxi(0, int(cooldowns[key]) - 1)


## The skill's .tres basename, like Party._skill_key; falls back to its id for
## a skill built in code (no resource_path).
static func cooldown_key(skill: SkillData) -> String:
	if skill.resource_path.is_empty():
		return skill.id
	return skill.resource_path.get_file().get_basename()
