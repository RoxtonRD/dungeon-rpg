@tool
## A reaction talent: triggers on its own, by chance, when the hero is hit, and
## costs the class's resource (D-023: no mid-turn prompts). A hero learns one
## reaction from ClassData.reactions for 1 SP, permanently, and can switch it
## on or off for free outside combat (see Party.learn_reaction). Authored as
## .tres assets under res://resources/reactions/.
class_name ReactionData
extends Resource

## Which incoming hits the reaction can trigger on.
enum AppliesTo { SINGLE_TARGET_PHYSICAL, SINGLE_TARGET_ANY }

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
## Amount of the class's own resource (Rage, Energy) needed to trigger, and
## spent when it does.
@export var cost: int = 0
## Multiplies the damage of the hit that triggered it (0.5 = half damage, 0.0 =
## none at all).
@export var damage_mult: float = 1.0
## The popup tag the triggering hit carries ("parried", "dodged"); see
## CombatState.damage_popup.
@export var popup_tag: String = "parried"
@export var applies_to: AppliesTo = AppliesTo.SINGLE_TARGET_PHYSICAL
## Only triggers on a hit that would leave the hero under this share of max HP
## (Arcane Barrier: 0.3). 0 = any hit.
@export var trigger_below_hp_pct: float = 0.0


## True when a hit from `skill`, resolving as `dmg_kind`, is one this reaction
## can trigger on.
func applies(skill: SkillData, dmg_kind: SkillData.SkillType) -> bool:
	match applies_to:
		AppliesTo.SINGLE_TARGET_PHYSICAL:
			return skill.target == SkillData.TargetType.ONE and dmg_kind == SkillData.SkillType.PHYS
		AppliesTo.SINGLE_TARGET_ANY:
			return skill.target == SkillData.TargetType.ONE
	return false


## True when a hit of `dmg` on a hero at `hp` of `max_hp` is one the HP
## threshold lets this reaction trigger on.
func passes_hp_threshold(hp: int, max_hp: int, dmg: int) -> bool:
	if trigger_below_hp_pct <= 0.0:
		return true
	return float(hp - dmg) < trigger_below_hp_pct * max_hp
