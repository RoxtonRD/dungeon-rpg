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
## Which caster stat scales the damage. AUTO follows skill_type (MAG for magic,
## ATK otherwise) — the historic behaviour. Overriding lets a physically-resolved
## skill scale off MAG ("physical spells": conjured weapons still take full DEF).
enum DamageStat { AUTO, ATK, MAG }

## Stable internal key, e.g. "slash". Used in save files — never translate.
@export var id: String = ""
## Name shown in the UI (pt-BR).
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Cost & Unlock")
## Cost in the caster's class resource (MP for mana classes, Rage for rage
## classes; see ClassData.resource_type). Named mp_cost for history.
@export var mp_cost: int = 0
## Caster turns before the skill can be used again (0 = no cooldown).
## Combat-only; enemy skills ignore it.
@export var cooldown: int = 0
## Hero level at which the skill unlocks. Unused by enemy skills.
@export var unlock_level: int = 1
## Highest tier reachable by spending Skill Points (base tier = 1).
@export var max_upgrade_level: int = 3

@export_group("Effect")
@export var skill_type: SkillType = SkillType.PHYS
@export var target: TargetType = TargetType.ONE
## Damage/heal multiplier applied to the caster's ATK or MAG.
@export var power: float = 1.0
## Overrides which caster stat scales the damage, without changing how the hit
## resolves against DEF. AUTO keeps the historic behaviour.
@export var damage_stat: DamageStat = DamageStat.AUTO
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
## Translation key of the DoT's status popup ("Poison %d", "Bleed %d").
@export var dot_popup_key: String = "UI_POPUP_POISON"

@export_group("Heal Over Time")
## HP restored to the target at the end of each round while active.
@export var heal_over_time: int = 0
@export var hot_duration: int = 0

@export_group("Rage")
## Rage this action gives the caster when it deals damage. -1 means the default
## (Battler.RAGE_PER_DAMAGING_ACTION).
@export var rage_on_action: int = -1
## Multiplies the Rage the bearer gains from hits taken, while the status this
## skill grants is active (Vengeance).
@export var rage_taken_mult: float = 1.0
## Rage refunded to the caster when this action kills a foe.
@export var on_kill_rage: int = 0
## A kill with this action resets its own cooldown.
@export var on_kill_reset_cooldown: bool = false

@export_group("Talents")
## The two talent variants of a hero skill (talent classes only, see
## ClassData.uses_talents). Each is a complete SkillData that replaces this
## one once the hero picks it. Null on variants and on enemy skills.
@export var fork_a: SkillData
@export var fork_b: SkillData

@export_group("Enemy AI")
@export var use_condition: UseCondition = UseCondition.NONE


## Returns the per-skill icon at assets/icons/skills/{filename}.png, or null
## if the file is missing. Uses the .tres filename basename to stay aligned
## with Party._skill_key (the canonical id used elsewhere).
func icon_or_null() -> Texture2D:
	if resource_path.is_empty():
		return null
	var key := resource_path.get_file().get_basename()
	var path := "res://assets/icons/skills/%s.png" % key
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
