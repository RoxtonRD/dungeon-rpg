## A combat-side wrapper around a Hero or an EnemyData. Owns the active
## status list and current HP for enemies; hero HP/MP live on the Hero
## itself (so damage taken in battle persists between encounters).
class_name Battler
extends RefCounted

enum Side { PARTY, ENEMY }

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


static func for_hero(h: Hero, idx: int) -> Battler:
	var b := Battler.new()
	b.side = Battler.Side.PARTY
	b.hero = h
	b.max_hp = h.max_hp()
	b.index = idx
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
		return hero.row == 0   # 0 = ClassData.Role.FRONT
	return enemy_data.role == EnemyData.Role.FRONT


## Raw {atk, def, mag, spd} before any status effects.
func base_stats() -> Dictionary:
	if side == Battler.Side.PARTY:
		return {
			"atk": hero.atk(), "def": hero.def(),
			"mag": hero.mag(), "spd": hero.spd(),
		}
	return {
		"atk": enemy_data.atk, "def": enemy_data.def,
		"mag": enemy_data.mag, "spd": enemy_data.spd,
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
