## Autoload singleton for run/meta state that isn't the party itself:
## gold, the shared inventory (item ids), and the active dungeon run.
## Step 8 (save) will add serialize/deserialize + file I/O on top of this;
## the inventory/equip UI is step 6.
extends Node

const STARTING_GOLD: int = 50
const STARTER_ITEMS: Array[String] = ["potion_heal", "potion_heal", "potion_mana"]

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
