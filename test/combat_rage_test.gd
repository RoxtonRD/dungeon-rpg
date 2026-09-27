## The Warrior's Rage and skill cooldowns (#38): Rage starts at 0, +10 per
## damaging action, +20 per hit taken (not for a barrier-blocked hit or a DoT
## tick), capped at 100, skill costs paid from it, and Execute's cooldown.
##
## Fights are built directly with CombatState.build against a practice dummy
## that can't die, and turns are driven by hand, so nothing here is random
## except damage rolls, which the assertions never depend on.
extends GdUnitTestSuite

const WARRIOR := "res://resources/classes/warrior.tres"
const MAGE := "res://resources/classes/mage.tres"
const SLASH := "res://resources/skills/warrior_slash.tres"
const CLEAVE := "res://resources/skills/warrior_cleave.tres"
const EXECUTE := "res://resources/skills/warrior_execute.tres"
const FIREBALL := "res://resources/skills/mage_fireball.tres"

var _slash: SkillData
var _cleave: SkillData
var _execute: SkillData


func before_test() -> void:
	_slash = load(SLASH)
	_cleave = load(CLEAVE)
	_execute = load(EXECUTE)


# ── Rage ──────────────────────────────────────────────────────────────────────


func test_rage_starts_at_zero() -> void:
	var st := _fight(1)
	assert_int(_warrior(st).rage).is_equal(0)
	st.start()
	assert_int(_warrior(st).rage).is_equal(0)


func test_warrior_has_no_mp() -> void:
	var st := _fight(1)
	assert_int(_warrior(st).hero.max_mp()).is_equal(0)
	assert_bool(_warrior(st).uses_rage()).is_true()


func test_damaging_action_gives_10() -> void:
	var st := _fight(1)
	_act(st, _slash, st.enemies[0])
	assert_int(_warrior(st).rage).is_equal(Battler.RAGE_PER_DAMAGING_ACTION)


func test_aoe_hitting_three_still_gives_10_once() -> void:
	var st := _fight(3)
	var w := _warrior(st)
	w.rage = _cleave.mp_cost
	_act(st, _cleave, null)
	assert_int(w.rage).is_equal(Battler.RAGE_PER_DAMAGING_ACTION)


func test_hit_taken_gives_20() -> void:
	var st := _fight(1)
	_enemy_hits_warrior(st)
	assert_int(_warrior(st).rage).is_equal(Battler.RAGE_PER_HIT_TAKEN)


func test_barrier_blocked_hit_gives_nothing() -> void:
	var st := _fight(1)
	var barrier := CombatStatus.new()
	barrier.kind = CombatStatus.Kind.BARRIER
	barrier.duration = 99
	_warrior(st).statuses.append(barrier)
	_enemy_hits_warrior(st)
	assert_int(_warrior(st).rage).is_equal(0)


func test_dot_tick_gives_nothing() -> void:
	var st := _fight(1)
	var dot := CombatStatus.new()
	dot.kind = CombatStatus.Kind.DOT
	dot.dot_damage = 3
	dot.duration = 2
	_warrior(st).statuses.append(dot)
	st._tick_statuses()
	assert_int(_warrior(st).rage).is_equal(0)


func test_rage_caps_at_100() -> void:
	var st := _fight(1)
	var w := _warrior(st)
	w.rage = 90
	_enemy_hits_warrior(st)
	assert_int(w.rage).is_equal(Battler.RAGE_MAX)
	_enemy_hits_warrior(st)
	assert_int(w.rage).is_equal(Battler.RAGE_MAX)


func test_costs_are_paid_from_rage() -> void:
	var st := _fight(3)
	var w := _warrior(st)
	# Not enough Rage: the gate says no and the action does nothing.
	w.rage = _cleave.mp_cost - 1
	assert_bool(st.can_use(w, _cleave)).is_false()
	_act(st, _cleave, null)
	assert_int(w.rage).is_equal(_cleave.mp_cost - 1)
	# Enough: pay 30, then +10 for the damage.
	w.rage = 50
	assert_bool(st.can_use(w, _cleave)).is_true()
	_act(st, _cleave, null)
	assert_int(w.rage).is_equal(50 - _cleave.mp_cost + Battler.RAGE_PER_DAMAGING_ACTION)
	assert_int(w.hero.mp).is_equal(0)


