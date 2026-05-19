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
