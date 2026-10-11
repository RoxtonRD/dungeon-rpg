## Warrior slice 3/3 (#62): the Bloodlust passive, the Parry reaction and its
## toggle, the Backstab bonus against a DEF debuff, passives and reactions in
## the SP pool and the save, and DevTools.swap_skill.
##
## Fights are built directly with CombatState.build against practice dummies,
## and turns are driven by hand (like talents_test.gd). Where two hits must be
## compared, the RNG is seeded the same before each, so both roll the same.
## Parry's chance is fixed at 1.0 for the tests and restored after.
extends GdUnitTestSuite

const WARRIOR := "res://resources/classes/warrior.tres"
const ROGUE := "res://resources/classes/rogue.tres"
const CLERIC := "res://resources/classes/cleric.tres"
const SLASH := "res://resources/skills/warrior_slash.tres"
const CLEAVE := "res://resources/skills/warrior_cleave.tres"
const BACKSTAB := "res://resources/skills/rogue_backstab.tres"
const STAB := "res://resources/skills/rogue_stab.tres"
const BLOODLUST := "res://resources/passives/warrior_bloodlust.tres"
const PARRY := "res://resources/reactions/warrior_parry.tres"

var _warrior_class: ClassData
var _bloodlust: PassiveData
var _parry: ReactionData
var _parry_chance: float
var _warrior_skills: Array[SkillData]


func before_test() -> void:
	_warrior_class = load(WARRIOR)
	_bloodlust = load(BLOODLUST)
	_parry = load(PARRY)
	_parry_chance = _parry.chance
	_parry.chance = 1.0
	_warrior_skills = _warrior_class.skills.duplicate()


func after_test() -> void:
	_parry.chance = _parry_chance
	_warrior_class.skills = _warrior_skills


# ── Data ──────────────────────────────────────────────────────────────────────


func test_warrior_has_bloodlust_and_parry() -> void:
	assert_array(_warrior_class.passives).contains_exactly([_bloodlust])
	assert_array(_warrior_class.reactions).contains_exactly([_parry])
	assert_int(_bloodlust.unlock_level).is_equal(2)
	assert_int(_parry.unlock_level).is_equal(3)
	assert_float(_parry_chance).is_equal_approx(0.2, 0.001)
	assert_int(_parry.rage_cost).is_equal(10)
	assert_float(_parry.damage_mult).is_equal_approx(0.5, 0.001)


# ── Bloodlust ─────────────────────────────────────────────────────────────────


func test_bloodlust_multiplier_by_rage() -> void:
	assert_float(_bloodlust.damage_mult(0)).is_equal_approx(1.0, 0.0001)
	assert_float(_bloodlust.damage_mult(9)).is_equal_approx(1.0, 0.0001)
	assert_float(_bloodlust.damage_mult(50)).is_equal_approx(1.1, 0.0001)
	assert_float(_bloodlust.damage_mult(55)).is_equal_approx(1.1, 0.0001)
	assert_float(_bloodlust.damage_mult(100)).is_equal_approx(1.2, 0.0001)


func test_bloodlust_scales_damage_at_0_50_100_rage() -> void:
	for rage in [0, 50, 100]:
		var st := _fight([_warrior_hero(10)], [_dummy()])
		var w := st.party[0]
		w.hero.talents[Party.PASSIVE_KEY] = "bloodlust"
		w.rage = rage
		assert_float(w.passive_damage_mult()).is_equal_approx(1.0 + rage / 500.0, 0.0001)
		var hits := _record_hits(st)
		# Slash: no cost, no crit roll, so the damage roll is the first randf.
		seed(1234)
		var raw := float(w.effective_stats()["atk"]) * 1.0 + randf_range(0.0, 3.0)
		seed(1234)
		_act(st, w, load(SLASH), st.enemies[0])
		var expected := int(floor(raw * (1.0 + rage / 500.0)))
		assert_int(hits[0]["amount"]).override_failure_message("rage %d" % rage).is_equal(expected)


func test_no_passive_no_bonus() -> void:
	var st := _fight([_warrior_hero(10)], [_dummy()])
	st.party[0].rage = 100
	assert_float(st.party[0].passive_damage_mult()).is_equal(1.0)
	assert_float(st.enemies[0].passive_damage_mult()).is_equal(1.0)


# ── Parry ─────────────────────────────────────────────────────────────────────


