## Talent rollout 1/5, the Rogue (#101): Energy (starts full, +25 a turn, caps
## at 100, pays skill costs), the eight fork variants and their new mechanics
## (resource refund, Ambush, Mark for Death, Shadowstep), both passives, the
## Dodge reaction, the rage_cost -> cost rename, and the Rogue's talents in the
## save.
##
## Fights are built directly with CombatState.build against practice dummies,
## and turns are driven by hand (like talents_passive_reaction_test.gd). Where
## two hits must be compared, the RNG is seeded the same before each. Chances
## the tests need fixed (Dodge, Ambush's crit, Assassin's Focus) are changed on
## the loaded resource and restored after.
extends GdUnitTestSuite

const ROGUE := "res://resources/classes/rogue.tres"
const WARRIOR := "res://resources/classes/warrior.tres"
const STAB := "res://resources/skills/rogue_stab.tres"
const BACKSTAB := "res://resources/skills/rogue_backstab.tres"
const RELENTLESS := "res://resources/skills/rogue_relentless.tres"
const ASSASSINATE := "res://resources/skills/rogue_assassinate.tres"
const SLASH := "res://resources/skills/warrior_slash.tres"
const OPPORTUNIST := "res://resources/passives/rogue_opportunist.tres"
const FOCUS := "res://resources/passives/rogue_assassins_focus.tres"
const DODGE := "res://resources/reactions/rogue_dodge.tres"
const PARRY := "res://resources/reactions/warrior_parry.tres"

var _rogue_class: ClassData
var _dodge: ReactionData
var _dodge_chance: float
var _focus: PassiveData
var _focus_bonus: float
var _ambush: SkillData
var _ambush_crit: float
var _stab: SkillData
var _backstab: SkillData
var _relentless: SkillData
var _assassinate: SkillData


func before_test() -> void:
	_rogue_class = load(ROGUE)
	_stab = load(STAB)
	_backstab = load(BACKSTAB)
	_relentless = load(RELENTLESS)
	_assassinate = load(ASSASSINATE)
	_dodge = load(DODGE)
	_dodge_chance = _dodge.chance
	_dodge.chance = 1.0
	_focus = load(FOCUS)
	_focus_bonus = _focus.crit_bonus_below_half_hp
	_ambush = _backstab.fork_b
	_ambush_crit = _ambush.crit_chance
	_ambush.crit_chance = 0.0  # only Ambush's guaranteed crit shows up


func after_test() -> void:
	_dodge.chance = _dodge_chance
	_focus.crit_bonus_below_half_hp = _focus_bonus
	_ambush.crit_chance = _ambush_crit


# ── Data ──────────────────────────────────────────────────────────────────────


func test_rogue_spends_energy_and_has_no_mp() -> void:
	assert_int(_rogue_class.resource_type).is_equal(ClassData.ResourceType.ENERGY)
	assert_bool(_rogue_class.uses_talents).is_true()
	var h := _rogue(10)
	assert_int(h.max_mp()).is_equal(0)
	assert_str(_rogue_class.resource_key()).is_equal("RES_ENERGY")


func test_rogue_costs_and_cooldown() -> void:
	assert_int(_stab.mp_cost).is_equal(0)
	assert_int(_backstab.mp_cost).is_equal(35)
	assert_int(_relentless.mp_cost).is_equal(50)
	assert_int(_assassinate.mp_cost).is_equal(70)
	assert_int(_assassinate.cooldown).is_equal(3)
	assert_int(_stab.cooldown + _backstab.cooldown + _relentless.cooldown).is_equal(0)


func test_every_skill_has_two_complete_variants() -> void:
	for base in _rogue_class.skills:
		assert_object(base.fork_a).is_not_null()
		assert_object(base.fork_b).is_not_null()
		for variant in [base.fork_a, base.fork_b]:
			assert_int(variant.mp_cost).is_equal(base.mp_cost)
			assert_int(variant.cooldown).is_equal(base.cooldown)
			assert_int(variant.unlock_level).is_equal(base.unlock_level)
			assert_bool(variant.description.is_empty()).is_false()


