## Warrior talents (#47): the talent-class SP rules, forks and boosts, the
## effective-skill resolution, the four new combat mechanics (Momentum,
## Vengeance, Reaper, Sunder), and talents in the save.
##
## Fights are built directly with CombatState.build against practice dummies,
## and turns are driven by hand (like combat_rage_test.gd). Nothing here saves
## the game: level-up skins are pre-owned so unlock_skin never fires a save.
extends GdUnitTestSuite

const WARRIOR := "res://resources/classes/warrior.tres"
const CLERIC := "res://resources/classes/cleric.tres"
const SLASH := "res://resources/skills/warrior_slash.tres"
const CLEAVE := "res://resources/skills/warrior_cleave.tres"
const PROVOKE := "res://resources/skills/warrior_provoke.tres"
const EXECUTE := "res://resources/skills/warrior_execute.tres"

var _slash: SkillData
var _cleave: SkillData
var _provoke: SkillData
var _execute: SkillData
var _owned_skins: Array


func before_test() -> void:
	_slash = load(SLASH)
	_cleave = load(CLEAVE)
	_provoke = load(PROVOKE)
	_execute = load(EXECUTE)
	_owned_skins = GameState.owned_skins.duplicate()


func after_test() -> void:
	GameState.owned_skins.assign(_owned_skins)


# ── Skill Points ──────────────────────────────────────────────────────────────


func test_talent_sp_by_level() -> void:
	var got: Array[int] = []
	for level in range(1, Party.LEVEL_CAP + 1):
		got.append(Party.talent_sp_for_level(level))
	assert_array(got).is_equal([0, 1, 1, 2, 2, 3, 3, 4, 4, 5])


func test_new_warrior_starts_with_no_sp() -> void:
	assert_int(_warrior_hero(1).sp_available).is_equal(0)


func test_level_ups_give_sp_on_even_levels_only() -> void:
	_own_level_skins()
	var h := _warrior_hero(1)
	var got: Array[int] = []
	while h.level < Party.LEVEL_CAP:
		Party.level_up(h)
		got.append(h.sp_available)
	assert_array(got).is_equal([1, 1, 2, 2, 3, 3, 4, 4, 5])


func test_mana_class_keeps_one_sp_per_level() -> void:
	_own_level_skins()
	var h := Hero.create(load(CLERIC))
	assert_int(h.sp_available).is_equal(1)
	Party.level_up(h)
	assert_int(h.sp_available).is_equal(2)


func test_talent_sp_never_converts_to_mp() -> void:
	var h := _warrior_hero(10)
	h.sp_available = 0
	assert_int(Party.award_sp(h, 1)).is_equal(0)  # the Tome of Mastery path
	assert_int(h.sp_available).is_equal(1)
	assert_int(Party.reconcile_surplus_sp(h)).is_equal(0)
	assert_int(h.sp_available).is_equal(1)
	assert_int(h.bonus_mp).is_equal(0)


# ── Forks and boosts ──────────────────────────────────────────────────────────


func test_fork_costs_one_sp() -> void:
	var h := _warrior_hero(1)
	assert_bool(Party.can_pick_fork(h, _slash, "a")).is_false()  # no SP
	h.sp_available = 1
	assert_bool(Party.pick_fork(h, _slash, "a")).is_true()
	assert_int(h.sp_available).is_equal(0)
	assert_dict(Party.get_talent(h, _slash)).is_equal({"fork": "a", "boost": false})


func test_fork_needs_the_unlock_level() -> void:
	var h := _warrior_hero(2)
	h.sp_available = 5
	assert_bool(Party.can_pick_fork(h, _provoke, "a")).is_false()  # unlocks at 3
	h.level = 3
	assert_bool(Party.can_pick_fork(h, _provoke, "a")).is_true()
	assert_bool(Party.can_pick_fork(h, _execute, "b")).is_false()  # unlocks at 5


func test_fork_is_permanent() -> void:
	var h := _warrior_hero(1)
	h.sp_available = 2
	Party.pick_fork(h, _slash, "a")
	assert_bool(Party.can_pick_fork(h, _slash, "b")).is_false()
	assert_bool(Party.pick_fork(h, _slash, "b")).is_false()
	assert_str(Party.get_talent(h, _slash)["fork"]).is_equal("a")
	assert_int(h.sp_available).is_equal(1)


func test_fork_must_be_a_or_b() -> void:
	var h := _warrior_hero(1)
	h.sp_available = 1
	assert_bool(Party.can_pick_fork(h, _slash, "c")).is_false()


