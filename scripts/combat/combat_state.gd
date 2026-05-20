## Per-battle state machine. A new CombatState is built when a fight starts
## and discarded when it ends. Drives the turn loop, runs skill resolution,
## and emits signals for any UI to listen to.
##
## API for callers (test driver, combat scene):
##   var state := CombatState.build(heroes, enemy_data_list)
##   state.start()                              # advances to first actor;
##                                              # auto-resolves any enemy
##                                              # turns until a party turn
##                                              # (or combat ends).
##   while not state.ended:
##       state.player_action(skill, target)     # or state.player_flee()
##
## Skill formulas, status interactions, AI selection and reward math are
## carried verbatim from reference/combat.js.
class_name CombatState
extends RefCounted

enum Result { NONE, VICTORY, DEFEAT, FLEE }

signal log_appended(line: String)
signal hp_changed(battler: Battler)
signal turn_started(battler: Battler)
signal combat_ended(result: Result, rewards: Dictionary)

var party: Array[Battler] = []
var enemies: Array[Battler] = []
## Remaining actors in the current round, in initiative order.
var initiative: Array[Battler] = []
var current_actor: Battler = null
var round_number: int = 0
var ended: bool = false
var result: Result = Result.NONE
var log_lines: Array[String] = []
var rewards: Dictionary = {}


static func build(heroes: Array[Hero], enemy_data_list: Array[EnemyData]) -> CombatState:
	var c := CombatState.new()
	for i in heroes.size():
		c.party.append(Battler.for_hero(heroes[i], i))
	for i in enemy_data_list.size():
		c.enemies.append(Battler.for_enemy(enemy_data_list[i], i))
	return c


# ── Public API ────────────────────────────────────────────────────────────────

func start() -> void:
	_log("O combate começou!")
	_roll_initiative()
	_advance_to_next_actor()


## Returns the set of battlers the player must pick from for this skill.
## Empty when the skill auto-resolves its targets (SELF / ALL / ALLIES / RANDOM).
func valid_targets_for(actor: Battler, skill: SkillData) -> Array[Battler]:
	var result_list: Array[Battler] = []
	match skill.target:
		SkillData.TargetType.ONE:
			var alive: Array[Battler] = _alive(_opposing_side(actor))
			var front: Array[Battler] = []
			for b in alive:
				if b.is_front_row():
					front.append(b)
			return front if not front.is_empty() else alive
		SkillData.TargetType.ALLY:
			return _alive(_same_side(actor))
		SkillData.TargetType.DEAD_ALLY:
			for b in _same_side(actor):
				if not b.is_alive():
					result_list.append(b)
			return result_list
	return result_list


func skill_is_auto_targeted(skill: SkillData) -> bool:
	return skill.target == SkillData.TargetType.SELF \
		or skill.target == SkillData.TargetType.ALL \
		or skill.target == SkillData.TargetType.ALLIES \
		or skill.target == SkillData.TargetType.RANDOM


## Resolves the player's chosen action. `target` may be null when the skill
## auto-targets (SELF / ALL / ALLIES / RANDOM).
func player_action(skill: SkillData, target: Battler) -> void:
	if ended or current_actor == null or current_actor.side != Battler.Side.PARTY:
		return
	var actor := current_actor
	if actor.hero.mp < skill.mp_cost:
		_log("MP insuficiente.")
		return
	actor.hero.mp -= skill.mp_cost
	var scaled := Party.get_upgraded_skill(actor.hero, skill)
	_apply_skill(actor, scaled, target)
	_after_action()


## 60% chance of success per prototype combat.js.
func player_flee() -> void:
	if ended or current_actor == null or current_actor.side != Battler.Side.PARTY:
		return
	if randf() < 0.6:
		_log("O grupo fugiu do combate.")
		_end(Result.FLEE)
	else:
		_log("A fuga falhou!")
		_after_action()


## Resolves the current enemy's turn and advances to the next actor.
## No-op when it's a party turn (caller should use player_action /
## player_flee) or when combat has ended.
func step() -> void:
	if ended or current_actor == null:
		return
	if current_actor.side != Battler.Side.ENEMY:
		return
	_enemy_take_turn()
	_after_action()


# ── Turn-order machinery ──────────────────────────────────────────────────────

