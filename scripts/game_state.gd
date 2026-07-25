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
	"sword_rusty", "sword_iron", "sword_steel", "dagger_shadow",
	"staff_apprentice", "staff_runed", "staff_arcane",
	"armor_cloth", "armor_leather", "armor_chain", "armor_plate",
	"ring_might", "ring_focus", "ring_arcane",
	"amulet_swift", "amulet_ward",
]
## How many random equipment items each restock puts on the shelves.
const MARKET_SLOTS: int = 5
const SAVE_PATH: String = "user://save.json"
## v2: room-based dungeon (floors of rooms, player position, explored state).
## v3: customizable party (hero custom_name / skin_id / is_main).
## Older saves are intentionally NOT migrated — the version check rejects them
## and the menu falls back to a fresh game.
const SAVE_VERSION: int = 3

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
## Where Personagens/Formação should return to when closed. Set by whichever
## screen opened them (city hub or dungeon map). Never persisted.
var nav_return_scene: String = "res://scripts/city/city_hub.tscn"


## Resets gold and inventory for a new game. Party.start_new_game() handles heroes.
func start_new_game() -> void:
	gold = STARTING_GOLD
	inventory = STARTER_ITEMS.duplicate()
	owned_skins = []
	current_run = null
	dungeon_level = 1
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
		"owned_skins": owned_skins.duplicate(),
		"heroes": Party.serialize(),
		"run": run_data,
		"dungeon_level": dungeon_level,
		"market": market_stock.duplicate(true),
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
	dungeon_level = int(data.get("dungeon_level", 1))
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
	return true


## TPK penalty: revive all heroes at 25 % HP, lose 20 % gold, clear the run.
## Called by DungeonMap on defeat before saving and returning to the city.
## A run ending (even in defeat) restocks the market.
func apply_tpk_penalty() -> void:
	for h in Party.heroes:
		h.hp = maxi(1, roundi(h.max_hp() * 0.25))
	gold = roundi(gold * 0.8)
	current_run = null
	restock_market()
