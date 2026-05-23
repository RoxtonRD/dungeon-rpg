## One dungeon run: a procedural branching node map plus the helpers that
## resolve each node type. Generation, encounter pools, events, treasure and
## rest logic are adapted from the prototype dungeon.js, trimmed to the v1
## enemy/item roster and 3 floors. A "floor" is one column of the map; with
## 3 floors that's: start combat -> one branch of 2-3 nodes -> boss.
class_name DungeonRun
extends RefCounted

const ENEMY_DIR := "res://resources/enemies/"

## Enemy id pools by floor depth (index clamped). v1 roster only.
const ENCOUNTER_POOLS := [
	["goblin", "bat", "wolf", "skeleton"],
	["bandit", "dark_elf", "orc", "skeleton", "wolf"],
]
## The single v1 dungeon boss: Necromante plus a skeleton minion.
const BOSS_ENCOUNTER := ["boss_necromancer", "skeleton"]

var level: int = 1
## Array of floors; each element is an Array[DungeonNode].
var floors: Array = []
## Highest floor fully resolved; -1 = nothing entered yet.
var current_floor: int = -1


# ── Generation ────────────────────────────────────────────────────────────────

static func generate(p_level: int = 1, num_floors: int = 3) -> DungeonRun:
	var run := DungeonRun.new()
	run.level = p_level
	for f in num_floors:
		var is_last := f == num_floors - 1
		var width: int
		if is_last or f == 0:
			width = 1
		else:
			width = 2 + (1 if randf() < 0.5 else 0)
		var row: Array[DungeonNode] = []
		for i in width:
			var node := DungeonNode.new()
			node.floor_index = f
			node.slot_index = i
			if is_last:
				node.kind = DungeonNode.NodeType.BOSS
			elif f == 0:
				node.kind = DungeonNode.NodeType.COMBAT
			else:
				node.kind = _random_kind()
			row.append(node)
		run.floors.append(row)
	return run


static func _random_kind() -> DungeonNode.NodeType:
	var r := randf()
	if r < 0.55:
		return DungeonNode.NodeType.COMBAT
	if r < 0.78:
		return DungeonNode.NodeType.TREASURE
	if r < 0.90:
		return DungeonNode.NodeType.EVENT
	return DungeonNode.NodeType.REST


# ── Navigation ────────────────────────────────────────────────────────────────

## Nodes the player may move to next (all nodes in the next floor).
func reachable_nodes() -> Array[DungeonNode]:
	var out: Array[DungeonNode] = []
	var next := current_floor + 1
	if next < floors.size():
		for node in floors[next]:
			out.append(node)
	return out


## Marks a node resolved and advances the run to its floor.
func advance_to(node: DungeonNode) -> void:
	node.visited = true
	current_floor = node.floor_index


func is_complete() -> bool:
	return current_floor >= floors.size() - 1


# ── Encounters ────────────────────────────────────────────────────────────────

func roll_encounter(floor_index: int) -> Array[EnemyData]:
	var pool: Array = ENCOUNTER_POOLS[mini(floor_index, ENCOUNTER_POOLS.size() - 1)]
	var count := randi_range(2, 4)
	var out: Array[EnemyData] = []
	for i in count:
		out.append(_scale_enemy(_load_enemy(pool[randi() % pool.size()])))
	return out


func roll_boss() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for id in BOSS_ENCOUNTER:
		out.append(_scale_enemy(_load_enemy(id)))
	return out


func _load_enemy(id: String) -> EnemyData:
	return load(ENEMY_DIR + id + ".tres") as EnemyData


## Returns the enemy with stats multiplied for the current dungeon level.
## Level 1 returns the base resource unchanged. Level 2+ duplicates it so
## the original .tres asset is never mutated.
func _scale_enemy(base: EnemyData) -> EnemyData:
	if level <= 1:
		return base
	var scaled := base.duplicate() as EnemyData
	var f := 1.0 + (level - 1) * 0.30  # +30 % per dungeon level above 1
	scaled.max_hp    = roundi(base.max_hp    * f)
	scaled.atk       = roundi(base.atk       * f)
	scaled.def       = roundi(base.def       * f)
	scaled.mag       = roundi(base.mag       * f)
	scaled.spd       = roundi(base.spd       * f)
	scaled.xp_reward = roundi(base.xp_reward * f)
	scaled.gold_min  = roundi(base.gold_min  * f)
	scaled.gold_max  = roundi(base.gold_max  * f)
	return scaled


# ── Treasure ──────────────────────────────────────────────────────────────────