func _advance_to_next_actor() -> void:
	while not ended:
		if initiative.is_empty():
			_tick_statuses()
			if ended:
				return
			round_number += 1
			_roll_initiative()
		var next: Battler = null
		while not initiative.is_empty():
			var candidate: Battler = initiative.pop_front()
			if candidate.is_alive():
				next = candidate
				break
		if next == null:
			# Every remaining entry was dead — reroll the round.
			continue
		current_actor = next
		turn_started.emit(next)
		# Stop here. The caller drives the turn:
		#   - player_action / player_flee for party turns
		#   - step() for enemy turns
		return


func _after_action() -> void:
	if _check_end_conditions():
		return
	_advance_to_next_actor()


func _check_end_conditions() -> bool:
	if not _side_has_living(enemies):
		_end(Result.VICTORY)
		return true
	if not _side_has_living(party):
		_end(Result.DEFEAT)
		return true
	return false


func _end(r: Result) -> void:
	ended = true
	result = r
	rewards = _calculate_rewards(r)
	combat_ended.emit(r, rewards)


## XP and gold per prototype combat.js. Loot drops require dungeon-level
## context (rollLoot) and are deferred to step 5.
func _calculate_rewards(r: Result) -> Dictionary:
	if r != Result.VICTORY:
		return {"xp": 0, "gold": 0}
	var xp_total := 0
	var gold_total := 0
	for b in enemies:
		xp_total += b.enemy_data.xp_reward
		gold_total += randi_range(b.enemy_data.gold_min, b.enemy_data.gold_max)
	return {"xp": xp_total, "gold": gold_total}


func _roll_initiative() -> void:
	var pool: Array = []
	for b in _all_battlers():
		if not b.is_alive():
			continue
		var spd := int(b.effective_stats()["spd"])
		pool.append({"battler": b, "score": spd + randf() * 2.0})
	pool.sort_custom(func(a, b): return a["score"] > b["score"])
	initiative.clear()
	for entry in pool:
		initiative.append(entry["battler"])


## Round-end heartbeat: DoT damage ticks, durations count down, expired
## statuses get removed.
func _tick_statuses() -> void:
	for b in _all_battlers():
		if not b.is_alive():
			continue
		for i in range(b.statuses.size() - 1, -1, -1):
			var st: CombatStatus = b.statuses[i]
			if st.kind == CombatStatus.Kind.DOT:
				b.set_hp(b.get_hp() - st.dot_damage)
				_log("%s sofre %d de %s." % [b.display_name(), st.dot_damage, st.source_name])
				hp_changed.emit(b)
			st.duration -= 1
			if st.duration <= 0:
				b.statuses.remove_at(i)
	_check_end_conditions()


# ── Skill resolution ──────────────────────────────────────────────────────────

func _apply_skill(caster: Battler, skill: SkillData, picked: Battler) -> void:
	var caster_stats := caster.effective_stats()
	var targets: Array[Battler] = _gather_targets(caster, skill, picked)
	match skill.skill_type:
		SkillData.SkillType.BUFF:
			for t in targets:
				_apply_buff(t, skill)
			_log("%s usa %s." % [caster.display_name(), skill.display_name])
		SkillData.SkillType.DEBUFF:
			for t in targets:
				_apply_debuff(t, skill)
			_log("%s usa %s!" % [caster.display_name(), skill.display_name])
		SkillData.SkillType.HEAL:
			for t in targets:
				_apply_heal(caster, caster_stats, skill, t)
		SkillData.SkillType.REVIVE:
			if not targets.is_empty():
				_apply_revive(caster, targets[0])
		SkillData.SkillType.MULTI:
			_log("%s usa %s." % [caster.display_name(), skill.display_name])
			var hit_kind := SkillData.SkillType.PHYS \
				if skill.multi_hit_type == SkillData.HitType.PHYS \
				else SkillData.SkillType.MAG
			for h in skill.hits:
				var ht: Battler = null
				if skill.target == SkillData.TargetType.RANDOM:
					var alive: Array[Battler] = _alive(_opposing_side(caster))
					if alive.is_empty():
						break
					ht = alive[randi() % alive.size()]
				elif picked != null and picked.is_alive():
					ht = picked
				if ht == null:
					break
				_apply_damage_hit(caster, caster_stats, skill, ht, hit_kind)
		SkillData.SkillType.PHYS, SkillData.SkillType.MAG:
			for t in targets:
				_apply_damage_hit(caster, caster_stats, skill, t, skill.skill_type)


