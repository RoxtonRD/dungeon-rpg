@tool
## An enemy combatant: stats, rewards and skill list.
## Authored as .tres assets under res://resources/enemies/.
class_name EnemyData
extends Resource

## Which combat row the enemy occupies (front is targeted first).
enum Role { FRONT, BACK }
## How the enemy AI picks skills and targets (encounters v3, D-038): BRUTE hits
## the front row, SKIRMISHER the weakest hero, CASTER prefers area damage and
## debuffs, SUPPORT heals and buffs its allies before attacking.
enum AiRole { BRUTE, SKIRMISHER, CASTER, SUPPORT }

## Stable internal key, e.g. "goblin". Used in save files — never translate.
@export var id: String = ""
## Name shown in the UI (pt-BR).
@export var display_name: String = ""
@export var role: Role = Role.FRONT

@export_group("Stats")
@export var max_hp: int = 1
@export var atk: int = 0
@export var def: int = 0
@export var mag: int = 0
@export var spd: int = 0

@export_group("Rewards")
@export var xp_reward: int = 0
@export var gold_min: int = 0
@export var gold_max: int = 0

@export_group("Behaviour & Art")
@export var is_boss: bool = false
## Drives targeting and skill preference in CombatState (see AiRole).
@export var ai_role: AiRole = AiRole.BRUTE
## Skills the enemy AI may choose from.
@export var skills: Array[SkillData] = []
## Hand-drawn portrait. Left empty in v1 — the UI shows a placeholder.
@export var portrait: Texture2D
