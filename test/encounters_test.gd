## Encounters v3 (E1, D-038): enemy AI roles and their targeting, telegraphed
## attacks, authored encounter groups, elite rooms and elite rewards.
##
## Fights are built directly with CombatState.build and enemy turns are driven
## by hand (`_enemy_acts`), so each test sets up exactly the situation it checks.
## The AI picks are deterministic for the cases below (the role leaves no
## choice), so nothing here depends on a lucky roll.
extends GdUnitTestSuite

const TestUtil := preload("res://test/support/test_util.gd")
const WARRIOR := "res://resources/classes/warrior.tres"
const MAGE := "res://resources/classes/mage.tres"
const ROGUE := "res://resources/classes/rogue.tres"
const SMASH := "res://resources/skills/enemy/e_smash.tres"
const PROVOKE := "res://resources/skills/warrior_provoke.tres"
const ENEMY_DIR := "res://resources/enemies/"
const GROUP_DIR := "res://resources/encounters/"
## Runs generated to look for elite rooms.
const GENERATED_RUNS := 150

# ── Builders ──────────────────────────────────────────────────────────────────


func _skill(
	id: String, type: SkillData.SkillType, target: SkillData.TargetType, power: float = 1.0
) -> SkillData:
	var sk := SkillData.new()
	sk.id = id
	sk.display_name = id
	sk.skill_type = type
	sk.target = target
	sk.power = power
	return sk


func _enemy(
	role: EnemyData.AiRole, skills: Array[SkillData], hp: int = 1000, mag: int = 10
) -> EnemyData:
	var e := EnemyData.new()
	e.id = "test_enemy"
	e.display_name = "test_enemy"
	e.ai_role = role
	e.max_hp = hp
	e.atk = 1  # hits stay tiny, so a hero at a few HP survives the test
	e.mag = mag
	e.skills = skills
	return e


## A level-1 hero of `class_path` at `hp_share` of full HP, in front (0) or
## back (1) row.
func _hero(class_path: String, hp_share: float, row: int) -> Hero:
	var h := Hero.create(load(class_path))
	h.row = row
	h.hp = maxi(2, roundi(h.max_hp() * hp_share))
	return h


func _state(heroes: Array, enemies: Array, elite: bool = false) -> CombatState:
	var party: Array[Hero] = []
	party.assign(heroes)
	var foes: Array[EnemyData] = []
	foes.assign(enemies)
	return CombatState.build(party, foes, elite)


## Starts recording every action_started as {caster, skill, targets}.
func _record_actions(st: CombatState) -> Array:
	var actions: Array = []
	st.action_started.connect(
		func(caster, skill, targets):
			actions.append({"caster": caster, "skill": skill, "targets": targets})
	)
	return actions


## Enemy `index` takes its turn now.
func _enemy_acts(st: CombatState, index: int = 0) -> void:
	st.current_actor = st.enemies[index]
	st.step()


func _skills(list: Array) -> Array[SkillData]:
	var out: Array[SkillData] = []
	out.assign(list)
	return out


# ── AI roles: targeting ───────────────────────────────────────────────────────


func test_skirmisher_hits_the_lowest_hp_percent_hero_in_any_row() -> void:
	var hit := _skill("hit", SkillData.SkillType.PHYS, SkillData.TargetType.ONE)
	var foe := _enemy(EnemyData.AiRole.SKIRMISHER, _skills([hit]))
	var heroes := [_hero(WARRIOR, 1.0, 0), _hero(MAGE, 0.3, 1), _hero(ROGUE, 0.6, 0)]
	for i in 15:
		var st := _state(heroes, [foe])
		var actions := _record_actions(st)
		_enemy_acts(st)
		assert_int(actions.size()).is_equal(1)
		# The mage is in the back row, but has the lowest share of its HP.
		assert_array(actions[0]["targets"]).contains_exactly([st.party[1]])
		# Put everyone back so the next try faces the same board.
		heroes[0].hp = heroes[0].max_hp()
		heroes[1].hp = maxi(2, roundi(heroes[1].max_hp() * 0.3))
		heroes[2].hp = maxi(2, roundi(heroes[2].max_hp() * 0.6))


