## One dungeon run (v2 Fase 1): four floors of orthogonally connected square
## rooms on a grid, plus the helpers that resolve room content. Generation
## grows each floor as a connected tree with extra loop passages; content
## types are rolled per room with per-floor weights. Encounters, events,
## treasure, rest and the difficulty formula are carried over from v1
## unchanged — the map changed, not the game.
class_name DungeonRun
extends RefCounted

const ENEMY_DIR := "res://resources/enemies/"

## Normal and elite fights come from the authored groups in
## resources/encounters/ (see EncounterGroupData and `roll_encounter`).
## Boss encounters, one rolled per run (see `boss`). Each is the boss plus
## thematic minions; the roll is stored on the run so it survives save/reload.
## Three comparable-but-distinct fights: a boss + tanky add, a boss + fragile
## swarm, and a lone hard-hitter (no add — its high stats and AoE offset the
## lost action economy).
const BOSS_ENCOUNTERS := [
	["boss_necromancer", "skeleton"],  # undead: Necromante + esqueleto
	["boss_vampire", "bat", "bat"],  # vampiro: Vampiro + morcegos
	["boss_dragon_hatchling"],  # draconico: Dragao Jovem (sozinho)
]

## Difficulty scaling per step. Enemy stats and rewards are multiplied by
##   pow(DUNGEON_GROWTH, dungeon_level-1) * (1 + (floor-1)*FLOOR_SCALE)
## Floor 1 of dungeon 1 is the 1.0 baseline.
##
## Dungeon scaling is exponential, not linear, because hero power compounds:
## levels stack stat growth AND unlock ultimates at level 5. A linear
## `1 + (n-1)*s` ramp shrinks in ratio each step (D2->D3 is only 1.26x at
## s=0.35), so deeper dungeons kept getting *easier*. A constant growth factor
## keeps each dungeon a fixed step harder than the last.
const FLOOR_SCALE := 0.15
const DUNGEON_GROWTH := 1.4

## Rooms per floor before the ±1 jitter; floor 4 additionally gets the
## boss room appended after generation.
const ROOM_BASE_COUNTS := [5, 7, 9, 6]
const NUM_FLOORS := 4
## Chance of opening an extra passage between two adjacent rooms that the
## growth tree left unconnected (checked once per pair).
const LOOP_CHANCE := 0.35
## Per-floor chance that one ordinary room becomes a rare SHRINE (grants an
## event-exclusive skin). FLAG: tune me.
const SHRINE_CHANCE := 0.12
## Per-floor chance of one optional ELITE room, on floors 2-4 only (the 0-based
## floor index must be at least ELITE_FIRST_FLOOR). FLAG: tune me.
const ELITE_CHANCE := 0.6
const ELITE_FIRST_FLOOR := 1

## Fight quota per floor (D-038): the fewest COMBAT rooms each floor has, and
## how many more than that it may have. The boss and elite rooms don't count.
## Generation adjusts the rolled room kinds to land inside the range. E5a cut
## these from [2, 3, 4, 3] + 2 to aim at fewer, longer fights.
const MIN_COMBAT_ROOMS := [2, 2, 3, 2]
const MAX_EXTRA_COMBAT_ROOMS := 1
## The order in which the quota turns rooms into fights when a floor is short:
## empty rooms go first and rest rooms only as a last resort, because rests are
## the dungeon's pressure valve (D-038).
const QUOTA_CONVERT_ORDER := [
	DungeonRoom.RoomType.EMPTY,
	DungeonRoom.RoomType.EVENT,
	DungeonRoom.RoomType.TREASURE,
	DungeonRoom.RoomType.REST,
]
## Kinds a fight trimmed by the quota is never rerolled as.
const QUOTA_TRIM_SKIPS := [DungeonRoom.RoomType.COMBAT, DungeonRoom.RoomType.REST]

