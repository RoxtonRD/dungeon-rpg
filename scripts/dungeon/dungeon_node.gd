## A single node in a dungeon map.
class_name DungeonNode
extends RefCounted

enum NodeType { COMBAT, TREASURE, EVENT, REST, BOSS }

var kind: DungeonNode.NodeType = DungeonNode.NodeType.COMBAT
var floor_index: int = 0
var slot_index: int = 0
var visited: bool = false


## Persistence ──────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"kind": int(kind),
		"floor_index": floor_index,
		"slot_index": slot_index,
		"visited": visited,
	}


static func from_dict(d: Dictionary) -> DungeonNode:
	var n := DungeonNode.new()
	n.kind = d.get("kind", 0) as DungeonNode.NodeType
	n.floor_index = int(d.get("floor_index", 0))
	n.slot_index = int(d.get("slot_index", 0))
	n.visited = bool(d.get("visited", false))
	return n


## Display label (pt-BR) for the node type.
func type_name() -> String:
	match kind:
		DungeonNode.NodeType.COMBAT: return "Combate"
		DungeonNode.NodeType.TREASURE: return "Tesouro"
		DungeonNode.NodeType.EVENT: return "Evento"
		DungeonNode.NodeType.REST: return "Descanso"
		DungeonNode.NodeType.BOSS: return "Chefe"
	return "?"
