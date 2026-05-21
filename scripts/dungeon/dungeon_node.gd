## A single node in a dungeon map.
class_name DungeonNode
extends RefCounted

enum NodeType { COMBAT, TREASURE, EVENT, REST, BOSS }

var kind: DungeonNode.NodeType = DungeonNode.NodeType.COMBAT
var floor_index: int = 0
var slot_index: int = 0
var visited: bool = false


## Display label (pt-BR) for the node type.
func type_name() -> String:
	match kind:
		DungeonNode.NodeType.COMBAT: return "Combate"
		DungeonNode.NodeType.TREASURE: return "Tesouro"
		DungeonNode.NodeType.EVENT: return "Evento"
		DungeonNode.NodeType.REST: return "Descanso"
		DungeonNode.NodeType.BOSS: return "Chefe"
	return "?"