func test_parry_halves_damage_and_spends_rage() -> void:
	var plain := _parry_fight(_dummy(40), false)
	plain.party[0].rage = 10
	var plain_hits := _record_hits(plain)
	seed(99)
	_enemy_turn(plain)

	var parried := _parry_fight(_dummy(40), true)
	parried.party[0].rage = 10
	var hits := _record_hits(parried)
	seed(99)
	_enemy_turn(parried)

	var full: int = plain_hits[0]["amount"]
	assert_int(full).is_greater(10)
	assert_bool(plain_hits[0]["tags"].has("parried")).is_false()
	assert_int(hits[0]["amount"]).is_equal(int(floor(full * 0.5)))
	assert_bool(hits[0]["tags"].has("parried")).is_true()
	# Spent 10, then still gained Rage from the (reduced) hit.
	assert_int(parried.party[0].rage).is_equal(10 - 10 + Battler.RAGE_PER_HIT_TAKEN)
	assert_int(plain.party[0].rage).is_equal(10 + Battler.RAGE_PER_HIT_TAKEN)


func test_parry_needs_10_rage() -> void:
	var st := _parry_fight(_dummy(40), true)
	st.party[0].rage = 9
	var hits := _record_hits(st)
	_enemy_turn(st)
	assert_bool(hits[0]["tags"].has("parried")).is_false()
	assert_int(st.party[0].rage).is_equal(9 + Battler.RAGE_PER_HIT_TAKEN)


func test_parry_ignores_area_hits() -> void:
	var st := _parry_fight(_dummy(40, SkillData.TargetType.ALL), true)
	st.party[0].rage = 50
	var hits := _record_hits(st)
	_enemy_turn(st)
	assert_bool(hits[0]["tags"].has("parried")).is_false()
	assert_int(st.party[0].rage).is_equal(50 + Battler.RAGE_PER_HIT_TAKEN)


func test_parry_ignores_magic_hits() -> void:
	var dummy := _dummy(40, SkillData.TargetType.ONE, SkillData.SkillType.MAG)
	dummy.mag = 40
	var st := _parry_fight(dummy, true)
	st.party[0].rage = 50
	var hits := _record_hits(st)
	_enemy_turn(st)
	assert_bool(hits[0]["tags"].has("parried")).is_false()
	assert_int(st.party[0].rage).is_equal(50 + Battler.RAGE_PER_HIT_TAKEN)


func test_parry_toggled_off_does_not_trigger() -> void:
	var st := _parry_fight(_dummy(40), true)
	var h := st.party[0].hero
	assert_bool(Party.set_reaction_enabled(h, false)).is_true()
	assert_object(Party.get_active_reaction(h)).is_null()
	assert_object(Party.get_reaction(h)).is_same(_parry)  # still learned
	st.party[0].rage = 50
	var hits := _record_hits(st)
	_enemy_turn(st)
	assert_bool(hits[0]["tags"].has("parried")).is_false()
	assert_int(st.party[0].rage).is_equal(50 + Battler.RAGE_PER_HIT_TAKEN)
	# Back on, it triggers again.
	Party.set_reaction_enabled(h, true)
	_enemy_turn(st)
	assert_bool(hits[1]["tags"].has("parried")).is_true()


func test_enemies_never_parry() -> void:
	var st := _fight([_warrior_hero(10)], [_dummy()])
	assert_object(st.enemies[0].reaction_for(load(SLASH), SkillData.SkillType.PHYS)).is_null()


# ── Backstab synergy ──────────────────────────────────────────────────────────


func test_backstab_has_the_bonus() -> void:
	assert_float((load(BACKSTAB) as SkillData).bonus_vs_def_debuff).is_equal_approx(0.5, 0.001)


func test_backstab_bonus_only_against_a_def_debuff() -> void:
	var plain := _backstab_damage(null)
	var exposed := _backstab_damage(_debuff(-3, 0))
	assert_bool(plain["tags"].has("exposed")).is_false()
	assert_bool(exposed["tags"].has("exposed")).is_true()
	# Same roll, the dummy has no DEF: exposed = floor(raw * 1.5), plain = floor(raw).
	var base: int = plain["amount"]
	assert_int(exposed["amount"]).is_between(int(floor(base * 1.5)), int(floor((base + 1) * 1.5)))


func test_backstab_ignores_a_debuff_that_is_not_def() -> void:
	var hit := _backstab_damage(_debuff(0, -3))
	assert_bool(hit["tags"].has("exposed")).is_false()


func test_other_skills_get_no_bonus() -> void:
	var st := _fight([_rogue_hero()], [_dummy()])
	st.enemies[0].statuses.append(_debuff(-3, 0))
	var hits := _record_hits(st)
	_act(st, st.party[0], load(STAB), st.enemies[0])
	assert_bool(hits[0]["tags"].has("exposed")).is_false()