func _gather_targets(caster: Battler, skill: SkillData, picked: Battler) -> Array[Battler]:
	var out: Array[Battler] = []
	match skill.target:
		SkillData.TargetType.ALL:
			for b in _opposing_side(caster):
				if b.is_alive():
					out.append(b)
		SkillData.TargetType.ALLIES:
			for b in _same_side(caster):
				if b.is_alive():
					out.append(b)
		SkillData.TargetType.SELF:
			out.append(caster)
		SkillData.TargetType.DEAD_ALLY:
			if picked != null:
				out.append(picked)
			else:
				for b in _same_side(caster):
					if not b.is_alive():
						out.append(b)
						break
		SkillData.TargetType.RANDOM:
			pass  # MULTI handles RANDOM per-hit
		_:
			if picked != null:
				out.append(picked)
	return out


func _apply_buff(target: Battler, skill: SkillData) -> void:
	var st := CombatStatus.new()
	st.kind = CombatStatus.Kind.BARRIER if skill.barrier else CombatStatus.Kind.BUFF
	st.source_name = skill.display_name
	st.mod_atk = skill.mod_atk
	st.mod_def = skill.mod_def
	st.mod_mag = skill.mod_mag
	st.mod_spd = skill.mod_spd
	st.duration = skill.mod_duration
	st.taunt = skill.taunt
	target.statuses.append(st)


func _apply_debuff(target: Battler, skill: SkillData) -> void:
	var st := CombatStatus.new()
	st.kind = CombatStatus.Kind.DEBUFF
	st.source_name = skill.display_name
	st.mod_atk = skill.mod_atk
	st.mod_def = skill.mod_def
	st.mod_mag = skill.mod_mag
	st.mod_spd = skill.mod_spd
	st.duration = skill.mod_duration
	target.statuses.append(st)


func _apply_heal(caster: Battler, caster_stats: Dictionary, skill: SkillData, target: Battler) -> void:
	var heal_amount := int(floor(float(caster_stats["mag"]) * skill.power + 5.0))
	target.set_hp(target.get_hp() + heal_amount)
	_log("%s cura %s em %d." % [caster.display_name(), target.display_name(), heal_amount])
	hp_changed.emit(target)


func _apply_revive(caster: Battler, target: Battler) -> void:
	# 30% of max HP, prototype value.
	var amount := maxi(1, int(floor(target.max_hp * 0.3)))
	target.set_hp(amount)
	_log("%s revive %s!" % [caster.display_name(), target.display_name()])
	hp_changed.emit(target)


func _apply_damage_hit(caster: Battler, caster_stats: Dictionary, skill: SkillData, target: Battler, dmg_kind: SkillData.SkillType) -> void:
	# Barrier eats the hit before damage is rolled.
	if target.consume_barrier():
		_log("A barreira de %s absorveu o golpe!" % target.display_name())
		return
	var is_mag := dmg_kind == SkillData.SkillType.MAG
	var raw_attack := float(caster_stats["mag"] if is_mag else caster_stats["atk"])
	var raw := raw_attack * skill.power + randf_range(0.0, 3.0)
	# Finisher: double power when target is under 25% HP.
	if skill.finisher and target.get_hp() <= int(target.max_hp * 0.25):
		raw *= 2.0
	var crit := false
	if skill.crit_chance > 0.0 and randf() < skill.crit_chance:
		raw *= 1.8
		crit = true
	var t_stats := target.effective_stats()
	# Magic damage uses 40% of DEF; physical uses full DEF.
	var t_def := int(floor(float(t_stats["def"]) * 0.4)) if is_mag else int(t_stats["def"])
	var dmg := maxi(1, int(floor(raw - t_def)))
	target.set_hp(target.get_hp() - dmg)
	hp_changed.emit(target)
	var crit_label := " (CRÍTICO)" if crit else ""
	_log("%s usa %s em %s causando %d%s." % [caster.display_name(), skill.display_name, target.display_name(), dmg, crit_label])
	# DoT rider (prototype adds unconditionally — dead targets simply won't tick).
	if skill.dot_damage > 0:
		var dot := CombatStatus.new()
		dot.kind = CombatStatus.Kind.DOT
		dot.source_name = skill.display_name
		dot.dot_damage = skill.dot_damage
		dot.duration = skill.dot_duration
		target.statuses.append(dot)
	# Debuff rider on damage skills.
	if skill.mod_duration > 0 and (skill.mod_atk != 0 or skill.mod_def != 0 or skill.mod_mag != 0 or skill.mod_spd != 0):
		var deb := CombatStatus.new()
		deb.kind = CombatStatus.Kind.DEBUFF
		deb.source_name = skill.display_name
		deb.mod_atk = skill.mod_atk
		deb.mod_def = skill.mod_def
		deb.mod_mag = skill.mod_mag
		deb.mod_spd = skill.mod_spd
		deb.duration = skill.mod_duration
		target.statuses.append(deb)
	# Drain: caster heals for 50% of damage dealt.
	if skill.drain:
		var healed := int(floor(dmg * 0.5))
		caster.set_hp(caster.get_hp() + healed)
		hp_changed.emit(caster)