func test_brute_stays_on_the_front_row() -> void:
	var hit := _skill("hit", SkillData.SkillType.PHYS, SkillData.TargetType.ONE)
	var foe := _enemy(EnemyData.AiRole.BRUTE, _skills([hit]))
	var heroes := [_hero(WARRIOR, 1.0, 0), _hero(MAGE, 0.1, 1)]
	for i in 15:
		var st := _state(heroes, [foe])
		var actions := _record_actions(st)
		_enemy_acts(st)
		assert_array(actions[0]["targets"]).contains_exactly([st.party[0]])
		heroes[0].hp = heroes[0].max_hp()
		heroes[1].hp = maxi(2, roundi(heroes[1].max_hp() * 0.1))


func test_taunt_overrides_a_skirmisher() -> void:
	var hit := _skill("hit", SkillData.SkillType.PHYS, SkillData.TargetType.ONE)
	var foe := _enemy(EnemyData.AiRole.SKIRMISHER, _skills([hit]))
	for i in 10:
		var tank := _hero(WARRIOR, 1.0, 0)
		var taunt := CombatStatus.new()
		taunt.kind = CombatStatus.Kind.BUFF
		taunt.taunt = true
		taunt.duration = 3
		tank.statuses.append(taunt)
		var st := _state([tank, _hero(MAGE, 0.2, 1)], [foe])
		var actions := _record_actions(st)
		_enemy_acts(st)
		# The mage has far less HP, but the taunter takes the hit.
		assert_array(actions[0]["targets"]).contains_exactly([st.party[0]])


func test_caster_uses_its_area_skill_against_three_or_more_heroes() -> void:
	var bolt := _skill("bolt", SkillData.SkillType.MAG, SkillData.TargetType.ONE)
	var storm := _skill("storm", SkillData.SkillType.MAG, SkillData.TargetType.ALL)
	var foe := _enemy(EnemyData.AiRole.CASTER, _skills([bolt, storm]))
	for i in 20:
		var st := _state([_hero(WARRIOR, 1.0, 0), _hero(MAGE, 1.0, 1), _hero(ROGUE, 1.0, 0)], [foe])
		var actions := _record_actions(st)
		_enemy_acts(st)
		assert_str(actions[0]["skill"].id).is_equal("storm")
		assert_int(actions[0]["targets"].size()).is_equal(3)


func test_support_heals_an_ally_under_half_hp() -> void:
	var heal := _skill("mend", SkillData.SkillType.HEAL, SkillData.TargetType.ALLY)
	var hit := _skill("hit", SkillData.SkillType.PHYS, SkillData.TargetType.ONE)
	var healer := _enemy(EnemyData.AiRole.SUPPORT, _skills([heal, hit]))
	var wounded := _enemy(EnemyData.AiRole.BRUTE, _skills([hit]), 100)
	for i in 10:
		var st := _state([_hero(WARRIOR, 1.0, 0)], [healer, wounded])
		st.enemies[1].set_hp(40)
		var actions := _record_actions(st)
		_enemy_acts(st, 0)
		assert_str(actions[0]["skill"].id).is_equal("mend")
		assert_array(actions[0]["targets"]).contains_exactly([st.enemies[1]])
		assert_int(st.enemies[1].get_hp()).is_greater(40)


func test_support_attacks_when_every_ally_is_healthy() -> void:
	var heal := _skill("mend", SkillData.SkillType.HEAL, SkillData.TargetType.ALLY)
	var hit := _skill("hit", SkillData.SkillType.PHYS, SkillData.TargetType.ONE)
	var healer := _enemy(EnemyData.AiRole.SUPPORT, _skills([heal, hit]))
	var healthy := _enemy(EnemyData.AiRole.BRUTE, _skills([hit]), 100)
	for i in 10:
		var st := _state([_hero(WARRIOR, 1.0, 0)], [healer, healthy])
		st.enemies[1].set_hp(60)  # hurt, but not under half
		var actions := _record_actions(st)
		_enemy_acts(st, 0)
		assert_str(actions[0]["skill"].id).is_equal("hit")