## Rest rooms (D-038): each living hero regains these shares of max HP and MP;
## a downed hero gets up at REST_REVIVE_HP_SHARE and regains the same MP share.
## Debuffs and DoTs are cleared.
const REST_HP_SHARE := 0.5
const REST_MP_SHARE := 0.25
const REST_REVIVE_HP_SHARE := 0.25
## The Fountain event: living heroes regain this share of max HP (no MP), and
## DoTs are washed off.
const FOUNTAIN_HP_SHARE := 0.3

## Content weights per floor: COMBAT, TREASURE, EVENT, REST, EMPTY.
## Deeper floors lean harder into combat and events (docs/design-doc-v2.md).
## E5a lowered COMBAT (fewer, longer fights) and spread the freed share over
## TREASURE, EVENT and EMPTY in proportion; REST is unchanged.
const KIND_WEIGHTS := [
	[0.25, 0.24, 0.18, 0.10, 0.23],
	[0.25, 0.23, 0.22, 0.10, 0.20],
	[0.30, 0.20, 0.27, 0.10, 0.13],
	[0.30, 0.18, 0.27, 0.10, 0.15],
]
## Kinds matching KIND_WEIGHTS columns.
const KIND_ORDER := [
	DungeonRoom.RoomType.COMBAT,
	DungeonRoom.RoomType.TREASURE,
	DungeonRoom.RoomType.EVENT,
	DungeonRoom.RoomType.REST,
	DungeonRoom.RoomType.EMPTY,
]

var level: int = 1
## Index into BOSS_ENCOUNTERS chosen for this run's floor-4 boss.
var boss: int = 0
## One Dictionary per floor: Vector2i grid position -> DungeonRoom.
var floors: Array = []
## 0-based floor the player is on (0..NUM_FLOORS-1).
var current_floor: int = 0
## Grid position of the room the player currently occupies.
var player_pos: Vector2i = Vector2i.ZERO

# ── Generation ────────────────────────────────────────────────────────────────


static func generate(p_level: int = 1) -> DungeonRun:
	var run := DungeonRun.new()
	run.level = p_level
	run.boss = randi() % BOSS_ENCOUNTERS.size()
	for f in NUM_FLOORS:
		run.floors.append(_generate_floor(f))
	run.current_floor = 0
	run.player_pos = Vector2i.ZERO
	run.current_room().explored = true
	run._mark_adjacent_seen()
	return run


## Builds one floor: connected room tree grown from (0,0), loop passages,
## rolled content, the stairs room (floors 1-3) or boss room (floor 4), then
## the fight quota.
static func _generate_floor(floor_index: int) -> Dictionary:
	var rooms := _rolled_floor(floor_index)
	_apply_fight_quota(rooms, floor_index)
	return rooms


## Everything `_generate_floor` does except the fight quota (tests use it to see
## what the quota changed).
static func _rolled_floor(floor_index: int) -> Dictionary:
	var rooms: Dictionary = {}
	var start := DungeonRoom.new()
	start.pos = Vector2i.ZERO
	rooms[Vector2i.ZERO] = start

	var target: int = maxi(3, ROOM_BASE_COUNTS[floor_index] + randi_range(-1, 1))
	while rooms.size() < target:
		var origin: DungeonRoom = rooms.values()[randi() % rooms.size()]
		var dir: Dictionary = DungeonRoom.DIRS[randi() % 4]
		var npos: Vector2i = origin.pos + dir["vec"]
		if rooms.has(npos):
			continue
		var room := DungeonRoom.new()
		room.pos = npos
		rooms[npos] = room
		origin.connections |= dir["bit"]
		room.connections |= dir["opposite"]

	# Extra loop passages so floors aren't pure trees. Checking only the
	# NORTH/EAST directions visits each adjacent pair exactly once.
	for room in rooms.values():
		for dir in DungeonRoom.DIRS:
			if dir["bit"] != DungeonRoom.NORTH and dir["bit"] != DungeonRoom.EAST:
				continue
			var npos: Vector2i = room.pos + dir["vec"]
			if rooms.has(npos) and (room.connections & dir["bit"]) == 0 and randf() < LOOP_CHANCE:
				room.connections |= dir["bit"]
				(rooms[npos] as DungeonRoom).connections |= dir["opposite"]

	# Content. The start room is always a safe, pre-explorable landing.
	for room in rooms.values():
		if room.pos == Vector2i.ZERO:
			room.kind = DungeonRoom.RoomType.EMPTY
		else:
			room.kind = _roll_kind(floor_index)

	if floor_index < NUM_FLOORS - 1:
		_place_stairs(rooms)
	else:
		_place_boss(rooms)
	_maybe_place_shrine(rooms)
	_maybe_place_elite(rooms, floor_index)
	return rooms