func test_wide_arc_sets_up_backstab() -> void:
	var st := _fight([_warrior_hero(1), _rogue_hero()], [_dummy()])
	var w := st.party[0]
	w.hero.talents["warrior_cleave"] = {"fork": "a", "boost": false}  # Wide Arc
	w.rage = 100
	_act(st, w, load(CLEAVE), null)
	assert_bool(st.enemies[0].has_def_debuff()).is_true()
	var hits := _record_hits(st)
	_act(st, st.party[1], load(BACKSTAB), st.enemies[0])
	assert_bool(hits[0]["tags"].has("exposed")).is_true()


# ── SP cost and permanence ────────────────────────────────────────────────────


func test_passive_costs_one_sp_and_is_permanent() -> void:
	var h := _warrior_hero(1)
	h.sp_available = 2
	assert_bool(Party.can_pick_passive(h, _bloodlust)).is_false()  # unlocks at 2
	h.level = 2
	assert_bool(Party.pick_passive(h, _bloodlust)).is_true()
	assert_int(h.sp_available).is_equal(1)
	assert_object(Party.get_passive(h)).is_same(_bloodlust)
	assert_str(h.talents[Party.PASSIVE_KEY]).is_equal("bloodlust")
	assert_bool(Party.can_pick_passive(h, _bloodlust)).is_false()  # permanent
	assert_bool(Party.pick_passive(h, _bloodlust)).is_false()
	assert_int(h.sp_available).is_equal(1)


func test_passive_needs_sp() -> void:
	var h := _warrior_hero(2)
	h.sp_available = 0
	assert_bool(Party.pick_passive(h, _bloodlust)).is_false()
	assert_object(Party.get_passive(h)).is_null()


func test_reaction_costs_one_sp_is_permanent_and_toggles_free() -> void:
	var h := _warrior_hero(2)
	h.sp_available = 2
	assert_bool(Party.can_learn_reaction(h, _parry)).is_false()  # unlocks at 3
	assert_bool(Party.set_reaction_enabled(h, true)).is_false()  # nothing learned
	h.level = 3
	assert_bool(Party.learn_reaction(h, _parry)).is_true()
	assert_int(h.sp_available).is_equal(1)
	assert_object(Party.get_active_reaction(h)).is_same(_parry)  # learned switched on
	assert_bool(Party.learn_reaction(h, _parry)).is_false()  # permanent
	Party.set_reaction_enabled(h, false)
	Party.set_reaction_enabled(h, true)
	assert_int(h.sp_available).is_equal(1)  # toggling is free


func test_other_classes_cannot_take_warrior_options() -> void:
	var cleric := Hero.create(load(CLERIC))
	cleric.level = 10
	cleric.sp_available = 5
	assert_bool(Party.can_pick_passive(cleric, _bloodlust)).is_false()
	assert_bool(Party.can_learn_reaction(cleric, _parry)).is_false()


func test_sp_in_talents_counts_passive_and_reaction() -> void:
	var h := _warrior_hero(10)
	h.sp_available = 5
	Party.pick_fork(h, load(SLASH), "a")
	Party.boost_skill(h, load(SLASH))
	Party.pick_passive(h, _bloodlust)
	Party.learn_reaction(h, _parry)
	assert_int(Party.sp_in_talents(h)).is_equal(4)
	assert_int(h.sp_available).is_equal(1)


# ── Save ──────────────────────────────────────────────────────────────────────


func test_passive_and_reaction_round_trip_through_json() -> void:
	var h := _warrior_hero(6)
	h.sp_available = 0
	h.talents = {
		"warrior_slash": {"fork": "b", "boost": false},
		Party.PASSIVE_KEY: "bloodlust",
		Party.REACTION_KEY: {"id": "parry", "enabled": false},
	}
	var back := Hero.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	assert_dict(back.talents).is_equal(h.talents)
	assert_object(Party.get_passive(back)).is_same(_bloodlust)
	assert_object(Party.get_reaction(back)).is_same(_parry)
	assert_bool(Party.is_reaction_enabled(back)).is_false()
	assert_int(Party.sp_in_talents(back)).is_equal(3)


# ── DevTools ──────────────────────────────────────────────────────────────────


