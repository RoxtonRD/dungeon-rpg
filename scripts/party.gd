## Autoload singleton. Owns the player's party of four heroes and the
## XP / level / Skill-Point logic. Registered as the "Party" autoload.
extends Node

## The classes the default (non-created) party is built from — exactly
## PARTY_SIZE of them, one hero each. This is NOT the full roster: see
## ALL_CLASS_IDS. The order is stable — formation and combat rows depend on it.
const CLASS_PATHS: Array[String] = [
	"res://resources/classes/warrior.tres",
	"res://resources/classes/cleric.tres",
	"res://resources/classes/rogue.tres",
	"res://resources/classes/mage.tres",
]

## Every playable class, in character-creation display order. Adding a class
## here must NOT grow the default party — start_new_game() clamps to PARTY_SIZE.
const ALL_CLASS_IDS: Array[String] = [
	"warrior",
	"cleric",
	"rogue",
	"mage",
	"conjurer",
	"alchemist",
]

const CLASS_DIR := "res://resources/classes/"
## Party size is fixed at 4 (the 2x2 formation grid depends on it).
const PARTY_SIZE := 4
## A single class may appear on at most this many heroes in one party.
const MAX_PER_CLASS := 2

## Hard ceiling on hero level. The prototype had none; we cap at 10 because
## a level-10 hero has earned exactly enough SP (10 total) to fully max all
## four skills — 3 normals to tier 3 + the ultimate to tier 4 = 9 SP, plus
## the starting SP.
const LEVEL_CAP: int = 10

var heroes: Array[Hero] = []

# ── New game ──────────────────────────────────────────────────────────────────


## Builds a fresh default party: one level-1 hero per class. Used by the F6
## standalone bootstraps and as the fallback when no custom party was created.
func start_new_game() -> void:
	heroes.clear()
	# Clamped to PARTY_SIZE: the roster can grow past four classes, the party
	# cannot (the 2x2 formation grid and combat rows assume exactly four).
	for i in mini(PARTY_SIZE, CLASS_PATHS.size()):
		var class_data := load(CLASS_PATHS[i]) as ClassData
		heroes.append(Hero.create(class_data))


# ── Custom party ──────────────────────────────────────────────────────────────


## Number of current party heroes belonging to `class_id`.
func class_count(class_id: String) -> int:
	var n := 0
	for h in heroes:
		if h.class_data.id == class_id:
			n += 1
	return n


## Builds the party from the character-creation specs — one Dictionary per hero,
## {name, class_id, skin_id}. Slot 0 is flagged as the main character. Callers
## enforce the naming / MAX_PER_CLASS / size rules; this trusts its inputs.
func build_party(specs: Array) -> void:
	heroes.clear()
	for i in specs.size():
		var s: Dictionary = specs[i]
		var class_id := str(s["class_id"])
		var h := Hero.create(load(CLASS_DIR + "%s.tres" % class_id) as ClassData)
		h.is_main = (i == 0)
		h.custom_name = str(s["name"]).strip_edges()
		# Store "" for the default skin ("1"), keeping saves tidy.
		var skin := str(s["skin_id"])
		h.skin_id = "" if skin == "1" else skin
		heroes.append(h)


# ── Status effects (persist outside combat) ───────────────────────────────────


## Advances every living hero's statuses by one turn: regen heals, DoT damages,
## durations count down and expired effects drop off. Called when the party moves
## between rooms; combat ticks its own via CombatState._tick_statuses.
## Returns log lines describing what happened, for the dungeon UI.
##
## DoT is floored at 1 HP out of combat: there is no non-combat defeat path, so
## dying while walking would leave the game in a state nothing handles.
func tick_statuses() -> Array[String]:
	var lines: Array[String] = []
	for h in heroes:
		if not h.is_alive():
			continue
		for i in range(h.statuses.size() - 1, -1, -1):
			var st: CombatStatus = h.statuses[i]
			if st.kind == CombatStatus.Kind.REGEN and st.heal_per_turn > 0:
				var before := h.hp
				h.hp = mini(h.max_hp(), h.hp + st.heal_per_turn)
				if h.hp > before:
					lines.append(
						tr("LOG_REGEN_TICK") % [h.display_name(), h.hp - before, tr(st.source_name)]
					)
			elif st.kind == CombatStatus.Kind.DOT and st.dot_damage > 0:
				var before_dot := h.hp
				h.hp = maxi(1, h.hp - st.dot_damage)
				if before_dot > h.hp:
					lines.append(
						tr("LOG_DOT") % [h.display_name(), before_dot - h.hp, tr(st.source_name)]
					)
			st.duration -= 1
			if st.duration <= 0:
				h.statuses.remove_at(i)
	return lines