## Rooms whose kind the fight quota may change: everything except the start,
## stairs, boss, shrine and elite rooms.
static func _ordinary_rooms(rooms: Dictionary) -> Array:
	var out: Array = []
	for room in rooms.values():
		if room.pos == Vector2i.ZERO:
			continue
		if (
			room.kind
			in [
				DungeonRoom.RoomType.STAIRS,
				DungeonRoom.RoomType.BOSS,
				DungeonRoom.RoomType.SHRINE,
				DungeonRoom.RoomType.ELITE,
			]
		):
			continue
		out.append(room)
	return out


## Brings the floor's COMBAT room count inside MIN_COMBAT_ROOMS ..
## MIN_COMBAT_ROOMS + MAX_EXTRA_COMBAT_ROOMS by changing the kinds of random
## ordinary rooms. Missing fights turn non-combat rooms into COMBAT in
## QUOTA_CONVERT_ORDER (random within a kind); extra ones are rerolled as
## treasure, event or empty with the floor's weights (never rest, see
## _roll_non_combat_kind). On a floor too small for its minimum, the elite room (then the shrine) gives its room back
## as a plain fight: the quota comes first.
static func _apply_fight_quota(rooms: Dictionary, floor_index: int) -> void:
	var min_fights: int = MIN_COMBAT_ROOMS[floor_index]
	var max_fights: int = min_fights + MAX_EXTRA_COMBAT_ROOMS
	var fights: Array = []
	var others: Array = []
	for room in _ordinary_rooms(rooms):
		if room.kind == DungeonRoom.RoomType.COMBAT:
			fights.append(room)
		else:
			others.append(room)

	if fights.size() + others.size() < min_fights:
		for kind in [DungeonRoom.RoomType.ELITE, DungeonRoom.RoomType.SHRINE]:
			for room in rooms.values():
				if room.kind == kind and fights.size() + others.size() < min_fights:
					others.append(room)

	while fights.size() < min_fights and not others.is_empty():
		var room := _next_to_convert(others)
		others.erase(room)
		room.kind = DungeonRoom.RoomType.COMBAT
		fights.append(room)
	while fights.size() > max_fights:
		var room: DungeonRoom = fights.pop_at(randi() % fights.size())
		room.kind = _roll_non_combat_kind(floor_index)


## A random room of the first QUOTA_CONVERT_ORDER kind found in `candidates`,
## or any of them when none matches (an elite or shrine given back).
static func _next_to_convert(candidates: Array) -> DungeonRoom:
	for kind in QUOTA_CONVERT_ORDER:
		var of_kind: Array = candidates.filter(func(r): return r.kind == kind)
		if not of_kind.is_empty():
			return of_kind[randi() % of_kind.size()]
	return candidates[randi() % candidates.size()]


## Rolls the kind for a fight the quota trims, from the floor's weights with
## COMBAT and REST left out: a trimmed fight becomes treasure, an event or an
## empty room, never an extra rest (E5a).
static func _roll_non_combat_kind(floor_index: int) -> DungeonRoom.RoomType:
	var weights: Array = KIND_WEIGHTS[floor_index]
	var total := 0.0
	for i in weights.size():
		if not QUOTA_TRIM_SKIPS.has(KIND_ORDER[i]):
			total += weights[i]
	var r := randf() * total
	var acc := 0.0
	for i in weights.size():
		if QUOTA_TRIM_SKIPS.has(KIND_ORDER[i]):
			continue
		acc += weights[i]
		if r < acc:
			return KIND_ORDER[i]
	return DungeonRoom.RoomType.EMPTY


