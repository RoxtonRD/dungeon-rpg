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
## Skill formulas, status interactions and reward math are carried verbatim from
## reference/combat.js. Enemy AI follows EnemyData.ai_role (encounters v3).
class_name CombatState
extends RefCounted

enum Result { NONE, VICTORY, DEFEAT, FLEE }
## Flavour of a floating combat number, so the UI can colour it.
enum PopupKind { PHYS, MAG, HEAL }
## Log-line category, so the UI can colour lines without parsing text
## (language-independent — the old substring matching broke under i18n).
enum LogKind { INFO, DAMAGE, CRIT, HEAL, BARRIER }

signal log_appended(line: String, kind: LogKind)
signal hp_changed(battler: Battler)
## Emitted alongside hp_changed when an amount should pop up on a battler.
## `tags` label what happened to a damage hit: "crit", "exposed" (a bonus
## against a DEF debuff) and the target's reaction ("parried", "dodged").
## Usually empty.
signal damage_popup(battler: Battler, amount: int, kind: PopupKind, tags: PackedStringArray)
signal turn_started(battler: Battler)
## Presentation only: emitted once per action (hero or enemy, skill or item),
## before its effects resolve, so the UI can name the action and mark its
## targets. An item is passed as a stand-in SkillData carrying the item's
## name. `targets` is empty for RANDOM multi-hit skills (rolled per hit).
signal action_started(caster: Battler, skill: SkillData, targets: Array[Battler])
## Presentation only: emitted whenever a status is added to a battler.
signal status_applied(target: Battler, status: CombatStatus)
signal combat_ended(result: Result, rewards: Dictionary)

## Elite fights pay out more (the guaranteed item drop is rolled by Loot).
const ELITE_XP_MULT := 1.5
const ELITE_GOLD_MULT := 2.0
## An enemy below this share of its HP counts as hurt for a SUPPORT's heals.
const SUPPORT_HEAL_BELOW := 0.5
## Chance a CASTER with no area skill (or fewer than 3 targets) picks a debuff.
const CASTER_DEBUFF_CHANCE := 0.5
## id of the stand-in skill action_started carries for a wind-up turn.
const WIND_UP_ID := "wind_up"

var party: Array[Battler] = []
var enemies: Array[Battler] = []
## Remaining actors in the current round, in initiative order.
var initiative: Array[Battler] = []
var current_actor: Battler = null
var round_number: int = 0
## Who has already taken a turn in the current round (Ambush crits a target that
## has not). Cleared when the next round is rolled.
var acted_this_round: Array[Battler] = []
var ended: bool = false
var result: Result = Result.NONE
var log_lines: Array[String] = []
var rewards: Dictionary = {}
## An elite room's fight: XP and gold are multiplied.
var elite: bool = false


static func build(
	heroes: Array[Hero], enemy_data_list: Array[EnemyData], p_elite: bool = false
) -> CombatState:
	var c := CombatState.new()
	c.elite = p_elite
	for i in heroes.size():
		c.party.append(Battler.for_hero(heroes[i], i))
	for i in enemy_data_list.size():
		c.enemies.append(Battler.for_enemy(enemy_data_list[i], i))
	return c


# ── Public API ────────────────────────────────────────────────────────────────


func start() -> void:
	_log(tr("LOG_BEGIN"))
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
	return (
		skill.target == SkillData.TargetType.SELF
		or skill.target == SkillData.TargetType.ALL
		or skill.target == SkillData.TargetType.ALLIES
		or skill.target == SkillData.TargetType.RANDOM
	)


## The single gate for a hero using a skill: unlocked at the hero's level,
## enough of the class resource (MP or Rage) and not on cooldown. The combat
## buttons, player_action and the balance sim all ask this. `skill` is the
## class's base skill; the cost is the effective skill's (Party.combat_cost).
func can_use(actor: Battler, skill: SkillData) -> bool:
	if actor.side != Battler.Side.PARTY:
		return true  # enemies don't pay costs or track cooldowns
	if actor.hero.level < skill.unlock_level:
		return false
	if actor.resource_amount() < Party.combat_cost(actor.hero, skill):
		return false
	return actor.cooldown_left(skill) == 0