func test_rogue_passives_and_dodge() -> void:
	assert_array(_rogue_class.passives).contains_exactly([load(OPPORTUNIST), _focus])
	assert_array(_rogue_class.reactions).contains_exactly([_dodge])
	assert_int(load(OPPORTUNIST).unlock_level).is_equal(2)
	assert_int(_focus.unlock_level).is_equal(2)
	assert_int(_dodge.unlock_level).is_equal(3)
	assert_float(_dodge_chance).is_equal_approx(0.25, 0.001)
	assert_int(_dodge.cost).is_equal(20)
	assert_float(_dodge.damage_mult).is_equal(0.0)
	assert_str(_dodge.popup_tag).is_equal("dodged")


func test_rogue_earns_talent_sp() -> void:
	assert_int(Party.talent_sp_for_level(10)).is_equal(5)
	assert_int(Hero.create(_rogue_class).sp_available).is_equal(0)


# ── Energy ────────────────────────────────────────────────────────────────────


func test_energy_starts_full_every_fight() -> void:
	var st := _fight([_rogue(10)], [_dummy()])
	assert_bool(st.party[0].uses_energy()).is_true()
	assert_bool(st.party[0].uses_rage()).is_false()
	assert_int(st.party[0].energy).is_equal(Battler.ENERGY_MAX)
	st.party[0].energy = 3
	var next_fight := _fight([st.party[0].hero], [_dummy()])
	assert_int(next_fight.party[0].energy).is_equal(100)


func test_energy_is_never_saved() -> void:
	assert_bool(_rogue(10).to_dict().has("energy")).is_false()


func test_energy_regens_25_at_the_start_of_each_turn_and_caps_at_100() -> void:
	var st := _fight([_rogue(10)], [_dummy()])
	st.start()  # the Rogue (SPD 7 against the dummy's 0) acts first
	var r := st.party[0]
	assert_object(st.current_actor).is_same(r)
	assert_int(r.energy).is_equal(100)  # already full: the regen is capped
	r.energy = 40
	st.player_action(_stab, st.enemies[0])  # Stab costs nothing
	assert_int(r.energy).is_equal(40)  # no regen mid-round
	st.step()  # the dummy acts, the next round starts, the Rogue's turn begins
	assert_object(st.current_actor).is_same(r)
	assert_int(r.energy).is_equal(65)
	r.energy = 90
	r.regen_energy()
	assert_int(r.energy).is_equal(Battler.ENERGY_MAX)


func test_skill_costs_are_paid_from_energy() -> void:
	var st := _fight([_rogue(10)], [_dummy()])
	var r := st.party[0]
	r.energy = 34
	assert_bool(st.can_use(r, _backstab)).is_false()
	r.energy = 35
	assert_bool(st.can_use(r, _backstab)).is_true()
	r.energy = 100
	_act(st, r, _backstab, st.enemies[0])
	assert_int(r.energy).is_equal(65)
	assert_int(r.hero.mp).is_equal(0)  # MP untouched
	assert_int(r.rage).is_equal(0)  # and no Rage for a Rogue


func test_assassinate_goes_on_a_three_turn_cooldown() -> void:
	var st := _fight([_rogue(10)], [_dummy()])
	var r := st.party[0]
	assert_bool(st.can_use(r, _assassinate)).is_true()
	_act(st, r, _assassinate, st.enemies[0])
	assert_int(r.energy).is_equal(30)
	r.energy = 100
	assert_bool(st.can_use(r, _assassinate)).is_false()
	assert_int(r.cooldown_left(_assassinate)).is_equal(3)


func test_a_hero_below_the_skill_level_cannot_use_it() -> void:
	var st := _fight([_rogue(2)], [_dummy()])
	assert_bool(st.can_use(st.party[0], _relentless)).is_false()  # unlocks at 3
	assert_bool(st.can_use(st.party[0], _backstab)).is_true()