func test_swap_skill_is_runtime_only() -> void:
	var h := _warrior_hero(5)
	var before := JSON.stringify(h.to_dict())
	var tres_md5 := FileAccess.get_md5(WARRIOR)
	var save_md5 := FileAccess.get_md5(GameState.save_path)
	var msg := DevTools.swap_skill("warrior", 0, "rogue_backstab")
	assert_bool(msg.begins_with("Error")).override_failure_message(msg).is_false()
	# Heroes share the cached class, so they all see the swap at once.
	assert_object(h.class_data.skills[0]).is_same(load(BACKSTAB))
	assert_object((load(WARRIOR) as ClassData).skills[0]).is_same(load(BACKSTAB))
	# Nothing that is saved changed: not the hero, the save, or the class file.
	assert_str(JSON.stringify(h.to_dict())).is_equal(before)
	assert_str(FileAccess.get_md5(GameState.save_path)).is_equal(save_md5)
	assert_str(FileAccess.get_md5(WARRIOR)).is_equal(tres_md5)
	# Swapping back restores it.
	DevTools.swap_skill("warrior", 0, "warrior_slash")
	assert_object(h.class_data.skills[0]).is_same(load(SLASH))


func test_swap_skill_rejects_bad_input() -> void:
	assert_str(DevTools.swap_skill("paladin", 0, "rogue_backstab")).starts_with("Error")
	assert_str(DevTools.swap_skill("warrior", 4, "rogue_backstab")).starts_with("Error")
	assert_str(DevTools.swap_skill("warrior", 0, "no_such_skill")).starts_with("Error")
	assert_object(_warrior_class.skills[0]).is_same(load(SLASH))


# ── Helpers ───────────────────────────────────────────────────────────────────


func _warrior_hero(level: int) -> Hero:
	var h := Hero.create(_warrior_class)
	h.level = level
	h.hp = h.max_hp()
	return h


func _rogue_hero() -> Hero:
	return Hero.create(load(ROGUE))


func _fight(heroes: Array, enemies: Array) -> CombatState:
	var typed_heroes: Array[Hero] = []
	typed_heroes.assign(heroes)
	var typed_enemies: Array[EnemyData] = []
	typed_enemies.assign(enemies)
	return CombatState.build(typed_heroes, typed_enemies)


## A level-3 Warrior who has learned Parry (on or off) against one dummy.
func _parry_fight(dummy: EnemyData, parry_on: bool) -> CombatState:
	var st := _fight([_warrior_hero(3)], [dummy])
	st.party[0].hero.talents[Party.REACTION_KEY] = {"id": "parry", "enabled": parry_on}
	return st


## A practice dummy with lots of HP and no DEF. Its only skill hits with power
## 1.0 off `atk` (a weak 1-ATK tap by default).
func _dummy(
	atk: int = 1,
	target := SkillData.TargetType.ONE,
	kind := SkillData.SkillType.PHYS,
) -> EnemyData:
	var hit := SkillData.new()
	hit.id = "dummy_hit"
	hit.display_name = "dummy_hit"
	hit.skill_type = kind
	hit.target = target
	hit.power = 1.0
	var e := EnemyData.new()
	e.id = "dummy"
	e.display_name = "dummy"
	e.max_hp = 99999
	e.atk = atk
	e.skills = [hit] as Array[SkillData]
	return e


func _debuff(def_mod: int, atk_mod: int) -> CombatStatus:
	var st := CombatStatus.new()
	st.kind = CombatStatus.Kind.DEBUFF
	st.mod_def = def_mod
	st.mod_atk = atk_mod
	st.duration = 5
	return st


## Every damage popup as {amount, tags}, in order (heals and DoTs included).
func _record_hits(st: CombatState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	st.damage_popup.connect(
		func(_b: Battler, amount: int, _k: CombatState.PopupKind, tags: PackedStringArray):
			out.append({"amount": amount, "tags": tags})
	)
	return out


## A level-1 Rogue Backstabs a dummy that carries `status` (or nothing), with a
## fixed seed. Returns that hit's {amount, tags}.
func _backstab_damage(status: CombatStatus) -> Dictionary:
	var st := _fight([_rogue_hero()], [_dummy()])
	if status != null:
		st.enemies[0].statuses.append(status)
	var hits := _record_hits(st)
	seed(4242)
	_act(st, st.party[0], load(BACKSTAB), st.enemies[0])
	return hits[0]


## `actor` uses `skill` now, whoever's turn it was.
func _act(st: CombatState, actor: Battler, skill: SkillData, target: Battler) -> void:
	st.current_actor = actor
	st.player_action(skill, target)


## The dummy takes a turn; the Warrior is its only target.
func _enemy_turn(st: CombatState) -> void:
	st.current_actor = st.enemies[0]
	st.step()
