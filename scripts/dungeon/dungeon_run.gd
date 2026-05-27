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

## Difficulty scaling per step. Enemy stats and rewards are multiplied by
## 1 + (floor-1)*FLOOR_SCALE + (dungeon_level-1)*DUNGEON_SCALE.
## Floor 1 of dungeon 1 is the 1.0 baseline.
const FLOOR_SCALE := 0.15
const DUNGEON_SCALE := 0.25

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
		out.append(_scale_enemy(_load_enemy(pool[randi() % pool.size()]), floor_index + 1))
	return out


func roll_boss() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	var boss_floor := floors.size()  # the boss sits on the last floor (1-based)
	for id in BOSS_ENCOUNTER:
		out.append(_scale_enemy(_load_enemy(id), boss_floor))
	return out


func _load_enemy(id: String) -> EnemyData:
	return load(ENEMY_DIR + id + ".tres") as EnemyData


## Returns the enemy with stats and rewards scaled for the current step.
## multiplier = 1 + (floor_num-1)*FLOOR_SCALE + (level-1)*DUNGEON_SCALE,
## where floor_num is the 1-based floor and `level` is the dungeon number.
## The baseline (floor 1, dungeon 1) returns the base resource unchanged;
## any higher step duplicates it so the original .tres asset is never mutated.
func _scale_enemy(base: EnemyData, floor_num: int) -> EnemyData:
	var mult := 1.0 + (floor_num - 1) * FLOOR_SCALE + (level - 1) * DUNGEON_SCALE
	if mult <= 1.0:
		return base
	var scaled := base.duplicate() as EnemyData
	scaled.max_hp    = roundi(base.max_hp    * mult)
	scaled.atk       = roundi(base.atk       * mult)
	scaled.def       = roundi(base.def       * mult)
	scaled.mag       = roundi(base.mag       * mult)
	scaled.spd       = roundi(base.spd       * mult)
	scaled.xp_reward = roundi(base.xp_reward * mult)
	scaled.gold_min  = roundi(base.gold_min  * mult)
	scaled.gold_max  = roundi(base.gold_max  * mult)
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
		"id": "fountain",
		"title": "Fonte Antiga",
		"desc": "Uma fonte cristalina brilha com luz suave. Beber dela?",
		"options": [
			{"text": "Beber", "available": true, "effect": _fountain_drink},
			{"text": "Ignorar", "available": true, "effect": _move_on},
		],
	}


func _event_merchant() -> Dictionary:
	return {
		"id": "merchant",
		"title": "Mercador Errante",
		"desc": "Um velho mercador oferece uma poção de cura por 30 ouro.",
		"options": [
			{"text": "Comprar (30 ouro)", "available": GameState.gold >= 30, "effect": _merchant_buy},
			{"text": "Recusar", "available": true, "effect": _move_on},
		],
	}


func _event_altar() -> Dictionary:
	return {
		"id": "altar",
		"title": "Altar Sombrio",
		"desc": "Um altar sussurra promessas de poder em troca de sangue.",
		"options": [
			{"text": "Sacrificar HP por XP", "available": true, "effect": _altar_sacrifice},
			{"text": "Recuar", "available": true, "effect": _altar_retreat},
		],
	}


func _event_chest() -> Dictionary:
	return {
		"id": "chest",
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
