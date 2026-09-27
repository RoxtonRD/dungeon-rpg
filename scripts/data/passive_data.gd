@tool
## A passive talent: always on once picked, no button, no cost in combat. A hero
## picks one passive from ClassData.passives for 1 SP, permanently (see
## Party.pick_passive). Authored as .tres assets under res://resources/passives/.
class_name PassiveData
extends Resource

## Stable internal key, e.g. "bloodlust". Stored in saves (Hero.talents
## "_passive") — never translate.
@export var id: String = ""
## Translation key of the name shown in the UI.
@export var display_name: String = ""
## Translation key of the description.
@export_multiline var description: String = ""
## Hero level at which the passive can be picked.
@export var unlock_level: int = 1

@export_group("Effect")
## Outgoing damage bonus, in percent, per 10 Rage the hero holds at the moment
## of the hit (Bloodlust). 0 = no effect.
@export var damage_pct_per_10_rage: float = 0.0


## Multiplier on this hero's outgoing damage while holding `rage` Rage: every
## full 10 Rage adds damage_pct_per_10_rage percent. 1.0 = no bonus.
func damage_mult(rage: int) -> float:
	return 1.0 + damage_pct_per_10_rage * floori(rage / 10.0) / 100.0