## Resolves the player's chosen action. `skill` is the class's base skill; it
## resolves as the hero's effective skill (tier upgrade or talent variant), and
## its cooldown stays keyed by the base skill. `target` may be null when the
## skill auto-targets (SELF / ALL / ALLIES / RANDOM).
func player_action(skill: SkillData, target: Battler) -> void:
	if ended or current_actor == null or current_actor.side != Battler.Side.PARTY:
		return
	var actor := current_actor
	var cost := Party.combat_cost(actor.hero, skill)
	if not can_use(actor, skill):
		if (
			actor.hero.class_data.resource_type == ClassData.ResourceType.MANA
			and actor.hero.mp < cost
		):
			_log(tr("LOG_NO_MP"))
		return
	var effective := Party.get_effective_skill(actor.hero, skill)
	actor.spend_resource(cost)
	actor.start_cooldown(skill, effective.cooldown)
	var foes_before := _alive(_opposing_side(actor))
	_apply_skill(actor, effective, target)
	if effective.resource_refund > 0:
		actor.refund_resource(effective.resource_refund)
	for foe in foes_before:
		if not foe.is_alive():
			_on_kill(actor, skill, effective)
			break
	_after_action()


## On-kill talent effects (Reaper): refund Rage and reset the skill's cooldown.
## Runs once per action, however many foes it killed.
func _on_kill(actor: Battler, base: SkillData, effective: SkillData) -> void:
	if effective.on_kill_rage > 0:
		actor.gain_rage(effective.on_kill_rage)
	if effective.on_kill_reset_cooldown:
		actor.reset_cooldown(base)


## Living party members — the pick list for a heal/mana item.
func item_targets(actor: Battler) -> Array[Battler]:
	return _alive(_same_side(actor))


## Consumes a party-inventory consumable as the actor's turn: heal/mana applied
## to `target`, or a party-wide revive (target ignored). Ends the turn. No-op if
## the item is missing from the inventory.
func player_item(item_id: String, target: Battler) -> void:
	if ended or current_actor == null or current_actor.side != Battler.Side.PARTY:
		return
	var item := load("res://resources/items/%s.tres" % item_id) as ItemData
	if item == null or not GameState.remove_item(item_id):
		return
	_apply_item(current_actor, item, target)
	_after_action()


func _apply_item(user: Battler, item: ItemData, target: Battler) -> void:
	_emit_item_action(user, item, target)
	_log(tr("LOG_ITEM") % [user.display_name(), tr(item.display_name)], LogKind.HEAL)
	if item.use_revive_party > 0.0:
		for b in party:
			if not b.is_alive():
				var amt := maxi(1, int(round(b.max_hp * item.use_revive_party)))
				b.set_hp(amt)
				hp_changed.emit(b)
				damage_popup.emit(b, amt, PopupKind.HEAL, PackedStringArray())
		return
	if target == null:
		return
	if item.use_heal > 0:
		var before := target.get_hp()
		target.set_hp(before + item.use_heal)
		hp_changed.emit(target)
		damage_popup.emit(target, target.get_hp() - before, PopupKind.HEAL, PackedStringArray())
	if item.use_mp > 0 and target.side == Battler.Side.PARTY:
		target.hero.mp = mini(target.hero.max_mp(), target.hero.mp + item.use_mp)
		hp_changed.emit(target)


## action_started for an item: a stand-in SkillData carries the item's name
## (and HEAL, so the UI reads it as friendly).
func _emit_item_action(user: Battler, item: ItemData, target: Battler) -> void:
	var as_skill := SkillData.new()
	as_skill.display_name = item.display_name
	as_skill.skill_type = SkillData.SkillType.HEAL
	var targets: Array[Battler] = []
	if item.use_revive_party > 0.0:
		for b in party:
			if not b.is_alive():
				targets.append(b)
	elif target != null:
		targets.append(target)
	action_started.emit(user, as_skill, targets)


