## XP (#71, D-036): the level curve at x3 and the combat XP split that the
## combat screen and the campaign bot share (Party.distribute_combat_xp).
##
## Nothing here saves the game: level-up skins are pre-owned so unlock_skin
## never fires a save, and Party.heroes is put back after each test.
extends GdUnitTestSuite

const WARRIOR := "res://resources/classes/warrior.tres"
const MAGE := "res://resources/classes/mage.tres"

var _heroes_before: Array[Hero]
var _owned_skins: Array


func before_test() -> void:
	_heroes_before = Party.heroes
	_owned_skins = GameState.owned_skins.duplicate()
	# Reaching any level must not unlock (and so save) a skin.
	for lvl in range(1, Party.LEVEL_CAP + 1):
		for id in Skins.level_unlocks_at_or_below(lvl):
			if not GameState.owned_skins.has(id):
				GameState.owned_skins.append(id)


func after_test() -> void:
	Party.heroes = _heroes_before
	GameState.owned_skins.assign(_owned_skins)


func _party(count: int) -> Array[Hero]:
	var out: Array[Hero] = []
	for i in count:
		out.append(Hero.create(load(WARRIOR)))
	Party.heroes = out
	return out


# ── Curve ─────────────────────────────────────────────────────────────────────


func test_xp_for_next_levels_1_to_9() -> void:
	var got: Array[int] = []
	for level in range(1, 10):
		got.append(Party.xp_for_next(level))
	# floor(20/3 * level^1.5)
	assert_array(got).is_equal([6, 18, 34, 53, 74, 97, 123, 150, 180])


# ── Split ─────────────────────────────────────────────────────────────────────


func test_alive_heroes_get_equal_shares() -> void:
	var heroes := _party(4)
	var res := Party.distribute_combat_xp(10)
	assert_int(res.size()).is_equal(4)
	for h in heroes:
		assert_int(res[h]["xp"]).is_equal(2)  # 10 / 4, integer division
		assert_int(h.xp).is_equal(2)
		assert_int(res[h]["levels_gained"]).is_equal(0)


func test_downed_hero_gets_half_and_stays_down() -> void:
	var heroes := _party(4)
	heroes[1].hp = 0
	var res := Party.distribute_combat_xp(16)
	assert_int(res[heroes[0]]["xp"]).is_equal(4)
	assert_int(res[heroes[1]]["xp"]).is_equal(2)
	assert_int(heroes[1].xp).is_equal(2)
	assert_int(heroes[1].hp).is_equal(0)
	assert_bool(heroes[1].is_alive()).is_false()


func test_results_follow_party_order() -> void:
	var heroes := _party(3)
	var res := Party.distribute_combat_xp(9)
	assert_array(res.keys()).is_equal(heroes)


# ── Level-ups ─────────────────────────────────────────────────────────────────


func test_level_up_is_reported() -> void:
	var heroes := _party(1)
	var res := Party.distribute_combat_xp(Party.xp_for_next(1))
	assert_int(heroes[0].level).is_equal(2)
	assert_int(heroes[0].xp).is_equal(0)
	assert_int(res[heroes[0]]["levels_gained"]).is_equal(1)


func test_several_levels_in_one_award() -> void:
	var heroes := _party(1)
	var need := Party.xp_for_next(1) + Party.xp_for_next(2) + 1
	var res := Party.distribute_combat_xp(need)
	assert_int(heroes[0].level).is_equal(3)
	assert_int(heroes[0].xp).is_equal(1)
	assert_int(res[heroes[0]]["levels_gained"]).is_equal(2)


func test_unlocked_skills_are_returned() -> void:
	var heroes := _party(1)
	var res := Party.distribute_combat_xp(100000)
	var unlocked: Array = res[heroes[0]]["unlocked"]
	var expected := 0
	for skill in heroes[0].class_data.skills:
		if skill.unlock_level > 1 and skill.unlock_level <= heroes[0].level:
			expected += 1
	assert_int(unlocked.size()).is_equal(expected)
	for skill in unlocked:
		assert_bool(skill.unlock_level > 1).is_true()


func test_converted_sp_is_reported_as_mp() -> void:
	var mage := Hero.create(load(MAGE))
	Party.heroes = [mage] as Array[Hero]
	var res := Party.distribute_combat_xp(100000)
	assert_int(res[mage]["mp_gained"]).is_equal(mage.bonus_mp)


# ── Cap ───────────────────────────────────────────────────────────────────────


func test_heroes_at_level_cap_ignore_xp() -> void:
	var heroes := _party(2)
	heroes[0].level = Party.LEVEL_CAP
	var res := Party.distribute_combat_xp(1000)
	assert_int(heroes[0].level).is_equal(Party.LEVEL_CAP)
	assert_int(heroes[0].xp).is_equal(0)
	assert_int(res[heroes[0]]["levels_gained"]).is_equal(0)
	assert_array(res[heroes[0]]["unlocked"]).is_empty()
	# The other hero still levels.
	assert_int(heroes[1].level).is_greater(1)
