@tool
## An equippable item or a consumable.
## Authored as .tres assets under res://resources/items/.
class_name ItemData
extends Resource

enum Slot { WEAPON, ARMOR, TRINKET, CONSUMABLE }

## Stable internal key, e.g. "sword_iron". Used in save files — never translate.
@export var id: String = ""
## Name shown in the UI (pt-BR).
@export var display_name: String = ""
@export var slot: Slot = Slot.WEAPON
## Shop buy price in gold. Sell value is derived from this at runtime.
@export var value: int = 0

@export_group("Equipment Stat Modifiers")
@export var mod_hp: int = 0
@export var mod_mp: int = 0
@export var mod_atk: int = 0
@export var mod_def: int = 0
@export var mod_mag: int = 0
@export var mod_spd: int = 0
## Class ids allowed to equip this item. Empty = every class may use it.
@export var class_restriction: Array[String] = []

@export_group("Consumable Effects")
@export var use_heal: int = 0
@export var use_mp: int = 0
## Skill Points granted to one hero.
@export var use_sp: int = 0
## Fraction of max HP each fallen ally revives with (0 = no revive).
@export var use_revive_party: float = 0.0

@export_group("Art")
## Hand-drawn icon. Left empty in v1 — the UI shows a placeholder.
@export var icon: Texture2D


## Returns the per-item icon Texture2D at assets/icons/items/{id}.png, or null
## if the file is missing. UI screens fall back to a placeholder ColorRect.
func icon_or_null() -> Texture2D:
	var path := "res://assets/icons/items/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Short, single-line summary built from the item's stats / effects. Shown as
## an always-visible description on the Personagens and Loja screens. v1 has no
## authored description field, so this is generated.
func short_description() -> String:
	var parts: Array[String] = []
	if slot == Slot.CONSUMABLE:
		if use_heal > 0:
			parts.append(tr("DESC_HEAL") % use_heal)
		if use_mp > 0:
			parts.append(tr("DESC_MP") % use_mp)
		if use_sp > 0:
			parts.append(tr("DESC_SP") % use_sp)
		if use_revive_party > 0.0:
			parts.append(tr("DESC_REVIVE") % roundi(use_revive_party * 100.0))
	else:
		var stats := _stat_mods_text()
		if not stats.is_empty():
			parts.append(stats)
		if class_restriction.size() > 0:
			parts.append(tr("DESC_ONLY") % ", ".join(_restriction_names()))
	return " · ".join(parts)


func _stat_mods_text() -> String:
	var mods: Array[String] = []
	if mod_hp != 0:  mods.append("%s %+d" % [tr("STAT_HP"), mod_hp])
	if mod_mp != 0:  mods.append("%s %+d" % [tr("STAT_MP"), mod_mp])
	if mod_atk != 0: mods.append("%s %+d" % [tr("STAT_ATK"), mod_atk])
	if mod_def != 0: mods.append("%s %+d" % [tr("STAT_DEF"), mod_def])
	if mod_mag != 0: mods.append("%s %+d" % [tr("STAT_MAG"), mod_mag])
	if mod_spd != 0: mods.append("%s %+d" % [tr("STAT_SPD"), mod_spd])
	return ", ".join(mods)


func _restriction_names() -> Array:
	var names: Array = []
	for cid in class_restriction:
		var c := load("res://resources/classes/%s.tres" % cid) as ClassData
		names.append(tr(c.display_name) if c != null else str(cid))
	return names