## Drops every hero's statuses — used by rest rooms, run end and TPK.
func clear_statuses() -> void:
	for h in heroes:
		h.statuses.clear()


# ── XP & leveling ─────────────────────────────────────────────────────────────


## Verbatim from prototype party.js: floor(20 * level^1.5).
func xp_for_next(level: int) -> int:
	return floori(20.0 * pow(level, 1.5))


## Adds XP and triggers level-ups while the threshold is met. Returns every
## SkillData newly unlocked across the awarded XP (empty if no level gained).
## Heroes already at LEVEL_CAP ignore further XP.
func award_xp(hero: Hero, amount: int) -> Array[SkillData]:
	var unlocked: Array[SkillData] = []
	if hero.level >= LEVEL_CAP:
		return unlocked
	hero.xp += amount
	while hero.level < LEVEL_CAP and hero.xp >= xp_for_next(hero.level):
		hero.xp -= xp_for_next(hero.level)
		unlocked.append_array(level_up(hero))
	if hero.level >= LEVEL_CAP:
		# Discard any leftover XP so the UI never shows "ready to level" at cap.
		hero.xp = 0
	return unlocked


## Performs a single level-up: +1 level, +1 SP (or converted to MP; talent
## classes only gain SP on even levels), no HP/MP restore. Per-level stat
## growth is applied automatically because Hero's max_hp/atk/etc. are derived
## from class_data + level. Returns SkillData entries whose unlock_level matches
## the new level.
func level_up(hero: Hero) -> Array[SkillData]:
	hero.level += 1
	var sp_gain := 1
	if hero.class_data.uses_talents:
		sp_gain = talent_sp_for_level(hero.level) - talent_sp_for_level(hero.level - 1)
	award_sp(hero, sp_gain)
	# Deliberately no HP/MP restore: levelling mid-run used to wipe out all
	# accumulated attrition, which is what made deep runs trivial. The hero
	# still gains max HP/MP from the level, they just don't get topped up.
	_grant_level_skins(hero.level)
	var newly: Array[SkillData] = []
	for skill in hero.class_data.skills:
		if skill.unlock_level == hero.level:
			newly.append(skill)
	return newly


## Unlocks any LEVEL-gated skin whose requirement this new level meets. Skins are
## account-wide, so reaching the level on any hero grants it for the whole save.
func _grant_level_skins(reached_level: int) -> void:
	for id in Skins.level_unlocks_at_or_below(reached_level):
		GameState.unlock_skin(id)


# ── Skill Points ──────────────────────────────────────────────────────────────

## Max MP granted per Skill Point when SP is converted (no skills to upgrade).
const SP_TO_MP: int = 2


## True while the hero still has a skill that can take more SP — i.e. any skill
## below its max tier. Skills not yet unlocked count too, since they become
## upgradable on level-up; SP is banked rather than converted in that case.
func has_upgradable_skills(hero: Hero) -> bool:
	for skill in hero.class_data.skills:
		if get_skill_tier(hero, skill) < skill.max_upgrade_level:
			return true
	return false


## Grants `points` Skill Points to a hero. When the hero has no skill left to
## upgrade (now or in the future), the points are instead converted to permanent
## max MP. Returns the MP gained (0 when the points were granted as SP), so
## callers can surface a "converted" message. Talent classes never convert:
## spare SP stays banked.
func award_sp(hero: Hero, points: int) -> int:
	if points <= 0:
		return 0
	if hero.class_data.uses_talents or has_upgradable_skills(hero):
		hero.sp_available += points
		return 0
	var mp_gain := points * SP_TO_MP
	hero.bonus_mp += mp_gain
	hero.mp = mini(hero.max_mp(), hero.mp + mp_gain)
	return mp_gain