## Very rarely converts one ordinary room into a SHRINE (grants an event skin).
## Never the start, stairs or boss room.
static func _maybe_place_shrine(rooms: Dictionary) -> void:
	if randf() >= SHRINE_CHANCE:
		return
	var eligible: Array = []
	for room in rooms.values():
		if room.pos == Vector2i.ZERO:
			continue
		if room.kind == DungeonRoom.RoomType.STAIRS or room.kind == DungeonRoom.RoomType.BOSS:
			continue
		eligible.append(room)
	if not eligible.is_empty():
		(eligible[randi() % eligible.size()] as DungeonRoom).kind = DungeonRoom.RoomType.SHRINE


## Floors 2-4, ELITE_CHANCE of the time: turns one ordinary room into an ELITE
## room. It is optional: it never sits on a room every route to the stairs (or
## the boss) has to pass through; when the floor has no other room to give, no
## elite is placed. Never the start, stairs, boss or shrine room.
static func _maybe_place_elite(rooms: Dictionary, floor_index: int) -> void:
	if floor_index < ELITE_FIRST_FLOOR or randf() >= ELITE_CHANCE:
		return
	var required := _required_rooms(rooms)
	var optional: Array = []
	for room in rooms.values():
		if room.pos == Vector2i.ZERO:
			continue
		if (
			room.kind
			in [DungeonRoom.RoomType.STAIRS, DungeonRoom.RoomType.BOSS, DungeonRoom.RoomType.SHRINE]
		):
			continue
		if not required.has(room.pos):
			optional.append(room)
	if not optional.is_empty():
		(optional[randi() % optional.size()] as DungeonRoom).kind = DungeonRoom.RoomType.ELITE


## Positions of the rooms every route from the start to the floor's goal (the
## stairs, or the boss on the last floor) must pass through.
static func _required_rooms(rooms: Dictionary) -> Dictionary:
	var goal := Vector2i(-9999, -9999)
	for room in rooms.values():
		if room.kind == DungeonRoom.RoomType.STAIRS or room.kind == DungeonRoom.RoomType.BOSS:
			goal = room.pos
	var required: Dictionary = {}
	for pos in rooms:
		if pos == Vector2i.ZERO or pos == goal:
			continue
		if not _reachable(rooms, pos).has(goal):
			required[pos] = true
	return required


## Every room position reachable from the start without entering `blocked`.
static func _reachable(rooms: Dictionary, blocked: Vector2i) -> Dictionary:
	var seen: Dictionary = {Vector2i.ZERO: true}
	var queue: Array = [Vector2i.ZERO]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var room: DungeonRoom = rooms[pos]
		for dir in DungeonRoom.DIRS:
			var npos: Vector2i = pos + dir["vec"]
			if npos == blocked or seen.has(npos) or not rooms.has(npos):
				continue
			if (room.connections & dir["bit"]) != 0:
				seen[npos] = true
				queue.append(npos)
	return seen


static func _roll_kind(floor_index: int) -> DungeonRoom.RoomType:
	var weights: Array = KIND_WEIGHTS[floor_index]
	var r := randf()
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if r < acc:
			return KIND_ORDER[i]
	return DungeonRoom.RoomType.EMPTY


## Converts a random room into the stairs room. Never the start room;
## prefers rooms at least 2 passages away from it.
static func _place_stairs(rooms: Dictionary) -> void:
	var dist := _distances(rooms)
	var far: Array = []
	var fallback: Array = []
	for room in rooms.values():
		if room.pos == Vector2i.ZERO:
			continue
		fallback.append(room)
		if int(dist.get(room.pos, 0)) >= 2:
			far.append(room)
	var pool: Array = far if not far.is_empty() else fallback
	var stairs: DungeonRoom = pool[randi() % pool.size()]
	stairs.kind = DungeonRoom.RoomType.STAIRS


