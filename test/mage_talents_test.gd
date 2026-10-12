## Talent rollout 2/5, the Mage (#109): the Mage as a talent class (Mana costs
## unchanged), the eight fork variants and their mechanics (Burn, MP refund,
## Frostbite, Shatter, Overload, Chain, and Meteor, the first hero telegraph),
## both passives (Mana Flow, Elemental Mastery), the Arcane Barrier reaction
## with Parry and Dodge unchanged, the new live-text placeholders, and the
## Mage's talents in the save.
##
## Fights are built directly with CombatState.build against practice dummies,
## and turns are driven by hand (like rogue_talents_test.gd). Where two hits must
## be compared, the RNG is seeded the same before each. Chances the tests need
## fixed (Arcane Barrier) are changed on the loaded resource and restored after.
extends GdUnitTestSuite

const MAGE := "res://resources/classes/mage.tres"
const WARRIOR := "res://resources/classes/warrior.tres"
const FIREBOLT := "res://resources/skills/mage_firebolt.tres"
const FIREBALL := "res://resources/skills/mage_fireball.tres"
const ICE_SPIKE := "res://resources/skills/mage_ice_spike.tres"
const ARCANE_BLAST := "res://resources/skills/mage_arcane_blast.tres"
const MANA_FLOW := "res://resources/passives/mage_mana_flow.tres"
const MASTERY := "res://resources/passives/mage_elemental_mastery.tres"
const BARRIER := "res://resources/reactions/mage_arcane_barrier.tres"
const PARRY := "res://resources/reactions/warrior_parry.tres"

var _mage_class: ClassData
var _firebolt: SkillData
var _fireball: SkillData
var _ice_spike: SkillData
var _arcane_blast: SkillData
var _barrier: ReactionData
var _barrier_chance: float
var _locale: String


func before_test() -> void:
	_mage_class = load(MAGE)
	_firebolt = load(FIREBOLT)
	_fireball = load(FIREBALL)
	_ice_spike = load(ICE_SPIKE)
	_arcane_blast = load(ARCANE_BLAST)
	_barrier = load(BARRIER)
	_barrier_chance = _barrier.chance
	_barrier.chance = 1.0
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	_barrier.chance = _barrier_chance
	TranslationServer.set_locale(_locale)


# ── Data ──────────────────────────────────────────────────────────────────────


func test_mage_is_a_talent_class_that_keeps_mana() -> void:
	assert_bool(_mage_class.uses_talents).is_true()
	assert_int(_mage_class.resource_type).is_equal(ClassData.ResourceType.MANA)
	assert_int(_mage_class.base_mp).is_equal(28)
	assert_int(_mage_class.mp_per_level).is_equal(5)
	assert_str(_mage_class.resource_key()).is_equal("RES_MP")


func test_mage_base_costs_are_unchanged() -> void:
	assert_int(_firebolt.mp_cost).is_equal(0)
	assert_int(_fireball.mp_cost).is_equal(10)
	assert_int(_ice_spike.mp_cost).is_equal(8)
	assert_int(_arcane_blast.mp_cost).is_equal(15)
	assert_float(_firebolt.power).is_equal_approx(1.1, 0.001)
	assert_float(_fireball.power).is_equal_approx(0.6, 0.001)
	assert_float(_ice_spike.power).is_equal_approx(1.6, 0.001)
	assert_float(_arcane_blast.power).is_equal_approx(2.4, 0.001)


func test_every_skill_has_two_complete_variants() -> void:
	for base in _mage_class.skills:
		assert_object(base.fork_a).is_not_null()
		assert_object(base.fork_b).is_not_null()
		for variant in [base.fork_a, base.fork_b]:
			assert_int(variant.unlock_level).is_equal(base.unlock_level)
			assert_int(variant.skill_type).is_equal(SkillData.SkillType.MAG)
			assert_bool(variant.description.is_empty()).is_false()
			assert_bool(variant.display_name.is_empty()).is_false()
		# Only Overload changes its cost.
		if base != _arcane_blast:
			assert_int(base.fork_a.mp_cost).is_equal(base.mp_cost)
		assert_int(base.fork_b.mp_cost).is_equal(base.mp_cost)


func test_variant_numbers() -> void:
	var kindle := _firebolt.fork_a
	assert_int(kindle.dot_damage).is_equal(3)
	assert_int(kindle.dot_duration).is_equal(2)
	assert_str(kindle.dot_popup_key).is_equal("UI_POPUP_BURN")
	assert_int(_firebolt.fork_b.resource_refund).is_equal(3)
	var inferno := _fireball.fork_a
	assert_int(inferno.dot_damage).is_equal(2)
	assert_int(inferno.dot_duration).is_equal(2)
	assert_int(inferno.target).is_equal(SkillData.TargetType.ALL)
	var meteor := _fireball.fork_b
	assert_float(meteor.power).is_equal_approx(1.2, 0.001)
	assert_int(meteor.telegraph_turns).is_equal(1)
	assert_int(meteor.target).is_equal(SkillData.TargetType.ALL)
	var frostbite := _ice_spike.fork_a
	assert_int(frostbite.mod_spd).is_equal(-3)
	assert_int(frostbite.mod_def).is_equal(-4)
	assert_int(frostbite.mod_duration).is_equal(2)
	var shatter := _ice_spike.fork_b
	assert_float(shatter.bonus_vs_def_debuff).is_equal_approx(0.5, 0.001)
	assert_int(shatter.mod_def).is_equal(-4)
	var overload := _arcane_blast.fork_a
	assert_int(overload.mp_cost).is_equal(30)
	assert_float(overload.power).is_equal_approx(2.4 * 1.6, 0.001)
	var chain := _arcane_blast.fork_b
	assert_int(chain.chain_targets).is_equal(2)
	assert_float(chain.chain_power_mult).is_equal_approx(0.5, 0.001)