## 60% chance of success per prototype combat.js.
func player_flee() -> void:
	if ended or current_actor == null or current_actor.side != Battler.Side.PARTY:
		return
	if randf() < 0.6:
		_log(tr("LOG_FLED"))
		_end(Result.FLEE)
	else:
		_log(tr("LOG_FLEE_FAIL"))
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
		next.tick_cooldowns()
		next.clear_until_next_turn()
		next.regen_energy()
		acted_this_round.append(next)
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
	# "Until their next turn" cannot outlast the fight: party statuses are saved.
	for b in party:
		b.clear_until_next_turn()
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
	if elite:
		xp_total = roundi(xp_total * ELITE_XP_MULT)
		gold_total = roundi(gold_total * ELITE_GOLD_MULT)
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
	acted_this_round.clear()
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
				_log(
					tr("LOG_DOT") % [b.display_name(), st.dot_damage, tr(st.source_name)],
					LogKind.DAMAGE
				)
				hp_changed.emit(b)
				damage_popup.emit(b, st.dot_damage, PopupKind.MAG, PackedStringArray())
			elif st.kind == CombatStatus.Kind.REGEN:
				var before := b.get_hp()
				b.set_hp(before + st.heal_per_turn)
				var healed := b.get_hp() - before
				if healed > 0:
					_log(
						tr("LOG_REGEN_TICK") % [b.display_name(), healed, tr(st.source_name)],
						LogKind.HEAL
					)
					hp_changed.emit(b)
					damage_popup.emit(b, healed, PopupKind.HEAL, PackedStringArray())
			if st.kind == CombatStatus.Kind.CHARGING:
				continue  # counts down on its bearer's own turns, not by round
			st.duration -= 1
			if st.duration <= 0:
				b.statuses.remove_at(i)
	_check_end_conditions()


# ── Skill resolution ──────────────────────────────────────────────────────────


func _apply_skill(caster: Battler, skill: SkillData, picked: Battler) -> void:
	var caster_stats := caster.effective_stats()
	# Total damage this action dealt, for the caster's Rage.
	var dealt := 0
	var targets: Array[Battler] = _gather_targets(caster, skill, picked)
	action_started.emit(caster, skill, targets)
	match skill.skill_type:
		SkillData.SkillType.BUFF:
			for t in targets:
				_apply_buff(t, skill)
			_log(tr("LOG_USE") % [caster.display_name(), tr(skill.display_name)])
		SkillData.SkillType.DEBUFF:
			for t in targets:
				_apply_debuff(t, skill)
			_log(tr("LOG_USE_EXCL") % [caster.display_name(), tr(skill.display_name)])
		SkillData.SkillType.HEAL:
			for t in targets:
				_apply_heal(caster, caster_stats, skill, t)
		SkillData.SkillType.REVIVE:
			if not targets.is_empty():
				_apply_revive(caster, skill, targets[0])
		SkillData.SkillType.MULTI:
			_log(tr("LOG_USE") % [caster.display_name(), tr(skill.display_name)])
			var hit_kind := (
				SkillData.SkillType.PHYS
				if skill.multi_hit_type == SkillData.HitType.PHYS
				else SkillData.SkillType.MAG
			)
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
				dealt += _apply_damage_hit(caster, caster_stats, skill, ht, hit_kind)
		SkillData.SkillType.PHYS, SkillData.SkillType.MAG:
			for t in targets:
				dealt += _apply_damage_hit(caster, caster_stats, skill, t, skill.skill_type)
	# Once per damaging action, however many targets or hits it had.
	# A skill may override the amount (Momentum).
	if dealt > 0:
		var rage_gain := Battler.RAGE_PER_DAMAGING_ACTION
		if skill.rage_on_action >= 0:
			rage_gain = skill.rage_on_action
		caster.gain_rage(rage_gain)
	if skill.self_untargetable:
		_apply_untargetable(caster, skill)


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


## Applies a buff skill's effects, built by the shared factory so in-combat and
## out-of-combat casting stay identical.
func _apply_buff(target: Battler, skill: SkillData) -> void:
	for st in CombatStatus.build_for_skill(skill):
		target.statuses.append(st)
		status_applied.emit(target, st)


