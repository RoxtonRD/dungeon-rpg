## The save system: a full round-trip, the crash-safety rules from #28, and a
## real v3 save that must keep loading.
##
## Every test points GameState.save_dir at its own folder under
## user://test_saves/ and puts it (and the live GameState / Party state) back
## afterwards, even when the test fails. The real save is never touched: the
## suite checksums it before and after and fails if it changed.
##
## Never award XP here: a level can unlock a skin, and unlocking a skin saves
## the game (see the SAFETY note in scripts/dev/balance_sim.gd).
extends GdUnitTestSuite

const GameStateScript := preload("res://scripts/game_state.gd")
const FIXTURE_V3 := "res://test/fixtures/saves/v3_basic.json"
const TEST_ROOT := "user://test_saves"
## The real save files, by their default paths. Checked, never written.
const REAL_SAVE_FILES: Array[String] = [
	"user://save.json",
	"user://save.bak.json",
	"user://save.tmp.json",
	"user://save.corrupt.json",
]

## MD5 of each real save file before the suite ran ("" if it didn't exist).
var _real_save_md5: Dictionary = {}
## Live GameState / Party state from before the current test.
var _snapshot: Dictionary = {}


func before() -> void:
	_real_save_md5 = _real_save_checksums()


## The guard. It watches the shared user:// folder, so a game running in the
## editor at the same time can also trip it: check which build wrote the file.
func after() -> void:
	var now := _real_save_checksums()
	var changed: PackedStringArray = []
	for path in now:
		if now[path] != _real_save_md5[path]:
			changed.append(path)
	(
		assert_array(changed)
		. override_failure_message(
			(
				"Real save files changed during the save tests: %s (%s)"
				% [", ".join(changed), "a game running in the editor also writes there"]
			)
		)
		. is_empty()
	)


func before_test() -> void:
	_snapshot = {
		"save_dir": GameState.save_dir,
		"gold": GameState.gold,
		"inventory": GameState.inventory.duplicate(),
		"owned_skins": GameState.owned_skins.duplicate(),
		"current_run": GameState.current_run,
		"dungeon_level": GameState.dungeon_level,
		"turn_counter": GameState.turn_counter,
		"market_stock": GameState.market_stock.duplicate(true),
		"potion_stock": GameState.potion_stock.duplicate(true),
		"heroes": Party.heroes.duplicate(),
	}
	var dir := TEST_ROOT.path_join("%d_%d" % [Time.get_ticks_usec(), randi()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	GameState.save_dir = dir


## Runs even when the test failed, so the redirect never leaks.
func after_test() -> void:
	var dir := GameState.save_dir
	GameState.save_dir = _snapshot["save_dir"]
	GameState.gold = _snapshot["gold"]
	GameState.inventory.assign(_snapshot["inventory"])
	GameState.owned_skins.assign(_snapshot["owned_skins"])
	GameState.current_run = _snapshot["current_run"]
	GameState.dungeon_level = _snapshot["dungeon_level"]
	GameState.turn_counter = _snapshot["turn_counter"]
	GameState.market_stock = _snapshot["market_stock"]
	GameState.potion_stock = _snapshot["potion_stock"]
	Party.heroes.assign(_snapshot["heroes"])
	if dir.begins_with(TEST_ROOT + "/"):
		_delete_dir(dir)
	# Drop the root too once no other run is using it.
	if (
		DirAccess.dir_exists_absolute(TEST_ROOT)
		and DirAccess.get_directories_at(TEST_ROOT).is_empty()
	):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_ROOT))


# ── The seam ──────────────────────────────────────────────────────────────────


func test_default_save_dir_keeps_the_real_paths() -> void:
	# A fresh GameState, not the autoload: before_test() redirected that one.
	var state: Node = GameStateScript.new()
	assert_str(state.save_dir).is_equal("user://")
	assert_str(state.save_path).is_equal("user://save.json")
	assert_str(state.backup_path).is_equal("user://save.bak.json")
	assert_str(state.tmp_path).is_equal("user://save.tmp.json")
	assert_str(state.corrupt_path).is_equal("user://save.corrupt.json")
	state.free()


func test_paths_follow_save_dir() -> void:
	assert_str(GameState.save_path).starts_with(TEST_ROOT + "/")
	assert_str(GameState.save_path.get_file()).is_equal("save.json")


# ── Round-trip ────────────────────────────────────────────────────────────────