## Appends the boss room adjacent to the farthest room from the start
## (falling back through closer rooms if the farthest has no free side).
static func _place_boss(rooms: Dictionary) -> void:
	var dist := _distances(rooms)
	var by_distance: Array = rooms.values()
	by_distance.sort_custom(func(a, b): return int(dist.get(a.pos, 0)) > int(dist.get(b.pos, 0)))
	for anchor in by_distance:
		for dir in DungeonRoom.DIRS:
			var npos: Vector2i = anchor.pos + dir["vec"]
			if rooms.has(npos):
				continue
			var boss := DungeonRoom.new()
			boss.pos = npos
			boss.kind = DungeonRoom.RoomType.BOSS
			rooms[npos] = boss
			anchor.connections |= dir["bit"]
			boss.connections |= dir["opposite"]
			return


## BFS passage-distance of every room from the floor's start room.
static func _distances(rooms: Dictionary) -> Dictionary:
	var dist: Dictionary = {Vector2i.ZERO: 0}
	var queue: Array = [Vector2i.ZERO]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var room: DungeonRoom = rooms[pos]
		for dir in DungeonRoom.DIRS:
			var npos: Vector2i = pos + dir["vec"]
			if (room.connections & dir["bit"]) != 0 and rooms.has(npos) and not dist.has(npos):
				dist[npos] = int(dist[pos]) + 1
				queue.append(npos)
	return dist


# ── Navigation ────────────────────────────────────────────────────────────────


func rooms_on_floor() -> Dictionary:
	return floors[current_floor]


func current_room() -> DungeonRoom:
	return rooms_on_floor()[player_pos]


## True when `pos` is an adjacent room connected to the player's room.
func can_move_to(pos: Vector2i) -> bool:
	var rooms: Dictionary = rooms_on_floor()
	if not rooms.has(pos):
		return false
	return current_room().connects_to(pos)


## Moves the party into an adjacent room. Entering a room for the first time
## advances the global turn, so buffs/debuffs decay and regen/DoT tick while
## exploring, not just in combat. Walking back through explored rooms is free
## but ticks nothing, so it can't be used to farm regen (D-038).
## Returns any status log lines so the caller can surface them.
func move_to(pos: Vector2i) -> Array[String]:
	player_pos = pos
	var first_visit := not current_room().explored
	current_room().explored = true
	_mark_adjacent_seen()
	if not first_visit:
		return []
	GameState.turn_counter += 1
	return Party.tick_statuses()


## Flags every room connected to the player's room as seen. Once seen, a
## room stays on the map permanently — the fog only hides the never-glimpsed.
func _mark_adjacent_seen() -> void:
	var rooms: Dictionary = rooms_on_floor()
	var cur := current_room()
	for dir in DungeonRoom.DIRS:
		var npos: Vector2i = player_pos + dir["vec"]
		if (cur.connections & dir["bit"]) != 0 and rooms.has(npos):
			(rooms[npos] as DungeonRoom).seen = true


## Rooms the map may draw: explored or previously seen ones, the current
## room, and rooms one connected passage away (covers saves from before the
## seen flag existed). Everything else is fog — simply not rendered.
func visible_rooms() -> Array[DungeonRoom]:
	var out: Array[DungeonRoom] = []
	var cur := current_room()
	for room in rooms_on_floor().values():
		if room.explored or room.seen or room.pos == player_pos or cur.connects_to(room.pos):
			out.append(room)
	return out


func is_boss_floor() -> bool:
	return current_floor == NUM_FLOORS - 1


## One-way descent to the next floor's start room.
func descend() -> void:
	current_floor += 1
	player_pos = Vector2i.ZERO
	current_room().explored = true
	_mark_adjacent_seen()


# ── Encounters ────────────────────────────────────────────────────────────────


