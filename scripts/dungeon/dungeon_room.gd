## One square room on a dungeon floor grid (v2 Fase 1).
## Rooms connect orthogonally; `connections` is a bitmask of open passages.
## `explored` = the player has entered it at least once (drawn as visited).
## `cleared` = its content (combat/treasure/event/rest) was consumed; the
## room then behaves as empty on revisit.
class_name DungeonRoom
extends RefCounted

enum RoomType { EMPTY, COMBAT, TREASURE, EVENT, REST, STAIRS, BOSS }

## Passage bitmask values, matching DIRS order below.
const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

## Direction vectors paired with their bitmask bit and the opposite bit.
const DIRS := [
	{"vec": Vector2i(0, -1), "bit": NORTH, "opposite": SOUTH},
	{"vec": Vector2i(1, 0), "bit": EAST, "opposite": WEST},
	{"vec": Vector2i(0, 1), "bit": SOUTH, "opposite": NORTH},
	{"vec": Vector2i(-1, 0), "bit": WEST, "opposite": EAST},
]

var pos: Vector2i = Vector2i.ZERO
var kind: RoomType = RoomType.EMPTY
var connections: int = 0
var explored: bool = false
var cleared: bool = false
## The room has been glimpsed (was adjacent-connected to the player at some
## point). Seen rooms stay on the map permanently, even after moving away.
var seen: bool = false


## True when there is an open passage from this room toward `other_pos`
## (which must be orthogonally adjacent).
func connects_to(other_pos: Vector2i) -> bool:
	for dir in DIRS:
		if pos + dir["vec"] == other_pos:
			return (connections & dir["bit"]) != 0
	return false


## True while the room still has unconsumed content to trigger on entry.
func has_content() -> bool:
	if cleared:
		return false
	return kind in [RoomType.COMBAT, RoomType.TREASURE, RoomType.EVENT, RoomType.REST, RoomType.BOSS]


## Display label (pt-BR) for the room type. Cleared content rooms read as
## explored/empty so the map reflects the consumed state.
func type_name() -> String:
	if cleared and kind != RoomType.STAIRS and kind != RoomType.BOSS:
		return tr("ROOM_EMPTY")
	match kind:
		RoomType.EMPTY: return tr("ROOM_EMPTY")
		RoomType.COMBAT: return tr("ROOM_COMBAT")
		RoomType.TREASURE: return tr("ROOM_TREASURE")
		RoomType.EVENT: return tr("ROOM_EVENT")
		RoomType.REST: return tr("ROOM_REST")
		RoomType.STAIRS: return tr("ROOM_STAIRS")
		RoomType.BOSS: return tr("ROOM_BOSS")
	return "?"


# ── Persistence ───────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"x": pos.x,
		"y": pos.y,
		"kind": int(kind),
		"conn": connections,
		"explored": explored,
		"cleared": cleared,
		"seen": seen,
	}


static func from_dict(d: Dictionary) -> DungeonRoom:
	var r := DungeonRoom.new()
	r.pos = Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
	r.kind = d.get("kind", 0) as RoomType
	r.connections = int(d.get("conn", 0))
	r.explored = bool(d.get("explored", false))
	r.cleared = bool(d.get("cleared", false))
	r.seen = bool(d.get("seen", false))
	return r
