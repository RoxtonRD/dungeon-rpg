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
## Energy cap for energy classes (see ClassData.ResourceType.ENERGY). It starts
## full every fight.
const ENERGY_MAX := 100
## Energy gained at the start of each of an energy hero's turns.
const ENERGY_REGEN := 25

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
## Energy for energy classes. Starts at ENERGY_MAX every fight and is never saved.
var energy: int = 0
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
	# A wind-up never outlives its fight (it is lost with the fight, see
	# CombatState._end); one left in a loaded save is inert, so drop it.
	b.clear_charge()
	if b.uses_energy():
		b.energy = ENERGY_MAX
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
	# A downed battler's wind-up is lost with it (Meteor: the cost is not refunded).
	if clamped == 0:
		clear_charge()


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


## True while a status stops single-target attacks from picking this battler
## (Shadowstep).
func is_untargetable() -> bool:
	for st in statuses:
		if st.untargetable:
			return true
	return false


## Multiplier on every hit this battler takes: the product of its statuses'
## damage_taken_mult (Mark for Death). 1.0 when none applies.
func damage_taken_mult() -> float:
	var mult := 1.0
	for st in statuses:
		mult *= st.damage_taken_mult
	return mult


## Ends the statuses that last "until this battler's next turn" (Shadowstep).
func clear_until_next_turn() -> void:
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i].untargetable:
			statuses.remove_at(i)


func has_taunt() -> bool:
	for st in statuses:
		if st.taunt:
			return true
	return false


## The wind-up this enemy is in the middle of, or null.
func charge_status() -> CombatStatus:
	for st in statuses:
		if st.kind == CombatStatus.Kind.CHARGING:
			return st
	return null


## True while this battler is winding up a telegraphed skill. For a hero that
## means its next turn resolves on its own (see CombatState.step).
func is_charging() -> bool:
	return charge_status() != null


## Cancels any wind-up (the battler died, or the fight ended).
func clear_charge() -> void:
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i].kind == CombatStatus.Kind.CHARGING:
			statuses.remove_at(i)


## Current HP as a fraction of max HP (0..1).
func hp_fraction() -> float:
	return float(get_hp()) / float(maxi(1, max_hp))


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


## True for a party hero whose class spends Energy instead of MP.
func uses_energy() -> bool:
	return (
		side == Battler.Side.PARTY
		and hero.class_data.resource_type == ClassData.ResourceType.ENERGY
	)


## Adds Rage, clamped to 0..RAGE_MAX. No-op for anyone who doesn't use it.
func gain_rage(amount: int) -> void:
	if uses_rage():
		rage = clampi(rage + amount, 0, RAGE_MAX)


## Adds Energy, clamped to 0..ENERGY_MAX. No-op for anyone who doesn't use it.
func gain_energy(amount: int) -> void:
	if uses_energy():
		energy = clampi(energy + amount, 0, ENERGY_MAX)


## Gives back some of the hero's own combat resource: Rage, Energy or MP.
func refund_resource(amount: int) -> void:
	gain_rage(amount)
	gain_energy(amount)
	gain_mp(amount)


## Adds MP, capped at the hero's max. No-op for anyone who doesn't use MP.
func gain_mp(amount: int) -> void:
	if side == Battler.Side.PARTY and not uses_rage() and not uses_energy():
		hero.mp = clampi(hero.mp + amount, 0, hero.max_mp())


## Energy refills at the start of each of the hero's turns.
func regen_energy() -> void:
	gain_energy(ENERGY_REGEN)


## MP the hero's passive gives at the start of each of its turns (Mana Flow).
func regen_mp() -> void:
	if side != Battler.Side.PARTY:
		return
	var passive := Party.get_passive(hero)
	if passive != null:
		gain_mp(passive.mp_regen_per_turn)


## The damage per tick and the duration a DoT of `dot_damage` for `duration`
## turns has once this battler's passive has had its say (Elemental Mastery).
## Unchanged for enemies and heroes without one.
func passive_dot(dot_damage: int, duration: int) -> Vector2i:
	if side != Battler.Side.PARTY:
		return Vector2i(dot_damage, duration)
	var passive := Party.get_passive(hero)
	if passive == null:
		return Vector2i(dot_damage, duration)
	return Vector2i(
		roundi(dot_damage * passive.dot_damage_mult), duration + passive.dot_duration_bonus
	)


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


## Extra crit chance from the hero's passive against `target` (Assassin's Focus:
## more against a target below half HP). 0.0 for enemies and heroes without one.
func passive_crit_bonus(target: Battler) -> float:
	if side != Battler.Side.PARTY:
		return 0.0
	var passive := Party.get_passive(hero)
	if passive == null or passive.crit_bonus_below_half_hp <= 0.0:
		return 0.0
	if target.hp_fraction() >= PassiveData.CRIT_BONUS_BELOW:
		return 0.0
	return passive.crit_bonus_below_half_hp


## The reaction this battler would use against a hit from `skill` resolving as
## `dmg_kind`, or null: it must be learned, switched on, apply to that hit, and
## be affordable, and (Arcane Barrier) the hit of `dmg` must leave the hero under
## the reaction's HP threshold, if it has one. The chance roll is the caller's.
func reaction_for(skill: SkillData, dmg_kind: SkillData.SkillType, dmg: int = 0) -> ReactionData:
	if side != Battler.Side.PARTY:
		return null
	var reaction := Party.get_active_reaction(hero)
	if reaction == null or not reaction.applies(skill, dmg_kind):
		return null
	if resource_amount() < reaction.cost:
		return null
	if not reaction.passes_hp_threshold(get_hp(), max_hp, dmg):
		return null
	return reaction


## The amount of this battler's class resource available to pay skill costs.
func resource_amount() -> int:
	if uses_rage():
		return rage
	if uses_energy():
		return energy
	return hero.mp if side == Battler.Side.PARTY else 0


## Pays a skill cost from Rage, Energy or MP.
func spend_resource(amount: int) -> void:
	if uses_rage():
		rage = clampi(rage - amount, 0, RAGE_MAX)
	elif uses_energy():
		energy = clampi(energy - amount, 0, ENERGY_MAX)
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