func test_boost_needs_a_fork_and_one_sp() -> void:
	var h := _warrior_hero(1)
	h.sp_available = 3
	assert_bool(Party.can_boost(h, _cleave)).is_false()  # no fork yet
	Party.pick_fork(h, _cleave, "b")
	assert_bool(Party.boost_skill(h, _cleave)).is_true()
	assert_int(h.sp_available).is_equal(1)
	assert_bool(Party.can_boost(h, _cleave)).is_false()  # already boosted
	assert_int(Party.sp_in_talents(h)).is_equal(2)


func test_boost_without_sp_fails() -> void:
	var h := _warrior_hero(1)
	h.sp_available = 1
	Party.pick_fork(h, _slash, "a")
	assert_bool(Party.boost_skill(h, _slash)).is_false()


func test_other_classes_have_no_talents_and_warrior_no_tiers() -> void:
	var cleric := Hero.create(load(CLERIC))
	cleric.sp_available = 5
	var heal: SkillData = cleric.class_data.skills[0]
	assert_bool(Party.can_pick_fork(cleric, heal, "a")).is_false()
	var w := _warrior_hero(5)
	w.sp_available = 5
	assert_bool(Party.can_upgrade_skill(w, _slash)).is_false()


# ── Effective skill ───────────────────────────────────────────────────────────


func test_every_warrior_skill_has_two_forks() -> void:
	for skill in (load(WARRIOR) as ClassData).skills:
		assert_object(skill.fork_a).override_failure_message(skill.id).is_not_null()
		assert_object(skill.fork_b).override_failure_message(skill.id).is_not_null()


func test_effective_skill_without_a_fork_is_the_base() -> void:
	var h := _warrior_hero(5)
	assert_object(Party.get_effective_skill(h, _execute)).is_same(_execute)


func test_effective_skill_is_the_picked_variant() -> void:
	var h := _warrior_hero(5)
	h.talents["warrior_execute"] = {"fork": "a", "boost": false}
	assert_object(Party.get_effective_skill(h, _execute)).is_same(_execute.fork_a)
	h.talents["warrior_execute"] = {"fork": "b", "boost": false}
	assert_object(Party.get_effective_skill(h, _execute)).is_same(_execute.fork_b)


func test_boost_applies_tier_two_scaling_to_the_variant() -> void:
	var h := _warrior_hero(1)
	h.talents["warrior_cleave"] = {"fork": "b", "boost": true}
	var heavy: SkillData = _cleave.fork_b
	var eff := Party.get_effective_skill(h, _cleave)
	assert_str(eff.display_name).is_equal(heavy.display_name)
	assert_float(eff.power).is_equal_approx(snappedf(heavy.power * 1.3, 0.01), 0.001)
	assert_int(eff.mp_cost).is_equal(heavy.mp_cost - 2)
	assert_float(heavy.power).is_equal_approx(0.7, 0.001)  # the resource is untouched


func test_other_classes_resolve_to_the_tier_upgrade() -> void:
	var cleric := Hero.create(load(CLERIC))
	var heal: SkillData = cleric.class_data.skills[0]
	assert_object(Party.get_effective_skill(cleric, heal)).is_same(heal)
	cleric.sp_spent[Battler.cooldown_key(heal)] = 1
	var eff := Party.get_effective_skill(cleric, heal)
	var upgraded := Party.get_upgraded_skill(cleric, heal)
	assert_float(eff.power).is_equal(upgraded.power)
	assert_int(Party.combat_cost(cleric, heal)).is_equal(heal.mp_cost)


func test_variant_cost_is_checked_and_paid() -> void:
	var st := _fight([_dummy()], 1)
	var w := _warrior(st)
	w.hero.talents["warrior_cleave"] = {"fork": "b", "boost": false}  # Heavy Arc, 40
	w.rage = 35
	assert_bool(st.can_use(w, _cleave)).is_false()
	w.rage = 45
	assert_bool(st.can_use(w, _cleave)).is_true()
	_act(st, _cleave, null)
	assert_int(w.rage).is_equal(45 - 40 + Battler.RAGE_PER_DAMAGING_ACTION)


# ── The new mechanics ─────────────────────────────────────────────────────────


func test_momentum_gives_20_rage() -> void:
	var st := _fight([_dummy()], 1)
	var w := _warrior(st)
	w.hero.talents["warrior_slash"] = {"fork": "b", "boost": false}
	_act(st, _slash, st.enemies[0])
	assert_int(w.rage).is_equal(20)


func test_vengeance_triples_rage_from_hits_while_taunting() -> void:
	var st := _fight([_dummy()], 3)
	var w := _warrior(st)
	w.hero.talents["warrior_provoke"] = {"fork": "b", "boost": false}
	w.rage = _provoke.mp_cost
	_act(st, _provoke, null)
	assert_int(w.rage).is_equal(0)
	assert_bool(w.has_taunt()).is_true()
	_enemy_hits_warrior(st)
	assert_int(w.rage).is_equal(Battler.RAGE_PER_HIT_TAKEN * 3)
	# Once the taunt wears off, hits give the normal amount again.
	w.statuses.clear()
	_enemy_hits_warrior(st)
	assert_int(w.rage).is_equal(Battler.RAGE_PER_HIT_TAKEN * 4)