func test_mage_passives_and_barrier() -> void:
	assert_array(_mage_class.passives).contains_exactly([load(MANA_FLOW), load(MASTERY)])
	assert_array(_mage_class.reactions).contains_exactly([_barrier])
	var flow: PassiveData = load(MANA_FLOW)
	assert_int(flow.unlock_level).is_equal(2)
	assert_int(flow.mp_regen_per_turn).is_equal(2)
	var mastery: PassiveData = load(MASTERY)
	assert_int(mastery.unlock_level).is_equal(2)
	assert_float(mastery.dot_damage_mult).is_equal_approx(1.25, 0.001)
	assert_int(mastery.dot_duration_bonus).is_equal(1)
	assert_int(_barrier.unlock_level).is_equal(3)
	assert_float(_barrier_chance).is_equal_approx(0.3, 0.001)
	assert_int(_barrier.cost).is_equal(8)
	assert_float(_barrier.trigger_below_hp_pct).is_equal_approx(0.3, 0.001)
	assert_float(_barrier.damage_mult).is_equal(0.0)
	assert_str(_barrier.popup_tag).is_equal("shielded")
	assert_int(_barrier.applies_to).is_equal(ReactionData.AppliesTo.SINGLE_TARGET_ANY)


func test_mage_earns_talent_sp() -> void:
	assert_int(Hero.create(_mage_class).sp_available).is_equal(0)
	assert_int(Party.talent_sp_for_level(10)).is_equal(5)


# ── Firebolt ──────────────────────────────────────────────────────────────────


func test_kindle_burns_the_target() -> void:
	var st := _fight([_fork_mage("mage_firebolt", "a")], [_dummy()])
	_act(st, st.party[0], _firebolt, st.enemies[0])
	var burn := _status_of(st.enemies[0], CombatStatus.Kind.DOT)
	assert_object(burn).is_not_null()
	assert_int(burn.dot_damage).is_equal(3)
	assert_int(burn.duration).is_equal(2)
	assert_str(burn.dot_popup_key).is_equal("UI_POPUP_BURN")


func test_arcane_siphon_refunds_3_mp_on_a_hit() -> void:
	var st := _fight([_fork_mage("mage_firebolt", "b")], [_dummy()])
	var mage := st.party[0]
	mage.hero.mp = 20
	_act(st, mage, _firebolt, st.enemies[0])
	assert_int(mage.hero.mp).is_equal(23)  # Firebolt costs nothing
	mage.hero.mp = mage.hero.max_mp() - 1
	_act(st, mage, _firebolt, st.enemies[0])
	assert_int(mage.hero.mp).is_equal(mage.hero.max_mp())  # the refund caps too


func test_arcane_siphon_pays_nothing_when_the_hit_is_blocked() -> void:
	var st := _fight([_fork_mage("mage_firebolt", "b")], [_dummy()])
	var mage := st.party[0]
	mage.hero.mp = 20
	var barrier := CombatStatus.new()
	barrier.kind = CombatStatus.Kind.BARRIER
	barrier.duration = 99
	st.enemies[0].statuses.append(barrier)
	_act(st, mage, _firebolt, st.enemies[0])
	assert_int(mage.hero.mp).is_equal(20)


func test_plain_firebolt_refunds_nothing_and_burns_nothing() -> void:
	var st := _fight([_mage(10)], [_dummy()])
	st.party[0].hero.mp = 20
	_act(st, st.party[0], _firebolt, st.enemies[0])
	assert_int(st.party[0].hero.mp).is_equal(20)
	assert_object(_status_of(st.enemies[0], CombatStatus.Kind.DOT)).is_null()


# ── Fireball ──────────────────────────────────────────────────────────────────


func test_inferno_burns_every_enemy_it_hits() -> void:
	var st := _fight([_fork_mage("mage_fireball", "a")], [_dummy(), _dummy(), _dummy()])
	_act(st, st.party[0], _fireball, null)
	assert_int(st.party[0].hero.mp).is_equal(st.party[0].hero.max_mp() - 10)
	for e in st.enemies:
		var burn := _status_of(e, CombatStatus.Kind.DOT)
		assert_object(burn).is_not_null()
		assert_int(burn.dot_damage).is_equal(2)
		assert_int(burn.duration).is_equal(2)
		assert_str(burn.dot_popup_key).is_equal("UI_POPUP_BURN")


# ── Meteor: the hero telegraph ────────────────────────────────────────────────


func test_meteor_pays_and_winds_up_without_hitting() -> void:
	var st := _fight([_fork_mage("mage_fireball", "b")], [_dummy(), _dummy()])
	var mage := st.party[0]
	var mp := mage.hero.mp
	var hits := _record_hits(st)
	var banners := _record_actions(st)
	_act(st, mage, _fireball, null)
	assert_int(mage.hero.mp).is_equal(mp - 10)
	assert_bool(mage.is_charging()).is_true()
	assert_object(mage.charge_status().charge_skill).is_same(_fireball.fork_b)
	assert_array(hits).is_empty()
	for e in st.enemies:
		assert_int(e.get_hp()).is_equal(e.max_hp)
	# The wind-up banner: the stand-in skill carries the wind-up id and name.
	assert_int(banners.size()).is_equal(1)
	assert_bool(CombatState.is_wind_up(banners[0]["skill"])).is_true()
	assert_str(banners[0]["skill"].display_name).is_equal("SKILL_MAGE_METEOR")
	assert_int(banners[0]["targets"].size()).is_equal(2)