func _apply_debuff(target: Battler, skill: SkillData) -> void:
	var st := _debuff_from(skill)
	target.statuses.append(st)
	status_applied.emit(target, st)
	_on_debuffed(target)


## The DEBUFF status a skill puts on its target: stat mods and/or a damage-taken
## multiplier, for mod_duration turns. Shared by DEBUFF skills and the rider on
## damage skills.
func _debuff_from(skill: SkillData) -> CombatStatus:
	var st := CombatStatus.new()
	st.kind = CombatStatus.Kind.DEBUFF
	st.source_name = skill.display_name
	st.mod_atk = skill.mod_atk
	st.mod_def = skill.mod_def
	st.mod_mag = skill.mod_mag
	st.mod_spd = skill.mod_spd
	st.damage_taken_mult = skill.damage_taken_mult
	st.duration = skill.mod_duration
	return st


## Shadowstep: the caster can't be picked by single-target attacks until their
## next turn. Lasts 2 round ticks so it survives the end of this round; the
## caster's next turn (or the end of the fight) removes it first.
func _apply_untargetable(caster: Battler, skill: SkillData) -> void:
	var st := CombatStatus.new()
	st.kind = CombatStatus.Kind.BUFF
	st.source_name = skill.display_name
	st.untargetable = true
	st.duration = 2
	caster.statuses.append(st)
	status_applied.emit(caster, st)


## Opportunist: a hero's passive gives it Energy whenever an enemy receives a
## debuff.
func _on_debuffed(target: Battler) -> void:
	if target.side != Battler.Side.ENEMY or not target.is_alive():
		return
	for b in _alive(party):
		var passive := Party.get_passive(b.hero)
		if passive != null:
			b.gain_energy(passive.energy_on_enemy_debuff)


## Opportunist: a crit by one hero gives every other living hero with the
## passive Energy.
func _on_crit(caster: Battler) -> void:
	if caster.side != Battler.Side.PARTY:
		return
	for b in _alive(party):
		if b == caster:
			continue
		var passive := Party.get_passive(b.hero)
		if passive != null:
			b.gain_energy(passive.energy_on_ally_crit)


func _apply_heal(
	caster: Battler, caster_stats: Dictionary, skill: SkillData, target: Battler
) -> void:
	var heal_amount := int(floor(float(caster_stats["mag"]) * skill.power + 5.0))
	target.set_hp(target.get_hp() + heal_amount)
	_log(tr("LOG_HEAL") % [caster.display_name(), target.display_name(), heal_amount], LogKind.HEAL)
	hp_changed.emit(target)
	damage_popup.emit(target, heal_amount, PopupKind.HEAL, PackedStringArray())
	_apply_regen(target, skill)


## Attaches a heal-over-time status when the skill carries one. Mirrors the DoT
## rider; ticked at round end by _tick_statuses.
func _apply_regen(target: Battler, skill: SkillData) -> void:
	if skill.heal_over_time <= 0 or skill.hot_duration <= 0:
		return
	var st := CombatStatus.new()
	st.kind = CombatStatus.Kind.REGEN
	st.source_name = skill.display_name
	st.heal_per_turn = skill.heal_over_time
	st.duration = skill.hot_duration
	target.statuses.append(st)
	status_applied.emit(target, st)


## Revives a fallen ally at `skill.power` of their max HP. Reading the fraction
## from power (rather than the old hardcoded 30%) is what makes Revive's SP
## upgrade tiers meaningful — get_upgraded_skill scales power, so each tier
## brings the ally back with more HP. Clamped so it can never exceed full.
func _apply_revive(caster: Battler, skill: SkillData, target: Battler) -> void:
	var frac := clampf(skill.power, 0.05, 1.0)
	var amount := maxi(1, int(floor(target.max_hp * frac)))
	target.set_hp(amount)
	_log(tr("LOG_REVIVE") % [caster.display_name(), target.display_name()], LogKind.HEAL)
	hp_changed.emit(target)
	damage_popup.emit(target, amount, PopupKind.HEAL, PackedStringArray())