func test_support_buffs_an_ally_that_lacks_the_buff_then_attacks() -> void:
	var ward := _skill("ward", SkillData.SkillType.BUFF, SkillData.TargetType.ALLY)
	ward.mod_def = 3
	ward.mod_duration = 3
	var hit := _skill("hit", SkillData.SkillType.PHYS, SkillData.TargetType.ONE)
	var support := _enemy(EnemyData.AiRole.SUPPORT, _skills([ward, hit]))
	var st := _state([_hero(WARRIOR, 1.0, 0)], [support])
	var actions := _record_actions(st)
	_enemy_acts(st)
	assert_str(actions[0]["skill"].id).is_equal("ward")
	_enemy_acts(st)  # already buffed: no point buffing again
	assert_str(actions[1]["skill"].id).is_equal("hit")


# ── Telegraphed attacks ───────────────────────────────────────────────────────


func _smasher() -> EnemyData:
	return _enemy(EnemyData.AiRole.BRUTE, _skills([load(SMASH)]))


func test_ogre_smash_is_a_telegraphed_area_attack() -> void:
	var smash: SkillData = load(SMASH)
	assert_int(smash.telegraph_turns).is_equal(1)
	assert_int(smash.target).is_equal(SkillData.TargetType.ALL)
	var ogre: EnemyData = load(ENEMY_DIR + "ogre.tres")
	assert_bool(ogre.skills.has(smash)).is_true()


func test_telegraph_winds_up_then_lands_next_turn() -> void:
	var heroes := [_hero(WARRIOR, 1.0, 0), _hero(MAGE, 1.0, 1)]
	var st := _state(heroes, [_smasher()])
	var actions := _record_actions(st)
	var statuses: Array = []
	st.status_applied.connect(func(_target, status): statuses.append(status))
	var hp_before := [st.party[0].get_hp(), st.party[1].get_hp()]

	# Turn 1: it winds up. Nobody is hurt and the Charging status shows.
	_enemy_acts(st)
	assert_int(st.party[0].get_hp()).is_equal(hp_before[0])
	assert_int(st.party[1].get_hp()).is_equal(hp_before[1])
	assert_object(st.enemies[0].charge_status()).is_not_null()
	assert_int(statuses.size()).is_equal(1)
	assert_int(statuses[0].kind).is_equal(CombatStatus.Kind.CHARGING)
	assert_bool(CombatState.is_wind_up(actions[0]["skill"])).is_true()
	assert_str(actions[0]["skill"].display_name).is_equal("ESKILL_SMASH")
	assert_int(actions[0]["targets"].size()).is_equal(2)  # the whole party is threatened

	# The round ending doesn't wear the wind-up off.
	st._tick_statuses()
	assert_object(st.enemies[0].charge_status()).is_not_null()

	# Turn 2: the smash lands on everyone and the status is gone.
	_enemy_acts(st)
	assert_int(st.party[0].get_hp()).is_less(hp_before[0])
	assert_int(st.party[1].get_hp()).is_less(hp_before[1])
	assert_object(st.enemies[0].charge_status()).is_null()
	assert_bool(CombatState.is_wind_up(actions[1]["skill"])).is_false()
	assert_str(actions[1]["skill"].id).is_equal("e_smash")


func test_telegraph_is_cancelled_by_death() -> void:
	var st := _state([_hero(WARRIOR, 1.0, 0)], [_smasher()])
	var hero_hp := st.party[0].get_hp()
	_enemy_acts(st)
	assert_object(st.enemies[0].charge_status()).is_not_null()
	st.enemies[0].set_hp(0)  # killed while charging
	assert_object(st.enemies[0].charge_status()).is_null()
	assert_bool(st.enemies[0].is_alive()).is_false()
	# The dead enemy never gets another turn, so the smash never lands.
	for i in 6:
		st._advance_to_next_actor()
		assert_bool(st.current_actor == st.enemies[0]).is_false()
	assert_int(st.party[0].get_hp()).is_equal(hero_hp)