func test_mana_class_still_pays_mp() -> void:
	var mage := Hero.create(load(MAGE))
	var st := CombatState.build([mage] as Array[Hero], [_dummy()] as Array[EnemyData])
	var b := st.party[0]
	var skill: SkillData = load(FIREBALL)
	var mp_before := mage.mp
	st.current_actor = b
	st.player_action(skill, st.enemies[0])
	assert_int(mage.mp).is_equal(mp_before - skill.mp_cost)
	assert_int(b.rage).is_equal(0)


# ── Cooldowns ─────────────────────────────────────────────────────────────────


func test_execute_cools_down_for_three_warrior_turns() -> void:
	var st := _fight(1, 5)
	var w := _warrior(st)
	w.rage = Battler.RAGE_MAX
	assert_bool(st.can_use(w, _execute)).is_true()
	_act(st, _execute, st.enemies[0])
	assert_bool(st.can_use(w, _execute)).is_false()

	# Set to 3; each Warrior turn start counts it down by one; usable at 0.
	# (The turn loop may hand the Warrior the very next turn, so the first
	# value we can see is already 2.)
	w.rage = Battler.RAGE_MAX
	_to_warrior_turn(st)
	assert_int(w.cooldown_left(_execute)).is_equal(2)
	assert_bool(st.can_use(w, _execute)).is_false()
	_act(st, _slash, st.enemies[0])
	_to_warrior_turn(st)
	assert_int(w.cooldown_left(_execute)).is_equal(1)
	assert_bool(st.can_use(w, _execute)).is_false()
	_act(st, _slash, st.enemies[0])
	_to_warrior_turn(st)
	assert_int(w.cooldown_left(_execute)).is_equal(0)
	assert_bool(st.can_use(w, _execute)).is_true()


func test_using_execute_sets_its_cooldown() -> void:
	var st := _fight(1, 5)
	var w := _warrior(st)
	w.start_cooldown(_execute)
	assert_int(w.cooldown_left(_execute)).is_equal(3)
	assert_int(w.cooldown_left(_slash)).is_equal(0)


func test_execute_is_locked_below_its_level() -> void:
	var st := _fight(1, 4)
	var w := _warrior(st)
	w.rage = Battler.RAGE_MAX
	assert_bool(st.can_use(w, _execute)).is_false()


# ── Helpers ───────────────────────────────────────────────────────────────────


## A fight: one Warrior at `level` against `enemy_count` unkillable dummies.
func _fight(enemy_count: int, level: int = 1) -> CombatState:
	var warrior := Hero.create(load(WARRIOR))
	warrior.level = level
	warrior.hp = warrior.max_hp()
	var enemies: Array[EnemyData] = []
	for i in enemy_count:
		enemies.append(_dummy())
	return CombatState.build([warrior] as Array[Hero], enemies)


## A practice dummy: huge HP, no defence, a weak single-target hit.
func _dummy() -> EnemyData:
	var hit := SkillData.new()
	hit.id = "dummy_hit"
	hit.display_name = "dummy_hit"
	hit.skill_type = SkillData.SkillType.PHYS
	hit.target = SkillData.TargetType.ONE
	hit.power = 0.1
	var e := EnemyData.new()
	e.id = "dummy"
	e.display_name = "dummy"
	e.max_hp = 99999
	e.atk = 1
	e.skills = [hit] as Array[SkillData]
	return e


func _warrior(st: CombatState) -> Battler:
	return st.party[0]


## The Warrior uses `skill` now, whoever's turn it was.
func _act(st: CombatState, skill: SkillData, target: Battler) -> void:
	st.current_actor = _warrior(st)
	st.player_action(skill, target)


## The first dummy takes a turn; the Warrior is its only possible target.
func _enemy_hits_warrior(st: CombatState) -> void:
	st.current_actor = st.enemies[0]
	st.step()


## Plays enemy turns through the real turn loop until the Warrior's next turn
## starts (which is when cooldowns count down).
func _to_warrior_turn(st: CombatState) -> void:
	for i in 20:
		if st.current_actor == _warrior(st):
			return
		st.step()
	fail("The Warrior never got a turn")
