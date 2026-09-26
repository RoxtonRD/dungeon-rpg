## Autoload singleton for run/meta state that isn't the party itself:
## gold, the shared inventory (item ids), the active dungeon run and the
## city market's limited stock. Includes file-based save/load (JSON,
## versioned) and the TPK penalty.
extends Node

const STARTING_GOLD: int = 50
const STARTER_ITEMS: Array[String] = ["potion_heal", "potion_heal", "potion_mana"]

## Equipment eligible for the market's random limited-stock section.
## Full roster minus consumables and the boss-drop tome. Hardcoded ids
## (matching the v1 shop convention) so exports never depend on res://
## directory listing.
const MARKET_EQUIPMENT_POOL: Array[String] = [
	"sword_rusty",
	"sword_iron",
	"sword_steel",
	"dagger_shadow",
	"staff_apprentice",
	"staff_runed",
	"staff_arcane",
	"armor_cloth",
	"armor_leather",
	"armor_chain",
	"armor_plate",
	"ring_might",
	"ring_focus",
	"ring_arcane",
	"amulet_swift",
	"amulet_ward",
]
## How many random equipment items each restock puts on the shelves.
const MARKET_SLOTS: int = 5

## Consumables the market carries, with the per-restock stock range for each.
## Limited stock (rather than the old unlimited supply) is what stops potion
## spam from erasing dungeon attrition. Restocked on every run end.
const MARKET_POTIONS: Array = [
	{"id": "potion_heal", "min": 2, "max": 4},
	{"id": "potion_mana", "min": 1, "max": 3},
	{"id": "elixir_full", "min": 0, "max": 2},
	{"id": "elixir_revival", "min": 0, "max": 1},
]
## v2: room-based dungeon (floors of rooms, player position, explored state).
## v3: customizable party (hero custom_name / skin_id / is_main).
const SAVE_VERSION: int = 3
## Oldest save _migrate() can bring up to SAVE_VERSION. v1 and v2 are
## intentionally never migrated; the menu falls back to a fresh game.
const MIN_SUPPORTED_VERSION: int = 3

var gold: int = 0
## Item ids (e.g. "potion_heal"). Duplicates allowed; resolved to ItemData on use.
var inventory: Array[String] = []
## Full ids of unlocked locked skins (gold/level/event). Free skins are never
## stored — always usable. See the Skins autoload and SkinData.
var owned_skins: Array[String] = []
## The active DungeonRun. Left untyped to avoid a class_name <-> autoload
## dependency cycle (DungeonRun references the GameState autoload), which
## Godot resolves inconsistently across recompiles. Callers cast as needed.
var current_run = null
## Which dungeon the party is on. Increments on each victory; resets to 1 for new game.
var dungeon_level: int = 1
## The market's random limited-stock shelf: Dictionaries {"id": String,
## "qty": int}. Restocked whenever a dungeon run ends (complete/abandon/TPK).
var market_stock: Array = []
## The market's consumable shelf: Dictionaries {"id": String, "qty": int},
## rolled from MARKET_POTIONS. Restocked alongside market_stock.
var potion_stock: Array = []
## Where Personagens/Formação should return to when closed. Set by whichever
## screen opened them (city hub or dungeon map). Never persisted.
var nav_return_scene: String = "res://scripts/city/city_hub.tscn"
## Global turn counter — advances on every combat round and every room the party
## walks into. Status durations are measured in these turns, so buffs decay while
## exploring as well as while fighting.
var turn_counter: int = 0
## Folder that holds the save files. Tests point it at a throwaway folder so
## they never touch the real save; the game never changes it.
var save_dir: String = "user://"
## The primary save: the one Continue loads.
var save_path: String:
	get:
		return save_dir.path_join("save.json")
## The previous good save, kept so an interrupted write never loses everything.
var backup_path: String:
	get:
		return save_dir.path_join("save.bak.json")
## Where a new save is written and checked before it replaces save_path.
## Never loaded: if it is still on disk, that write was interrupted.
var tmp_path: String:
	get:
		return save_dir.path_join("save.tmp.json")
## A primary save that failed to parse is moved here (evidence, never loaded).
var corrupt_path: String:
	get:
		return save_dir.path_join("save.corrupt.json")