func test_single_target_telegraph_keeps_its_target_or_repicks() -> void:
	var slam := _skill("slam", SkillData.SkillType.PHYS, SkillData.TargetType.ONE, 1.0)
	slam.telegraph_turns = 1
	var foe := _enemy(EnemyData.AiRole.SKIRMISHER, _skills([slam]))
	# Same target: the mage is the weakest when it winds up and stays targeted
	# even after the warrior becomes the weaker hero.
	var st := _state([_hero(WARRIOR, 1.0, 0), _hero(MAGE, 0.4, 1)], [foe])
	var actions := _record_actions(st)
	_enemy_acts(st)
	assert_array(actions[0]["targets"]).contains_exactly([st.party[1]])
	st.party[0].set_hp(1)
	_enemy_acts(st)
	assert_array(actions[1]["targets"]).contains_exactly([st.party[1]])

	# Dead target: it picks again among the heroes still standing.
	var st2 := _state([_hero(WARRIOR, 1.0, 0), _hero(MAGE, 0.4, 1)], [foe])
	var actions2 := _record_actions(st2)
	_enemy_acts(st2)
	assert_array(actions2[0]["targets"]).contains_exactly([st2.party[1]])
	st2.party[1].set_hp(0)
	_enemy_acts(st2)
	assert_array(actions2[1]["targets"]).contains_exactly([st2.party[0]])


## The Warrior casts Provoke for real (rage paid, taunt from the skill).
func _warrior_provokes(st: CombatState) -> void:
	var provoke: SkillData = load(PROVOKE)
	var warrior := st.party[0]
	warrior.hero.level = provoke.unlock_level
	warrior.rage = Party.combat_cost(warrior.hero, provoke)
	st.current_actor = warrior
	st.player_action(provoke, null)
	assert_bool(warrior.has_taunt()).is_true()


## E5a: Provoke answers a single-target telegraph. The hit was wound up on the
## mage, the Warrior provoked in between, so it lands on the Warrior.
func test_provoke_during_a_wind_up_pulls_a_single_target_hit() -> void:
	var slam := _skill("slam", SkillData.SkillType.PHYS, SkillData.TargetType.ONE, 1.0)
	slam.telegraph_turns = 1
	var foe := _enemy(EnemyData.AiRole.SKIRMISHER, _skills([slam]))
	var st := _state([_hero(WARRIOR, 1.0, 0), _hero(MAGE, 0.4, 1)], [foe])
	var actions := _record_actions(st)
	_enemy_acts(st)
	assert_array(actions[0]["targets"]).contains_exactly([st.party[1]])
	var mage_hp := st.party[1].get_hp()

	_warrior_provokes(st)
	_enemy_acts(st)
	var hit: Dictionary = actions[actions.size() - 1]
	assert_bool(hit["caster"] == st.enemies[0]).is_true()
	assert_bool(CombatState.is_wind_up(hit["skill"])).is_false()
	assert_array(hit["targets"]).contains_exactly([st.party[0]])
	assert_int(st.party[1].get_hp()).is_equal(mage_hp)


## E5a: an area telegraph still hits everyone, taunt or not.
func test_provoke_does_not_narrow_an_area_telegraph() -> void:
	var st := _state([_hero(WARRIOR, 1.0, 0), _hero(MAGE, 1.0, 1)], [_smasher()])
	var actions := _record_actions(st)
	_enemy_acts(st)
	assert_int(actions[0]["targets"].size()).is_equal(2)
	var mage_hp := st.party[1].get_hp()

	_warrior_provokes(st)
	_enemy_acts(st)
	var hit: Dictionary = actions[actions.size() - 1]
	assert_str(hit["skill"].id).is_equal("e_smash")
	assert_array(hit["targets"]).contains_exactly_in_any_order([st.party[0], st.party[1]])
	assert_int(st.party[1].get_hp()).is_less(mage_hp)


