## Autoload "DevTools": debug-build cheats (D-015). Lets Roxton set up a
## feel test in minutes, and lets agents set up any game state through the
## Godot MCP's game_eval, e.g.
##     DevTools.quick_party(["warrior", "cleric", "rogue", "mage"], 5)
##     return DevTools.start_run(1)
## then, once the dungeon map has loaded,
##     return DevTools.start_fight(["boss_necromancer", "skeleton"])
##
## In a release build this node does nothing: no panel, and every call
## returns an error string. Every call returns a short String saying what
## happened (or starting with "Error:") and never crashes on a bad id.
##
## Dev-only UI, so English-only hardcoded text is allowed here (D-015).
extends Node

const PANEL_SCENE := "res://scripts/dev/dev_panel.tscn"
const CITY_SCENE := "res://scripts/city/city_hub.tscn"
const DUNGEON_SCENE := "res://scripts/dungeon/dungeon_map.tscn"
const COMBAT_SCENE := "res://scripts/combat/combat_screen.tscn"
const CLASS_DIR := "res://resources/classes/"
const ENEMY_DIR := "res://resources/enemies/"
const ITEM_DIR := "res://resources/items/"
const DEFAULT_CLASSES: Array = ["warrior", "cleric", "rogue", "mage"]
## Names given to quick_party heroes, by slot.
const QUICK_NAMES: Array[String] = ["Aria", "Bram", "Cora", "Dax"]
## Most enemies a dev fight may hold (the largest real encounter is 4).
const MAX_ENEMIES := 4

## True only in debug builds. Every API call checks it first.
var enabled := false


func _ready() -> void:
	enabled = OS.is_debug_build()
	if not enabled:
		return
	# Loaded (not preloaded) so a release build never touches the panel scene.
	var panel := (load(PANEL_SCENE) as PackedScene).instantiate()
	add_child(panel)


# ── Party ─────────────────────────────────────────────────────────────────────


## Builds a named party of the given classes at `level`, with full HP/MP,
## skipping character creation. Like character creation, it starts a new
## game (gold, inventory and run reset) and goes to the city hub.
func quick_party(class_ids: Array = DEFAULT_CLASSES, level: int = 1) -> String:
	if not enabled:
		return _disabled()
	if _in_combat():
		return "Error: finish or flee the current fight first."
	if class_ids.size() != Party.PARTY_SIZE:
		return "Error: need exactly %d class ids, got %d." % [Party.PARTY_SIZE, class_ids.size()]
	var specs: Array = []
	for i in class_ids.size():
		var class_id := str(class_ids[i]).strip_edges()
		if not Party.ALL_CLASS_IDS.has(class_id):
			return "Error: unknown class id '%s'. Valid: %s." % [class_id, Party.ALL_CLASS_IDS]
		specs.append({"name": QUICK_NAMES[i], "class_id": class_id, "skin_id": "1"})
	Party.build_party(specs)
	GameState.start_new_game()
	var lvl := _apply_level(level)
	Fade.change_scene(CITY_SCENE)
	return "Party built at level %d: %s. Going to the city." % [lvl, _party_summary()]


## Sets every hero to `level` (clamped 1..LEVEL_CAP) with full HP/MP. XP is
## never awarded: Party.award_xp can unlock a skin, which saves the game.
func set_level(level: int) -> String:
	if not enabled:
		return _disabled()
	if Party.heroes.is_empty():
		return "Error: no party. Call quick_party() first."
	if _in_combat():
		return "Error: finish or flee the current fight first."
	var lvl := _apply_level(level)
	_refresh_map()
	return "All heroes set to level %d (full HP/MP): %s." % [lvl, _party_summary()]


## Restores every hero to full HP and MP, reviving the fallen.
func heal_party() -> String:
	if not enabled:
		return _disabled()
	if Party.heroes.is_empty():
		return "Error: no party. Call quick_party() first."
	for h in Party.heroes:
		h.hp = h.max_hp()
		h.mp = h.max_mp()
	_refresh_map()
	return "Party healed to full HP/MP."


## Sets each hero's level directly (like BalanceSim), keeping Skill Points
## consistent with it: a hero has 1 SP per level in total, spent or not.
func _apply_level(level: int) -> int:
	var lvl := clampi(level, 1, Party.LEVEL_CAP)
	for h in Party.heroes:
		h.level = lvl
		h.xp = 0
		var spent := 0
		for key in h.sp_spent:
			spent += int(h.sp_spent[key])
		if spent > lvl:
			# Lowered below what was already spent: refund everything.
			h.sp_spent = {}
			spent = 0
		h.sp_available = lvl - spent
		Party.reconcile_surplus_sp(h)
		h.hp = h.max_hp()
		h.mp = h.max_mp()
	return lvl


# ── Gold & items ──────────────────────────────────────────────────────────────


## Adds (or, if negative, removes) gold. Gold never drops below 0.
func add_gold(amount: int) -> String:
	if not enabled:
		return _disabled()
	GameState.gold = maxi(0, GameState.gold + amount)
	_refresh_map()
	return "Gold %+d, now %d." % [amount, GameState.gold]


## Adds `qty` copies of an item to the shared inventory.
func add_item(id: String, qty: int = 1) -> String:
	if not enabled:
		return _disabled()
	if not ResourceLoader.exists(ITEM_DIR + id + ".tres"):
		return "Error: unknown item id '%s'." % id
	if qty < 1:
		return "Error: qty must be at least 1."
	for i in qty:
		GameState.add_item(id)
	return "Added %d x %s (inventory: %d items)." % [qty, id, GameState.inventory.size()]


