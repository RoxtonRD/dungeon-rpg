## Encounters E6a (#95): per-dungeon difficulty tables. DUNGEON_MULT scales
## every enemy by dungeon, ELITE_MULT stacks on top only for enemies rolled for
## an elite room, and bosses use DUNGEON_MULT alone.
##
## ELITE_MULT is all 1.0 for now, so the elite tests run on a DungeonRun whose
## elite multiplier is forced to EliteRun.MULT: otherwise "applied" and "not
## applied" would look the same.
extends GdUnitTestSuite

const ENEMY_DIR := "res://resources/enemies/"


## A run with a fixed elite multiplier, so the tests can tell it was applied.
class EliteRun:
	extends DungeonRun

	const MULT := 2.0

	func _elite_mult() -> float:
		return MULT


func _elite_run(dungeon_level: int) -> DungeonRun:
	var run := EliteRun.new()
	run.level = dungeon_level
	for f in DungeonRun.NUM_FLOORS:
		run.floors.append({})
	return run


## Every field _scale_enemy multiplies, in a fixed order.
func _stats(e: EnemyData) -> Array[int]:
	return [e.max_hp, e.atk, e.def, e.mag, e.spd, e.xp_reward, e.gold_min, e.gold_max]


func _expected(base: EnemyData, mult: float) -> Array[int]:
	var out: Array[int] = []
	for v in _stats(base):
		out.append(roundi(v * mult))
	return out


func _base(id: String) -> EnemyData:
	return load(ENEMY_DIR + id + ".tres") as EnemyData


# ── Table lookup ──────────────────────────────────────────────────────────────


func test_dungeon_mult_reads_the_table() -> void:
	for i in DungeonRun.DUNGEON_MULT.size():
		assert_float(DungeonRun.dungeon_mult(i + 1)).is_equal(DungeonRun.DUNGEON_MULT[i])


func test_dungeon_mult_matches_the_old_growth_formula() -> void:
	# E6a must not change any value: the table equals pow(1.6, level-1).
	for dungeon_level in range(1, 9):
		assert_float(DungeonRun.dungeon_mult(dungeon_level)).is_equal_approx(
			pow(DungeonRun.DUNGEON_GROWTH, dungeon_level - 1), 1e-9
		)


func test_dungeon_mult_extrapolates_past_the_table() -> void:
	var size := DungeonRun.DUNGEON_MULT.size()
	var last: float = DungeonRun.DUNGEON_MULT[size - 1]
	var growth := DungeonRun.DUNGEON_GROWTH
	assert_float(DungeonRun.dungeon_mult(size + 1)).is_equal_approx(last * growth, 1e-9)
	assert_float(DungeonRun.dungeon_mult(size + 3)).is_equal_approx(
		last * growth * growth * growth, 1e-9
	)


func test_elite_mult_reads_the_table_and_holds_the_last_value() -> void:
	var size := DungeonRun.ELITE_MULT.size()
	for i in size:
		assert_float(DungeonRun.elite_mult(i + 1)).is_equal(DungeonRun.ELITE_MULT[i])
	var last: float = DungeonRun.ELITE_MULT[size - 1]
	assert_float(DungeonRun.elite_mult(size + 1)).is_equal(last)
	assert_float(DungeonRun.elite_mult(size + 10)).is_equal(last)


func test_scale_enemy_uses_the_dungeon_table() -> void:
	var base := _base("goblin")
	var run := DungeonRun.new()
	run.level = 1
	# The baseline is the untouched resource.
	assert_object(run._scale_enemy(base, 1)).is_same(base)
	for dungeon_level in range(2, 7):
		run.level = dungeon_level
		var scaled := run._scale_enemy(base, 1)
		assert_array(_stats(scaled)).is_equal(
			_expected(base, DungeonRun.dungeon_mult(dungeon_level))
		)


# ── Elite multiplier ──────────────────────────────────────────────────────────


func test_elite_mult_applies_only_to_elite_rooms() -> void:
	for dungeon_level in range(1, 6):
		var run := _elite_run(dungeon_level)
		var dmult := DungeonRun.dungeon_mult(dungeon_level)
		for floor_index in range(1, DungeonRun.NUM_FLOORS):
			for roll in 10:
				for e in run.roll_encounter(floor_index):
					assert_array(_stats(e)).is_equal(_expected(_base(e.id), dmult))
				for e in run.roll_encounter(floor_index, true):
					assert_array(_stats(e)).is_equal(_expected(_base(e.id), dmult * EliteRun.MULT))


func test_bosses_ignore_the_elite_mult() -> void:
	for dungeon_level in range(1, 6):
		var run := _elite_run(dungeon_level)
		var dmult := DungeonRun.dungeon_mult(dungeon_level)
		for b in DungeonRun.BOSS_ENCOUNTERS.size():
			run.boss = b
			# Boss resources' ids differ from their file names, so pair each
			# enemy with the file it was loaded from.
			var files: Array = DungeonRun.BOSS_ENCOUNTERS[b]
			var fight := run.roll_boss()
			assert_int(fight.size()).is_equal(files.size())
			for i in fight.size():
				assert_array(_stats(fight[i])).is_equal(_expected(_base(files[i]), dmult))


# ── Dev tools ─────────────────────────────────────────────────────────────────


func test_dev_spawned_elite_groups_get_the_elite_mult() -> void:
	# DevTools.start_encounter scales groups through _encounter_enemies: an
	# elite group must match a real elite room, a normal group must not.
	var run := _elite_run(2)
	var dmult := DungeonRun.dungeon_mult(2)
	var saw_elite := false
	var saw_normal := false
	for group in EncounterGroupData.all():
		run.current_floor = group.floor_min - 1
		var mult := dmult * EliteRun.MULT if group.elite else dmult
		var fight: Array[EnemyData] = DevTools._encounter_enemies(run, group)
		assert_int(fight.size()).is_equal(group.members.size())
		for i in fight.size():
			assert_array(_stats(fight[i])).is_equal(_expected(_base(group.members[i]), mult))
		saw_elite = saw_elite or group.elite
		saw_normal = saw_normal or not group.elite
	assert_bool(saw_elite).is_true()
	assert_bool(saw_normal).is_true()