## Resets gold and inventory for a new game. Party.start_new_game() handles heroes.
func start_new_game() -> void:
	gold = STARTING_GOLD
	inventory = STARTER_ITEMS.duplicate()
	owned_skins = []
	current_run = null
	dungeon_level = 1
	turn_counter = 0
	Party.clear_statuses()
	restock_market()


## Grants a locked skin (by full id). Returns true if it was newly unlocked.
## The unlock hook for gold buys, level milestones and event rewards.
func unlock_skin(id: String) -> bool:
	if id.is_empty() or owned_skins.has(id):
		return false
	owned_skins.append(id)
	save_game()
	return true


## Rolls a fresh random shelf for the market's limited-stock section:
## MARKET_SLOTS distinct equipment items, one unit each.
func restock_market() -> void:
	var pool := MARKET_EQUIPMENT_POOL.duplicate()
	pool.shuffle()
	market_stock = []
	for i in mini(MARKET_SLOTS, pool.size()):
		market_stock.append({"id": pool[i], "qty": 1})
	restock_potions()


## Rolls a fresh, random consumable shelf. Quantities vary per restock so the
## player cannot count on stocking up to the same depth every trip.
func restock_potions() -> void:
	potion_stock = []
	for entry in MARKET_POTIONS:
		(
			potion_stock
			. append(
				{
					"id": str(entry["id"]),
					"qty": randi_range(int(entry["min"]), int(entry["max"])),
				}
			)
		)


func add_item(item_id: String) -> void:
	inventory.append(item_id)


func remove_item(item_id: String) -> bool:
	var idx := inventory.find(item_id)
	if idx >= 0:
		inventory.remove_at(idx)
		return true
	return false


# ── Persistence ───────────────────────────────────────────────────────────────


## True if Continue has something to load: the primary save or its backup.
## A leftover tmp file does not count; it is an interrupted write.
func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(backup_path)


## Removes the primary, backup and tmp files. The .corrupt file is kept.
func delete_save() -> void:
	for path in [save_path, backup_path, tmp_path]:
		_remove_file(path)