## Sweeps banked SP that can never be spent — every skill already at its max
## tier — into permanent max MP, applying the surplus-SP rule that award_sp()
## only enforces at earn time. Without this, SP hoarded (or held while skills
## are still level-locked) and then spent down to a fully-maxed build would
## strand points in sp_available, letting a hero hold more SP than the skill
## tiers can ever absorb. Safe to call anytime; returns the max MP gained.
func reconcile_surplus_sp(hero: Hero) -> int:
	if hero.class_data.uses_talents:
		return 0  # talent SP is never converted
	if hero.sp_available <= 0 or has_upgradable_skills(hero):
		return 0
	var leftover := hero.sp_available
	hero.sp_available = 0
	var gain := leftover * SP_TO_MP
	hero.bonus_mp += gain
	hero.mp = mini(hero.max_mp(), hero.mp + gain)
	return gain


## Stable key used inside Hero.sp_spent. The .tres filename without extension —
## e.g. "warrior_slash" for res://resources/skills/warrior_slash.tres.
func _skill_key(skill: SkillData) -> String:
	return skill.resource_path.get_file().get_basename()


## Current upgrade tier of a skill for this hero (base = 1, max = skill.max_upgrade_level).
func get_skill_tier(hero: Hero, skill: SkillData) -> int:
	return 1 + int(hero.sp_spent.get(_skill_key(skill), 0))


func can_upgrade_skill(hero: Hero, skill: SkillData) -> bool:
	if hero.class_data.uses_talents:
		return false  # talent classes buy forks and boosts instead
	if hero.level < skill.unlock_level:
		return false
	if get_skill_tier(hero, skill) >= skill.max_upgrade_level:
		return false
	return hero.sp_available >= 1


## Spends 1 SP to raise the skill's tier by 1. Returns false if not allowed.
func upgrade_skill(hero: Hero, skill: SkillData) -> bool:
	if not can_upgrade_skill(hero, skill):
		return false
	var key := _skill_key(skill)
	hero.sp_spent[key] = int(hero.sp_spent.get(key, 0)) + 1
	hero.sp_available -= 1
	# If that was the last available upgrade, convert any SP still banked so it
	# doesn't strand above the skills' capacity (hoard-then-spend case).
	reconcile_surplus_sp(hero)
	return true


## Returns a SkillData (duplicated and scaled) reflecting the hero's current
## upgrade tier. At tier 1 returns the original SkillData unmodified. Formula
## is carried verbatim from prototype party.js getUpgradedSkill — see the
## inline note below for one comment-vs-code discrepancy in the source.
func get_upgraded_skill(hero: Hero, skill: SkillData) -> SkillData:
	return _scaled_to_tier(skill, get_skill_tier(hero, skill))


## `skill` duplicated and scaled to upgrade `tier` (1 = unchanged). Shared by
## tier upgrades and talent boosts (a boost is the tier-2 scaling).
func _scaled_to_tier(skill: SkillData, tier: int) -> SkillData:
	if tier <= 1:
		return skill
	var bonus := tier - 1  # 1, 2, or 3
	var mult := 1.0 + 0.3 * bonus  # 1.3 / 1.6 / 2.0
	var s: SkillData = skill.duplicate()
	s.power = snappedf(s.power * mult, 0.01)
	# Stat modifier — covers both buff and debuff in the unified SkillData.
	if s.mod_atk != 0:
		s.mod_atk = roundi(s.mod_atk * mult)
	if s.mod_def != 0:
		s.mod_def = roundi(s.mod_def * mult)
	if s.mod_mag != 0:
		s.mod_mag = roundi(s.mod_mag * mult)
	if s.mod_spd != 0:
		s.mod_spd = roundi(s.mod_spd * mult)
	if s.mod_duration > 0 and s.mod_duration < 99:
		s.mod_duration = mini(6, s.mod_duration + bonus)
	# Damage-over-time scales like a debuff; duration only grows from tier 3.
	if s.dot_damage > 0:
		s.dot_damage = roundi(s.dot_damage * mult)
		if tier >= 3:
			s.dot_duration = mini(5, s.dot_duration + 1)
	# Heal-over-time scales the same way.
	if s.heal_over_time > 0:
		s.heal_over_time = roundi(s.heal_over_time * mult)
		if tier >= 3:
			s.hot_duration = mini(5, s.hot_duration + 1)
	# Multi-hit: prototype adds `bonus` hits (+1/+2/+3 at tiers 2/3/4). Note:
	# party.js's comment on this block disagrees with the code — code wins.
	if s.skill_type == SkillData.SkillType.MULTI:
		s.hits += bonus
	# MP cost reduction kicks in only for skills costing ≥3 MP.
	if s.mp_cost >= 3:
		s.mp_cost = maxi(1, s.mp_cost - bonus * 2)
	return s


