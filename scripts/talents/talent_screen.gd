## Talent screen: a full-screen overlay the Characters screen instances for a
## talent-class hero (ClassData.uses_talents). Shows each skill's two forks
## side by side and a Boost button, the class's passives (pick one) and its
## reaction (learn it, then switch it on or off), and spends SP through the
## Party talent API. All talent rules live in Party; this script only presents
## them.
##
## The content is built from a list of section builders (Skills, Passive,
## Reaction), so later sections can be appended without a redesign.
extends Control

## Emitted when the player closes the overlay. The opener refreshes and frees it.
signal closed

enum CardState { LOCKED, AVAILABLE, CHOSEN, NOT_CHOSEN }

const GOLD := Color(1, 0.82, 0.35, 1)
const DIM_TEXT := Color(0.68, 0.70, 0.78)
## Modulate for locked and not-chosen cards.
const DIMMED := Color(1, 1, 1, 0.4)

var hero: Hero
## Each builder returns a section Control, or null when it has nothing to show
## (empty sections are never drawn). Filled in _ready(); append new ones there.
var _section_builders: Array[Callable] = []
## The Party call (a fork, passive or reaction pick) waiting on the confirm
## dialog. It returns true when it spent the SP.
var _pending_action: Callable

@onready var hero_label: Label = %HeroLabel
@onready var sp_label: Label = %SpLabel
@onready var sections: VBoxContainer = %Sections
@onready var close_button: Button = %CloseButton
@onready var confirm_overlay: Control = %ConfirmOverlay
@onready var confirm_label: Label = %ConfirmLabel
@onready var cancel_button: Button = %CancelButton
@onready var confirm_button: Button = %ConfirmButton


## Call before adding the overlay to the tree.
func setup(for_hero: Hero) -> void:
	hero = for_hero


func _ready() -> void:
	SafeArea.apply($VBox)
	_section_builders = [_build_skills_section, _build_passive_section, _build_reaction_section]
	close_button.pressed.connect(_on_close)
	cancel_button.pressed.connect(_on_confirm_cancelled)
	confirm_button.pressed.connect(_on_confirm_accepted)
	confirm_overlay.visible = false
	_rebuild()


func _rebuild() -> void:
	_update_header()
	for child in sections.get_children():
		sections.remove_child(child)
		child.queue_free()
	for builder in _section_builders:
		var section: Control = builder.call()
		if section != null:
			sections.add_child(section)


func _update_header() -> void:
	var class_name_str := tr(hero.class_data.display_name)
	var parts: Array[String] = [hero.display_name()]
	# An unrenamed hero's display name is already the class name.
	if parts[0] != class_name_str:
		parts.append(class_name_str)
	parts.append(tr("UI_TALENT_LOCKED") % hero.level)
	hero_label.text = " · ".join(parts)
	sp_label.text = tr("UI_TALENT_SP") % hero.sp_available


## Titled section wrapper shared by every builder.
func _make_section(title_key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = tr(title_key)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	return box


# ── Skills section ────────────────────────────────────────────────────────────


func _build_skills_section() -> Control:
	var skills: Array[SkillData] = []
	for skill in hero.class_data.skills:
		if skill.fork_a != null and skill.fork_b != null:
			skills.append(skill)
	if skills.is_empty():
		return null
	# Unlock order; the stable sort keeps the class's order within a level.
	skills.sort_custom(
		func(a: SkillData, b: SkillData) -> bool: return a.unlock_level < b.unlock_level
	)
	var section := _make_section("UI_SKILLS")
	for skill in skills:
		section.add_child(_make_skill_block(skill))
	return section


## One skill: base name + icon, the two fork cards (A | B), then Boost.
func _make_skill_block(base: SkillData) -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_make_icon(base.icon_or_null(), 48))
	var name_lbl := Label.new()
	name_lbl.text = tr(base.display_name)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_lbl)
	box.add_child(head)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	cards.add_child(_make_fork_card(base, "a"))
	cards.add_child(_make_fork_card(base, "b"))
	box.add_child(cards)

	box.add_child(_make_boost_button(base))
	return panel


func _card_state(base: SkillData, fork: String) -> CardState:
	if hero.level < base.unlock_level:
		return CardState.LOCKED
	var picked: String = Party.get_talent(hero, base).get("fork", "")
	if picked.is_empty():
		return CardState.AVAILABLE
	return CardState.CHOSEN if picked == fork else CardState.NOT_CHOSEN