## Rolls a fight for the 0-based `floor_index`: a weighted authored group valid
## on that floor, scaled for the run. `elite` rolls from the elite groups (an
## elite room); if a floor has none it falls back to a normal group.
func roll_encounter(floor_index: int, elite: bool = false) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	var group := EncounterGroupData.pick(floor_index + 1, elite)
	if group == null and elite:
		group = EncounterGroupData.pick(floor_index + 1, false)
	if group == null:
		push_error("No encounter group for floor %d" % (floor_index + 1))
		return out
	for id in group.members:
		out.append(_scale_enemy(_load_enemy(id), floor_index + 1))
	return out


func roll_boss() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	var boss_floor := floors.size()  # the boss sits on the last floor (1-based)
	for id in BOSS_ENCOUNTERS[boss % BOSS_ENCOUNTERS.size()]:
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
	var mult := pow(DUNGEON_GROWTH, level - 1) * (1.0 + (floor_num - 1) * FLOOR_SCALE)
	if mult <= 1.0:
		return base
	var scaled := base.duplicate() as EnemyData
	scaled.max_hp = roundi(base.max_hp * mult)
	scaled.atk = roundi(base.atk * mult)
	scaled.def = roundi(base.def * mult)
	scaled.mag = roundi(base.mag * mult)
	scaled.spd = roundi(base.spd * mult)
	scaled.xp_reward = roundi(base.xp_reward * mult)
	scaled.gold_min = roundi(base.gold_min * mult)
	scaled.gold_max = roundi(base.gold_max * mult)
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
		return [
			"sword_rusty",
			"staff_apprentice",
			"armor_cloth",
			"potion_heal",
			"potion_heal",
			"potion_mana"
		]
	return [
		"sword_iron",
		"staff_apprentice",
		"armor_leather",
		"ring_might",
		"ring_focus",
		"potion_heal",
		"potion_mana"
	]


# ── Rest ──────────────────────────────────────────────────────────────────────


## A rest room (D-038): living heroes regain REST_HP_SHARE of max HP and
## REST_MP_SHARE of max MP, downed heroes get up at REST_REVIVE_HP_SHARE (and
## regain the same MP), and debuffs and DoTs are cleared. Buffs, barriers and regen stay.
func resolve_rest() -> void:
	for h in Party.heroes:
		if h.is_alive():
			h.hp = mini(h.max_hp(), h.hp + roundi(h.max_hp() * REST_HP_SHARE))
		else:
			h.hp = maxi(1, roundi(h.max_hp() * REST_REVIVE_HP_SHARE))
		h.mp = mini(h.max_mp(), h.mp + roundi(h.max_mp() * REST_MP_SHARE))
	Party.clear_status_kinds([CombatStatus.Kind.DEBUFF, CombatStatus.Kind.DOT])


# ── Shrine ────────────────────────────────────────────────────────────────────


## Grants a random unowned event-exclusive skin. When every event skin is owned,
## gives a gold consolation instead. Returns {skin_id, skin_name} or {gold}.
func resolve_shrine() -> Dictionary:
	var pool := Skins.unowned_event_skins()
	if not pool.is_empty():
		var id: String = pool[randi() % pool.size()]
		GameState.unlock_skin(id)
		return {"skin_id": id, "skin_name": Skins.display_name(id)}
	var gold_amount := randi_range(20 + level * 6, 40 + level * 10)
	GameState.gold += gold_amount
	return {"gold": gold_amount}


# ── Events ────────────────────────────────────────────────────────────────────


## Returns a random event as {title:String, desc:String, options:Array}, where
## each option is {text:String, available:bool, effect:Callable() -> String}.
func roll_event() -> Dictionary:
	var pool := [_event_fountain(), _event_merchant(), _event_altar(), _event_chest()]
	return pool[randi() % pool.size()]


func _event_fountain() -> Dictionary:
	return {
		"id": "fountain",
		"title": tr("EVT_FOUNTAIN_TITLE"),
		"desc": tr("EVT_FOUNTAIN_DESC"),
		"options":
		[
			{"text": tr("EVT_FOUNTAIN_OPT1"), "available": true, "effect": _fountain_drink},
			{"text": tr("EVT_FOUNTAIN_OPT2"), "available": true, "effect": _move_on},
		],
	}