func _apply_damage_hit(
	caster: Battler,
	caster_stats: Dictionary,
	skill: SkillData,
	target: Battler,
	dmg_kind: SkillData.SkillType
) -> int:
	# Barrier eats the hit before damage is rolled (and gives no Rage).
	if target.consume_barrier():
		_log(tr("LOG_BARRIER") % target.display_name(), LogKind.BARRIER)
		return 0
	# is_mag decides how the hit resolves against DEF; damage_stat decides which
	# caster stat scales it. They're independent so a physically-resolved skill
	# can scale off MAG (Conjurer's "physical spells").
	var is_mag := dmg_kind == SkillData.SkillType.MAG
	var use_mag := is_mag
	match skill.damage_stat:
		SkillData.DamageStat.ATK:
			use_mag = false
		SkillData.DamageStat.MAG:
			use_mag = true
	var raw_attack := float(caster_stats["mag"] if use_mag else caster_stats["atk"])
	var raw := raw_attack * skill.power + randf_range(0.0, 3.0)
	# Finisher: double power when target is under 25% HP.
	if skill.finisher and target.get_hp() <= int(target.max_hp * 0.25):
		raw *= 2.0
	var tags := PackedStringArray()
	# Ambush always crits a target that hasn't acted yet this round; otherwise
	# the skill's chance, plus the caster's passive bonus (Assassin's Focus).
	var crit_chance := skill.crit_chance + caster.passive_crit_bonus(target)
	var ambushed := skill.ambush and not acted_this_round.has(target)
	if ambushed or (crit_chance > 0.0 and randf() < crit_chance):
		raw *= 1.8
		tags.append("crit")
		_on_crit(caster)
	# Synergy: a bonus against a target whose DEF is debuffed (Backstab).
	if skill.bonus_vs_def_debuff > 0.0 and target.has_def_debuff():
		raw *= 1.0 + skill.bonus_vs_def_debuff
		tags.append("exposed")
	# The caster's passive (Bloodlust: more damage the more Rage it holds).
	raw *= caster.passive_damage_mult()
	var t_stats := target.effective_stats()
	# Magic damage uses 40% of DEF; physical uses full DEF.
	var t_def := int(floor(float(t_stats["def"]) * 0.4)) if is_mag else int(t_stats["def"])
	# A marked target (Mark for Death) takes more from every source.
	var dmg := maxi(1, int(floor((raw - t_def) * target.damage_taken_mult())))
	# The target's reaction (Parry, Dodge): by chance, pay its cost to cut the
	# damage. A reaction that leaves some damage never cuts it below 1.
	var reaction := target.reaction_for(skill, dmg_kind)
	if reaction != null and randf() < reaction.chance:
		target.spend_resource(reaction.cost)
		dmg = int(floor(dmg * reaction.damage_mult))
		if reaction.damage_mult > 0.0:
			dmg = maxi(1, dmg)
		tags.append(reaction.popup_tag)
	target.set_hp(target.get_hp() - dmg)
	# Rage comes from hits that hurt; a dodged hit gives none.
	if dmg > 0:
		target.gain_rage(target.rage_per_hit_taken())
	hp_changed.emit(target)
	damage_popup.emit(target, dmg, PopupKind.MAG if is_mag else PopupKind.PHYS, tags)
	var crit := tags.has("crit")
	_log(
		(
			tr("LOG_DAMAGE")
			% [
				caster.display_name(),
				tr(skill.display_name),
				target.display_name(),
				dmg,
				_log_suffix(tags)
			]
		),
		LogKind.CRIT if crit else LogKind.DAMAGE
	)
	# DoT rider (prototype adds unconditionally — dead targets simply won't tick).
	if skill.dot_damage > 0:
		var dot := CombatStatus.new()
		dot.kind = CombatStatus.Kind.DOT
		dot.source_name = skill.display_name
		dot.dot_damage = skill.dot_damage
		dot.dot_popup_key = skill.dot_popup_key
		dot.duration = skill.dot_duration
		target.statuses.append(dot)
		status_applied.emit(target, dot)
	# Debuff rider on damage skills.
	if (
		skill.mod_duration > 0
		and (
			skill.mod_atk != 0
			or skill.mod_def != 0
			or skill.mod_mag != 0
			or skill.mod_spd != 0
			or skill.damage_taken_mult != 1.0
		)
	):
		var deb := _debuff_from(skill)
		target.statuses.append(deb)
		status_applied.emit(target, deb)
		_on_debuffed(target)
	# Drain: caster heals for 50% of damage dealt.
	if skill.drain:
		var healed := int(floor(dmg * 0.5))
		caster.set_hp(caster.get_hp() + healed)
		hp_changed.emit(caster)
		damage_popup.emit(caster, healed, PopupKind.HEAL, PackedStringArray())
	return dmg