func test_charging_status_serializes_without_its_references() -> void:
	var st := CombatStatus.new()
	st.kind = CombatStatus.Kind.CHARGING
	st.source_name = "ESKILL_SMASH"
	st.charge_skill = load(SMASH)
	var back := CombatStatus.from_dict(st.to_dict())
	assert_int(back.kind).is_equal(CombatStatus.Kind.CHARGING)
	assert_object(back.charge_skill).is_null()  # enemy-only, never saved
	# A charging enemy with no skill (reloaded) just clears the status.
	var combat := _state([_hero(WARRIOR, 1.0, 0)], [_smasher()])
	combat.enemies[0].statuses.append(back)
	_enemy_acts(combat)
	assert_object(combat.enemies[0].charge_status()).is_null()


# ── Roles on the real roster ──────────────────────────────────────────────────


func test_existing_enemies_have_their_roles() -> void:
	var expected := {
		"goblin": EnemyData.AiRole.BRUTE,
		"skeleton": EnemyData.AiRole.BRUTE,
		"orc": EnemyData.AiRole.BRUTE,
		"ogre": EnemyData.AiRole.BRUTE,
		"bandit": EnemyData.AiRole.BRUTE,
		"wolf": EnemyData.AiRole.SKIRMISHER,
		"bat": EnemyData.AiRole.SKIRMISHER,
		"dark_elf": EnemyData.AiRole.SKIRMISHER,
		"cultist": EnemyData.AiRole.CASTER,
		"boss_necromancer": EnemyData.AiRole.CASTER,
		"boss_vampire": EnemyData.AiRole.SKIRMISHER,
		"boss_dragon_hatchling": EnemyData.AiRole.BRUTE,
	}
	for id in expected:
		var e: EnemyData = load(ENEMY_DIR + id + ".tres")
		assert_int(e.ai_role).is_equal(expected[id])


# ── Encounter groups ──────────────────────────────────────────────────────────


func _folder_group_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for file in DirAccess.get_files_at(GROUP_DIR):
		if file.ends_with(".tres"):
			ids.append(file.get_basename())
	ids.sort()
	return ids


func test_fallback_list_matches_the_folder() -> void:
	var fallback := PackedStringArray(EncounterGroupData.FALLBACK_IDS)
	fallback.sort()
	assert_array(Array(fallback)).is_equal(Array(_folder_group_ids()))


func test_every_group_is_well_formed() -> void:
	var problems: PackedStringArray = []
	assert_int(EncounterGroupData.all().size()).is_equal(_folder_group_ids().size())
	for group in EncounterGroupData.all():
		var ids := {}
		var front := 0
		var supports := 0
		var telegraphs := 0
		for member in group.members:
			var path := ENEMY_DIR + member + ".tres"
			if not ResourceLoader.exists(path):
				problems.append("%s: unknown enemy '%s'" % [group.id, member])
				continue
			var e: EnemyData = load(path)
			ids[member] = true
			if e.role == EnemyData.Role.FRONT:
				front += 1
			if e.ai_role == EnemyData.AiRole.SUPPORT:
				supports += 1
			for sk in e.skills:
				if sk.telegraph_turns > 0:
					telegraphs += 1
		if group.floor_min < 1 or group.floor_max > DungeonRun.NUM_FLOORS:
			problems.append(
				"%s: floors %d-%d out of range" % [group.id, group.floor_min, group.floor_max]
			)
		if group.floor_min > group.floor_max:
			problems.append("%s: floor_min above floor_max" % group.id)
		if group.weight <= 0.0:
			problems.append("%s: weight must be positive" % group.id)
		if front < 1:
			problems.append("%s: needs a front-row enemy" % group.id)
		if supports > 1:
			problems.append("%s: more than one support" % group.id)
		if group.elite:
			if group.members.size() < 3 or group.members.size() > 5:
				problems.append("%s: elite groups hold 3-5 enemies" % group.id)
			if telegraphs + supports == 0:
				problems.append("%s: an elite group needs a telegraph or a support" % group.id)
		else:
			if group.members.size() < 2 or group.members.size() > 4:
				problems.append("%s: normal groups hold 2-4 enemies" % group.id)
			if telegraphs > 1:
				problems.append("%s: more than one telegraph user" % group.id)
	(
		assert_array(problems)
		. override_failure_message(TestUtil.problem_list("Bad encounter groups", problems))
		. is_empty()
	)


