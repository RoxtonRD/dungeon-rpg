## Live skill text (#97): SkillText fills description templates from the
## effective skill, every description used by a skill, passive or reaction
## renders with no placeholder left over in both languages, and the boost
## button says what a boost does.
extends GdUnitTestSuite

const TestUtil := preload("res://test/support/test_util.gd")
const WARRIOR := "res://resources/classes/warrior.tres"
const EXECUTE := "res://resources/skills/warrior_execute.tres"
const PROVOKE := "res://resources/skills/warrior_provoke.tres"
const VOLLEY := "res://resources/skills/conjurer_volley.tres"
const CLERIC := "res://resources/classes/cleric.tres"
const CLERIC_HEAL := "res://resources/skills/cleric_heal.tres"
const LOCALES := ["pt_BR", "en"]

var _locale: String
var _heroes: Array
var _save_dir: String
## A throwaway save folder a test redirected GameState to, or "".
var _test_save_dir := ""


func before_test() -> void:
	_locale = TranslationServer.get_locale()
	_heroes = Party.heroes.duplicate()
	_save_dir = GameState.save_dir


## Runs even when the test failed, so no redirect or party change leaks.
func after_test() -> void:
	TranslationServer.set_locale(_locale)
	Party.heroes.assign(_heroes)
	GameState.save_dir = _save_dir
	if not _test_save_dir.is_empty():
		var abs_dir := ProjectSettings.globalize_path(_test_save_dir)
		for file in DirAccess.get_files_at(_test_save_dir):
			DirAccess.remove_absolute(abs_dir.path_join(file))
		DirAccess.remove_absolute(abs_dir)
		_test_save_dir = ""


# ── Placeholders ──────────────────────────────────────────────────────────────


func test_every_skill_placeholder_renders() -> void:
	var s := SkillData.new()
	s.power = 1.8
	s.mp_cost = 12
	s.cooldown = 3
	s.hits = 4
	s.dot_damage = 5
	s.dot_duration = 2
	s.mod_atk = 3
	s.mod_def = -6
	s.mod_mag = 0
	s.mod_spd = -1
	s.mod_duration = 4
	s.heal_over_time = 7
	s.hot_duration = 3
	s.crit_chance = 0.5
	s.rage_on_action = 20
	s.on_kill_rage = 30
	s.bonus_vs_def_debuff = 0.25
	var template := (
		"{power}|{cost}|{cooldown}|{hits}|{dot}|{dot_turns}|{atk}|{def}|{mag}|{spd}"
		+ "|{mod_turns}|{heal}|{heal_turns}|{crit}|{rage_gain}|{kill_rage}|{bonus}"
	)
	assert_str(SkillText.fill_skill(template, s)).is_equal(
		"180%|12|3|4|5|2|+3|-6|0|-1|4|7|3|50%|20|30|25%"
	)


func test_rage_gain_defaults_to_the_per_action_rage() -> void:
	var s := SkillData.new()  # rage_on_action = -1: the default
	assert_str(SkillText.fill_skill("{rage_gain}", s)).is_equal(
		str(Battler.RAGE_PER_DAMAGING_ACTION)
	)


func test_unused_placeholders_and_plain_text_are_left_alone() -> void:
	assert_str(SkillText.fill_skill("No numbers here.", SkillData.new())).is_equal(
		"No numbers here."
	)


func test_every_passive_placeholder_renders() -> void:
	var p := PassiveData.new()
	p.damage_pct_per_10_rage = 2.0
	assert_str(SkillText.fill_passive("{pct}|{pct_max}", p)).is_equal("2%|20%")


func test_every_reaction_placeholder_renders() -> void:
	var r := ReactionData.new()
	r.chance = 0.2
	r.cost = 10
	r.damage_mult = 0.5
	assert_str(SkillText.fill_reaction("{chance}|{cost}|{mult}", r)).is_equal("20%|10|50%")


# ── Effective skills ──────────────────────────────────────────────────────────


