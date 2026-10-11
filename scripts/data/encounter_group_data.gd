@tool
## A hand-authored enemy group (encounters v3, D-038): which enemies appear
## together, on which floors, and whether it belongs to an elite room.
## Authored as .tres assets under res://resources/encounters/ and found by
## scanning that folder, so adding a group needs no code change.
class_name EncounterGroupData
extends Resource

const DIR := "res://resources/encounters/"
## Used only when the folder cannot be listed (a failsafe for exported builds;
## encounters_test keeps it in step with the folder).
const FALLBACK_IDS: Array[String] = [
	"f1_goblin_camp",
	"f1_wolf_pack",
	"f1_bat_swarm",
	"f1_scouts",
	"f1_ambush",
	"f2_goblin_camp",
	"f2_wolf_pack",
	"f2_crypt_patrol",
	"f2_wolf_riders",
	"f2_crypt_raiders",
	"f2_ogre_keepers",
	"f2_great_pack",
	"f3_bandit_gang",
	"f3_crypt_watch",
	"f3_cult_cell",
	"f3_elf_raiders",
	"f3_hired_blades",
	"f3_warlord_raid",
	"f3_cult_ogre",
	"f4_orc_warband",
	"f4_orc_patrol",
	"f4_ogre_handlers",
	"f4_dark_rite",
	"f4_ogre_cult",
	"f4_warlord_horde",
	"f4_ogre_chieftain",
]

## Stable internal key, e.g. "f2_goblin_camp". Not shown to the player.
@export var id: String = ""
## Enemy ids (file names in resources/enemies/), in battle order.
@export var members: Array[String] = []
## Floors (1-based, inclusive) the group can appear on.
@export var floor_min: int = 1
@export var floor_max: int = 4
## Relative chance against the other groups valid for the same floor.
@export var weight: float = 1.0
## Elite groups only appear in elite rooms, normal groups never do.
@export var elite: bool = false

## Every group, loaded once.
static var _all: Array[EncounterGroupData] = []


## Every encounter group. Scans DIR, falling back to FALLBACK_IDS if the scan
## finds nothing.
static func all() -> Array[EncounterGroupData]:
	if _all.is_empty():
		var names := PackedStringArray()
		for file in DirAccess.get_files_at(DIR):
			# Exported builds rename .tres to .tres.remap.
			var file_name := file.trim_suffix(".remap")
			if file_name.ends_with(".tres"):
				names.append(file_name.get_basename())
		if names.is_empty():
			names.append_array(FALLBACK_IDS)
		names.sort()
		for group_id in names:
			var group := load(DIR + group_id + ".tres") as EncounterGroupData
			if group != null:
				_all.append(group)
	return _all


## The groups that can appear on `floor_num` (1-based) in a normal or elite room.
static func candidates(floor_num: int, want_elite: bool) -> Array[EncounterGroupData]:
	var out: Array[EncounterGroupData] = []
	for group in all():
		if (
			group.elite == want_elite
			and floor_num >= group.floor_min
			and floor_num <= group.floor_max
		):
			out.append(group)
	return out


## A weighted random group for the floor, or null when none is valid.
static func pick(floor_num: int, want_elite: bool) -> EncounterGroupData:
	var pool := candidates(floor_num, want_elite)
	var total := 0.0
	for group in pool:
		total += maxf(0.0, group.weight)
	if pool.is_empty() or total <= 0.0:
		return null
	var roll := randf() * total
	for group in pool:
		roll -= maxf(0.0, group.weight)
		if roll < 0.0:
			return group
	return pool[pool.size() - 1]