func test_meteor_resolves_on_its_own_at_the_next_turn() -> void:
	var st := _fight([_fork_mage("mage_fireball", "b")], [_dummy(), _dummy()])
	var mage := st.party[0]
	_act(st, mage, _fireball, null)
	var mp := mage.hero.mp
	var hits := _record_hits(st)
	# The mage's next turn begins charging, and plays itself.
	st.current_actor = mage
	_pin_next(st, st.enemies[0])
	assert_bool(st.is_auto_turn()).is_true()
	assert_bool(st.can_use(mage, _fireball)).is_false()
	assert_bool(st.can_use(mage, _firebolt)).is_false()
	st.step()
	assert_bool(mage.is_charging()).is_false()
	assert_int(mage.hero.mp).is_equal(mp)  # nothing more to pay
	assert_int(hits.size()).is_equal(2)  # every living enemy
	for e in st.enemies:
		assert_int(e.get_hp()).is_less(e.max_hp)
	assert_bool(st.can_use(mage, _fireball)).is_true()  # free to act again


func test_meteor_cannot_be_overridden_by_the_player_while_charging() -> void:
	var st := _fight([_fork_mage("mage_fireball", "b")], [_dummy()])
	var mage := st.party[0]
	_act(st, mage, _fireball, null)
	var mp := mage.hero.mp
	st.current_actor = mage
	_pin_next(st, st.enemies[0])
	st.player_action(_firebolt, st.enemies[0])  # refused
	assert_int(st.enemies[0].get_hp()).is_equal(st.enemies[0].max_hp)
	assert_bool(mage.is_charging()).is_true()
	assert_int(mage.hero.mp).is_equal(mp)
	st.player_flee()  # refused too
	assert_bool(st.ended).is_false()
	assert_object(st.current_actor).is_same(mage)


func test_meteor_through_the_real_turn_loop() -> void:
	var st := _fight([_fork_mage("mage_fireball", "b")], [_dummy(), _dummy()])
	st.start()  # the Mage (SPD 14 against 0) acts first
	var mage := st.party[0]
	assert_object(st.current_actor).is_same(mage)
	assert_bool(st.is_auto_turn()).is_false()
	st.player_action(_fireball, null)
	assert_bool(mage.is_charging()).is_true()
	# Both dummies act, the round ends, and the Mage's turn comes up charging.
	while st.current_actor != mage:
		st.step()
	assert_bool(st.is_auto_turn()).is_true()
	st.step()
	assert_bool(mage.is_charging()).is_false()
	for e in st.enemies:
		assert_int(e.get_hp()).is_less(e.max_hp)


func test_meteor_hits_harder_than_fireball() -> void:
	var meteor := _mage_hit_amounts("mage_fireball", "b", true)
	var plain := _mage_hit_amounts("mage_fireball", "", false)
	assert_int(meteor.size()).is_equal(1)
	assert_int(plain.size()).is_equal(1)
	assert_int(meteor[0]).is_greater(int(plain[0] * 1.5))  # power 1.2 against 0.6


func test_meteor_is_lost_if_the_mage_is_downed_and_costs_nothing_back() -> void:
	var st := _fight([_fork_mage("mage_fireball", "b")], [_dummy(999)])
	var mage := st.party[0]
	_act(st, mage, _fireball, null)
	var mp := mage.hero.mp
	_enemy_turn(st)  # a 999-damage hit
	assert_bool(mage.is_alive()).is_false()
	assert_bool(mage.is_charging()).is_false()
	assert_int(mage.hero.mp).is_equal(mp)  # not refunded


func test_a_charging_mage_that_is_set_to_zero_hp_loses_the_wind_up() -> void:
	var st := _fight([_fork_mage("mage_fireball", "b"), _mage(10)], [_dummy()])
	var mage := st.party[0]
	_act(st, mage, _fireball, null)
	assert_bool(mage.is_charging()).is_true()
	mage.set_hp(0)
	assert_bool(mage.is_charging()).is_false()
	assert_object(_status_of(mage, CombatStatus.Kind.CHARGING)).is_null()


func test_meteor_is_lost_with_the_fight() -> void:
	var h := _fork_mage("mage_fireball", "b")
	var st := _fight([h], [_dummy()])
	_act(st, st.party[0], _fireball, null)
	assert_bool(st.party[0].is_charging()).is_true()
	st.current_actor = st.party[0]
	st._end(CombatState.Result.FLEE)
	assert_bool(st.ended).is_true()
	assert_bool(st.party[0].is_charging()).is_false()
	assert_bool(h.statuses.is_empty()).is_true()  # nothing leaks into the save


func test_a_charging_status_left_in_a_save_is_dropped_at_the_next_fight() -> void:
	var h := _mage(10)
	var stale := CombatStatus.new()
	stale.kind = CombatStatus.Kind.CHARGING
	stale.source_name = "SKILL_MAGE_METEOR"
	stale.duration = 1
	h.statuses.append(stale)
	var st := _fight([h], [_dummy()])
	assert_bool(st.party[0].is_charging()).is_false()