## The damage log line's ending for a hit's popup tags: " (CRITICAL)",
## " (EXPOSED)", " (PARRIED)", " (DODGED)", or several of them.
func _log_suffix(tags: PackedStringArray) -> String:
	var suffix := ""
	if tags.has("crit"):
		suffix += tr("LOG_CRIT_SUFFIX")
	if tags.has("exposed"):
		suffix += tr("LOG_EXPOSED_SUFFIX")
	if tags.has("parried"):
		suffix += tr("LOG_PARRIED_SUFFIX")
	if tags.has("dodged"):
		suffix += tr("LOG_DODGED_SUFFIX")
	return suffix


# ── Enemy AI ──────────────────────────────────────────────────────────────────
# An enemy's EnemyData.ai_role decides which skill it prefers and whom it aims
# at; the pick inside that preference stays random (no lookahead). Taunt
# overrides hostile targeting for every role.


## True for the stand-in skill action_started carries on a wind-up turn, so the
## UI words the banner "X is winding up Y" instead of "X — Y".
static func is_wind_up(skill: SkillData) -> bool:
	return skill.id == WIND_UP_ID


func _enemy_take_turn() -> void:
	var e := current_actor
	var charge := e.charge_status()
	if charge != null:
		_continue_wind_up(e, charge)
		return
	var skill := _choose_enemy_skill(e)
	if skill == null:
		return
	var picked := _pick_enemy_target(e, skill)
	if skill.telegraph_turns > 0:
		_begin_wind_up(e, skill, picked)
		return
	_enemy_use(e, skill, picked)


## The skill the enemy uses this turn: a use_condition filter, then the role's
## preference, then a random pick.
func _choose_enemy_skill(e: Battler) -> SkillData:
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
		return null
	match data.ai_role:
		EnemyData.AiRole.CASTER:
			return _caster_skill(usable)
		EnemyData.AiRole.SUPPORT:
			return _support_skill(e, usable)
	return _random_skill(usable)


## CASTER: area damage when 3+ heroes stand, otherwise a debuff or a damaging
## spell.
func _caster_skill(usable: Array[SkillData]) -> SkillData:
	var area := _skills_where(
		usable, func(sk): return sk.target == SkillData.TargetType.ALL and _is_offensive(sk)
	)
	if _alive(party).size() >= 3 and not area.is_empty():
		return _random_skill(area)
	var debuffs := _skills_where(usable, _is_debuff)
	if not debuffs.is_empty() and randf() < CASTER_DEBUFF_CHANCE:
		return _random_skill(debuffs)
	var damage := _skills_where(usable, _is_offensive)
	return _random_skill(damage if not damage.is_empty() else usable)


## SUPPORT: heal a hurt ally, else buff one that lacks the buff, else attack.
func _support_skill(e: Battler, usable: Array[SkillData]) -> SkillData:
	var heals := _skills_where(usable, func(sk): return _heal_is_useful(e, sk))
	if not heals.is_empty():
		return _random_skill(heals)
	var buffs := _skills_where(usable, func(sk): return _buff_is_useful(e, sk))
	if not buffs.is_empty():
		return _random_skill(buffs)
	var attacks := _skills_where(usable, _is_offensive)
	return _random_skill(attacks if not attacks.is_empty() else usable)