## Every field in the save comes back exactly as it went out. If a field is
## added to the save, add it to _live_state() too: the key check below fails
## until you do.
func test_round_trip_keeps_every_saved_field() -> void:
	_set_up_known_state()
	var expected := _live_state()
	GameState.save_game()

	var saved_keys: Array = GameStateScript._read_save_dict(GameState.save_path).keys()
	saved_keys.erase("version")
	saved_keys.sort()
	var live_keys: Array = expected.keys()
	live_keys.sort()
	(
		assert_array(saved_keys)
		. override_failure_message(
			"Save keys %s != round-trip test keys %s" % [saved_keys, live_keys]
		)
		. is_equal(live_keys)
	)

	_reset_live_state()
	assert_bool(GameState.load_game()).is_true()
	var actual := _live_state()
	for key in expected:
		(
			assert_that(actual.get(key))
			. override_failure_message(
				(
					"'%s' did not survive the round-trip:\n  saved:  %s\n  loaded: %s"
					% [key, expected[key], actual.get(key)]
				)
			)
			. is_equal(expected[key])
		)


# ── Crash safety (#28) ────────────────────────────────────────────────────────


func test_first_save_writes_only_the_primary() -> void:
	_set_up_known_state()
	GameState.save_game()
	assert_bool(FileAccess.file_exists(GameState.save_path)).is_true()
	assert_bool(FileAccess.file_exists(GameState.backup_path)).is_false()
	assert_bool(FileAccess.file_exists(GameState.tmp_path)).is_false()
	assert_bool(GameState.has_save()).is_true()


func test_second_save_moves_the_first_to_backup() -> void:
	_set_up_known_state()
	GameState.save_game()
	var first := _bytes(GameState.save_path)
	GameState.gold += 1
	GameState.save_game()
	assert_array(Array(_bytes(GameState.backup_path))).is_equal(Array(first))
	assert_int(_saved_gold(GameState.save_path)).is_equal(GameState.gold)
	assert_bool(FileAccess.file_exists(GameState.tmp_path)).is_false()


func test_garbage_primary_loads_the_backup_and_is_kept_as_corrupt() -> void:
	_set_up_known_state()
	GameState.save_game()
	var backup_gold := GameState.gold
	GameState.gold += 1
	GameState.save_game()
	var garbage := "{ this is not json".to_utf8_buffer()
	_write(GameState.save_path, garbage)

	_reset_live_state()
	assert_bool(GameState.load_game()).is_true()
	assert_int(GameState.gold).is_equal(backup_gold)
	assert_bool(FileAccess.file_exists(GameState.save_path)).is_false()
	assert_array(Array(_bytes(GameState.corrupt_path))).is_equal(Array(garbage))


func test_missing_primary_loads_the_backup() -> void:
	_set_up_known_state()
	GameState.save_game()
	var backup_gold := GameState.gold
	GameState.gold += 1
	GameState.save_game()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))

	_reset_live_state()
	assert_bool(GameState.has_save()).is_true()
	assert_bool(GameState.load_game()).is_true()
	assert_int(GameState.gold).is_equal(backup_gold)


