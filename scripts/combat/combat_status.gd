## A single active status effect on a battler: buff, debuff, DoT, or barrier.
## Created and owned by CombatState; never persisted.
class_name CombatStatus
extends RefCounted

enum Kind { BUFF, DEBUFF, DOT, BARRIER }

var kind: Kind = Kind.BUFF
## Display name of the skill that applied this status — used in log lines.
var source_name: String = ""

## Stat modifiers (buff/debuff only). Sign carries direction.
var mod_atk: int = 0
var mod_def: int = 0
var mod_mag: int = 0
var mod_spd: int = 0

## Per-turn damage (DoT only).
var dot_damage: int = 0

## Turns remaining. 99 means "until consumed" (used by barrier).
var duration: int = 0

## Forces enemies to target the bearer.
var taunt: bool = false