func _heal_is_useful(e: Battler, sk: SkillData) -> bool:
	if sk.skill_type != SkillData.SkillType.HEAL:
		return false
	match sk.target:
		SkillData.TargetType.SELF:
			return e.hp_fraction() < SUPPORT_HEAL_BELOW
		SkillData.TargetType.ALLY, SkillData.TargetType.ALLIES:
			return _hurt_ally() != null
	return false


func _buff_is_useful(e: Battler, sk: SkillData) -> bool:
	if sk.skill_type != SkillData.SkillType.BUFF:
		return false
	match sk.target:
		SkillData.TargetType.SELF:
			return not _has_status_from(e, sk)
		SkillData.TargetType.ALLY, SkillData.TargetType.ALLIES:
			return _unbuffed_ally(sk) != null
	return false


## The living enemy with the lowest HP share, if it is under the heal threshold.
func _hurt_ally() -> Battler:
	var worst: Battler = null
	for b in _alive(enemies):
		if b.hp_fraction() >= SUPPORT_HEAL_BELOW:
			continue
		if worst == null or b.hp_fraction() < worst.hp_fraction():
			worst = b
	return worst


## A living enemy that doesn't carry a status from `sk` yet.
func _unbuffed_ally(sk: SkillData) -> Battler:
	for b in _alive(enemies):
		if not _has_status_from(b, sk):
			return b
	return null


func _has_status_from(b: Battler, sk: SkillData) -> bool:
	for st in b.statuses:
		if st.source_name == sk.display_name:
			return true
	return false


## Anything aimed at the other side (damage, debuffs); heals, buffs and revives
## are friendly.
func _is_offensive(sk: SkillData) -> bool:
	match sk.skill_type:
		SkillData.SkillType.HEAL, SkillData.SkillType.BUFF, SkillData.SkillType.REVIVE:
			return false
	return true


## An offensive skill that lowers a stat, alone or as a rider on damage.
func _is_debuff(sk: SkillData) -> bool:
	if not _is_offensive(sk) or sk.mod_duration <= 0:
		return false
	return sk.mod_atk < 0 or sk.mod_def < 0 or sk.mod_mag < 0 or sk.mod_spd < 0


func _skills_where(list: Array[SkillData], test: Callable) -> Array[SkillData]:
	var out: Array[SkillData] = []
	for sk in list:
		if test.call(sk):
			out.append(sk)
	return out


func _random_skill(list: Array[SkillData]) -> SkillData:
	return list[randi() % list.size()]


## Who the skill is aimed at (null for skills that auto-target).
func _pick_enemy_target(e: Battler, skill: SkillData) -> Battler:
	match skill.target:
		SkillData.TargetType.ONE:
			return _pick_hero_target(e)
		SkillData.TargetType.ALLY:
			if skill.skill_type == SkillData.SkillType.HEAL:
				return _hurt_ally()
			return _unbuffed_ally(skill)
	return null


## A hero to hit: a taunter if any, else the lowest-HP% hero for a SKIRMISHER,
## else a random front-row hero (any hero if the front row is gone). A hero a
## single-target attack can't pick (Shadowstep) is left out; with nobody left to
## hit the enemy has no target.
func _pick_hero_target(e: Battler) -> Battler:
	var alive_party: Array[Battler] = []
	for b in _alive(party):
		if not b.is_untargetable():
			alive_party.append(b)
	if alive_party.is_empty():
		return null
	var taunters: Array[Battler] = []
	for b in alive_party:
		if b.has_taunt():
			taunters.append(b)
	var pool: Array[Battler] = []
	if not taunters.is_empty():
		pool = taunters
	elif e.enemy_data.ai_role == EnemyData.AiRole.SKIRMISHER:
		var lowest := 2.0
		for b in alive_party:
			lowest = minf(lowest, b.hp_fraction())
		for b in alive_party:
			if is_equal_approx(b.hp_fraction(), lowest):
				pool.append(b)
	else:
		for b in alive_party:
			if b.is_front_row():
				pool.append(b)
		if pool.is_empty():
			pool = alive_party
	return pool[randi() % pool.size()]