func test_boosted_variant_shows_boosted_numbers() -> void:
	TranslationServer.set_locale("en")
	var h := _warrior_hero()
	var execute: SkillData = load(EXECUTE)
	assert_bool(Party.pick_fork(h, execute, "b")).is_true()  # Sunder
	var sunder := Party.get_effective_skill(h, execute)
	assert_str(SkillText.describe(sunder)).is_equal(
		"A heavy blow with a 50% crit chance. Lowers the target's DEF: -6 for 3 turns."
	)
	assert_bool(Party.boost_skill(h, execute)).is_true()
	var boosted := Party.get_effective_skill(h, execute)
	assert_str(SkillText.describe(boosted)).is_equal(
		"A heavy blow with a 50% crit chance. Lowers the target's DEF: -8 for 4 turns."
	)


func test_upgraded_tier_shows_upgraded_numbers() -> void:
	TranslationServer.set_locale("pt_BR")
	var volley: SkillData = load(VOLLEY)
	assert_str(SkillText.describe(volley)).is_equal("3 lâminas atingem inimigos aleatórios.")
	var conjurer := Hero.create(load("res://resources/classes/conjurer.tres"))
	conjurer.sp_spent[volley.resource_path.get_file().get_basename()] = 1
	assert_str(SkillText.describe(Party.get_effective_skill(conjurer, volley))).is_equal(
		"4 lâminas atingem inimigos aleatórios."
	)


func test_passive_and_reaction_describe() -> void:
	TranslationServer.set_locale("en")
	var w: ClassData = load(WARRIOR)
	assert_str(SkillText.describe_passive(w.passives[0])).is_equal(
		"+2% damage for every 10 Rage held (up to +20%)."
	)
	assert_str(SkillText.describe_reaction(w.reactions[0])).is_equal(
		(
			"When hit by a single-target physical attack, a 20% chance to take 50% of"
			+ " the damage. Costs 10 Rage."
		)
	)


# ── Content ───────────────────────────────────────────────────────────────────


## Every description a skill (hero, variant or enemy), passive or reaction uses
## translates, and leaves no {placeholder} behind, in both languages. Boosted
## and top-tier copies are checked too, since those are what players read.
func test_every_description_renders_without_leftovers() -> void:
	var leftover := RegEx.create_from_string("\\{[^}]*\\}")
	var problems: PackedStringArray = []
	var checked := 0
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for path in TestUtil.find_files("res://resources", ".tres"):
			var res: Resource = load(path)
			var texts: Array[String] = []
			if res is SkillData:
				if (res as SkillData).description.is_empty():
					continue
				texts.append(SkillText.describe(res))
				texts.append(SkillText.describe(Party.boosted_skill(res)))
				texts.append(SkillText.describe(Party._scaled_to_tier(res, 3)))
			elif res is PassiveData:
				texts.append(SkillText.describe_passive(res))
			elif res is ReactionData:
				texts.append(SkillText.describe_reaction(res))
			else:
				continue
			checked += 1
			for text in texts:
				if text == res.get("description"):
					problems.append("%s [%s]: %s is not translated" % [path, locale, text])
				elif leftover.search(text) != null:
					problems.append("%s [%s]: %s" % [path, locale, text])
	assert_int(checked).is_greater(0)
	(
		assert_array(problems)
		. override_failure_message(TestUtil.problem_list("Unfilled descriptions", problems))
		. is_empty()
	)


# ── Boost button ──────────────────────────────────────────────────────────────


func test_boost_summary_lists_what_changes() -> void:
	TranslationServer.set_locale("en")
	var execute: SkillData = load(EXECUTE)
	var sunder := execute.fork_b
	assert_str(SkillText.boost_summary(sunder, Party.boosted_skill(sunder))).is_equal(
		"+30% power, -2 cost, -2 DEF, +1 turn"
	)
	TranslationServer.set_locale("pt_BR")
	assert_str(SkillText.boost_summary(sunder, Party.boosted_skill(sunder))).is_equal(
		"+30% de poder, -2 de custo, -2 DEF, +1 turno"
	)