func test_iron_wall_gives_10_def_and_normal_rage() -> void:
	var st := _fight([_dummy()], 3)
	var w := _warrior(st)
	w.hero.talents["warrior_provoke"] = {"fork": "a", "boost": false}
	var def_before := int(w.effective_stats()["def"])
	w.rage = _provoke.mp_cost
	_act(st, _provoke, null)
	assert_int(int(w.effective_stats()["def"])).is_equal(def_before + 10)
	_enemy_hits_warrior(st)
	assert_int(w.rage).is_equal(Battler.RAGE_PER_HIT_TAKEN)


func test_reaper_kill_refunds_rage_and_resets_cooldown() -> void:
	var st := _fight([_dummy(1), _dummy()], 5)
	var w := _warrior(st)
	w.hero.talents["warrior_execute"] = {"fork": "a", "boost": false}
	w.rage = Battler.RAGE_MAX
	_act(st, _execute, st.enemies[0])
	assert_bool(st.enemies[0].is_alive()).is_false()
	assert_int(w.rage).is_equal(100 - 50 + Battler.RAGE_PER_DAMAGING_ACTION + 30)
	assert_int(w.cooldown_left(_execute)).is_equal(0)
	assert_bool(st.can_use(w, _execute)).is_true()


func test_reaper_without_a_kill_keeps_the_cooldown() -> void:
	var st := _fight([_dummy()], 5)
	var w := _warrior(st)
	w.hero.talents["warrior_execute"] = {"fork": "a", "boost": false}
	w.rage = Battler.RAGE_MAX
	_act(st, _execute, st.enemies[0])
	assert_int(w.rage).is_equal(100 - 50 + Battler.RAGE_PER_DAMAGING_ACTION)
	assert_bool(st.can_use(w, _execute)).is_false()


func test_base_execute_kill_keeps_the_cooldown() -> void:
	var st := _fight([_dummy(1), _dummy()], 5)
	var w := _warrior(st)
	w.rage = Battler.RAGE_MAX
	_act(st, _execute, st.enemies[0])
	assert_bool(st.enemies[0].is_alive()).is_false()
	assert_bool(st.can_use(w, _execute)).is_false()


func test_sunder_is_a_mid_fight_debuff() -> void:
	var st := _fight([_dummy()], 5)
	var w := _warrior(st)
	w.hero.talents["warrior_execute"] = {"fork": "b", "boost": false}
	var sunder := Party.get_effective_skill(w.hero, _execute)
	assert_bool(sunder.finisher).is_false()
	w.rage = Battler.RAGE_MAX
	var foe := st.enemies[0]
	assert_int(foe.get_hp()).is_equal(foe.max_hp)  # full HP
	assert_bool(st.can_use(w, _execute)).is_true()
	var applied := _durations_applied(st)
	_act(st, _execute, foe)
	assert_int(int(foe.effective_stats()["def"])).is_equal(maxi(0, foe.enemy_data.def - 6))
	var debuffs := foe.statuses.filter(func(s): return s.kind == CombatStatus.Kind.DEBUFF)
	assert_int(debuffs.size()).is_equal(1)
	assert_int(debuffs[0].mod_def).is_equal(-6)
	assert_array(applied).is_equal([3])
	# Cooldowns stay keyed by the base skill. (It may already have ticked once:
	# the turn loop can hand the Warrior the very next turn.)
	assert_int(w.cooldown_left(_execute)).is_greater(0)
	assert_bool(w.cooldowns.has(Battler.cooldown_key(_execute))).is_true()


func test_rending_bleeds() -> void:
	var st := _fight([_dummy()], 1)
	_set_talent(st, "warrior_slash", "a")
	var applied := _durations_applied(st)
	_act(st, _slash, st.enemies[0])
	var dots := st.enemies[0].statuses.filter(func(s): return s.kind == CombatStatus.Kind.DOT)
	assert_int(dots.size()).is_equal(1)
	assert_int(dots[0].dot_damage).is_equal(3)
	assert_array(applied).is_equal([2])
	assert_str(dots[0].dot_popup_key).is_equal("UI_POPUP_BLEED")


func test_wide_arc_lowers_def_on_everything_hit() -> void:
	var st := _fight([_dummy(), _dummy()], 1)
	var w := _warrior(st)
	_set_talent(st, "warrior_cleave", "a")
	w.rage = _cleave.mp_cost
	_act(st, _cleave, null)
	for foe in st.enemies:
		var debuffs := foe.statuses.filter(func(s): return s.kind == CombatStatus.Kind.DEBUFF)
		assert_int(debuffs.size()).is_equal(1)
		assert_int(debuffs[0].mod_def).is_equal(-3)


