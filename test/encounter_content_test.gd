## Encounters E2 content (#78, D-038): the authored roster and group tables.
## encounters_test covers the engine and the shape of every group (sizes,
## front row, telegraph limits, FALLBACK_IDS); this suite covers what each
## floor offers and that the roster is complete.
extends GdUnitTestSuite

const TestUtil := preload("res://test/support/test_util.gd")
const ENEMY_DIR := "res://resources/enemies/"
## Minimum normal groups on every floor, and elite groups on floors 2-4.
const MIN_NORMAL_GROUPS := 4
const MIN_ELITE_GROUPS := 1


## Every enemy resource, keyed by its file basename (the id groups use).
func _enemies() -> Dictionary:
	var out := {}
	for path in TestUtil.find_files(ENEMY_DIR.trim_suffix("/"), ".tres"):
		out[path.get_file().get_basename()] = load(path)
	return out


func test_every_floor_has_enough_groups() -> void:
	var problems: PackedStringArray = []
	for floor_num in range(1, DungeonRun.NUM_FLOORS + 1):
		var normal := EncounterGroupData.candidates(floor_num, false).size()
		if normal < MIN_NORMAL_GROUPS:
			problems.append("F%d: %d normal groups" % [floor_num, normal])
		if floor_num >= 2:
			var elite := EncounterGroupData.candidates(floor_num, true).size()
			if elite < MIN_ELITE_GROUPS:
				problems.append("F%d: %d elite groups" % [floor_num, elite])
	(
		assert_array(problems)
		. override_failure_message(TestUtil.problem_list("Thin floors", problems))
		. is_empty()
	)


func test_every_group_member_resolves() -> void:
	var problems: PackedStringArray = []
	assert_array(EncounterGroupData.all()).is_not_empty()
	for group in EncounterGroupData.all():
		for member in group.members:
			var path := ENEMY_DIR + member + ".tres"
			if not ResourceLoader.exists(path):
				problems.append("%s: no enemy '%s'" % [group.id, member])
				continue
			var e := load(path) as EnemyData
			if e == null or e.id != member:
				problems.append("%s: '%s' does not load as that enemy" % [group.id, member])
	(
		assert_array(problems)
		. override_failure_message(TestUtil.problem_list("Unresolved members", problems))
		. is_empty()
	)


func test_every_enemy_has_an_ai_role() -> void:
	var problems: PackedStringArray = []
	var enemies := _enemies()
	assert_dict(enemies).is_not_empty()
	for id in enemies:
		var e := enemies[id] as EnemyData
		if not EnemyData.AiRole.values().has(e.ai_role):
			problems.append("%s: ai_role %d" % [id, e.ai_role])
	(
		assert_array(problems)
		. override_failure_message(TestUtil.problem_list("Enemies without a role", problems))
		. is_empty()
	)


func test_no_normal_group_has_more_than_one_support() -> void:
	var problems: PackedStringArray = []
	for group in EncounterGroupData.all():
		if group.elite:
			continue
		var supports := 0
		for member in group.members:
			var e := load(ENEMY_DIR + member + ".tres") as EnemyData
			if e != null and e.ai_role == EnemyData.AiRole.SUPPORT:
				supports += 1
		if supports > 1:
			problems.append("%s: %d supports" % [group.id, supports])
	(
		assert_array(problems)
		. override_failure_message(TestUtil.problem_list("Too many supports", problems))
		. is_empty()
	)


## An enemy in no group never spawns (bosses come from BOSS_ENCOUNTERS).
func test_every_enemy_appears_in_a_group() -> void:
	var used := {}
	for group in EncounterGroupData.all():
		for member in group.members:
			used[member] = true
	var problems: PackedStringArray = []
	var enemies := _enemies()
	for id in enemies:
		if not (enemies[id] as EnemyData).is_boss and not used.has(id):
			problems.append(id)
	(
		assert_array(problems)
		. override_failure_message(TestUtil.problem_list("Enemies in no group", problems))
		. is_empty()
	)


func test_e2_enemies_have_their_roles_and_rows() -> void:
	var expected := {
		"goblin_shaman": [EnemyData.AiRole.SUPPORT, EnemyData.Role.BACK],
		"wolf_alpha": [EnemyData.AiRole.SUPPORT, EnemyData.Role.FRONT],
		"skeleton_archer": [EnemyData.AiRole.SKIRMISHER, EnemyData.Role.BACK],
		"orc_warlord": [EnemyData.AiRole.BRUTE, EnemyData.Role.FRONT],
		"cultist": [EnemyData.AiRole.CASTER, EnemyData.Role.BACK],
	}
	for id in expected:
		var e: EnemyData = load(ENEMY_DIR + id + ".tres")
		assert_int(e.ai_role).override_failure_message(id).is_equal(expected[id][0])
		assert_int(e.role).override_failure_message(id).is_equal(expected[id][1])


func test_e2_signature_skills() -> void:
	var shaman: EnemyData = load(ENEMY_DIR + "goblin_shaman.tres")
	assert_bool(_has_skill(shaman, SkillData.SkillType.HEAL, SkillData.TargetType.ALLY)).is_true()
	var alpha: EnemyData = load(ENEMY_DIR + "wolf_alpha.tres")
	assert_bool(_has_skill(alpha, SkillData.SkillType.BUFF, SkillData.TargetType.ALLIES)).is_true()
	var cultist: EnemyData = load(ENEMY_DIR + "cultist.tres")
	var dark_flame := _skill_by_id(cultist, "e_dark_flame")
	assert_object(dark_flame).is_not_null()
	assert_int(dark_flame.target).is_equal(SkillData.TargetType.ALL)
	# The warlord's Crushing Blow is telegraphed and hits about twice as hard.
	var warlord: EnemyData = load(ENEMY_DIR + "orc_warlord.tres")
	var blow := _skill_by_id(warlord, "e_crushing_blow")
	assert_object(blow).is_not_null()
	assert_int(blow.telegraph_turns).is_equal(1)
	assert_int(blow.target).is_equal(SkillData.TargetType.ONE)
	assert_float(blow.power).is_between(1.5, 2.5)


func _has_skill(e: EnemyData, type: SkillData.SkillType, target: SkillData.TargetType) -> bool:
	for sk in e.skills:
		if sk.skill_type == type and sk.target == target:
			return true
	return false


func _skill_by_id(e: EnemyData, id: String) -> SkillData:
	for sk in e.skills:
		if sk.id == id:
			return sk
	return null