# ── Stab forks ────────────────────────────────────────────────────────────────


func test_poisoned_blade_poisons_the_target() -> void:
	var st := _fight([_fork_rogue("rogue_stab", "a")], [_dummy()])
	_act(st, st.party[0], _stab, st.enemies[0])
	var poison := _status_of(st.enemies[0], CombatStatus.Kind.DOT)
	assert_object(poison).is_not_null()
	assert_int(poison.dot_damage).is_equal(3)
	assert_int(poison.duration).is_equal(2)
	assert_str(poison.dot_popup_key).is_equal("UI_POPUP_POISON")


func test_quick_strike_refunds_15_energy() -> void:
	var st := _fight([_fork_rogue("rogue_stab", "b")], [_dummy()])
	var r := st.party[0]
	r.energy = 50
	_act(st, r, _stab, st.enemies[0])
	assert_int(r.energy).is_equal(65)
	r.energy = 95
	_act(st, r, _stab, st.enemies[0])
	assert_int(r.energy).is_equal(Battler.ENERGY_MAX)  # the refund caps too


func test_plain_stab_refunds_nothing() -> void:
	var st := _fight([_rogue(10)], [_dummy()])
	st.party[0].energy = 50
	_act(st, st.party[0], _stab, st.enemies[0])
	assert_int(st.party[0].energy).is_equal(50)


# ── Backstab forks ────────────────────────────────────────────────────────────


func test_exploit_weakness_doubles_the_def_debuff_bonus() -> void:
	var base := _backstab_vs_debuffed(null)
	var exploit := _backstab_vs_debuffed("a")
	assert_bool(base["tags"].has("exposed")).is_true()
	assert_bool(exploit["tags"].has("exposed")).is_true()
	# Same seed, same roll: +100% against +50% is a third more damage.
	assert_int(exploit["amount"]).is_greater(base["amount"])
	assert_int(exploit["amount"]).is_between(
		int(floor(base["amount"] * 4.0 / 3.0)) - 1, int(ceil(base["amount"] * 4.0 / 3.0)) + 1
	)


func test_ambush_crits_a_target_that_has_not_acted() -> void:
	var st := _fight([_fork_rogue("rogue_backstab", "b")], [_dummy()])
	var hits := _record_hits(st)
	assert_bool(st.acted_this_round.has(st.enemies[0])).is_false()
	_act(st, st.party[0], _backstab, st.enemies[0])
	assert_bool(hits[0]["tags"].has("crit")).is_true()


func test_ambush_does_not_crit_a_target_that_has_acted() -> void:
	var st := _fight([_fork_rogue("rogue_backstab", "b")], [_dummy()])
	var hits := _record_hits(st)
	st.acted_this_round.append(st.enemies[0])
	_act(st, st.party[0], _backstab, st.enemies[0])
	assert_bool(hits[0]["tags"].has("crit")).is_false()


func test_acted_this_round_follows_the_turn_order() -> void:
	var st := _fight([_rogue(10)], [_dummy()])
	st.start()
	assert_array(st.acted_this_round).contains_exactly([st.party[0]])  # the Rogue is up
	st.player_action(_stab, st.enemies[0])
	assert_array(st.acted_this_round).contains_exactly([st.party[0], st.enemies[0]])
	st.step()  # next round: the list starts over
	assert_array(st.acted_this_round).contains_exactly([st.party[0]])


func test_only_the_ambush_variant_has_a_guaranteed_crit() -> void:
	assert_bool(_backstab.ambush).is_false()
	assert_bool(_backstab.fork_a.ambush).is_false()
	assert_bool(_ambush.ambush).is_true()
	assert_float(_ambush_crit).is_equal_approx(0.4, 0.001)


# ── Relentless forks ──────────────────────────────────────────────────────────