func test_group_selection_respects_floor_ranges_and_the_elite_flag() -> void:
	for floor_num in range(1, DungeonRun.NUM_FLOORS + 1):
		var normal := EncounterGroupData.candidates(floor_num, false)
		assert_bool(normal.is_empty()).is_false()  # every floor has fights
		for group in normal:
			assert_bool(group.elite).is_false()
			assert_int(floor_num).is_between(group.floor_min, group.floor_max)
		for roll in 40:
			var picked := EncounterGroupData.pick(floor_num, false)
			assert_bool(normal.has(picked)).is_true()
	# Elite rooms exist on floors 2-4, so those floors have elite groups.
	for floor_num in range(2, DungeonRun.NUM_FLOORS + 1):
		var elites := EncounterGroupData.candidates(floor_num, true)
		assert_bool(elites.is_empty()).is_false()
		for group in elites:
			assert_bool(group.elite).is_true()
			assert_int(floor_num).is_between(group.floor_min, group.floor_max)
		for roll in 40:
			assert_bool(EncounterGroupData.pick(floor_num, true).elite).is_true()


func test_roll_encounter_builds_a_group_and_elite_rolls_an_elite_group() -> void:
	var run := DungeonRun.new()
	for floor_index in DungeonRun.NUM_FLOORS:
		for roll in 20:
			var fight := run.roll_encounter(floor_index)
			assert_int(fight.size()).is_between(2, 4)
	for floor_index in range(1, DungeonRun.NUM_FLOORS):
		var elite_rosters: Array = []
		for group in EncounterGroupData.candidates(floor_index + 1, true):
			elite_rosters.append(group.members)
		for roll in 20:
			var fight := run.roll_encounter(floor_index, true)
			var ids: Array[String] = []
			for e in fight:
				ids.append(e.id)
			# The fight is one of that floor's elite groups, member for member.
			assert_bool(elite_rosters.has(ids)).is_true()


func test_weighted_pick_follows_the_weights() -> void:
	# Floor 1 has several groups of weight 1.0: each should come up, none dominate.
	var seen := {}
	for roll in 300:
		seen[EncounterGroupData.pick(1, false).id] = true
	assert_int(seen.size()).is_equal(EncounterGroupData.candidates(1, false).size())


# ── Elite rooms ───────────────────────────────────────────────────────────────


func test_elite_rooms_only_on_floors_two_to_four_at_most_one_each() -> void:
	var floors_with_elite := {}
	for i in GENERATED_RUNS:
		var run := DungeonRun.generate(1)
		for floor_index in run.floors.size():
			var count := 0
			for room in (run.floors[floor_index] as Dictionary).values():
				if room.kind == DungeonRoom.RoomType.ELITE:
					count += 1
					floors_with_elite[floor_index] = true
					assert_bool(room.pos == Vector2i.ZERO).is_false()
			assert_int(count).is_less_equal(1)
			if floor_index == 0:
				assert_int(count).is_equal(0)
	# 60% per floor over 150 runs: every eligible floor sees some.
	assert_bool(floors_with_elite.has(0)).is_false()
	for floor_index in range(1, DungeonRun.NUM_FLOORS):
		assert_bool(floors_with_elite.has(floor_index)).is_true()


## Links two adjacent rooms with a passage.
func _link(rooms: Dictionary, a: Vector2i, b: Vector2i) -> void:
	for dir in DungeonRoom.DIRS:
		if a + dir["vec"] == b:
			(rooms[a] as DungeonRoom).connections |= dir["bit"]
			(rooms[b] as DungeonRoom).connections |= dir["opposite"]


func _room(rooms: Dictionary, pos: Vector2i, kind: DungeonRoom.RoomType) -> void:
	var room := DungeonRoom.new()
	room.pos = pos
	room.kind = kind
	rooms[pos] = room


