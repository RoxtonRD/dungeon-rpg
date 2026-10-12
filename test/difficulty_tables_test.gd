## Encounters E6a (#95) / E6c (#104): per-dungeon difficulty tables.
## DUNGEON_MULT scales every enemy's stats by dungeon, REWARD_MULT its XP and
## gold. For enemies rolled for an elite room, ELITE_HP_MULT (max HP, DEF),
## ELITE_POWER_MULT (ATK, MAG, SPD) and ELITE_REWARD_MULT (XP, gold) stack on
## top. Bosses never get the elite factors.
##
## The real tables hold equal values where E6c split one table in two
## (REWARD_MULT = DUNGEON_MULT; the three elite tables match), and every
## elite value is 1.0 in dungeon 1. So most scaling tests run on a FixedRun
## whose multipliers are forced to distinct values: otherwise "this table" and
## "that table" would look the same.
extends GdUnitTestSuite

const ENEMY_DIR := "res://resources/enemies/"


## A run with fixed multipliers, so the tests can tell which one was applied.
class FixedRun:
	extends DungeonRun

	var dungeon := 1.0
	var reward := 1.0
	var elite_hp := 1.0
	var elite_power := 1.0
	var elite_reward := 1.0

	func _dungeon_mult() -> float:
		return dungeon

	func _reward_mult() -> float:
		return reward

	func _elite_hp_mult() -> float:
		return elite_hp

	func _elite_power_mult() -> float:
		return elite_power

	func _elite_reward_mult() -> float:
		return elite_reward


## A FixedRun for `dungeon_level` with the real dungeon and reward multipliers
## and distinct elite ones (HP 2.0, power 3.0, reward 4.0).
func _elite_run(dungeon_level: int) -> FixedRun:
	var run := FixedRun.new()
	run.level = dungeon_level
	run.dungeon = DungeonRun.dungeon_mult(dungeon_level)
	run.reward = DungeonRun.reward_mult(dungeon_level)
	run.elite_hp = 2.0
	run.elite_power = 3.0
	run.elite_reward = 4.0
	for f in DungeonRun.NUM_FLOORS:
		run.floors.append({})
	return run


## Every field _scale_enemy multiplies, grouped by the multiplier it follows:
## [max_hp, def | atk, mag, spd | xp_reward, gold_min, gold_max].
func _stats(e: EnemyData) -> Array[int]:
	return [e.max_hp, e.def, e.atk, e.mag, e.spd, e.xp_reward, e.gold_min, e.gold_max]


func _expected(base: EnemyData, hp: float, power: float, reward: float) -> Array[int]:
	return [
		roundi(base.max_hp * hp),
		roundi(base.def * hp),
		roundi(base.atk * power),
		roundi(base.mag * power),
		roundi(base.spd * power),
		roundi(base.xp_reward * reward),
		roundi(base.gold_min * reward),
		roundi(base.gold_max * reward),
	]


func _base(id: String) -> EnemyData:
	return load(ENEMY_DIR + id + ".tres") as EnemyData


# ── Table lookup ──────────────────────────────────────────────────────────────


func test_dungeon_mult_reads_the_table() -> void:
	for i in DungeonRun.DUNGEON_MULT.size():
		assert_float(DungeonRun.dungeon_mult(i + 1)).is_equal(DungeonRun.DUNGEON_MULT[i])


func test_dungeon_mult_starts_at_the_baseline_and_rises() -> void:
	# E6b (#96) tuned the table away from pow(1.6, level-1). D1 is the 1.0
	# baseline, and every dungeon must be harder than the one before, past
	# the table's end too.
	assert_float(DungeonRun.dungeon_mult(1)).is_equal(1.0)
	for dungeon_level in range(2, 9):
		assert_float(DungeonRun.dungeon_mult(dungeon_level)).is_greater(
			DungeonRun.dungeon_mult(dungeon_level - 1)
		)


func test_dungeon_mult_extrapolates_past_the_table() -> void:
	var size := DungeonRun.DUNGEON_MULT.size()
	var last: float = DungeonRun.DUNGEON_MULT[size - 1]
	var growth := DungeonRun.DUNGEON_GROWTH
	assert_float(DungeonRun.dungeon_mult(size + 1)).is_equal_approx(last * growth, 1e-9)
	assert_float(DungeonRun.dungeon_mult(size + 3)).is_equal_approx(
		last * growth * growth * growth, 1e-9
	)