func test_flurry_hits_five_times_for_less() -> void:
	var h := _fork_rogue("rogue_relentless", "a")
	var flurry := Party.get_effective_skill(h, _relentless)
	assert_int(flurry.hits).is_equal(5)
	assert_float(flurry.power).is_equal_approx(0.55, 0.001)
	var st := _fight([h], [_dummy()])
	var hits := _record_hits(st)
	_act(st, st.party[0], _relentless, null)
	assert_int(hits.size()).is_equal(5)


func test_focus_puts_every_hit_on_the_chosen_enemy() -> void:
	var h := _fork_rogue("rogue_relentless", "b")
	var focus := Party.get_effective_skill(h, _relentless)
	assert_int(focus.target).is_equal(SkillData.TargetType.ONE)
	var st := _fight([h], [_dummy(), _dummy()])
	var struck: Array[Battler] = []
	st.damage_popup.connect(
		func(b: Battler, _a: int, _k: CombatState.PopupKind, _t: PackedStringArray):
			struck.append(b)
	)
	for i in 10:  # random targeting would split 3 hits over two enemies by now
		st.party[0].energy = 100
		st.party[0].reset_cooldown(_relentless)
		struck.clear()
		_act(st, st.party[0], _relentless, st.enemies[1])
		assert_int(struck.size()).is_equal(3)
		for b in struck:
			assert_object(b).is_same(st.enemies[1])


func test_plain_relentless_still_hits_random_enemies() -> void:
	assert_int(_relentless.target).is_equal(SkillData.TargetType.RANDOM)
	assert_int(_relentless.hits).is_equal(3)


# ── Assassinate forks ─────────────────────────────────────────────────────────


func test_mark_for_death_debuffs_the_target() -> void:
	var st := _fight([_fork_rogue("rogue_assassinate", "a")], [_dummy()])
	_act(st, st.party[0], _assassinate, st.enemies[0])
	var mark := _status_of(st.enemies[0], CombatStatus.Kind.DEBUFF)
	assert_object(mark).is_not_null()
	assert_float(mark.damage_taken_mult).is_equal_approx(1.25, 0.0001)
	assert_int(mark.duration).is_equal(2)
	assert_float(st.enemies[0].damage_taken_mult()).is_equal_approx(1.25, 0.0001)


func test_mark_for_death_amplifies_another_heros_hit() -> void:
	var slash: SkillData = load(SLASH)
	var plain := _fight([_warrior(), _rogue(10)], [_dummy()])
	var plain_hits := _record_hits(plain)
	seed(777)
	_act(plain, plain.party[0], slash, plain.enemies[0])

	var marked := _fight([_warrior(), _fork_rogue("rogue_assassinate", "a")], [_dummy()])
	_act(marked, marked.party[1], _assassinate, marked.enemies[0])
	var marked_hits := _record_hits(marked)
	seed(777)
	_act(marked, marked.party[0], slash, marked.enemies[0])

	var base: int = plain_hits[0]["amount"]
	assert_int(marked_hits[0]["amount"]).is_greater(base)
	assert_int(marked_hits[0]["amount"]).is_between(
		int(floor(base * 1.25)) - 1, int(ceil(base * 1.25)) + 1
	)


func test_mark_for_death_does_not_change_a_plain_hit() -> void:
	var st := _fight([_rogue(10)], [_dummy()])
	assert_float(st.enemies[0].damage_taken_mult()).is_equal(1.0)


func test_shadowstep_makes_the_rogue_untargetable() -> void:
	var st := _fight([_warrior(), _fork_rogue("rogue_assassinate", "b")], [_dummy()])
	var rogue := st.party[1]
	_act(st, rogue, _assassinate, st.enemies[0])
	assert_bool(rogue.is_untargetable()).is_true()
	for i in 60:
		assert_object(st._pick_hero_target(st.enemies[0])).is_same(st.party[0])