func test_lone_tmp_file_is_ignored() -> void:
	_set_up_known_state()
	GameState.save_game()
	var bytes := _bytes(GameState.save_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	_write(GameState.tmp_path, bytes)

	_reset_live_state()
	assert_bool(GameState.has_save()).is_false()
	assert_bool(GameState.load_game()).is_false()
	assert_int(GameState.gold).is_equal(-1)
	assert_array(Array(_bytes(GameState.tmp_path))).is_equal(Array(bytes))


func test_newer_primary_is_refused_and_left_byte_identical() -> void:
	_set_up_known_state()
	GameState.save_game()
	GameState.save_game()  # a valid backup, which must not be loaded either
	var data := GameStateScript._read_save_dict(GameState.save_path)
	data["version"] = 99
	var v99 := JSON.stringify(data, "\t").to_utf8_buffer()
	_write(GameState.save_path, v99)
	var backup := _bytes(GameState.backup_path)

	_reset_live_state()
	assert_bool(GameState.load_game()).is_false()
	assert_int(GameState.gold).is_equal(-1)
	assert_array(Array(_bytes(GameState.save_path))).is_equal(Array(v99))
	assert_array(Array(_bytes(GameState.backup_path))).is_equal(Array(backup))
	assert_bool(FileAccess.file_exists(GameState.corrupt_path)).is_false()


# ── Fixture ───────────────────────────────────────────────────────────────────


## A real v3 save from a play session (hero names made neutral). It must
## keep loading after every save format change, through _migrate().
func test_v3_fixture_loads() -> void:
	var bytes := FileAccess.get_file_as_bytes(FIXTURE_V3)
	assert_int(bytes.size()).is_greater(0)
	_write(GameState.save_path, bytes)

	_reset_live_state()
	assert_bool(GameState.load_game()).is_true()
	assert_int(Party.heroes.size()).is_equal(4)
	for hero in Party.heroes:
		assert_object(hero.class_data).is_not_null()
		assert_int(hero.hp).is_between(1, hero.max_hp())
	assert_int(GameState.gold).is_greater_equal(0)
	assert_int(GameState.dungeon_level).is_greater_equal(1)
	assert_object(GameState.current_run).is_not_null()
	assert_array(GameState.current_run.floors).is_not_empty()


# ── Helpers ───────────────────────────────────────────────────────────────────


## A small, known, non-default state touching every saved field.
func _set_up_known_state() -> void:
	GameState.gold = 1234
	GameState.inventory.assign(["potion_heal", "potion_mana", "sword_iron"])
	GameState.owned_skins.assign(["test/skin"])
	GameState.dungeon_level = 3
	GameState.turn_counter = 42
	GameState.market_stock = [{"id": "ring_focus", "qty": 1}, {"id": "armor_chain", "qty": 2}]
	GameState.potion_stock = [{"id": "potion_heal", "qty": 3}, {"id": "elixir_full", "qty": 0}]
	(
		Party
		. build_party(
			[
				{"name": "Alfa", "class_id": "warrior", "skin_id": "1"},
				{"name": "Bravo", "class_id": "cleric", "skin_id": "2"},
				{"name": "Charlie", "class_id": "rogue", "skin_id": "1"},
				{"name": "Delta", "class_id": "mage", "skin_id": "1"},
			]
		)
	)
	# Set fields directly: never award_xp (it can save the game).
	var hero: Hero = Party.heroes[0]
	hero.level = 3
	hero.xp = 7
	hero.sp_available = 2
	hero.sp_spent = {"warrior_slash": 1}
	hero.bonus_mp = 4
	hero.hp -= 5
	hero.mp -= 1
	hero.row = 1 - hero.row
	hero.equipment["weapon"] = load("res://resources/items/sword_iron.tres")
	var status := CombatStatus.new()
	status.source_name = "test"
	status.mod_def = 2
	status.duration = 3
	hero.statuses.append(status)
	var run := DungeonRun.generate(3)
	run.current_floor = 1
	run.player_pos = Vector2i(0, 0)
	GameState.current_run = run


## Every saved field, read back from live state. Keys match the save payload.
func _live_state() -> Dictionary:
	return {
		"gold": GameState.gold,
		"inventory": Array(GameState.inventory),
		"owned_skins": Array(GameState.owned_skins),
		"heroes": _heroes_state(),
		"run": GameState.current_run.to_dict() if GameState.current_run != null else null,
		"dungeon_level": GameState.dungeon_level,
		"turn_counter": GameState.turn_counter,
		"market": GameState.market_stock.duplicate(true),
		"potions": GameState.potion_stock.duplicate(true),
	}


## Party.serialize(), with sp_spent counts as ints. Hero.from_dict keeps the
## floats JSON parses them to (1 comes back as 1.0); every reader wraps them in
## int(), so compare the numbers, not the types.
func _heroes_state() -> Dictionary:
	var data := Party.serialize()
	for hero in data["heroes"]:
		for key in hero["sp_spent"]:
			hero["sp_spent"][key] = int(hero["sp_spent"][key])
	return data


## Values no real save holds, so a field that fails to load stands out.
func _reset_live_state() -> void:
	GameState.gold = -1
	GameState.inventory.clear()
	GameState.owned_skins.clear()
	GameState.current_run = null
	GameState.dungeon_level = -1
	GameState.turn_counter = -1
	GameState.market_stock = []
	GameState.potion_stock = []
	Party.heroes.clear()


func _real_save_checksums() -> Dictionary:
	var out := {}
	for path in REAL_SAVE_FILES:
		out[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	return out


func _saved_gold(path: String) -> int:
	return int(GameStateScript._read_save_dict(path).get("gold", -1))


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _delete_dir(dir: String) -> void:
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(file)))
	for sub in DirAccess.get_directories_at(dir):
		_delete_dir(dir.path_join(sub))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