func test_meteor_on_a_lone_survivor_after_the_other_enemy_died() -> void:
	var st := _fight([_fork_mage("mage_fireball", "b")], [_dummy(), _dummy()])
	_act(st, st.party[0], _fireball, null)
	st.enemies[0].set_hp(0)
	st.current_actor = st.party[0]
	_pin_next(st, st.enemies[1])
	var hits := _record_hits(st)
	st.step()
	assert_int(hits.size()).is_equal(1)  # only the living enemy


func test_meteor_that_kills_the_last_enemy_wins_the_fight() -> void:
	var weak := _dummy()
	weak.max_hp = 1
	var st := _fight([_fork_mage("mage_fireball", "b")], [weak])
	_act(st, st.party[0], _fireball, null)
	st.current_actor = st.party[0]
	_pin_next(st, st.enemies[0])
	st.step()
	assert_bool(st.ended).is_true()
	assert_int(st.result).is_equal(CombatState.Result.VICTORY)


# ── Ice Spike ─────────────────────────────────────────────────────────────────


func test_frostbite_slows_and_lowers_def() -> void:
	var st := _fight([_fork_mage("mage_ice_spike", "a")], [_dummy()])
	var e := st.enemies[0]
	e.enemy_data.spd = 10
	_act(st, st.party[0], _ice_spike, e)
	var debuff := _status_of(e, CombatStatus.Kind.DEBUFF)
	assert_object(debuff).is_not_null()
	assert_int(debuff.mod_spd).is_equal(-3)
	assert_int(debuff.mod_def).is_equal(-4)
	assert_int(debuff.duration).is_equal(2)
	assert_int(int(e.effective_stats()["spd"])).is_equal(7)


func test_shatter_hits_a_def_debuffed_target_harder() -> void:
	var exposed := _ice_spike_vs("b", true)
	var plain := _ice_spike_vs("b", false)
	assert_bool(exposed["tags"].has("exposed")).is_true()
	assert_bool(plain["tags"].has("exposed")).is_false()
	assert_int(exposed["amount"]).is_greater(plain["amount"])
	# Without the fork the same setup gives no bonus.
	var base := _ice_spike_vs("", true)
	assert_bool(base["tags"].has("exposed")).is_false()


func test_shatter_still_lowers_def() -> void:
	var st := _fight([_fork_mage("mage_ice_spike", "b")], [_dummy()])
	_act(st, st.party[0], _ice_spike, st.enemies[0])
	var debuff := _status_of(st.enemies[0], CombatStatus.Kind.DEBUFF)
	assert_int(debuff.mod_def).is_equal(-4)


# ── Arcane Blast ──────────────────────────────────────────────────────────────


func test_overload_costs_30_and_hits_harder() -> void:
	var st := _fight([_fork_mage("mage_arcane_blast", "a")], [_dummy()])
	var mage := st.party[0]
	var mp := mage.hero.mp
	_act(st, mage, _arcane_blast, st.enemies[0])
	assert_int(mage.hero.mp).is_equal(mp - 30)
	var overload := _mage_hit_amounts("mage_arcane_blast", "a", false)
	var plain := _mage_hit_amounts("mage_arcane_blast", "", false)
	assert_int(overload[0]).is_greater(int(plain[0] * 1.4))  # x1.6 power


func test_overload_needs_30_mp() -> void:
	var st := _fight([_fork_mage("mage_arcane_blast", "a")], [_dummy()])
	var mage := st.party[0]
	mage.hero.mp = 29
	assert_bool(st.can_use(mage, _arcane_blast)).is_false()
	mage.hero.mp = 30
	assert_bool(st.can_use(mage, _arcane_blast)).is_true()


func test_chain_hits_two_other_enemies_at_half_power() -> void:
	var st := _fight(
		[_fork_mage("mage_arcane_blast", "b")], [_dummy(), _dummy(), _dummy(), _dummy()]
	)
	var mage := st.party[0]
	var by_target := _record_hits_by_target(st)
	var mp := mage.hero.mp
	_act(st, mage, _arcane_blast, st.enemies[1])
	assert_int(mage.hero.mp).is_equal(mp - 15)  # Chain costs the base 15
	assert_int(by_target.size()).is_equal(3)
	assert_bool(by_target.has(st.enemies[1])).is_true()
	# The two others are two of the three not picked, never the main target twice.
	var others := 0
	for e in st.enemies:
		if e != st.enemies[1] and by_target.has(e):
			others += 1
	assert_int(others).is_equal(2)
	assert_int(by_target[st.enemies[1]].size()).is_equal(1)
	# A chain hit is about half the main hit (DEF 0, damage rolls differ by <= 3).
	var main_amount: int = by_target[st.enemies[1]][0]
	for e in by_target:
		if e != st.enemies[1]:
			var amount: int = by_target[e][0]
			assert_int(amount).is_less(main_amount)
			assert_int(absi(amount - main_amount / 2)).is_less(4)


func test_chain_copes_with_fewer_enemies() -> void:
	var two := _fight([_fork_mage("mage_arcane_blast", "b")], [_dummy(), _dummy()])
	var two_hits := _record_hits_by_target(two)
	_act(two, two.party[0], _arcane_blast, two.enemies[0])
	assert_int(two_hits.size()).is_equal(2)  # the target and its one neighbour
	var one := _fight([_fork_mage("mage_arcane_blast", "b")], [_dummy()])
	var one_hits := _record_hits_by_target(one)
	_act(one, one.party[0], _arcane_blast, one.enemies[0])
	assert_int(one_hits.size()).is_equal(1)