# ── Talents (talent classes only) ─────────────────────────────────────────────
# Each skill of a talent class has a fork (pick variant A or B, 1 SP, from the
# skill's unlock level) and then a boost (1 SP). Forks are permanent for now.
# A hero also picks one passive and learns one reaction (1 SP each, permanent),
# stored in Hero.talents under the reserved keys below.
# See ClassData.uses_talents and Hero.talents.

## Hero.talents key of the picked passive's id.
const PASSIVE_KEY := "_passive"
## Hero.talents key of the learned reaction: {"id": String, "enabled": bool}.
const REACTION_KEY := "_reaction"


## Total SP a talent-class hero earns by `level`: +1 at levels 2, 4, 6, 8 and
## 10, so 0, 1, 1, 2, 2, … 5. A Tome of Mastery adds to this.
func talent_sp_for_level(level: int) -> int:
	return floori(clampi(level, 0, LEVEL_CAP) / 2.0)


## SP a hero has put into talents: 1 per fork, 1 per boost, 1 for the passive
## and 1 for the reaction.
func sp_in_talents(hero: Hero) -> int:
	var total := 0
	for key in hero.talents:
		if key == PASSIVE_KEY or key == REACTION_KEY:
			total += 1
			continue
		var t: Dictionary = hero.talents[key]
		if t.get("fork", "") != "":
			total += 1
		if t.get("boost", false):
			total += 1
	return total


## The talent choice for a base skill, or {} when no fork is picked.
func get_talent(hero: Hero, skill: SkillData) -> Dictionary:
	return hero.talents.get(_skill_key(skill), {})


## True when the hero can spend 1 SP to pick `fork` ("a" or "b") for `skill`.
func can_pick_fork(hero: Hero, skill: SkillData, fork: String) -> bool:
	if not hero.class_data.uses_talents or not hero.class_data.skills.has(skill):
		return false
	if fork != "a" and fork != "b":
		return false
	if (skill.fork_a if fork == "a" else skill.fork_b) == null:
		return false
	if hero.level < skill.unlock_level:
		return false
	if not get_talent(hero, skill).is_empty():
		return false  # already picked, and permanent
	return hero.sp_available >= 1


## Spends 1 SP to pick a fork. Returns false if not allowed.
func pick_fork(hero: Hero, skill: SkillData, fork: String) -> bool:
	if not can_pick_fork(hero, skill, fork):
		return false
	hero.talents[_skill_key(skill)] = {"fork": fork, "boost": false}
	hero.sp_available -= 1
	return true


## True when the hero can spend 1 SP to boost `skill` (its fork is picked).
func can_boost(hero: Hero, skill: SkillData) -> bool:
	var t := get_talent(hero, skill)
	if t.is_empty() or t.get("boost", false):
		return false
	return hero.sp_available >= 1


## Spends 1 SP to boost a skill. Returns false if not allowed.
func boost_skill(hero: Hero, skill: SkillData) -> bool:
	if not can_boost(hero, skill):
		return false
	hero.talents[_skill_key(skill)]["boost"] = true
	hero.sp_available -= 1
	return true


## The hero's picked passive, or null.
func get_passive(hero: Hero) -> PassiveData:
	var id: String = hero.talents.get(PASSIVE_KEY, "")
	for passive in hero.class_data.passives:
		if passive.id == id:
			return passive
	return null


