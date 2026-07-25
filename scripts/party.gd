## Autoload singleton. Owns the player's party of four heroes and the
## XP / level / Skill-Point logic. Registered as the "Party" autoload.
extends Node

## The v1 party is fixed: one hero per class, in this order. The order is
## stable — formation (step 9) and combat rows depend on it.
const CLASS_PATHS: Array[String] = [
	"res://resources/classes/warrior.tres",
	"res://resources/classes/cleric.tres",
	"res://resources/classes/rogue.tres",
	"res://resources/classes/mage.tres",
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
	for path in CLASS_PATHS:
		var class_data := load(path) as ClassData
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


## Performs a single level-up: +1 level, +1 SP (or converted to MP), full
## HP/MP restore. Per-level stat growth is applied automatically because
## Hero's max_hp/atk/etc. are derived from class_data + level. Returns
## SkillData entries whose unlock_level matches the new level.
func level_up(hero: Hero) -> Array[SkillData]:
	hero.level += 1
	award_sp(hero, 1)
	hero.hp = hero.max_hp()
	hero.mp = hero.max_mp()
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
## callers can surface a "converted" message.
func award_sp(hero: Hero, points: int) -> int:
	if points <= 0:
		return 0
	if has_upgradable_skills(hero):
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
	var tier := get_skill_tier(hero, skill)
	if tier <= 1:
		return skill
	var bonus := tier - 1            # 1, 2, or 3
	var mult := 1.0 + 0.3 * bonus    # 1.3 / 1.6 / 2.0
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
	# Multi-hit: prototype adds `bonus` hits (+1/+2/+3 at tiers 2/3/4). Note:
	# party.js's comment on this block disagrees with the code — code wins.
	if s.skill_type == SkillData.SkillType.MULTI:
		s.hits += bonus
	# MP cost reduction kicks in only for skills costing ≥3 MP.
	if s.mp_cost >= 3:
		s.mp_cost = maxi(1, s.mp_cost - bonus * 2)
	return s


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
