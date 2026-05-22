## Autoload singleton for run/meta state that isn't the party itself:
## gold, the shared inventory (item ids), and the active dungeon run.
## Includes file-based save/load (JSON, versioned) and the TPK penalty.
extends Node

const STARTING_GOLD: int = 50
const STARTER_ITEMS: Array[String] = ["potion_heal", "potion_heal", "potion_mana"]
const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 1

var gold: int = 0
## Item ids (e.g. "potion_heal"). Duplicates allowed; resolved to ItemData on use.
var inventory: Array[String] = []
## The active DungeonRun. Left untyped to avoid a class_name <-> autoload
## dependency cycle (DungeonRun references the GameState autoload), which
## Godot resolves inconsistently across recompiles. Callers cast as needed.
var current_run = null


## Resets gold and inventory for a new game. Party.start_new_game() handles heroes.
func start_new_game() -> void:
	gold = STARTING_GOLD
	inventory = STARTER_ITEMS.duplicate()
	current_run = null


func add_item(item_id: String) -> void:
	inventory.append(item_id)


func remove_item(item_id: String) -> bool:
	var idx := inventory.find(item_id)
	if idx >= 0:
		inventory.remove_at(idx)
		return true
	return false


# ── Persistence ───────────────────────────────────────────────────────────────

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save_game() -> void:
	var run_data = null
	if current_run != null:
		run_data = (current_run as DungeonRun).to_dict()
	var payload := {
		"version": SAVE_VERSION,
		"gold": gold,
		"inventory": inventory.duplicate(),
		"heroes": Party.serialize(),
		"run": run_data,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState.save_game: cannot open %s for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


## Returns true on success. On version mismatch or corrupt data returns false
## so the caller can start fresh.
func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("GameState.load_game: corrupt save — starting fresh")
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("GameState.load_game: version mismatch — starting fresh")
		return false
	gold = int(data.get("gold", STARTING_GOLD))
	var inv: Array = data.get("inventory", [])
	inventory.clear()
	for item_id in inv:
		inventory.append(str(item_id))
	Party.deserialize(data.get("heroes", {}))
	var run_data = data.get("run", null)
	if run_data != null and run_data is Dictionary:
		current_run = DungeonRun.from_dict(run_data)
	else:
		current_run = null
	return true


## TPK penalty: revive all heroes at 25 % HP, lose 20 % gold, clear the run.
## Called by DungeonMap on defeat before saving and returning to the menu.
func apply_tpk_penalty() -> void:
	for h in Party.heroes:
		h.hp = maxi(1, roundi(h.max_hp() * 0.25))
	gold = roundi(gold * 0.8)
	current_run = null
