## Skin catalog + availability queries (autoload `Skins`).
##
## Two kinds of skin coexist:
##  - drop-in per-class numbered skins ("1", "2", …) — free, no catalog entry;
##  - catalog skins (common + locked) — a SkinData in resources/skins/catalog.tres.
##
## Ownership of locked skins lives in the save (GameState.owned_skins); this node
## just reads the catalog and answers "what can this class pick / is it owned".
extends Node

const CATALOG_PATH := "res://resources/skins/catalog.tres"
const CLASS_DIR := "res://resources/classes/"
const COMMON_DIR := "res://assets/heroes/common/"
## Highest common skin number probed for. Common skins are drop-in like class ones.
const MAX_COMMON := 12

var _by_id: Dictionary = {}  # full id -> SkinData
var _common_ids: Array[String] = []  # catalog ids beginning with "common/"


func _ready() -> void:
	var cat := load(CATALOG_PATH) as SkinCatalog
	if cat == null:
		return
	for s in cat.entries:
		if s == null or s.id.is_empty():
			continue
		_by_id[s.id] = s
		if s.id.begins_with("common/") and not _common_ids.has(s.id):
			_common_ids.append(s.id)


## Full catalog id for a picker skin viewed on `class_id`. A common id is already
## full; a bare class number "2" maps to "<class>/2".
func full_id(class_id: String, skin: String) -> String:
	return skin if skin.begins_with("common/") else "%s/%s" % [class_id, skin]


## Skin ids a class can browse, in order: its drop-in class numbers, then the
## common skins. (Locked ones are included — the picker shows them locked.)
func for_class(class_id: String) -> Array:
	var cd := load(CLASS_DIR + "%s.tres" % class_id) as ClassData
	var out: Array = cd.all_skins()
	out.append_array(common_skins())
	return out


## Common skins available to every class, as full ids ("common/1", "common/2",
## …). Auto-discovered by probing assets/heroes/common/<n>.png (drop-in, like
## per-class skins), plus any named common skins declared in the catalog.
func common_skins() -> Array[String]:
	var out: Array[String] = []
	for n in range(1, MAX_COMMON + 1):
		if ResourceLoader.exists(COMMON_DIR + "%d.png" % n):
			out.append("common/%d" % n)
	for id in _common_ids:
		if not out.has(id):
			out.append(id)
	return out


## SkinData for a full id, or null when the skin is a plain free class skin.
func meta(full: String) -> SkinData:
	return _by_id.get(full, null)


## True when the skin is free (no entry, or unlock FREE) or the player owns it.
func is_owned(full: String) -> bool:
	var m: SkinData = _by_id.get(full, null)
	if m == null or m.unlock == SkinData.Unlock.FREE:
		return true
	return GameState.owned_skins.has(full)


## Full ids of LEVEL-gated skins whose level_req is met at `level`. Used by the
## level-up grant.
func level_unlocks_at_or_below(level: int) -> Array[String]:
	var out: Array[String] = []
	for id in _by_id:
		var m: SkinData = _by_id[id]
		if m.unlock == SkinData.Unlock.LEVEL and m.level_req <= level:
			out.append(id)
	return out


## Full ids of EVENT-gated skins the player does not yet own. The pool a rare
## shrine draws its reward from.
func unowned_event_skins() -> Array[String]:
	var out: Array[String] = []
	for id in _by_id:
		if _by_id[id].unlock == SkinData.Unlock.EVENT and not GameState.owned_skins.has(id):
			out.append(id)
	return out


## Display name (translated) for a skin id, or the id itself if uncataloged.
func display_name(full: String) -> String:
	var m: SkinData = _by_id.get(full, null)
	return tr(m.display_name) if m != null else full