func test_chain_skips_dead_enemies() -> void:
	var st := _fight([_fork_mage("mage_arcane_blast", "b")], [_dummy(), _dummy(), _dummy()])
	st.enemies[2].set_hp(0)
	var by_target := _record_hits_by_target(st)
	_act(st, st.party[0], _arcane_blast, st.enemies[0])
	assert_int(by_target.size()).is_equal(2)
	assert_bool(by_target.has(st.enemies[2])).is_false()


func test_chain_still_chains_when_the_main_target_dies() -> void:
	var weak := _dummy()
	weak.max_hp = 1
	var st := _fight([_fork_mage("mage_arcane_blast", "b")], [weak, _dummy(), _dummy()])
	var by_target := _record_hits_by_target(st)
	_act(st, st.party[0], _arcane_blast, st.enemies[0])
	assert_bool(st.enemies[0].is_alive()).is_false()
	assert_int(by_target.size()).is_equal(3)


func test_a_boosted_chain_scales_both_hits() -> void:
	var h := _mage(10)
	h.talents["mage_arcane_blast"] = {"fork": "b", "boost": true}
	var boosted := Party.get_effective_skill(h, _arcane_blast)
	assert_int(boosted.chain_targets).is_equal(2)
	assert_float(boosted.power).is_greater(_arcane_blast.fork_b.power)


# ── Mana Flow ─────────────────────────────────────────────────────────────────


func test_mana_flow_gives_2_mp_at_the_start_of_each_turn_and_caps() -> void:
	var st := _fight([_passive_mage("mana_flow")], [_dummy()])
	st.start()  # the Mage acts first; it is already full
	var mage := st.party[0]
	assert_object(st.current_actor).is_same(mage)
	assert_int(mage.hero.mp).is_equal(mage.hero.max_mp())
	mage.hero.mp = 10
	st.player_action(_firebolt, st.enemies[0])  # Firebolt costs nothing
	assert_int(mage.hero.mp).is_equal(10)  # no regen mid-round
	st.step()  # the dummy acts, the next round starts, the Mage's turn begins
	assert_object(st.current_actor).is_same(mage)
	assert_int(mage.hero.mp).is_equal(12)
	mage.hero.mp = mage.hero.max_mp() - 1
	mage.regen_mp()
	assert_int(mage.hero.mp).is_equal(mage.hero.max_mp())


func test_mana_flow_also_counts_the_turn_meteor_lands() -> void:
	var h := _passive_mage("mana_flow")
	h.talents["mage_fireball"] = {"fork": "b", "boost": false}
	var st := _fight([h], [_dummy()])
	st.start()
	var mage := st.party[0]
	st.player_action(_fireball, null)
	var mp := mage.hero.mp
	st.step()  # the dummy acts, the Mage's charging turn begins: +2
	assert_object(st.current_actor).is_same(mage)
	assert_bool(mage.is_charging()).is_true()
	assert_int(mage.hero.mp).is_equal(mp + 2)


func test_a_mage_without_the_passive_regens_nothing() -> void:
	var st := _fight([_mage(10)], [_dummy()])
	st.start()
	var mage := st.party[0]
	mage.hero.mp = 10
	st.player_action(_firebolt, st.enemies[0])
	st.step()
	assert_int(mage.hero.mp).is_equal(10)


func test_other_heroes_do_not_gain_mana_from_a_mages_passive() -> void:
	var st := _fight([_passive_mage("mana_flow"), _warrior()], [_dummy()])
	st.party[1].regen_mp()
	assert_int(st.party[1].hero.mp).is_equal(0)


# ── Elemental Mastery ─────────────────────────────────────────────────────────


func test_elemental_mastery_strengthens_and_lengthens_burn() -> void:
	var h := _passive_mage("elemental_mastery")
	h.talents["mage_firebolt"] = {"fork": "a", "boost": false}
	var st := _fight([h], [_dummy()])
	_act(st, st.party[0], _firebolt, st.enemies[0])
	var burn := _status_of(st.enemies[0], CombatStatus.Kind.DOT)
	assert_int(burn.dot_damage).is_equal(4)  # 3 x 1.25 = 3.75, rounded
	assert_int(burn.duration).is_equal(3)  # 2 + 1
	assert_str(burn.dot_popup_key).is_equal("UI_POPUP_BURN")


func test_elemental_mastery_applies_to_inferno_too() -> void:
	var h := _passive_mage("elemental_mastery")
	h.talents["mage_fireball"] = {"fork": "a", "boost": false}
	var st := _fight([h], [_dummy(), _dummy()])
	_act(st, st.party[0], _fireball, null)
	for e in st.enemies:
		var burn := _status_of(e, CombatStatus.Kind.DOT)
		assert_int(burn.dot_damage).is_equal(3)  # 2 x 1.25 = 2.5, rounded up
		assert_int(burn.duration).is_equal(3)


func test_without_the_passive_burn_is_unchanged() -> void:
	var st := _fight([_fork_mage("mage_firebolt", "a")], [_dummy()])
	_act(st, st.party[0], _firebolt, st.enemies[0])
	var burn := _status_of(st.enemies[0], CombatStatus.Kind.DOT)
	assert_int(burn.dot_damage).is_equal(3)
	assert_int(burn.duration).is_equal(2)