# ── Enemy AI ──────────────────────────────────────────────────────────────────

func _enemy_take_turn() -> void:
	var e := current_actor
	var data := e.enemy_data
	# Filter by use_condition (lowHp triggers below 50% HP, etc.).
	var usable: Array[SkillData] = []
	for sk in data.skills:
		if sk.use_condition == SkillData.UseCondition.LOW_HP and e.get_hp() > e.max_hp * 0.5:
			continue
		if sk.use_condition == SkillData.UseCondition.NOT_LOW_HP and e.get_hp() <= e.max_hp * 0.5:
			continue
		usable.append(sk)
	if usable.is_empty():
		usable = data.skills
	if usable.is_empty():
		return
	var skill: SkillData = usable[randi() % usable.size()]
	var e_stats := e.effective_stats()

	# Self-targeting skills (self-buff, regen).
	if skill.target == SkillData.TargetType.SELF:
		if skill.skill_type == SkillData.SkillType.BUFF:
			_apply_buff(e, skill)
			_log("%s usa %s." % [e.display_name(), skill.display_name])
		elif skill.skill_type == SkillData.SkillType.HEAL:
			var mag_val := int(e_stats["mag"])
			if mag_val <= 0:
				mag_val = int(e_stats["atk"])
			var heal_amount := int(floor(mag_val * skill.power + 5.0))
			e.set_hp(e.get_hp() + heal_amount)
			_log("%s se regenera em %d." % [e.display_name(), heal_amount])
			hp_changed.emit(e)
		return

	# Pick a party target for ONE-target skills; taunt overrides front-first.
	var picked: Battler = null
	if skill.target == SkillData.TargetType.ONE:
		var alive_party: Array[Battler] = _alive(party)
		var taunters: Array[Battler] = []
		for b in alive_party:
			if b.has_taunt():
				taunters.append(b)
		var pool: Array[Battler] = []
		if not taunters.is_empty():
			pool = taunters
		else:
			for b in alive_party:
				if b.is_front_row():
					pool.append(b)
			if pool.is_empty():
				pool = alive_party
		if not pool.is_empty():
			picked = pool[randi() % pool.size()]
	_apply_skill(e, skill, picked)


# ── Small helpers ─────────────────────────────────────────────────────────────

func _opposing_side(b: Battler) -> Array[Battler]:
	return enemies if b.side == Battler.Side.PARTY else party


func _same_side(b: Battler) -> Array[Battler]:
	return party if b.side == Battler.Side.PARTY else enemies


func _all_battlers() -> Array[Battler]:
	var all: Array[Battler] = []
	all.append_array(party)
	all.append_array(enemies)
	return all


func _alive(list: Array[Battler]) -> Array[Battler]:
	var out: Array[Battler] = []
	for b in list:
		if b.is_alive():
			out.append(b)
	return out


func _side_has_living(list: Array[Battler]) -> bool:
	for b in list:
		if b.is_alive():
			return true
	return false


func _log(msg: String) -> void:
	log_lines.append(msg)
	log_appended.emit(msg)