## Rolls gold + maybe one item, deposits both into GameState. Returns a summary
## {gold:int, items:Array[String]}.
func resolve_treasure() -> Dictionary:
	var gold_amount := randi_range(5 + level * 4, 12 + level * 8)
	GameState.gold += gold_amount
	var items: Array[String] = []
	if randf() < 0.55:
		var pool := _loot_pool()
		var item_id: String = pool[randi() % pool.size()]
		items.append(item_id)
		GameState.add_item(item_id)
	return {"gold": gold_amount, "items": items}


func _loot_pool() -> Array:
	if level <= 1:
		return ["sword_rusty", "staff_apprentice", "armor_cloth", "potion_heal", "potion_heal", "potion_mana"]
	return ["sword_iron", "staff_apprentice", "armor_leather", "ring_might", "ring_focus", "potion_heal", "potion_mana"]


# ── Rest ──────────────────────────────────────────────────────────────────────

func resolve_rest() -> void:
	for h in Party.heroes:
		h.hp = h.max_hp()
		h.mp = h.max_mp()


# ── Events ────────────────────────────────────────────────────────────────────

## Returns a random event as {title:String, desc:String, options:Array}, where
## each option is {text:String, available:bool, effect:Callable() -> String}.
func roll_event() -> Dictionary:
	var pool := [_event_fountain(), _event_merchant(), _event_altar(), _event_chest()]
	return pool[randi() % pool.size()]


func _event_fountain() -> Dictionary:
	return {
		"title": "Fonte Antiga",
		"desc": "Uma fonte cristalina brilha com luz suave. Beber dela?",
		"options": [
			{"text": "Beber", "available": true, "effect": _fountain_drink},
			{"text": "Ignorar", "available": true, "effect": _move_on},
		],
	}


func _event_merchant() -> Dictionary:
	return {
		"title": "Mercador Errante",
		"desc": "Um velho mercador oferece uma poção de cura por 30 ouro.",
		"options": [
			{"text": "Comprar (30 ouro)", "available": GameState.gold >= 30, "effect": _merchant_buy},
			{"text": "Recusar", "available": true, "effect": _move_on},
		],
	}


func _event_altar() -> Dictionary:
	return {
		"title": "Altar Sombrio",
		"desc": "Um altar sussurra promessas de poder em troca de sangue.",
		"options": [
			{"text": "Sacrificar HP por XP", "available": true, "effect": _altar_sacrifice},
			{"text": "Recuar", "available": true, "effect": _altar_retreat},
		],
	}


func _event_chest() -> Dictionary:
	return {
		"title": "Baú Suspeito",
		"desc": "Um baú trancado pulsa com energia.",
		"options": [
			{"text": "Forçar (pode dar errado)", "available": true, "effect": _chest_force},
			{"text": "Deixar", "available": true, "effect": _chest_leave},
		],
	}


func _move_on() -> String:
	return "Vocês seguem em frente."


func _fountain_drink() -> String:
	resolve_rest()
	return "O grupo é completamente curado!"


func _merchant_buy() -> String:
	if GameState.gold < 30:
		return "Ouro insuficiente."
	GameState.gold -= 30
	GameState.add_item("potion_heal")
	return "Poção adquirida."


func _altar_sacrifice() -> String:
	for h in Party.heroes:
		h.hp = maxi(1, int(h.hp / 2.0))
		Party.award_xp(h, 12)
	return "Cada herói perde metade do HP, mas ganha 12 XP."


func _altar_retreat() -> String:
	return "Vocês recuam, evitando o altar."


func _chest_force() -> String:
	if randf() < 0.6:
		var loot := ["potion_heal", "ring_might", "ring_focus"]
		GameState.add_item(loot[randi() % loot.size()])
		return "Sucesso! Um item estava dentro."
	for h in Party.heroes:
		h.hp = maxi(1, h.hp - 8)
	return "Armadilha! Cada herói perde 8 HP."


func _chest_leave() -> String:
	return "Melhor não arriscar."


# ── Persistence ───────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	var floors_data: Array = []
	for floor_row in floors:
		var row_data: Array = []
		for node in floor_row:
			row_data.append((node as DungeonNode).to_dict())
		floors_data.append(row_data)
	return {
		"level": level,
		"current_floor": current_floor,
		"floors": floors_data,
	}


static func from_dict(d: Dictionary) -> DungeonRun:
	var run := DungeonRun.new()
	run.level = int(d.get("level", 1))
	run.current_floor = int(d.get("current_floor", -1))
	var floors_data: Array = d.get("floors", [])
	for row_data in floors_data:
		var row: Array[DungeonNode] = []
		for nd in row_data:
			row.append(DungeonNode.from_dict(nd))
		run.floors.append(row)
	return run