func test_elite_avoids_the_route_to_the_stairs() -> void:
	# start - A - stairs, with a dead-end B off A: A is on the only route.
	var rooms := {}
	_room(rooms, Vector2i(0, 0), DungeonRoom.RoomType.EMPTY)
	_room(rooms, Vector2i(1, 0), DungeonRoom.RoomType.COMBAT)
	_room(rooms, Vector2i(2, 0), DungeonRoom.RoomType.STAIRS)
	_room(rooms, Vector2i(1, 1), DungeonRoom.RoomType.COMBAT)
	_link(rooms, Vector2i(0, 0), Vector2i(1, 0))
	_link(rooms, Vector2i(1, 0), Vector2i(2, 0))
	_link(rooms, Vector2i(1, 0), Vector2i(1, 1))
	var required := DungeonRun._required_rooms(rooms)
	assert_bool(required.has(Vector2i(1, 0))).is_true()
	assert_bool(required.has(Vector2i(1, 1))).is_false()
	var placed := 0
	for i in 60:
		(rooms[Vector2i(1, 0)] as DungeonRoom).kind = DungeonRoom.RoomType.COMBAT
		(rooms[Vector2i(1, 1)] as DungeonRoom).kind = DungeonRoom.RoomType.COMBAT
		DungeonRun._maybe_place_elite(rooms, 1)
		assert_int((rooms[Vector2i(1, 0)] as DungeonRoom).kind).is_equal(
			DungeonRoom.RoomType.COMBAT
		)
		if (rooms[Vector2i(1, 1)] as DungeonRoom).kind == DungeonRoom.RoomType.ELITE:
			placed += 1
	assert_int(placed).is_greater(0)  # 60%: it does get placed, always off the route


func test_elite_room_is_content_and_survives_a_save() -> void:
	var room := DungeonRoom.new()
	room.kind = DungeonRoom.RoomType.ELITE
	assert_bool(room.has_content()).is_true()
	room.cleared = true
	assert_bool(room.has_content()).is_false()
	room.cleared = false
	var back := DungeonRoom.from_dict(room.to_dict())
	assert_int(back.kind).is_equal(DungeonRoom.RoomType.ELITE)
	# The saved kind ints of the older room types did not move.
	assert_int(DungeonRoom.RoomType.SHRINE).is_equal(7)
	assert_int(DungeonRoom.RoomType.ELITE).is_equal(8)


# ── Elite rewards ─────────────────────────────────────────────────────────────


func test_elite_fights_pay_more_xp_and_gold() -> void:
	var foe := _enemy(EnemyData.AiRole.BRUTE, _skills([]), 10)
	foe.xp_reward = 20
	foe.gold_min = 10
	foe.gold_max = 10
	var normal := _state([_hero(WARRIOR, 1.0, 0)], [foe, foe])
	var elite := _state([_hero(WARRIOR, 1.0, 0)], [foe, foe], true)
	var base: Dictionary = normal._calculate_rewards(CombatState.Result.VICTORY)
	var bonus: Dictionary = elite._calculate_rewards(CombatState.Result.VICTORY)
	assert_int(base["xp"]).is_equal(40)
	assert_int(base["gold"]).is_equal(20)
	assert_int(bonus["xp"]).is_equal(roundi(40 * CombatState.ELITE_XP_MULT))
	assert_int(bonus["gold"]).is_equal(roundi(20 * CombatState.ELITE_GOLD_MULT))
	assert_int(bonus["xp"]).is_equal(60)
	assert_int(bonus["gold"]).is_equal(40)
	# A defeat pays nothing, elite or not.
	assert_int(elite._calculate_rewards(CombatState.Result.DEFEAT)["xp"]).is_equal(0)


func test_elite_fights_always_drop_an_item() -> void:
	for dungeon_level in [1, 2, 3]:
		for i in 60:
			assert_int(Loot.roll_drops(dungeon_level, false, true).size()).is_equal(1)
