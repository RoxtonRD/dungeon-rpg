## Live skill, passive and reaction descriptions (#97).
##
## A description key translates to a template with named placeholders, e.g.
## "{crit} crit chance. Lowers the target's DEF: {def} for {mod_turns} turns."
## describe() fills them from the skill instance it is given, so callers pass
## the *effective* skill (Party.get_effective_skill: variant, boost and tier
## applied) and every number the player reads is the one combat uses.
## Placeholders a text doesn't use are ignored. Static util (no autoload).
class_name SkillText
extends RefCounted


## The translated, filled-in description of `skill` ("" when it has none).
static func describe(skill: SkillData) -> String:
	if skill == null or skill.description.is_empty():
		return ""
	return fill_skill(_tr(skill.description), skill)


## `template` with every skill placeholder replaced (see skill_values).
static func fill_skill(template: String, skill: SkillData) -> String:
	return template.format(skill_values(skill))


## The value of every skill placeholder, already formatted for display:
## {power} damage/heal multiplier as a % ("180%"); {cost} cost in the class's
## resource; {cooldown}; {hits}; {dot} / {dot_turns} damage over time per turn
## and its turns; {atk} / {def} / {mag} / {spd} the signed stat modifiers ("+5",
## "-6"); {mod_turns} how long they last; {heal} / {heal_turns} heal over time
## per round and its rounds; {crit} crit chance ("50%"); {rage_gain} Rage the
## action gives; {kill_rage} Rage refunded on a kill; {bonus} the damage bonus
## against a lowered-DEF target ("50%").
## Note: {cost} is the skill's own cost. Non-talent classes pay the base cost in
## combat whatever the tier (Party.combat_cost), so no description uses it yet.
static func skill_values(skill: SkillData) -> Dictionary:
	var rage_gain := skill.rage_on_action
	if rage_gain < 0:
		rage_gain = Battler.RAGE_PER_DAMAGING_ACTION
	return {
		"power": percent(skill.power),
		"cost": str(skill.mp_cost),
		"cooldown": str(skill.cooldown),
		"hits": str(skill.hits),
		"dot": str(skill.dot_damage),
		"dot_turns": str(skill.dot_duration),
		"atk": signed(skill.mod_atk),
		"def": signed(skill.mod_def),
		"mag": signed(skill.mod_mag),
		"spd": signed(skill.mod_spd),
		"mod_turns": str(skill.mod_duration),
		"heal": str(skill.heal_over_time),
		"heal_turns": str(skill.hot_duration),
		"crit": percent(skill.crit_chance),
		"rage_gain": str(rage_gain),
		"kill_rage": str(skill.on_kill_rage),
		"bonus": percent(skill.bonus_vs_def_debuff),
	}


## The translated, filled-in description of a passive ("" when it has none).
static func describe_passive(passive: PassiveData) -> String:
	if passive == null or passive.description.is_empty():
		return ""
	return fill_passive(_tr(passive.description), passive)


static func fill_passive(template: String, passive: PassiveData) -> String:
	return template.format(passive_values(passive))


## {pct} damage bonus per 10 Rage held ("2%"); {pct_max} the bonus at full
## Rage ("20%").
static func passive_values(passive: PassiveData) -> Dictionary:
	var steps := floori(Battler.RAGE_MAX / 10.0)
	return {
		"pct": percent(passive.damage_pct_per_10_rage / 100.0),
		"pct_max": percent(passive.damage_pct_per_10_rage * steps / 100.0),
	}


## The translated, filled-in description of a reaction ("" when it has none).
static func describe_reaction(reaction: ReactionData) -> String:
	if reaction == null or reaction.description.is_empty():
		return ""
	return fill_reaction(_tr(reaction.description), reaction)


static func fill_reaction(template: String, reaction: ReactionData) -> String:
	return template.format(reaction_values(reaction))


## {chance} trigger chance ("20%"); {cost} Rage spent; {mult} the share of the
## hit's damage still taken ("50%").
static func reaction_values(reaction: ReactionData) -> Dictionary:
	return {
		"chance": percent(reaction.chance),
		"cost": str(reaction.rage_cost),
		"mult": percent(reaction.damage_mult),
	}


## What a boost changes, from the skill before and after it, e.g.
## "+30% power, -2 cost" (translated). "" when nothing changes.
static func boost_summary(before: SkillData, after: SkillData) -> String:
	var parts: PackedStringArray = []
	# Power only matters to skills that deal damage or heal.
	var uses_power := (
		before.skill_type != SkillData.SkillType.BUFF
		and before.skill_type != SkillData.SkillType.DEBUFF
	)
	if uses_power and before.power > 0.0 and not is_equal_approx(before.power, after.power):
		var pct := roundi((after.power / before.power - 1.0) * 100.0)
		parts.append(_tr("UI_BOOST_POWER") % signed_text(pct, "%"))
	if after.mp_cost != before.mp_cost:
		parts.append(_tr("UI_BOOST_COST") % signed(after.mp_cost - before.mp_cost))
	if after.hits != before.hits:
		parts.append(_counted("UI_BOOST_HITS", after.hits - before.hits))
	var stats := [
		["STAT_ATK", before.mod_atk, after.mod_atk],
		["STAT_DEF", before.mod_def, after.mod_def],
		["STAT_MAG", before.mod_mag, after.mod_mag],
		["STAT_SPD", before.mod_spd, after.mod_spd],
	]
	for s in stats:
		if s[2] != s[1]:
			parts.append("%s %s" % [signed(s[2] - s[1]), _tr(s[0])])
	if after.mod_duration != before.mod_duration:
		parts.append(_counted("UI_BOOST_TURNS", after.mod_duration - before.mod_duration))
	if after.dot_damage != before.dot_damage:
		parts.append(_tr("UI_BOOST_DOT") % signed(after.dot_damage - before.dot_damage))
	if after.dot_duration != before.dot_duration:
		parts.append(_counted("UI_BOOST_TURNS", after.dot_duration - before.dot_duration))
	if after.heal_over_time != before.heal_over_time:
		parts.append(_tr("UI_BOOST_HOT") % signed(after.heal_over_time - before.heal_over_time))
	if after.hot_duration != before.hot_duration:
		parts.append(_counted("UI_BOOST_TURNS", after.hot_duration - before.hot_duration))
	return ", ".join(parts)


## A 0..1 fraction (or multiplier) as a whole percent: 1.8 -> "180%".
static func percent(fraction: float) -> String:
	return "%d%%" % roundi(fraction * 100.0)


## A whole number with its sign: 5 -> "+5", -6 -> "-6", 0 -> "0".
static func signed(value: int) -> String:
	return signed_text(value, "")


static func signed_text(value: int, suffix: String) -> String:
	return ("+%d%s" if value > 0 else "%d%s") % [value, suffix]


## "+1 hit" / "+2 hits": KEY_ONE for a change of one, KEY otherwise.
static func _counted(key: String, delta: int) -> String:
	var k: String = key + "_ONE" if absi(delta) == 1 else key
	return _tr(k) % signed(delta)


static func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))