func _event_merchant() -> Dictionary:
	return {
		"id": "merchant",
		"title": tr("EVT_MERCHANT_TITLE"),
		"desc": tr("EVT_MERCHANT_DESC"),
		"options":
		[
			{
				"text": tr("EVT_MERCHANT_OPT1"),
				"available": GameState.gold >= 30,
				"effect": _merchant_buy
			},
			{"text": tr("EVT_MERCHANT_OPT2"), "available": true, "effect": _move_on},
		],
	}


func _event_altar() -> Dictionary:
	return {
		"id": "altar",
		"title": tr("EVT_ALTAR_TITLE"),
		"desc": tr("EVT_ALTAR_DESC"),
		"options":
		[
			{"text": tr("EVT_ALTAR_OPT1"), "available": true, "effect": _altar_sacrifice},
			{"text": tr("EVT_ALTAR_OPT2"), "available": true, "effect": _altar_retreat},
		],
	}


func _event_chest() -> Dictionary:
	return {
		"id": "chest",
		"title": tr("EVT_CHEST_TITLE"),
		"desc": tr("EVT_CHEST_DESC"),
		"options":
		[
			{"text": tr("EVT_CHEST_OPT1"), "available": true, "effect": _chest_force},
			{"text": tr("EVT_CHEST_OPT2"), "available": true, "effect": _chest_leave},
		],
	}


func _move_on() -> String:
	return tr("EVT_MOVE_ON")


## Living heroes regain FOUNTAIN_HP_SHARE of max HP (no MP, no revive) and the
## party's DoTs are washed off; every other status stays.
func _fountain_drink() -> String:
	for h in Party.heroes:
		if h.is_alive():
			h.hp = mini(h.max_hp(), h.hp + roundi(h.max_hp() * FOUNTAIN_HP_SHARE))
	Party.clear_status_kinds([CombatStatus.Kind.DOT])
	return tr("EVT_FOUNTAIN_R")


func _merchant_buy() -> String:
	if GameState.gold < 30:
		return tr("EVT_NO_GOLD")
	GameState.gold -= 30
	GameState.add_item("potion_heal")
	return tr("EVT_MERCHANT_R")


func _altar_sacrifice() -> String:
	for h in Party.heroes:
		h.hp = maxi(1, int(h.hp / 2.0))
		Party.award_xp(h, 12)
	return tr("EVT_ALTAR_R")


func _altar_retreat() -> String:
	return tr("EVT_ALTAR_RETREAT")


func _chest_force() -> String:
	if randf() < 0.6:
		var loot := ["potion_heal", "ring_might", "ring_focus"]
		GameState.add_item(loot[randi() % loot.size()])
		return tr("EVT_CHEST_WIN")
	for h in Party.heroes:
		h.hp = maxi(1, h.hp - 8)
	return tr("EVT_CHEST_TRAP")


func _chest_leave() -> String:
	return tr("EVT_CHEST_LEAVE")


# ── Persistence ───────────────────────────────────────────────────────────────


func to_dict() -> Dictionary:
	var floors_data: Array = []
	for rooms in floors:
		var arr: Array = []
		for room in rooms.values():
			arr.append((room as DungeonRoom).to_dict())
		floors_data.append(arr)
	return {
		"level": level,
		"boss": boss,
		"current_floor": current_floor,
		"px": player_pos.x,
		"py": player_pos.y,
		"floors": floors_data,
	}


static func from_dict(d: Dictionary) -> DungeonRun:
	var run := DungeonRun.new()
	run.level = int(d.get("level", 1))
	run.boss = int(d.get("boss", 0))
	run.current_floor = int(d.get("current_floor", 0))
	run.player_pos = Vector2i(int(d.get("px", 0)), int(d.get("py", 0)))
	for arr in d.get("floors", []):
		var rooms: Dictionary = {}
		for rd in arr:
			var room := DungeonRoom.from_dict(rd)
			rooms[room.pos] = room
		run.floors.append(rooms)
	return run
