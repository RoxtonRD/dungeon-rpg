@tool
## A playable hero class: base stats, per-level growth and skill list.
## Authored as .tres assets under res://resources/classes/.
class_name ClassData
extends Resource

## Which combat row the class occupies by default.
enum Role { FRONT, BACK }

## Stable internal key, e.g. "warrior". Used in save files — never translate.
@export var id: String = ""
## Name shown in the UI (pt-BR).
@export var display_name: String = ""
@export var role: Role = Role.FRONT

@export_group("Base Stats (level 1)")
@export var base_hp: int = 1
@export var base_mp: int = 0
@export var atk: int = 0
@export var def: int = 0
@export var mag: int = 0
@export var spd: int = 0

@export_group("Per-Level Growth")
@export var hp_per_level: int = 0
@export var mp_per_level: int = 0
@export var atk_per_level: int = 0
@export var def_per_level: int = 0
@export var mag_per_level: int = 0
@export var spd_per_level: int = 0

@export_group("Skills & Art")
## The 4 skills this class can learn (v1 scope). Order = unlock order.
@export var skills: Array[SkillData] = []
## Hand-drawn portrait (skin 1's head-crop). Used as a last-ditch fallback by
## HeroArt; skins normally resolve straight from the class folder.
@export var portrait: Texture2D

## Highest skin number probed for. Skins are drop-in: no registration needed.
const MAX_SKINS := 12


## Skin numbers available to this class, as strings ("1", "2", …). Discovered by
## probing assets/heroes/<id>/<n>.png — drop the next numbered file in and it
## appears. Always returns at least ["1"] (the default look).
func all_skins() -> Array[String]:
	var out: Array[String] = []
	for n in range(1, MAX_SKINS + 1):
		if ResourceLoader.exists("res://assets/heroes/%s/%d.png" % [id, n]):
			out.append(str(n))
	if out.is_empty():
		out.append("1")
	return out