## Writes the save atomically: to tmp_path first, read back to confirm it is
## valid, and only then rotated into place (see _rotate_tmp_into_place).
func save_game() -> void:
	var run_data = null
	if current_run != null:
		run_data = (current_run as DungeonRun).to_dict()
	var payload := {
		"version": SAVE_VERSION,
		"gold": gold,
		"inventory": inventory.duplicate(),
		"owned_skins": owned_skins.duplicate(),
		"heroes": Party.serialize(),
		"run": run_data,
		"dungeon_level": dungeon_level,
		"turn_counter": turn_counter,
		"market": market_stock.duplicate(true),
		"potions": potion_stock.duplicate(true),
	}
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("GameState.save_game: cannot open %s for writing" % tmp_path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	if _read_save_dict(tmp_path).is_empty():
		push_error(
			"GameState.save_game: %s did not read back as valid JSON; old save kept" % tmp_path
		)
		_remove_file(tmp_path)
		return
	_rotate_tmp_into_place()


## Moves the checked tmp_path into save_path, demoting the current save to
## backup_path. Godot's rename does not overwrite atomically on every platform
## (on Windows it deletes the target, then moves), so no step here ever
## renames onto an existing file. A crash between any two steps still leaves
## a valid save that load_game() will find:
##   1. drop the old backup     -> primary + tmp on disk
##   2. primary -> backup       -> backup + tmp (the backup loads)
##   3. tmp -> primary          -> primary + backup
## A primary that no longer parses is moved to corrupt_path in step 2 instead,
## so it never replaces a good backup.
func _rotate_tmp_into_place() -> void:
	if FileAccess.file_exists(save_path):
		if _read_save_dict(save_path).is_empty():
			_move_file(save_path, corrupt_path)
		else:
			_remove_file(backup_path)
			_move_file(save_path, backup_path)
	if FileAccess.file_exists(save_path):
		push_error(
			(
				"GameState.save_game: could not move the old %s aside; new save left in %s"
				% [save_path, tmp_path]
			)
		)
		return
	_move_file(tmp_path, save_path)


## Returns true on success. Tries save_path, then backup_path, and returns
## false (so the caller can start fresh) if neither can be loaded. A save
## written by a newer build is refused without touching any file, so an older
## build can't clobber it.
func load_game() -> bool:
	var data := _read_save_dict(save_path)
	if data.is_empty() and FileAccess.file_exists(save_path):
		push_warning("GameState.load_game: %s is corrupt; moved to %s" % [save_path, corrupt_path])
		_move_file(save_path, corrupt_path)
	if not data.is_empty() and not _is_supported_version(save_path, data):
		if _save_version(data) > SAVE_VERSION:
			return false
		data = {}
	if data.is_empty():
		data = _read_save_dict(backup_path)
		if data.is_empty() or not _is_supported_version(backup_path, data):
			return false
		push_warning(
			"GameState.load_game: primary save unusable; loaded the backup %s" % backup_path
		)
	data = _migrate(data)
	if data.is_empty():
		return false
	_apply_save_dict(data)
	return true


## Reads and parses one save file. Returns {} if it is missing, unreadable or
## not a JSON object. Never changes anything on disk.
static func _read_save_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	return json.data


static func _save_version(data: Dictionary) -> int:
	return int(data.get("version", 0))


## True if `data` can be migrated to SAVE_VERSION. Warns (naming `path`) if
## not: too old (v1/v2 are never migrated) or newer than this build.
static func _is_supported_version(path: String, data: Dictionary) -> bool:
	var version := _save_version(data)
	if version > SAVE_VERSION:
		push_warning(
			(
				"GameState.load_game: %s is v%d, newer than this build (v%d); left untouched"
				% [path, version, SAVE_VERSION]
			)
		)
		return false
	if version < MIN_SUPPORTED_VERSION:
		push_warning(
			(
				"GameState.load_game: %s is v%d, older than v%d; not migrated"
				% [path, version, MIN_SUPPORTED_VERSION]
			)
		)
		return false
	return true


## Steps a supported save up to SAVE_VERSION, one version at a time. Returns
## {} if a step is missing. Nothing to do yet: the save is still v3.
static func _migrate(data: Dictionary) -> Dictionary:
	var version := _save_version(data)
	# When SAVE_VERSION becomes 4, add the first step here, then one `if` per
	# later version, in order:
	# if version == 3:
	# 	data = _migrate_v3_to_v4(data)
	# 	version = 4
	if version != SAVE_VERSION:
		push_error(
			"GameState._migrate: no migration step from v%d to v%d" % [version, SAVE_VERSION]
		)
		return {}
	data["version"] = version
	return data


## Renames `from` to `to`, replacing any existing `to`. Not atomic.
static func _move_file(from: String, to: String) -> void:
	_remove_file(to)
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to)
	)
	if err != OK:
		push_error("GameState: could not rename %s to %s (error %d)" % [from, to, err])


static func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Copies a parsed, migrated save dictionary into live state.
func _apply_save_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", STARTING_GOLD))
	dungeon_level = int(data.get("dungeon_level", 1))
	turn_counter = int(data.get("turn_counter", 0))
	var inv: Array = data.get("inventory", [])
	inventory.clear()
	for item_id in inv:
		inventory.append(str(item_id))
	owned_skins.clear()
	for sid in data.get("owned_skins", []):
		owned_skins.append(str(sid))
	Party.deserialize(data.get("heroes", {}))
	var run_data = data.get("run", null)
	if run_data != null and run_data is Dictionary:
		current_run = DungeonRun.from_dict(run_data)
	else:
		current_run = null
	var market_data = data.get("market", null)
	if market_data is Array and not market_data.is_empty():
		market_stock = []
		for entry in market_data:
			market_stock.append({"id": str(entry.get("id", "")), "qty": int(entry.get("qty", 0))})
	else:
		# Save predates the market (Fase 1) — just stock the shelves.
		restock_market()
	var potion_data = data.get("potions", null)
	if potion_data is Array and not potion_data.is_empty():
		potion_stock = []
		for entry in potion_data:
			potion_stock.append({"id": str(entry.get("id", "")), "qty": int(entry.get("qty", 0))})
	else:
		# Save predates limited potion stock — roll a fresh shelf.
		restock_potions()


## TPK penalty: revive all heroes at 25 % HP, lose 20 % gold, clear the run.
## Called by DungeonMap on defeat before saving and returning to the city.
## A run ending (even in defeat) restocks the market.
func apply_tpk_penalty() -> void:
	for h in Party.heroes:
		h.hp = maxi(1, roundi(h.max_hp() * 0.25))
	gold = roundi(gold * 0.8)
	current_run = null
	Party.clear_statuses()
	restock_market()