func test_enemy_dots_ignore_the_mages_passive() -> void:
	# A DoT an enemy puts on the Mage is not strengthened by the Mage's own passive.
	var hit := SkillData.new()
	hit.id = "venom"
	hit.display_name = "venom"
	hit.skill_type = SkillData.SkillType.PHYS
	hit.dot_damage = 4
	hit.dot_duration = 2
	var e := _dummy()
	e.skills = [hit] as Array[SkillData]
	var st := _fight([_passive_mage("elemental_mastery")], [e])
	_enemy_turn(st)
	var dot := _status_of(st.party[0], CombatStatus.Kind.DOT)
	assert_int(dot.dot_damage).is_equal(4)
	assert_int(dot.duration).is_equal(2)


# ── Arcane Barrier ────────────────────────────────────────────────────────────


func test_barrier_blocks_a_hit_that_would_drop_the_mage_below_30_percent() -> void:
	var st := _barrier_fight(true, 30)
	var hits := _record_hits(st)
	var mage := st.party[0]
	var mp := mage.hero.mp
	_enemy_turn(st)
	assert_int(mage.get_hp()).is_equal(30)
	assert_int(mage.hero.mp).is_equal(mp - 8)
	assert_int(hits[0]["amount"]).is_equal(0)
	assert_bool(hits[0]["tags"].has("shielded")).is_true()
	assert_bool(hits[0]["tags"].has("dodged")).is_false()


func test_barrier_does_nothing_while_the_hit_leaves_the_mage_above_30_percent() -> void:
	var st := _barrier_fight(true, -1)  # full HP: the hit cannot take it under 30%
	var mage := st.party[0]
	var hp := mage.get_hp()
	var mp := mage.hero.mp
	_enemy_turn(st)
	assert_int(mage.get_hp()).is_less(hp)
	assert_int(mage.hero.mp).is_equal(mp)


func test_barrier_triggers_exactly_at_the_threshold_crossing() -> void:
	# 69 max HP: 30% is 20.7. The dummy hits for 29-32 (40 ATK against 11 DEF):
	# from 55 HP that leaves 23 or more (not below); from 48 it leaves 19 or less.
	var above := _barrier_fight(true, 55)
	_enemy_turn(above)
	assert_int(above.party[0].hero.mp).is_equal(above.party[0].hero.max_mp())
	var below := _barrier_fight(true, 48)
	_enemy_turn(below)
	assert_int(below.party[0].hero.mp).is_equal(below.party[0].hero.max_mp() - 8)


func test_barrier_covers_magic_hits_too() -> void:
	var st := _barrier_fight(true, 30, SkillData.TargetType.ONE, SkillData.SkillType.MAG)
	var hits := _record_hits(st)
	_enemy_turn(st)
	assert_int(st.party[0].get_hp()).is_equal(30)
	assert_bool(hits[0]["tags"].has("shielded")).is_true()


func test_barrier_does_not_apply_to_area_hits() -> void:
	var st := _barrier_fight(true, 30, SkillData.TargetType.ALL)
	_enemy_turn(st)
	assert_int(st.party[0].get_hp()).is_less(30)
	assert_int(st.party[0].hero.mp).is_equal(st.party[0].hero.max_mp())


func test_barrier_needs_8_mp() -> void:
	var st := _barrier_fight(true, 45)  # a hit leaves 13-16: under 30%, still alive
	var mage := st.party[0]
	mage.hero.mp = 7
	_enemy_turn(st)
	assert_int(mage.get_hp()).is_less(45)
	assert_int(mage.hero.mp).is_equal(7)
	mage.set_hp(45)
	mage.hero.mp = 8
	_enemy_turn(st)
	assert_int(mage.get_hp()).is_equal(45)
	assert_int(mage.hero.mp).is_equal(0)


func test_barrier_toggled_off_does_nothing() -> void:
	var st := _barrier_fight(false, 30)
	var mage := st.party[0]
	_enemy_turn(st)
	assert_int(mage.get_hp()).is_less(30)
	assert_int(mage.hero.mp).is_equal(mage.hero.max_mp())


func test_barrier_chance_is_a_roll() -> void:
	_barrier.chance = 0.0
	var st := _barrier_fight(true, 30)
	_enemy_turn(st)
	assert_int(st.party[0].get_hp()).is_less(30)
	assert_int(st.party[0].hero.mp).is_equal(st.party[0].hero.max_mp())


func test_a_shielded_hit_is_named_in_the_log() -> void:
	TranslationServer.set_locale("en")
	var st := _barrier_fight(true, 30)
	var log_before := st.log_lines.size()
	_enemy_turn(st)
	assert_str(st.log_lines[log_before]).contains("SHIELDED")


func test_barrier_threshold_helper() -> void:
	assert_bool(_barrier.passes_hp_threshold(69, 69, 10)).is_false()
	assert_bool(_barrier.passes_hp_threshold(30, 69, 10)).is_true()  # 20 < 20.7
	assert_bool(_barrier.passes_hp_threshold(31, 69, 10)).is_false()  # 21 >= 20.7
	assert_bool(_barrier.passes_hp_threshold(10, 69, 50)).is_true()  # lethal
	var any_hit := ReactionData.new()  # threshold 0 = any hit
	assert_bool(any_hit.passes_hp_threshold(69, 69, 1)).is_true()


