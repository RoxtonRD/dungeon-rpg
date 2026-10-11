@tool
## A reaction talent: triggers on its own, by chance, when the hero is hit, and
## costs the class's resource (D-023: no mid-turn prompts). A hero learns one
## reaction from ClassData.reactions for 1 SP, permanently, and can switch it
## on or off for free outside combat (see Party.learn_reaction). Authored as
## .tres assets under res://resources/reactions/.
class_name ReactionData
extends Resource

## Which incoming hits the reaction can trigger on.
enum AppliesTo { SINGLE_TARGET_PHYSICAL }

## Stable internal key, e.g. "parry". Stored in saves (Hero.talents
## "_reaction") — never translate.
@export var id: String = ""
## Translation key of the name shown in the UI.
@export var display_name: String = ""
## Translation key of the description.
@export_multiline var description: String = ""
## Hero level at which the reaction can be learned.
@export var unlock_level: int = 1

@export_group("Effect")
## Chance, 0..1, that the reaction triggers on an eligible hit.
@export var chance: float = 0.0
## Rage needed to trigger, and spent when it does.
@export var rage_cost: int = 0
## Multiplies the damage of the hit that triggered it (0.5 = half damage).
@export var damage_mult: float = 1.0
@export var applies_to: AppliesTo = AppliesTo.SINGLE_TARGET_PHYSICAL


## True when a hit from `skill`, resolving as `dmg_kind`, is one this reaction
## can trigger on.
func applies(skill: SkillData, dmg_kind: SkillData.SkillType) -> bool:
	match applies_to:
		AppliesTo.SINGLE_TARGET_PHYSICAL:
			return skill.target == SkillData.TargetType.ONE and dmg_kind == SkillData.SkillType.PHYS
	return false