func _make_fork_card(base: SkillData, fork: String) -> Control:
	var state := _card_state(base, fork)
	var variant: SkillData = base.fork_a if fork == "a" else base.fork_b
	# The chosen card shows the skill as the hero really uses it (boost included).
	var shown := Party.get_effective_skill(hero, base) if state == CardState.CHOSEN else variant
	var tappable := state == CardState.AVAILABLE and Party.can_pick_fork(hero, base, fork)
	return _make_card(
		{
			"state": state,
			"tappable": tappable,
			"icon": base.icon_or_null(),
			"title": tr(shown.display_name),
			"description": tr(shown.description),
			"info": _cost_text(shown),
			"unlock_level": base.unlock_level,
			"chosen_key": "UI_TALENT_CHOSEN",
		},
		_ask_pick.bind(base, fork)
	)


## A tappable talent card (a fork, passive or reaction). `spec` holds: state,
## tappable, icon (Texture2D or null), title, description, info (a cost line,
## or "" for none), unlock_level (shown while locked) and chosen_key (the
## label shown once chosen). `on_tap` runs when a tappable card is tapped.
func _make_card(spec: Dictionary, on_tap: Callable) -> Control:
	var state: CardState = spec["state"]
	var tappable: bool = spec["tappable"]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style(state, tappable))
	if state == CardState.LOCKED or state == CardState.NOT_CHOSEN:
		card.modulate = DIMMED

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_make_icon(spec["icon"], 40))
	var name_lbl := _make_label(spec["title"], 18)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if state == CardState.CHOSEN:
		name_lbl.add_theme_color_override("font_color", GOLD)
	head.add_child(name_lbl)
	box.add_child(head)

	var desc := _make_label(spec["description"], 14)
	desc.add_theme_color_override("font_color", DIM_TEXT)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)

	if not str(spec["info"]).is_empty():
		box.add_child(_make_label(spec["info"], 14))
	match state:
		CardState.LOCKED:
			box.add_child(_make_label(tr("UI_TALENT_LOCKED") % int(spec["unlock_level"]), 15))
		CardState.CHOSEN:
			var chosen := _make_label("✓ " + tr(spec["chosen_key"]), 15)
			chosen.add_theme_color_override("font_color", GOLD)
			box.add_child(chosen)

	# A flat, invisible button over the whole card takes the tap.
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.disabled = not tappable
	if tappable:
		tap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tap.pressed.connect(on_tap)
	card.add_child(tap)
	return card


## "50 Fúria · recarga 3" (cooldown only when the skill has one).
func _cost_text(skill: SkillData) -> String:
	var uses_rage := hero.class_data.resource_type == ClassData.ResourceType.RAGE
	var text := "%d %s" % [skill.mp_cost, tr("RES_RAGE") if uses_rage else tr("RES_MP")]
	if skill.cooldown > 0:
		text += "  ·  " + tr("UI_SKILL_COOLDOWN") % skill.cooldown
	return text