# ── Runs ──────────────────────────────────────────────────────────────────────


## Starts a fresh run of `dungeon_level` and opens the dungeon map. The map
## loads a moment later (fade + scene change), so wait about a second before
## calling goto_floor / start_fight through game_eval.
func start_run(dungeon_level: int = 1) -> String:
	if not enabled:
		return _disabled()
	if Party.heroes.is_empty():
		return "Error: no party. Call quick_party() first."
	if _in_combat():
		return "Error: finish or flee the current fight first."
	var lvl := maxi(1, dungeon_level)
	GameState.dungeon_level = lvl
	var run := DungeonRun.generate(lvl)
	GameState.current_run = run
	GameState.save_game()
	Fade.change_scene(DUNGEON_SCENE)
	var boss_ids: Array = DungeonRun.BOSS_ENCOUNTERS[run.boss]
	return "Run started: dungeon %d, floor 1, boss %s. Opening the map." % [lvl, boss_ids[0]]


## Moves the current run to floor `n` (1..NUM_FLOORS), at its start room.
func goto_floor(n: int) -> String:
	if not enabled:
		return _disabled()
	var run := GameState.current_run as DungeonRun
	if run == null:
		return "Error: no active run. Call start_run() first."
	if n < 1 or n > DungeonRun.NUM_FLOORS:
		return "Error: floor must be 1..%d, got %d." % [DungeonRun.NUM_FLOORS, n]
	if _in_combat():
		return "Error: finish or flee the current fight first."
	run.current_floor = n - 1
	run.player_pos = Vector2i.ZERO
	run.current_room().explored = true
	run._mark_adjacent_seen()
	GameState.save_game()
	_refresh_map()
	return "Now on floor %d of %d." % [n, DungeonRun.NUM_FLOORS]


## Marks every room on the current floor as seen, lifting the fog.
func reveal_floor() -> String:
	if not enabled:
		return _disabled()
	var run := GameState.current_run as DungeonRun
	if run == null:
		return "Error: no active run. Call start_run() first."
	var rooms: Dictionary = run.rooms_on_floor()
	for room in rooms.values():
		(room as DungeonRoom).seen = true
	_refresh_map()
	return "Revealed %d rooms on floor %d." % [rooms.size(), run.current_floor + 1]


# ── Combat ────────────────────────────────────────────────────────────────────


## Starts combat on the dungeon map against `enemy_ids` (boss ids work too),
## scaled for the current dungeon and floor like a real encounter. The fight
## resolves like one in the player's current room: a win clears that room.
func start_fight(enemy_ids: Array) -> String:
	if not enabled:
		return _disabled()
	var map := _dungeon_map()
	if map == null or map.run == null:
		return "Error: not on the dungeon map. Call start_run() and wait for the map to load."
	if _in_combat():
		return "Error: a fight is already running."
	if enemy_ids.is_empty() or enemy_ids.size() > MAX_ENEMIES:
		return "Error: need 1..%d enemy ids, got %d." % [MAX_ENEMIES, enemy_ids.size()]
	var run: DungeonRun = map.run
	var encounter: Array[EnemyData] = []
	for raw_id in enemy_ids:
		var id := str(raw_id).strip_edges()
		if not ResourceLoader.exists(ENEMY_DIR + id + ".tres"):
			return "Error: unknown enemy id '%s'." % id
		encounter.append(run._scale_enemy(run._load_enemy(id), run.current_floor + 1))
	map._start_combat(encounter)
	return "Fight started on floor %d: %s." % [run.current_floor + 1, ", ".join(enemy_ids)]


# ── Lists (for the panel's pickers) ───────────────────────────────────────────


## Every enemy id in resources/enemies/, sorted.
func list_enemies() -> Array[String]:
	return _list_ids(ENEMY_DIR)


## Every item id in resources/items/, sorted.
func list_items() -> Array[String]:
	return _list_ids(ITEM_DIR)


## Resource ids (file names without extension) in `dir`. Exported builds
## rename .tres files to .tres.remap, so that suffix is stripped too.
func _list_ids(dir: String) -> Array[String]:
	var ids: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		var file_name := file.trim_suffix(".remap")
		if file_name.ends_with(".tres"):
			ids.append(file_name.get_basename())
	ids.sort()
	return ids


# ── Helpers ───────────────────────────────────────────────────────────────────


func _disabled() -> String:
	return "Error: DevTools is disabled in release builds."


## The dungeon map scene if it is the current screen, else null.
func _dungeon_map() -> Node:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == DUNGEON_SCENE:
		return scene
	return null


## True while a combat screen is up: the map's overlay, or a standalone one.
func _in_combat() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	if scene.scene_file_path == COMBAT_SCENE:
		return true
	var map := _dungeon_map()
	return map != null and map._combat_overlay != null


## Redraws the dungeon map (header, party strip, grid) if it is on screen.
func _refresh_map() -> void:
	var map := _dungeon_map()
	if map != null and map.run != null:
		map._refresh_all()


func _party_summary() -> String:
	var parts: Array[String] = []
	for h in Party.heroes:
		parts.append("%s (%s)" % [h.display_name(), h.class_data.id])
	return ", ".join(parts)