func test_shadowstep_forces_an_enemy_to_repick() -> void:
	var st := _fight([_warrior(), _fork_rogue("rogue_assassinate", "b")], [_dummy(5)])
	var rogue := st.party[1]
	_act(st, rogue, _assassinate, st.enemies[0])
	var struck: Array[Battler] = []
	st.damage_popup.connect(
		func(b: Battler, _a: int, _k: CombatState.PopupKind, _t: PackedStringArray):
			struck.append(b)
	)
	var rogue_hp := rogue.get_hp()
	for i in 12:
		_pin_next(st, st.enemies[0])
		st.step()
	assert_int(struck.size()).is_equal(12)
	for b in struck:
		assert_object(b).is_same(st.party[0])
	assert_int(rogue.get_hp()).is_equal(rogue_hp)


func test_shadowstep_does_not_stop_area_attacks() -> void:
	var st := _fight(
		[_warrior(), _fork_rogue("rogue_assassinate", "b")], [_dummy(5, SkillData.TargetType.ALL)]
	)
	var rogue := st.party[1]
	_act(st, rogue, _assassinate, st.enemies[0])
	var hp_before := rogue.get_hp()
	_pin_next(st, st.enemies[0])
	st.step()
	assert_int(rogue.get_hp()).is_less(hp_before)
	assert_int(st.party[0].get_hp()).is_less(st.party[0].max_hp)


func test_a_lone_untargetable_rogue_leaves_the_enemy_without_a_target() -> void:
	var st := _fight([_fork_rogue("rogue_assassinate", "b")], [_dummy(5)])
	_act(st, st.party[0], _assassinate, st.enemies[0])
	var hp_before := st.party[0].get_hp()
	_pin_next(st, st.enemies[0])
	st.step()
	assert_int(st.party[0].get_hp()).is_equal(hp_before)


func test_shadowstep_ends_when_the_rogues_next_turn_starts() -> void:
	var st := _fight([_fork_rogue("rogue_assassinate", "b")], [_dummy()])
	var rogue := st.party[0]
	_act(st, rogue, _assassinate, st.enemies[0])
	assert_bool(rogue.is_untargetable()).is_true()
	st.initiative.assign([rogue])
	st._advance_to_next_actor()
	assert_object(st.current_actor).is_same(rogue)
	assert_bool(rogue.is_untargetable()).is_false()


func test_shadowstep_does_not_outlast_the_fight() -> void:
	var st := _fight([_fork_rogue("rogue_assassinate", "b")], [_dummy()])
	_act(st, st.party[0], _assassinate, st.enemies[0])
	assert_bool(st.party[0].is_untargetable()).is_true()
	st._end(CombatState.Result.FLEE)
	assert_bool(st.party[0].is_untargetable()).is_false()
	assert_array(st.party[0].hero.statuses).is_empty()


# ── Passives ──────────────────────────────────────────────────────────────────


func test_opportunist_gives_energy_when_an_ally_crits() -> void:
	var st := _fight([_warrior(), _passive_rogue("opportunist")], [_dummy()])
	var rogue := st.party[1]
	rogue.energy = 50
	_act(st, st.party[0], _crit_skill(), st.enemies[0])
	assert_int(rogue.energy).is_equal(60)


func test_opportunist_ignores_a_non_crit_and_the_rogues_own_crit() -> void:
	var st := _fight([_warrior(), _passive_rogue("opportunist")], [_dummy()])
	var rogue := st.party[1]
	rogue.energy = 50
	_act(st, st.party[0], load(SLASH), st.enemies[0])
	assert_int(rogue.energy).is_equal(50)
	_act(st, rogue, _crit_skill(), st.enemies[0])
	assert_int(rogue.energy).is_equal(50)


func test_opportunist_gives_energy_when_an_enemy_is_debuffed() -> void:
	var st := _fight([_warrior(), _passive_rogue("opportunist")], [_dummy()])
	var rogue := st.party[1]
	rogue.energy = 50
	_act(st, st.party[0], _debuff_skill(), st.enemies[0])
	assert_int(rogue.energy).is_equal(60)


