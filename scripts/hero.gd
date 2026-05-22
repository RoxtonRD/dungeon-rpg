## Runtime state of a single party hero.
## Created and owned by the Party autoload — never an autoload itself.
class_name Hero
extends RefCounted

## The class this hero belongs to. Drives base stats and the skill list.
var class_data: ClassData

var level: int = 1
var xp: int = 0

## Unspent Skill Points.
var sp_available: int = 0
## SP spent per skill, keyed by the skill's .tres filename (no extension).
## A missing key means 0 SP spent, i.e. the skill is at upgrade tier 1.
var sp_spent: Dictionary = {}

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
	return class_data.base_mp + class_data.mp_per_level * (level - 1) + _equipment_mod("mod_mp")


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
		"level": level,
		"xp": xp,
		"sp_available": sp_available,
		"sp_spent": sp_spent.duplicate(),
		"hp": hp,
		"mp": mp,
		"row": row,
		"equipment": equip,
	}


static func from_dict(data: Dictionary) -> Hero:
	var h := Hero.new()
	var class_id: String = data.get("class_id", "")
	h.class_data = load("res://resources/classes/%s.tres" % class_id) as ClassData
	h.level = int(data.get("level", 1))
	h.xp = int(data.get("xp", 0))
	h.sp_available = int(data.get("sp_available", 0))
	var spent_in: Dictionary = data.get("sp_spent", {})
	h.sp_spent = spent_in.duplicate()
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