func _card_style(state: CardState, tappable: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_content_margin_all(10)
	s.set_corner_radius_all(6)
	s.bg_color = Color(0.16, 0.13, 0.18, 0.92)
	s.border_color = Color(0.55, 0.42, 0.22, 0.4)
	s.set_border_width_all(1)
	if state == CardState.CHOSEN:
		s.bg_color = Color(0.26, 0.2, 0.14, 1)
		s.border_color = GOLD
		s.set_border_width_all(3)
	elif tappable:
		s.border_color = Color(0.75, 0.6, 0.32, 0.9)
		s.set_border_width_all(2)
	return s


func _make_boost_button(base: SkillData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	var boosted: bool = Party.get_talent(hero, base).get("boost", false)
	if boosted:
		btn.text = "✓ " + tr("UI_TALENT_BOOSTED")
		btn.add_theme_color_override("font_disabled_color", GOLD)
		btn.disabled = true
	else:
		btn.text = tr("UI_TALENT_BOOST")
		btn.disabled = not Party.can_boost(hero, base)
		btn.pressed.connect(_on_boost.bind(base))
	return btn


# ── Passive section ───────────────────────────────────────────────────────────


## Pick-one cards for the class's passives (one per hero, permanent).
func _build_passive_section() -> Control:
	if hero.class_data.passives.is_empty():
		return null
	var section := _make_section("UI_TALENT_PASSIVE")
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	for passive in hero.class_data.passives:
		cards.add_child(_make_passive_card(passive))
	section.add_child(cards)
	return section


func _passive_state(passive: PassiveData) -> CardState:
	if hero.level < passive.unlock_level:
		return CardState.LOCKED
	var picked := Party.get_passive(hero)
	if picked == null:
		return CardState.AVAILABLE
	return CardState.CHOSEN if picked == passive else CardState.NOT_CHOSEN


func _make_passive_card(passive: PassiveData) -> Control:
	var state := _passive_state(passive)
	return _make_card(
		{
			"state": state,
			"tappable": state == CardState.AVAILABLE and Party.can_pick_passive(hero, passive),
			"icon": null,
			"title": tr(passive.display_name),
			"description": tr(passive.description),
			"info": "",
			"unlock_level": passive.unlock_level,
			"chosen_key": "UI_TALENT_CHOSEN",
		},
		_ask_confirm.bind(tr(passive.display_name), Party.pick_passive.bind(hero, passive))
	)


# ── Reaction section ──────────────────────────────────────────────────────────


## Cards to learn one of the class's reactions (permanent), then an on/off
## switch for the learned one (free; this screen is only reachable outside
## combat).
func _build_reaction_section() -> Control:
	if hero.class_data.reactions.is_empty():
		return null
	var section := _make_section("UI_TALENT_REACTION")
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	for reaction in hero.class_data.reactions:
		cards.add_child(_make_reaction_card(reaction))
	section.add_child(cards)
	if Party.get_reaction(hero) != null:
		var toggle := CheckButton.new()
		toggle.text = tr("UI_REACTION_TOGGLE")
		toggle.custom_minimum_size = Vector2(0, 52)
		toggle.add_theme_font_size_override("font_size", 18)
		toggle.button_pressed = Party.is_reaction_enabled(hero)
		toggle.toggled.connect(_on_reaction_toggled)
		section.add_child(toggle)
	return section


func _reaction_state(reaction: ReactionData) -> CardState:
	if hero.level < reaction.unlock_level:
		return CardState.LOCKED
	var learned := Party.get_reaction(hero)
	if learned == null:
		return CardState.AVAILABLE
	return CardState.CHOSEN if learned == reaction else CardState.NOT_CHOSEN


func _make_reaction_card(reaction: ReactionData) -> Control:
	var state := _reaction_state(reaction)
	return _make_card(
		{
			"state": state,
			"tappable": state == CardState.AVAILABLE and Party.can_learn_reaction(hero, reaction),
			"icon": null,
			"title": tr(reaction.display_name),
			"description": tr(reaction.description),
			"info": "%d %s" % [reaction.rage_cost, tr("RES_RAGE")],
			"unlock_level": reaction.unlock_level,
			"chosen_key": "UI_TALENT_LEARNED",
		},
		_ask_confirm.bind(tr(reaction.display_name), Party.learn_reaction.bind(hero, reaction))
	)


# ── Actions ───────────────────────────────────────────────────────────────────


## Forks are permanent, so a pick always goes through the confirm dialog.
func _ask_pick(base: SkillData, fork: String) -> void:
	if not Party.can_pick_fork(hero, base, fork):
		return
	var variant: SkillData = base.fork_a if fork == "a" else base.fork_b
	_ask_confirm(tr(variant.display_name), Party.pick_fork.bind(hero, base, fork))


## Every permanent pick (fork, passive, reaction) goes through this dialog.
## `action` is the Party call that spends the SP, run on Confirm.
func _ask_confirm(title: String, action: Callable) -> void:
	_pending_action = action
	confirm_label.text = tr("UI_TALENT_CONFIRM") % title
	confirm_overlay.visible = true


func _on_confirm_accepted() -> void:
	confirm_overlay.visible = false
	if _pending_action.is_valid() and _pending_action.call():
		GameState.save_game()
	_pending_action = Callable()
	_rebuild()


func _on_confirm_cancelled() -> void:
	confirm_overlay.visible = false
	_pending_action = Callable()


## The reaction's on/off switch: free, and saved at once.
func _on_reaction_toggled(enabled: bool) -> void:
	if Party.set_reaction_enabled(hero, enabled):
		GameState.save_game()


func _on_boost(base: SkillData) -> void:
	if Party.boost_skill(hero, base):
		GameState.save_game()
	_rebuild()


func _on_close() -> void:
	closed.emit()


# ── Helpers ───────────────────────────────────────────────────────────────────


func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## A square icon, or a neutral ColorRect when the skill has none (D-002).
func _make_icon(tex: Texture2D, size: int) -> Control:
	var icon: Control
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon = rect
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.25, 0.25, 0.32)
		icon = bg
	icon.custom_minimum_size = Vector2(size, size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