func test_no_passive_no_energy() -> void:
	var st := _fight([_warrior(), _rogue(10)], [_dummy()])
	st.party[1].energy = 50
	_act(st, st.party[0], _crit_skill(), st.enemies[0])
	_act(st, st.party[0], _debuff_skill(), st.enemies[0])
	assert_int(st.party[1].energy).is_equal(50)


func test_assassins_focus_adds_crit_chance_below_half_hp() -> void:
	var st := _fight([_passive_rogue("assassins_focus")], [_dummy()])
	var r := st.party[0]
	var foe := st.enemies[0]
	assert_float(r.passive_crit_bonus(foe)).is_equal(0.0)  # full HP
	foe.set_hp(int(foe.max_hp * 0.49))
	assert_float(r.passive_crit_bonus(foe)).is_equal_approx(0.2, 0.0001)
	foe.set_hp(50000)  # 50000 of 99999 is just over half
	assert_float(r.passive_crit_bonus(foe)).is_equal(0.0)  # "below" half, not at half
	var other := _fight([_rogue(10)], [_dummy()])
	other.enemies[0].set_hp(1)
	assert_float(other.party[0].passive_crit_bonus(other.enemies[0])).is_equal(0.0)


func test_assassins_focus_changes_whether_a_hit_crits() -> void:
	_focus.crit_bonus_below_half_hp = 1.0  # every weak target is a sure crit
	var st := _fight([_passive_rogue("assassins_focus")], [_dummy()])
	var hits := _record_hits(st)
	_act(st, st.party[0], _stab, st.enemies[0])  # Stab has no crit chance of its own
	assert_bool(hits[0]["tags"].has("crit")).is_false()
	st.enemies[0].set_hp(100)
	_act(st, st.party[0], _stab, st.enemies[0])
	assert_bool(hits[1]["tags"].has("crit")).is_true()


# ── Dodge ─────────────────────────────────────────────────────────────────────


func test_dodge_takes_no_damage_and_pays_energy() -> void:
	var st := _dodge_fight(true)
	var hits := _record_hits(st)
	var rogue := st.party[0]
	var hp := rogue.get_hp()
	_enemy_turn(st)
	assert_int(rogue.get_hp()).is_equal(hp)
	assert_int(rogue.energy).is_equal(80)
	assert_int(hits[0]["amount"]).is_equal(0)
	assert_bool(hits[0]["tags"].has("dodged")).is_true()
	assert_bool(hits[0]["tags"].has("parried")).is_false()


func test_dodge_needs_20_energy() -> void:
	var st := _dodge_fight(true)
	var rogue := st.party[0]
	rogue.energy = 19
	var hp := rogue.get_hp()
	_enemy_turn(st)
	assert_int(rogue.get_hp()).is_less(hp)
	assert_int(rogue.energy).is_equal(19)
	rogue.energy = 20
	hp = rogue.get_hp()
	_enemy_turn(st)
	assert_int(rogue.get_hp()).is_equal(hp)
	assert_int(rogue.energy).is_equal(0)


func test_dodge_toggled_off_does_nothing() -> void:
	var st := _dodge_fight(false)
	var rogue := st.party[0]
	var hp := rogue.get_hp()
	_enemy_turn(st)
	assert_int(rogue.get_hp()).is_less(hp)
	assert_int(rogue.energy).is_equal(100)


func test_dodge_does_not_apply_to_area_or_magic_hits() -> void:
	var area := _dodge_fight(true, SkillData.TargetType.ALL)
	var hp := area.party[0].get_hp()
	_enemy_turn(area)
	assert_int(area.party[0].get_hp()).is_less(hp)
	var magic := _dodge_fight(true, SkillData.TargetType.ONE, SkillData.SkillType.MAG)
	hp = magic.party[0].get_hp()
	_enemy_turn(magic)
	assert_int(magic.party[0].get_hp()).is_less(hp)
	assert_int(magic.party[0].energy).is_equal(100)


