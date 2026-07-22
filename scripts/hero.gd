## Runtime state of a single party hero.
## Created and owned by the Party autoload — never an autoload itself.
class_name Hero
extends RefCounted

## The class this hero belongs to. Drives base stats and the skill list.
var class_data: ClassData

## Player-typed display name. When set it overrides the roster/class name and is
## shown literally (never translated). Empty = fall back to roster/class name.
var custom_name: String = ""
## Roster character this hero was created from (companions). Supplies a default,
## localizable name via its CharacterData. Empty for the freely-built main hero.
var character_id: String = ""
## Art skin id. Empty means "use the class default" (see effective_skin / HeroArt).
var skin_id: String = ""
## True for the player's main character.
var is_main: bool = false

var level: int = 1
var xp: int = 0

## Unspent Skill Points.
var sp_available: int = 0
## SP spent per skill, keyed by the skill's .tres filename (no extension).
## A missing key means 0 SP spent, i.e. the skill is at upgrade tier 1.
var sp_spent: Dictionary = {}
## Permanent bonus to max MP, gained when Skill Points are converted because
## the hero has no skill left to upgrade (see Party.award_sp).
var bonus_mp: int = 0

## Current HP/MP. Maximums are derived from class_data + level + equipment.
var hp: int = 0
var mp: int = 0

## Formation row chosen by the player. 0 = front, 1 = back.
## Initialised from class_data.role in create(); player can override it.
var row: int = 0

## Equipped items, keyed by slot name. Null = empty slot.
var equipment: Dictionary = {
	"weapon": null,
	"armor": null,
	"trinket": null,
}


## Builds a fresh level-1 hero of the given class at full HP/MP.
static func create(from_class: ClassData) -> Hero:
	var h := Hero.new()
	h.class_data = from_class
	h.level = 1
	h.xp = 0
	# Level-1 heroes start with 1 SP (prototype: Party.makeChar).
	h.sp_available = 1
	h.row = int(from_class.role)   # default: warriors/rogues front, mages/clerics back
	h.hp = h.max_hp()
	h.mp = h.max_mp()
	return h


## Sums one equipment stat modifier across every equipped item.
func _equipment_mod(field: String) -> int:
	var total := 0
	for slot in equipment:
		var item: ItemData = equipment[slot]
		if item != null:
			total += item.get(field)
	return total


func max_hp() -> int:
	return class_data.base_hp + class_data.hp_per_level * (level - 1) + _equipment_mod("mod_hp")


func max_mp() -> int:
	return class_data.base_mp + class_data.mp_per_level * (level - 1) + _equipment_mod("mod_mp") + bonus_mp


func atk() -> int:
	return class_data.atk + class_data.atk_per_level * (level - 1) + _equipment_mod("mod_atk")


func def() -> int:
	return class_data.def + class_data.def_per_level * (level - 1) + _equipment_mod("mod_def")


func mag() -> int:
	return class_data.mag + class_data.mag_per_level * (level - 1) + _equipment_mod("mod_mag")


func spd() -> int:
	return class_data.spd + class_data.spd_per_level * (level - 1) + _equipment_mod("mod_spd")


func is_alive() -> bool:
	return hp > 0


## The name shown in every UI. Priority: a player-typed name (literal), else the
## roster character's localizable name, else the class name (today's behaviour).
## Roster/class names resolve through tr() at call time so they follow a live
## language switch; a typed custom_name is intentionally never translated.
func display_name() -> String:
	if not custom_name.strip_edges().is_empty():
		return custom_name
	if not character_id.is_empty():
		var cd := load("res://resources/characters/%s.tres" % character_id) as CharacterData
		if cd != null:
			return tr(cd.display_name)
	return tr(class_data.display_name)


## Art key for this hero: the chosen skin, or the class default when unset.
func effective_skin() -> String:
	return skin_id if not skin_id.is_empty() else class_data.id


# ── Persistence ───────────────────────────────────────────────────────────────

## Plain-Dictionary snapshot of this hero. Equipment is stored by item id;
## class_data by class id. Both are restored by path convention in from_dict.
func to_dict() -> Dictionary:
	var equip := {}
	for slot in equipment:
		var item: ItemData = equipment[slot]
		equip[slot] = item.id if item != null else ""
	return {
		"class_id": class_data.id,
		"custom_name": custom_name,
		"character_id": character_id,
		"skin_id": skin_id,
		"is_main": is_main,
		"level": level,
		"xp": xp,
		"sp_available": sp_available,
		"sp_spent": sp_spent.duplicate(),
		"bonus_mp": bonus_mp,
		"hp": hp,
		"mp": mp,
		"row": row,
		"equipment": equip,
	}


static func from_dict(data: Dictionary) -> Hero:
	var h := Hero.new()
	var class_id: String = data.get("class_id", "")
	h.class_data = load("res://resources/classes/%s.tres" % class_id) as ClassData
	h.custom_name = str(data.get("custom_name", ""))
	h.character_id = str(data.get("character_id", ""))
	h.skin_id = str(data.get("skin_id", ""))
	h.is_main = bool(data.get("is_main", false))
	h.level = int(data.get("level", 1))
	h.xp = int(data.get("xp", 0))
	h.sp_available = int(data.get("sp_available", 0))
	var spent_in: Dictionary = data.get("sp_spent", {})
	h.sp_spent = spent_in.duplicate()
	h.bonus_mp = int(data.get("bonus_mp", 0))
	h.hp = int(data.get("hp", 0))
	h.mp = int(data.get("mp", 0))
	h.row = int(data.get("row", int(h.class_data.role)))
	var equip_in: Dictionary = data.get("equipment", {})
	for slot in ["weapon", "armor", "trinket"]:
		var item_id: String = equip_in.get(slot, "")
		if item_id != "":
			h.equipment[slot] = load("res://resources/items/%s.tres" % item_id) as ItemData
		else:
			h.equipment[slot] = null
	return h