func test_boost_summary_skips_power_on_buffs() -> void:
	TranslationServer.set_locale("en")
	var provoke: SkillData = load(PROVOKE)
	assert_str(SkillText.boost_summary(provoke, Party.boosted_skill(provoke))).is_equal(
		"-2 cost, +2 DEF, +1 turn"
	)


## The talent screen shows the live text: the chosen card's description, the
## boost button's summary, and the passive and reaction numbers.
func test_talent_screen_shows_live_text() -> void:
	TranslationServer.set_locale("en")
	var h := _warrior_hero()
	var execute: SkillData = load(EXECUTE)
	Party.pick_fork(h, execute, "b")
	Party.boost_skill(h, execute)
	var provoke: SkillData = load(PROVOKE)
	Party.pick_fork(h, provoke, "a")  # Iron Wall, not boosted
	var screen: Control = auto_free(load("res://scripts/talents/talent_screen.tscn").instantiate())
	screen.setup(h)
	add_child(screen)
	var texts := _texts_under(screen)
	assert_array(texts).contains(
		["A heavy blow with a 50% crit chance. Lowers the target's DEF: -8 for 4 turns."]
	)
	assert_array(texts).contains(["Boost: -2 cost, +3 DEF, +1 turn"])
	assert_array(texts).contains(["+2% damage for every 10 Rage held (up to +20%)."])


## A mana-class skill at tier 2 costs the same in its description, in combat
## and when cast outside combat (the Characters screen).
func test_upgraded_mana_skill_costs_the_same_everywhere() -> void:
	var heal: SkillData = load(CLERIC_HEAL)
	var expected := Party.get_upgraded_skill(_cleric_tier_2(heal), heal).mp_cost
	assert_int(expected).is_less(heal.mp_cost)  # the tier really changes the cost

	# Description
	var described := Party.get_effective_skill(_cleric_tier_2(heal), heal)
	assert_str(SkillText.fill_skill("{cost}", described)).is_equal(str(expected))

	# Combat
	var fighter := _cleric_tier_2(heal)
	var st := CombatState.build([fighter] as Array[Hero], [_dummy()] as Array[EnemyData])
	st.current_actor = st.party[0]
	var mp_before := fighter.mp
	st.player_action(heal, st.party[0])
	assert_int(mp_before - fighter.mp).is_equal(expected)

	# Out-of-combat cast, with the save redirected so the real one is untouched.
	var caster := _cleric_tier_2(heal)
	caster.hp = caster.max_hp() - 10  # someone to heal
	_test_save_dir = "user://test_saves/skill_text_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_test_save_dir))
	GameState.save_dir = _test_save_dir
	Party.heroes.assign([caster])
	var screen: Control = auto_free(
		load("res://scripts/inventory/inventory_screen.tscn").instantiate()
	)
	add_child(screen)
	mp_before = caster.mp
	screen._on_cast(caster, heal)
	assert_int(mp_before - caster.mp).is_equal(expected)


func _cleric_tier_2(heal: SkillData) -> Hero:
	var h := Hero.create(load(CLERIC))
	h.sp_spent[heal.resource_path.get_file().get_basename()] = 1
	h.mp = h.max_mp()
	return h


## A practice dummy with a harmless hit.
func _dummy() -> EnemyData:
	var hit := SkillData.new()
	hit.id = "dummy_hit"
	hit.display_name = "dummy_hit"
	hit.power = 0.1
	var e := EnemyData.new()
	e.id = "dummy"
	e.display_name = "dummy"
	e.max_hp = 99999
	e.atk = 1
	e.skills = [hit] as Array[SkillData]
	return e


func _texts_under(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label or node is Button:
		out.append(node.text)
	for child in node.get_children():
		out.append_array(_texts_under(child))
	return out


func _warrior_hero() -> Hero:
	var h := Hero.create(load(WARRIOR))
	h.level = 10
	h.hp = h.max_hp()
	h.sp_available = 5
	return h