func test_dodge_chance_is_a_roll() -> void:
	_dodge.chance = 0.0
	var st := _dodge_fight(true)
	var hp := st.party[0].get_hp()
	_enemy_turn(st)
	assert_int(st.party[0].get_hp()).is_less(hp)
	assert_int(st.party[0].energy).is_equal(100)


func test_a_dodged_hit_gives_no_rage() -> void:
	# Parry shares the code path: a Rage hero that dodges (damage_mult 0.0)
	# gets no Rage for a hit that did nothing.
	var parry: ReactionData = load(PARRY)
	var chance := parry.chance
	var mult := parry.damage_mult
	parry.chance = 1.0
	parry.damage_mult = 0.0
	var st := _fight([_warrior()], [_dummy(5)])
	st.party[0].hero.talents[Party.REACTION_KEY] = {"id": "parry", "enabled": true}
	st.party[0].rage = 10
	_enemy_turn(st)
	parry.chance = chance
	parry.damage_mult = mult
	assert_int(st.party[0].rage).is_equal(0)  # paid 10, gained none


func test_parry_still_works_after_the_rename() -> void:
	var parry: ReactionData = load(PARRY)
	assert_int(parry.cost).is_equal(10)
	assert_str(parry.popup_tag).is_equal("parried")
	assert_float(parry.damage_mult).is_equal_approx(0.5, 0.001)
	var chance := parry.chance
	parry.chance = 1.0
	var st := _fight([_warrior()], [_dummy(8)])
	st.party[0].hero.talents[Party.REACTION_KEY] = {"id": "parry", "enabled": true}
	st.party[0].rage = 10
	var hits := _record_hits(st)
	_enemy_turn(st)
	parry.chance = chance
	assert_bool(hits[0]["tags"].has("parried")).is_true()
	assert_int(st.party[0].rage).is_equal(Battler.RAGE_PER_HIT_TAKEN)  # 10 - 10 + 20


# ── Text ──────────────────────────────────────────────────────────────────────


func test_new_descriptions_fill_their_numbers() -> void:
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var h := _fork_rogue("rogue_assassinate", "a")
	(
		assert_str(SkillText.describe(Party.get_effective_skill(h, _assassinate)))
		. is_equal(
			"A lethal blow with a 60% crit chance. The target takes +25% damage from everyone for 2 turns."
		)
	)
	assert_str(SkillText.describe_passive(load(OPPORTUNIST))).is_equal(
		"+10 Energy whenever an ally lands a crit, and +10 whenever an enemy receives a debuff."
	)
	assert_str(SkillText.describe_passive(_focus)).is_equal(
		"+20% crit chance against targets below 50% HP."
	)
	assert_str(SkillText.describe_reaction(_dodge)).is_equal(
		(
			"When hit by a single-target physical attack, a 100% chance to take no damage."
			+ " Costs 20 Energy."
		)
	)
	var quick := Party.get_effective_skill(_fork_rogue("rogue_stab", "b"), _stab)
	assert_str(SkillText.describe(quick)).is_equal("A basic strike that refunds 15 Energy.")
	TranslationServer.set_locale(locale)


# ── Save ──────────────────────────────────────────────────────────────────────


func test_rogue_talents_round_trip_through_json() -> void:
	var h := _rogue(10)
	h.sp_available = 1
	h.talents = {
		"rogue_stab": {"fork": "b", "boost": true},
		"rogue_backstab": {"fork": "b", "boost": false},
		"rogue_relentless": {"fork": "a", "boost": false},
		"rogue_assassinate": {"fork": "b", "boost": true},
		Party.PASSIVE_KEY: "assassins_focus",
		Party.REACTION_KEY: {"id": "dodge", "enabled": false},
	}
	var back := Hero.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	assert_dict(back.talents).is_equal(h.talents)
	assert_int(back.sp_available).is_equal(1)
	assert_object(back.class_data).is_same(_rogue_class)
	assert_object(Party.get_effective_skill(back, _backstab)).is_same(_backstab.fork_b)
	assert_object(Party.get_passive(back)).is_same(_focus)
	assert_object(Party.get_reaction(back)).is_same(_dodge)
	assert_bool(Party.is_reaction_enabled(back)).is_false()