## Resolves the skill now: self skills here, everything else through
## _apply_skill.
func _enemy_use(e: Battler, skill: SkillData, picked: Battler) -> void:
	# Self-targeting skills (self-buff, regen).
	if skill.target == SkillData.TargetType.SELF:
		var self_target: Array[Battler] = [e]
		action_started.emit(e, skill, self_target)
		if skill.skill_type == SkillData.SkillType.BUFF:
			_apply_buff(e, skill)
			_log(tr("LOG_USE") % [e.display_name(), tr(skill.display_name)])
		elif skill.skill_type == SkillData.SkillType.HEAL:
			var e_stats := e.effective_stats()
			var mag_val := int(e_stats["mag"])
			if mag_val <= 0:
				mag_val = int(e_stats["atk"])
			var heal_amount := int(floor(mag_val * skill.power + 5.0))
			e.set_hp(e.get_hp() + heal_amount)
			_log(tr("LOG_REGEN") % [e.display_name(), heal_amount], LogKind.HEAL)
			hp_changed.emit(e)
			damage_popup.emit(e, heal_amount, PopupKind.HEAL, PackedStringArray())
		return
	_apply_skill(e, skill, picked)


# ── Telegraphed skills ────────────────────────────────────────────────────────


## The enemy spends this turn winding up `skill`: a Charging status that
## remembers the skill and its target, and a banner naming the threat.
func _begin_wind_up(e: Battler, skill: SkillData, picked: Battler) -> void:
	var st := CombatStatus.new()
	st.kind = CombatStatus.Kind.CHARGING
	st.source_name = skill.display_name
	st.duration = skill.telegraph_turns  # wind-up turns left, see _continue_wind_up
	st.charge_skill = skill
	st.charge_target = picked
	e.statuses.append(st)
	_announce_wind_up(e, skill, picked)
	status_applied.emit(e, st)


func _announce_wind_up(e: Battler, skill: SkillData, picked: Battler) -> void:
	var stand_in := skill.duplicate() as SkillData
	stand_in.id = WIND_UP_ID
	action_started.emit(e, stand_in, _gather_targets(e, skill, picked))
	_log(tr("UI_TELEGRAPH") % [e.display_name(), tr(skill.display_name)])


## The enemy's turn while Charging: keep winding up if the telegraph is longer
## than one turn, else the skill lands. A single-target skill hits the same
## target if still standing, else a freshly picked one. Taunt still overrides
## it: if a hero taunted during the wind-up, the hit goes to a taunter instead
## (Provoke is one of the answers to a telegraph). Area skills are unaffected.
func _continue_wind_up(e: Battler, st: CombatStatus) -> void:
	var skill := st.charge_skill
	if skill == null:
		e.statuses.erase(st)  # a reloaded status carries no skill
		return
	st.duration -= 1
	if st.duration > 0:
		_announce_wind_up(e, skill, st.charge_target)
		return
	e.statuses.erase(st)
	var picked := st.charge_target
	if (
		(skill.target == SkillData.TargetType.ONE or skill.target == SkillData.TargetType.ALLY)
		and (picked == null or not picked.is_alive())
	):
		picked = _pick_enemy_target(e, skill)
	elif (
		skill.target == SkillData.TargetType.ONE
		and (picked.is_untargetable() or _taunter_overrides(picked))
	):
		picked = _pick_enemy_target(e, skill)
	_enemy_use(e, skill, picked)


## True when some living hero taunts and `picked` isn't one of them, so a
## single-target hit aimed at `picked` should go to a taunter instead.
func _taunter_overrides(picked: Battler) -> bool:
	if picked != null and picked.has_taunt():
		return false
	for b in _alive(party):
		if b.has_taunt():
			return true
	return false


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


func _log(msg: String, kind: LogKind = LogKind.INFO) -> void:
	log_lines.append(msg)
	log_appended.emit(msg, kind)