# ── Save ──────────────────────────────────────────────────────────────────────


func test_talents_round_trip_through_json() -> void:
	var h := _warrior_hero(6)
	h.sp_available = 1
	h.talents = {
		"warrior_slash": {"fork": "b", "boost": true},
		"warrior_execute": {"fork": "a", "boost": false},
	}
	var back := _through_json(h)
	assert_dict(back.talents).is_equal(h.talents)
	assert_int(back.sp_available).is_equal(1)
	assert_object(Party.get_effective_skill(back, _execute)).is_same(_execute.fork_a)


func test_old_warrior_save_is_converted() -> void:
	var data := _warrior_hero(5).to_dict()
	data.erase("talents")  # a save from before talents
	data["sp_available"] = 1
	data["sp_spent"] = {"warrior_slash": 2.0, "warrior_cleave": 2.0}
	var back := Hero.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_dict(back.sp_spent).is_empty()
	assert_dict(back.talents).is_empty()
	assert_int(back.sp_available).is_equal(Party.talent_sp_for_level(5))


func test_new_warrior_save_keeps_banked_sp() -> void:
	var h := _warrior_hero(4)
	h.sp_available = 3  # 2 from levels, 1 from a Tome of Mastery
	assert_int(_through_json(h).sp_available).is_equal(3)


func test_sp_spent_loads_as_int() -> void:
	var cleric := Hero.create(load(CLERIC))
	cleric.sp_spent = {"cleric_heal": 2}
	var back := _through_json(cleric)
	assert_int(typeof(back.sp_spent["cleric_heal"])).is_equal(TYPE_INT)
	assert_int(back.sp_spent["cleric_heal"]).is_equal(2)


func test_status_talent_fields_round_trip() -> void:
	var st := CombatStatus.new()
	st.rage_taken_mult = 3.0
	st.dot_popup_key = "UI_POPUP_BLEED"
	var back := CombatStatus.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	assert_float(back.rage_taken_mult).is_equal(3.0)
	assert_str(back.dot_popup_key).is_equal("UI_POPUP_BLEED")
	# An older status without the fields gets the defaults.
	var old := CombatStatus.from_dict({"kind": 0, "dur": 2})
	assert_float(old.rage_taken_mult).is_equal(1.0)
	assert_str(old.dot_popup_key).is_equal("UI_POPUP_POISON")


# ── Helpers ───────────────────────────────────────────────────────────────────


func _warrior_hero(level: int) -> Hero:
	var h := Hero.create(load(WARRIOR))
	h.level = level
	h.hp = h.max_hp()
	return h


func _through_json(h: Hero) -> Hero:
	return Hero.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))


## Marks every level-unlocked skin as owned, so Party.level_up never saves.
func _own_level_skins() -> void:
	for id in Skins.level_unlocks_at_or_below(Party.LEVEL_CAP):
		if not GameState.owned_skins.has(id):
			GameState.owned_skins.append(id)


func _fight(enemies: Array, level: int) -> CombatState:
	var typed: Array[EnemyData] = []
	typed.assign(enemies)
	return CombatState.build([_warrior_hero(level)] as Array[Hero], typed)


## A practice dummy: `hp` HP, no defence, a weak single-target hit.
func _dummy(hp: int = 99999) -> EnemyData:
	var hit := SkillData.new()
	hit.id = "dummy_hit"
	hit.display_name = "dummy_hit"
	hit.skill_type = SkillData.SkillType.PHYS
	hit.target = SkillData.TargetType.ONE
	hit.power = 0.1
	var e := EnemyData.new()
	e.id = "dummy"
	e.display_name = "dummy"
	e.max_hp = hp
	e.atk = 1
	e.skills = [hit] as Array[SkillData]
	return e


## Records the duration of every status as it is applied: the round-end tick
## right after a hand-driven action counts it down at once.
func _durations_applied(st: CombatState) -> Array[int]:
	var out: Array[int] = []
	st.status_applied.connect(func(_t: Battler, s: CombatStatus): out.append(s.duration))
	return out


func _warrior(st: CombatState) -> Battler:
	return st.party[0]


## Gives the Warrior a fork (no boost) directly, ignoring SP.
func _set_talent(st: CombatState, key: String, fork: String) -> void:
	_warrior(st).hero.talents[key] = {"fork": fork, "boost": false}


## The Warrior uses `skill` now, whoever's turn it was.
func _act(st: CombatState, skill: SkillData, target: Battler) -> void:
	st.current_actor = _warrior(st)
	st.player_action(skill, target)


## The first living dummy takes a turn; the Warrior is its only target.
func _enemy_hits_warrior(st: CombatState) -> void:
	for e in st.enemies:
		if e.is_alive():
			st.current_actor = e
			st.step()
			return