func test_new_status_fields_round_trip() -> void:
	var st := CombatStatus.new()
	st.damage_taken_mult = 1.25
	st.untargetable = true
	var back := CombatStatus.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())))
	assert_float(back.damage_taken_mult).is_equal_approx(1.25, 0.0001)
	assert_bool(back.untargetable).is_true()
	# A status saved before the fields gets the defaults.
	var old := CombatStatus.from_dict({"kind": 1, "dur": 2})
	assert_float(old.damage_taken_mult).is_equal(1.0)
	assert_bool(old.untargetable).is_false()


func test_an_old_rogue_save_loads_without_mp() -> void:
	var data := _rogue(5).to_dict()
	data["mp"] = 14  # the Rogue used to hold MP
	var back := Hero.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_int(back.mp).is_equal(0)
	assert_int(back.max_mp()).is_equal(0)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _rogue(level: int) -> Hero:
	var h := Hero.create(_rogue_class)
	h.level = level
	h.hp = h.max_hp()
	return h


## A level-10 Rogue with `fork` ("a"/"b") picked on the skill `key`.
func _fork_rogue(key: String, fork: String) -> Hero:
	var h := _rogue(10)
	h.talents[key] = {"fork": fork, "boost": false}
	return h


func _passive_rogue(passive_id: String) -> Hero:
	var h := _rogue(10)
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
	e.skills = [hit] as Array[SkillData]
	return e


## A Rogue (Dodge learned, on or off) against one dummy that hits hard.
func _dodge_fight(
	dodge_on: bool,
	target := SkillData.TargetType.ONE,
	kind := SkillData.SkillType.PHYS,
) -> CombatState:
	var h := _rogue(10)
	h.talents[Party.REACTION_KEY] = {"id": "dodge", "enabled": dodge_on}
	return _fight([h], [_dummy(30, target, kind)])


## A skill that always crits, for the Opportunist tests.
func _crit_skill() -> SkillData:
	var s := SkillData.new()
	s.id = "sure_crit"
	s.display_name = "sure_crit"
	s.crit_chance = 1.0
	return s


## A skill that only debuffs, for the Opportunist tests.
func _debuff_skill() -> SkillData:
	var s := SkillData.new()
	s.id = "weaken"
	s.display_name = "weaken"
	s.skill_type = SkillData.SkillType.DEBUFF
	s.mod_def = -3
	s.mod_duration = 2
	return s


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


## A level-10 Rogue (the Backstab `fork`, or none) Backstabs a dummy whose DEF
## is debuffed, with a fixed seed. Returns that hit's {amount, tags}.
func _backstab_vs_debuffed(fork) -> Dictionary:
	var h := _rogue(10)
	if fork != null:
		h.talents["rogue_backstab"] = {"fork": fork, "boost": false}
	var st := _fight([h], [_dummy()])
	var debuff := CombatStatus.new()
	debuff.kind = CombatStatus.Kind.DEBUFF
	debuff.mod_def = -3
	debuff.duration = 5
	st.enemies[0].statuses.append(debuff)
	var hits := _record_hits(st)
	seed(4242)
	_act(st, st.party[0], _backstab, st.enemies[0])
	return hits[0]


## Makes `b` the next to act, so the end of an action doesn't roll a new round
## (and refill a Rogue's Energy) under the assertion.
func _pin_next(st: CombatState, b: Battler) -> void:
	st.initiative.assign([b])


## `actor` uses `skill` now, whoever's turn it was.
func _act(st: CombatState, actor: Battler, skill: SkillData, target: Battler) -> void:
	st.current_actor = actor
	_pin_next(st, st.enemies[0])
	st.player_action(skill, target)


## The dummy takes a turn.
func _enemy_turn(st: CombatState) -> void:
	st.current_actor = st.enemies[0]
	_pin_next(st, st.enemies[0])
	st.step()
