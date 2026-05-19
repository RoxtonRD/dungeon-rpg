@tool
## A single skill, used by both hero classes and enemies.
## Authored as .tres assets under res://resources/skills/.
class_name SkillData
extends Resource

## How the skill resolves.
enum SkillType { PHYS, MAG, HEAL, BUFF, DEBUFF, MULTI, REVIVE }
## Who the skill can be aimed at.
enum TargetType { ONE, ALL, SELF, ALLY, ALLIES, DEAD_ALLY, RANDOM }
## Damage flavour of each individual hit of a MULTI skill.
enum HitType { PHYS, MAG }
## Restricts when enemy AI is allowed to pick the skill.
enum UseCondition { NONE, LOW_HP, NOT_LOW_HP }

## Stable internal key, e.g. "slash". Used in save files — never translate.
@export var id: String = ""
## Name shown in the UI (pt-BR).
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Cost & Unlock")
@export var mp_cost: int = 0
## Hero level at which the skill unlocks. Unused by enemy skills.
@export var unlock_level: int = 1
## Highest tier reachable by spending Skill Points (base tier = 1).
@export var max_upgrade_level: int = 3

@export_group("Effect")
@export var skill_type: SkillType = SkillType.PHYS
@export var target: TargetType = TargetType.ONE
## Damage/heal multiplier applied to the caster's ATK or MAG.
@export var power: float = 1.0
## Chance, 0..1, to land a critical hit.
@export var crit_chance: float = 0.0
## Doubles power when the target is below 25% HP.
@export var finisher: bool = false
## Caster heals for 50% of the damage dealt (used by enemy skills).
@export var drain: bool = false

@export_group("Multi-hit")
## Number of separate hits. Only meaningful for MULTI skills.
@export var hits: int = 1
@export var multi_hit_type: HitType = HitType.PHYS

@export_group("Stat Modifier (buff / debuff)")
## Flat stat changes. Positive values buff (BUFF skills); negative values
## debuff (DEBUFF skills, or a debuff rider attached to a damage skill).
@export var mod_atk: int = 0
@export var mod_def: int = 0
@export var mod_mag: int = 0
@export var mod_spd: int = 0
## Turns the modifier lasts. 99 means "until consumed" (used by barrier).
@export var mod_duration: int = 0
## Forces enemies to target the buffed ally.
@export var taunt: bool = false
## Absorbs the next incoming hit entirely.
@export var barrier: bool = false

@export_group("Damage Over Time")
@export var dot_damage: int = 0
@export var dot_duration: int = 0

@export_group("Enemy AI")
@export var use_condition: UseCondition = UseCondition.NONE