func test_parry_and_dodge_are_unchanged() -> void:
	# Parry has no HP threshold and stays physical-only.
	var parry: ReactionData = load(PARRY)
	assert_float(parry.trigger_below_hp_pct).is_equal(0.0)
	assert_int(parry.applies_to).is_equal(ReactionData.AppliesTo.SINGLE_TARGET_PHYSICAL)
	var dodge: ReactionData = load("res://resources/reactions/rogue_dodge.tres")
	assert_float(dodge.trigger_below_hp_pct).is_equal(0.0)
	assert_int(dodge.applies_to).is_equal(ReactionData.AppliesTo.SINGLE_TARGET_PHYSICAL)
	var phys := SkillData.new()
	var mag := SkillData.new()
	phys.target = SkillData.TargetType.ONE
	assert_bool(parry.applies(phys, SkillData.SkillType.PHYS)).is_true()
	assert_bool(parry.applies(phys, SkillData.SkillType.MAG)).is_false()
	assert_bool(_barrier.applies(phys, SkillData.SkillType.PHYS)).is_true()
	assert_bool(_barrier.applies(phys, SkillData.SkillType.MAG)).is_true()
	mag.target = SkillData.TargetType.ALL
	assert_bool(_barrier.applies(mag, SkillData.SkillType.MAG)).is_false()


# ── Live text ─────────────────────────────────────────────────────────────────


func test_new_skill_placeholders_render() -> void:
	var s := SkillData.new()
	s.chain_targets = 2
	s.chain_power_mult = 0.5
	assert_str(SkillText.fill_skill("{chain}|{chain_power}", s)).is_equal("2|50%")


func test_new_passive_and_reaction_placeholders_render() -> void:
	var p := PassiveData.new()
	p.mp_regen_per_turn = 2
	p.dot_damage_mult = 1.25
	p.dot_duration_bonus = 1
	assert_str(SkillText.fill_passive("{mp_regen}|{dot_bonus}|{dot_turns_bonus}", p)).is_equal(
		"2|25%|1"
	)
	assert_str(SkillText.fill_passive("{dot_bonus}", PassiveData.new())).is_equal("0%")
	assert_str(SkillText.fill_reaction("{below}", _barrier)).is_equal("30%")


func test_mage_descriptions_read_correctly() -> void:
	TranslationServer.set_locale("en")
	(
		assert_str(SkillText.describe(_arcane_blast.fork_b))
		. is_equal(
			"Arcane power that leaps: after the target, 2 other random enemies take a hit at 50% of the power."
		)
	)
	assert_str(SkillText.describe(_firebolt.fork_a)).is_equal(
		"A dart of flame that sets the target ablaze: 3 damage for 2 turns."
	)
	assert_str(SkillText.describe_passive(load(MANA_FLOW))).is_equal(
		"+2 MP at the start of each of your turns in combat."
	)
	assert_str(SkillText.describe_passive(load(MASTERY))).is_equal(
		"Your damage-over-time effects deal +25% damage and last 1 more turn(s)."
	)
	assert_str(SkillText.describe_reaction(_barrier)).contains("30%")
	assert_str(SkillText.describe_reaction(_barrier)).contains("8 MP")


func test_popup_and_log_strings_exist_in_both_languages() -> void:
	for locale in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		for key in ["UI_POPUP_SHIELDED", "LOG_SHIELDED_SUFFIX", "UI_POPUP_BURN"]:
			assert_str(String(TranslationServer.translate(key))).is_not_equal(key)


# ── Save ──────────────────────────────────────────────────────────────────────


func test_mage_talents_round_trip_through_json() -> void:
	var h := _mage(10)
	h.sp_available = 1
	h.talents = {
		"mage_firebolt": {"fork": "a", "boost": true},
		"mage_fireball": {"fork": "b", "boost": false},
		Party.PASSIVE_KEY: "elemental_mastery",
		Party.REACTION_KEY: {"id": "arcane_barrier", "enabled": false},
	}
	var back := Hero.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	assert_dict(back.talents).is_equal(h.talents)
	assert_int(back.sp_available).is_equal(1)
	assert_object(back.class_data).is_same(_mage_class)
	assert_object(Party.get_effective_skill(back, _fireball)).is_same(_fireball.fork_b)
	assert_object(Party.get_passive(back)).is_same(load(MASTERY))
	assert_object(Party.get_reaction(back)).is_same(_barrier)
	assert_bool(Party.is_reaction_enabled(back)).is_false()


func test_an_old_mage_save_gets_its_tier_sp_back() -> void:
	# Saved before the Mage had talents: SP went into upgrade tiers.
	var old := _mage(6).to_dict()
	old.erase("talents")
	old["sp_spent"] = {"mage_fireball": 1, "mage_ice_spike": 1}
	old["sp_available"] = 0
	var back := Hero.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_bool(back.sp_spent.is_empty()).is_true()
	assert_int(back.sp_available).is_equal(Party.talent_sp_for_level(6))
	# The same hero keeps its mana and level.
	assert_int(back.level).is_equal(6)
	assert_int(back.max_mp()).is_equal(28 + 5 * 5)


func test_no_wind_up_is_ever_saved_after_a_fight() -> void:
	var h := _fork_mage("mage_fireball", "b")
	var st := _fight([h], [_dummy()])
	_act(st, st.party[0], _fireball, null)
	st.current_actor = st.party[0]
	st._end(CombatState.Result.FLEE)
	var saved: Array = h.to_dict()["statuses"]
	for s in saved:
		assert_int(int(s["kind"])).is_not_equal(int(CombatStatus.Kind.CHARGING))