func test_reward_mult_reads_the_table_and_extrapolates() -> void:
	var size := DungeonRun.REWARD_MULT.size()
	for i in size:
		assert_float(DungeonRun.reward_mult(i + 1)).is_equal(DungeonRun.REWARD_MULT[i])
	var last: float = DungeonRun.REWARD_MULT[size - 1]
	var growth := DungeonRun.REWARD_GROWTH
	assert_float(DungeonRun.reward_mult(size + 1)).is_equal_approx(last * growth, 1e-9)
	assert_float(DungeonRun.reward_mult(size + 3)).is_equal_approx(
		last * growth * growth * growth, 1e-9
	)


func test_elite_hp_mult_reads_the_table_and_holds_the_last_value() -> void:
	var size := DungeonRun.ELITE_HP_MULT.size()
	for i in size:
		assert_float(DungeonRun.elite_hp_mult(i + 1)).is_equal(DungeonRun.ELITE_HP_MULT[i])
	var last: float = DungeonRun.ELITE_HP_MULT[size - 1]
	assert_float(DungeonRun.elite_hp_mult(size + 1)).is_equal(last)
	assert_float(DungeonRun.elite_hp_mult(size + 10)).is_equal(last)


func test_elite_reward_mult_reads_the_table_and_holds_the_last_value() -> void:
	var size := DungeonRun.ELITE_REWARD_MULT.size()
	for i in size:
		assert_float(DungeonRun.elite_reward_mult(i + 1)).is_equal(DungeonRun.ELITE_REWARD_MULT[i])
	var last: float = DungeonRun.ELITE_REWARD_MULT[size - 1]
	assert_float(DungeonRun.elite_reward_mult(size + 1)).is_equal(last)
	assert_float(DungeonRun.elite_reward_mult(size + 10)).is_equal(last)


func test_elite_power_mult_reads_the_table_and_holds_the_last_value() -> void:
	var size := DungeonRun.ELITE_POWER_MULT.size()
	for i in size:
		assert_float(DungeonRun.elite_power_mult(i + 1)).is_equal(DungeonRun.ELITE_POWER_MULT[i])
	var last: float = DungeonRun.ELITE_POWER_MULT[size - 1]
	assert_float(DungeonRun.elite_power_mult(size + 1)).is_equal(last)
	assert_float(DungeonRun.elite_power_mult(size + 10)).is_equal(last)


# ── _scale_enemy ──────────────────────────────────────────────────────────────


func test_scale_enemy_uses_the_real_tables() -> void:
	var base := _base("goblin")
	var run := DungeonRun.new()
	run.level = 1
	# Every multiplier is 1.0 in dungeon 1: the untouched resource.
	assert_object(run._scale_enemy(base, 1)).is_same(base)
	for dungeon_level in range(2, 7):
		run.level = dungeon_level
		var d := DungeonRun.dungeon_mult(dungeon_level)
		assert_array(_stats(run._scale_enemy(base, 1))).is_equal(
			_expected(base, d, d, DungeonRun.reward_mult(dungeon_level))
		)


func test_mult_below_one_scales_down() -> void:
	# Before E6c, _scale_enemy ignored any multiplier at or below 1.0.
	var base := _base("orc")
	var before := _stats(base)
	var run := FixedRun.new()
	run.dungeon = 0.5
	run.reward = 0.5
	var scaled := run._scale_enemy(base, 1)
	assert_object(scaled).is_not_same(base)
	assert_array(_stats(scaled)).is_equal(_expected(base, 0.5, 0.5, 0.5))
	assert_int(scaled.max_hp).is_less(base.max_hp)
	# The .tres asset itself is never mutated.
	assert_array(_stats(base)).is_equal(before)
	# Elite factors below 1.0 apply too.
	run.dungeon = 1.0
	run.reward = 1.0
	run.elite_hp = 0.5
	run.elite_power = 0.8
	run.elite_reward = 0.25
	assert_array(_stats(run._scale_enemy(base, 1, true))).is_equal(_expected(base, 0.5, 0.8, 0.25))