## True when the hero can spend 1 SP to pick `passive`: one of its class's, at
## its unlock level, and no passive picked yet (the pick is permanent).
func can_pick_passive(hero: Hero, passive: PassiveData) -> bool:
	if passive == null or not hero.class_data.passives.has(passive):
		return false
	if hero.level < passive.unlock_level:
		return false
	if hero.talents.has(PASSIVE_KEY):
		return false
	return hero.sp_available >= 1


## Spends 1 SP to pick a passive. Returns false if not allowed.
func pick_passive(hero: Hero, passive: PassiveData) -> bool:
	if not can_pick_passive(hero, passive):
		return false
	hero.talents[PASSIVE_KEY] = passive.id
	hero.sp_available -= 1
	return true


## The hero's learned reaction, switched on or not, or null.
func get_reaction(hero: Hero) -> ReactionData:
	var learned: Dictionary = hero.talents.get(REACTION_KEY, {})
	for reaction in hero.class_data.reactions:
		if reaction.id == learned.get("id", ""):
			return reaction
	return null


## True when the hero's learned reaction is switched on.
func is_reaction_enabled(hero: Hero) -> bool:
	var learned: Dictionary = hero.talents.get(REACTION_KEY, {})
	return bool(learned.get("enabled", false))


## The reaction combat should use for this hero: learned and switched on, or null.
func get_active_reaction(hero: Hero) -> ReactionData:
	return get_reaction(hero) if is_reaction_enabled(hero) else null


## True when the hero can spend 1 SP to learn `reaction`: one of its class's, at
## its unlock level, and no reaction learned yet (learning is permanent).
func can_learn_reaction(hero: Hero, reaction: ReactionData) -> bool:
	if reaction == null or not hero.class_data.reactions.has(reaction):
		return false
	if hero.level < reaction.unlock_level:
		return false
	if hero.talents.has(REACTION_KEY):
		return false
	return hero.sp_available >= 1


## Spends 1 SP to learn a reaction, switched on. Returns false if not allowed.
func learn_reaction(hero: Hero, reaction: ReactionData) -> bool:
	if not can_learn_reaction(hero, reaction):
		return false
	hero.talents[REACTION_KEY] = {"id": reaction.id, "enabled": true}
	hero.sp_available -= 1
	return true


## Switches the learned reaction on or off (free). Callers only offer this
## outside combat. Returns false when the hero has no reaction.
func set_reaction_enabled(hero: Hero, enabled: bool) -> bool:
	if not hero.talents.has(REACTION_KEY):
		return false
	hero.talents[REACTION_KEY]["enabled"] = enabled
	return true


## The skill as this hero actually uses it. Talent classes: the picked variant
## (or the base skill), then the tier-2 scaling when boosted. Other classes:
## the tier-upgraded skill (get_upgraded_skill). `base` is the class's skill.
func get_effective_skill(hero: Hero, base: SkillData) -> SkillData:
	if not hero.class_data.uses_talents:
		return get_upgraded_skill(hero, base)
	var t := get_talent(hero, base)
	var skill := base
	match t.get("fork", ""):
		"a":
			skill = base.fork_a if base.fork_a != null else base
		"b":
			skill = base.fork_b if base.fork_b != null else base
	if t.get("boost", false):
		skill = _scaled_to_tier(skill, 2)
	return skill


## What using `base` costs this hero in combat. Talent classes pay the effective
## skill's cost (a variant or a boost can change it). Other classes have always
## paid the base cost in combat, whatever the tier, and still do.
func combat_cost(hero: Hero, base: SkillData) -> int:
	if hero.class_data.uses_talents:
		return get_effective_skill(hero, base).mp_cost
	return base.mp_cost


# ── Persistence ───────────────────────────────────────────────────────────────


## Returns a plain Dictionary snapshot of the party. Step 8 (save) will wrap
## this with versioning and write it to disk.
func serialize() -> Dictionary:
	var hero_dicts: Array = []
	for h in heroes:
		hero_dicts.append(h.to_dict())
	return {"heroes": hero_dicts}


## Restores the party from a Dictionary previously produced by serialize().
func deserialize(data: Dictionary) -> void:
	heroes.clear()
	var arr: Array = data.get("heroes", [])
	for hd in arr:
		heroes.append(Hero.from_dict(hd))