# ── Helpers ───────────────────────────────────────────────────────────────────


func _mage(level: int) -> Hero:
	var h := Hero.create(_mage_class)
	h.level = level
	h.hp = h.max_hp()
	h.mp = h.max_mp()
	return h


## A level-10 Mage with `fork` ("a"/"b") picked on the skill `key`.
func _fork_mage(key: String, fork: String) -> Hero:
	var h := _mage(10)
	if fork != "":
		h.talents[key] = {"fork": fork, "boost": false}
	return h


func _passive_mage(passive_id: String) -> Hero:
	var h := _mage(10)
	h.talents[Party.PASSIVE_KEY] = passive_id
	return h


func _warrior() -> Hero:
	var h := Hero.create(load(WARRIOR))
	h.level = 10
	h.hp = h.max_hp()
	return h


func _fight(heroes: Array, enemies: Array) -> CombatState:
	var typed_heroes: Array[Hero] = []
	typed_heroes.assign(heroes)
	var typed_enemies: Array[EnemyData] = []
	typed_enemies.assign(enemies)
	return CombatState.build(typed_heroes, typed_enemies)


## A practice dummy with lots of HP and no DEF. Its only skill hits with power
## 1.0 off `atk`.
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
	e.mag = atk
	e.skills = [hit] as Array[SkillData]
	return e


## A Mage with Arcane Barrier learned (on or off), at `hp` HP (-1 = full), against
## one dummy that hits for about 30.
func _barrier_fight(
	barrier_on: bool,
	hp: int,
	target := SkillData.TargetType.ONE,
	kind := SkillData.SkillType.PHYS,
) -> CombatState:
	var h := _mage(10)
	h.talents[Party.REACTION_KEY] = {"id": "arcane_barrier", "enabled": barrier_on}
	if hp >= 0:
		h.hp = hp
	return _fight([h], [_dummy(40, target, kind)])


func _status_of(b: Battler, kind: CombatStatus.Kind) -> CombatStatus:
	for st in b.statuses:
		if st.kind == kind:
			return st
	return null


## Every damage popup as {amount, tags}, in order.
func _record_hits(st: CombatState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	st.damage_popup.connect(
		func(_b: Battler, amount: int, _k: CombatState.PopupKind, tags: PackedStringArray):
			out.append({"amount": amount, "tags": tags})
	)
	return out


## Damage amounts per battler (enemies only), in order.
func _record_hits_by_target(st: CombatState) -> Dictionary:
	var out := {}
	st.damage_popup.connect(
		func(b: Battler, amount: int, kind: CombatState.PopupKind, _tags: PackedStringArray):
			if b.side == Battler.Side.ENEMY and kind != CombatState.PopupKind.HEAL:
				if not out.has(b):
					out[b] = []
				out[b].append(amount)
	)
	return out


## Every action_started as {skill, targets}.
func _record_actions(st: CombatState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	st.action_started.connect(
		func(_c: Battler, skill: SkillData, targets: Array[Battler]):
			out.append({"skill": skill, "targets": targets})
	)
	return out


## The damage of one hit of a level-10 Mage's skill on a single dummy, with a fixed
## seed. `resolve_wind_up` plays the Meteor wind-up out first.
func _mage_hit_amounts(key: String, fork: String, resolve_wind_up: bool) -> Array[int]:
	var base: SkillData = load("res://resources/skills/%s.tres" % key)
	var st := _fight([_fork_mage(key, fork)], [_dummy()])
	var amounts: Array[int] = []
	st.damage_popup.connect(
		func(_b: Battler, amount: int, _k: CombatState.PopupKind, _tags: PackedStringArray):
			amounts.append(amount)
	)
	seed(777)
	var target: Battler = null if base.target == SkillData.TargetType.ALL else st.enemies[0]
	_act(st, st.party[0], base, target)
	if resolve_wind_up:
		st.current_actor = st.party[0]
		_pin_next(st, st.enemies[0])
		st.step()
	return amounts


## A level-10 Mage (Ice Spike's `fork`, or none) Ice Spikes a dummy, whose DEF is
## debuffed or not, with a fixed seed. Returns that hit's {amount, tags}.
func _ice_spike_vs(fork: String, debuffed: bool) -> Dictionary:
	var st := _fight([_fork_mage("mage_ice_spike", fork)], [_dummy()])
	if debuffed:
		var debuff := CombatStatus.new()
		debuff.kind = CombatStatus.Kind.DEBUFF
		debuff.mod_def = -3
		debuff.duration = 5
		st.enemies[0].statuses.append(debuff)
	var hits := _record_hits(st)
	seed(4242)
	_act(st, st.party[0], _ice_spike, st.enemies[0])
	return hits[0]


## Makes `b` the next to act, so the end of an action doesn't roll a new round
## (and tick a Mage's Mana Flow) under the assertion.
func _pin_next(st: CombatState, b: Battler) -> void:
	st.initiative.assign([b])


## `actor` uses `skill` now, whoever's turn it was.
func _act(st: CombatState, actor: Battler, skill: SkillData, target: Battler) -> void:
	st.current_actor = actor
	_pin_next(st, st.enemies[0])
	st.player_action(skill, target)


## The first dummy takes a turn.
func _enemy_turn(st: CombatState) -> void:
	st.current_actor = st.enemies[0]
	_pin_next(st, st.enemies[0])
	st.step()