func test_rewards_follow_reward_mult_not_dungeon_mult() -> void:
	var base := _base("orc")
	var run := FixedRun.new()
	run.dungeon = 2.0
	run.reward = 0.5
	assert_array(_stats(run._scale_enemy(base, 1))).is_equal(_expected(base, 2.0, 2.0, 0.5))
	# Rewards alone can scale while the stats stay at base.
	run.dungeon = 1.0
	run.reward = 3.0
	assert_array(_stats(run._scale_enemy(base, 1))).is_equal(_expected(base, 1.0, 1.0, 3.0))


func test_elite_hp_and_power_scale_independently() -> void:
	var base := _base("orc")
	var run := FixedRun.new()
	run.elite_hp = 2.0
	assert_array(_stats(run._scale_enemy(base, 1, true))).is_equal(_expected(base, 2.0, 1.0, 1.0))
	run.elite_hp = 1.0
	run.elite_power = 3.0
	assert_array(_stats(run._scale_enemy(base, 1, true))).is_equal(_expected(base, 1.0, 3.0, 1.0))
	# A non-elite enemy ignores every elite factor.
	run.elite_reward = 4.0
	assert_object(run._scale_enemy(base, 1)).is_same(base)


func test_elite_rewards_follow_elite_reward_mult_not_elite_hp_mult() -> void:
	var base := _base("orc")
	var run := FixedRun.new()
	run.reward = 2.0
	run.elite_hp = 3.0
	run.elite_reward = 0.5
	assert_array(_stats(run._scale_enemy(base, 1, true))).is_equal(_expected(base, 3.0, 1.0, 1.0))
	# Elite rewards alone can scale while elite HP stays at 1.0.
	run.elite_hp = 1.0
	run.elite_reward = 1.5
	assert_array(_stats(run._scale_enemy(base, 1, true))).is_equal(_expected(base, 1.0, 1.0, 3.0))


# ── Elite multipliers ─────────────────────────────────────────────────────────


func test_elite_mults_apply_only_to_elite_rooms() -> void:
	for dungeon_level in range(1, 6):
		var run := _elite_run(dungeon_level)
		var d := run.dungeon
		var r := run.reward
		for floor_index in range(1, DungeonRun.NUM_FLOORS):
			for roll in 10:
				for e in run.roll_encounter(floor_index):
					assert_array(_stats(e)).is_equal(_expected(_base(e.id), d, d, r))
				for e in run.roll_encounter(floor_index, true):
					assert_array(_stats(e)).is_equal(
						_expected(
							_base(e.id), d * run.elite_hp, d * run.elite_power, r * run.elite_reward
						)
					)


func test_bosses_ignore_the_elite_mults() -> void:
	for dungeon_level in range(1, 6):
		var run := _elite_run(dungeon_level)
		var d := run.dungeon
		var r := run.reward
		for b in DungeonRun.BOSS_ENCOUNTERS.size():
			run.boss = b
			# Boss resources' ids differ from their file names, so pair each
			# enemy with the file it was loaded from.
			var files: Array = DungeonRun.BOSS_ENCOUNTERS[b]
			var fight := run.roll_boss()
			assert_int(fight.size()).is_equal(files.size())
			for i in fight.size():
				assert_array(_stats(fight[i])).is_equal(_expected(_base(files[i]), d, d, r))


# ── Dev tools ─────────────────────────────────────────────────────────────────


func test_dev_spawned_elite_groups_get_every_elite_mult() -> void:
	# DevTools.start_encounter scales groups through _encounter_enemies: an
	# elite group must match a real elite room, a normal group must not.
	var run := _elite_run(2)
	var d := run.dungeon
	var r := run.reward
	var saw_elite := false
	var saw_normal := false
	for group in EncounterGroupData.all():
		run.current_floor = group.floor_min - 1
		var hp := d * run.elite_hp if group.elite else d
		var power := d * run.elite_power if group.elite else d
		var reward := r * run.elite_reward if group.elite else r
		var fight: Array[EnemyData] = DevTools._encounter_enemies(run, group)
		assert_int(fight.size()).is_equal(group.members.size())
		for i in fight.size():
			assert_array(_stats(fight[i])).is_equal(
				_expected(_base(group.members[i]), hp, power, reward)
			)
		saw_elite = saw_elite or group.elite
		saw_normal = saw_normal or not group.elite
	assert_bool(saw_elite).is_true()
	assert_bool(saw_normal).is_true()
