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
## Hand-drawn portrait. Left empty in v1 — the UI shows a placeholder.
@export var portrait: Texture2D
## Alternate skin ids available to this class, beyond the default look (which is
## always the class id itself). Add a new skin by dropping its art in and listing
## its id here — see assets/full_body/README.md and HeroArt.
@export var skins: Array[String] = []


## Every skin id for this class: the default look (the class id) first, then the
## authored extras, de-duplicated. Never empty. Used by the skin pickers.
func all_skins() -> Array[String]:
	var out: Array[String] = [id]
	for s in skins:
		if not out.has(s):
			out.append(s)
	return out
