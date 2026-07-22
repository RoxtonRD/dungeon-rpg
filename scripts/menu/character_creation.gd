## Character creation (v2 Fase 2). Builds the party for a new game: a freely
## configured main character (name / class / skin) plus 3 companions chosen from
## the premade roster, enforcing at most Party.MAX_PER_CLASS heroes of any one
## class (the main character counts). Reached from the main menu's New Adventure
## flow. Nothing is wiped until the player confirms here — on confirm it builds
## the party, resets meta state and enters the city; Back leaves the save intact.
extends Control

const CITY_SCENE := "res://scripts/city/city_hub.tscn"
const MENU_SCENE := "res://scenes/main.tscn"
const CLASS_DIR := "res://resources/classes/"

## Main-character class order shown in the picker.
const CLASS_IDS: Array[String] = ["warrior", "cleric", "rogue", "mage"]

@onready var name_input: LineEdit = %NameInput
@onready var class_row: GridContainer = %ClassRow
@onready var skin_label: Label = %SkinLabel
@onready var prev_skin_button: Button = %PrevSkinButton
@onready var next_skin_button: Button = %NextSkinButton
@onready var preview_tex: TextureRect = %PreviewTex
@onready var preview_bg: ColorRect = %PreviewBg
@onready var count_label: Label = %CountLabel
@onready var roster_grid: GridContainer = %RosterGrid
@onready var hint_label: Label = %HintLabel
@onready var back_button: Button = %BackButton
@onready var confirm_button: Button = %ConfirmButton

var _mc_class_id: String = CLASS_IDS[0]
var _mc_skin_idx: int = 0
## Selected companion character ids, in pick order (max Party.NUM_COMPANIONS).
var _selected: Array[String] = []

var _roster_buttons: Dictionary = {}   # character_id -> Button


func _ready() -> void:
	SafeArea.apply($VBox)
	Backdrop.apply($Background, "create")
	preview_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_class_buttons()
	_build_roster()
	name_input.text_changed.connect(func(_t): _refresh_validity())
	prev_skin_button.pressed.connect(_on_skin_step.bind(-1))
	next_skin_button.pressed.connect(_on_skin_step.bind(1))
	back_button.pressed.connect(func(): Fade.change_scene(MENU_SCENE))
	confirm_button.pressed.connect(_on_confirm)
	_refresh_mc()
	_refresh_roster()
	_refresh_validity()


# ── Main character ────────────────────────────────────────────────────────────

func _build_class_buttons() -> void:
	var group := ButtonGroup.new()
	for cid in CLASS_IDS:
		var cd := load(CLASS_DIR + "%s.tres" % cid) as ClassData
		var btn := Button.new()
		btn.text = tr(cd.display_name)
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.button_pressed = (cid == _mc_class_id)
		btn.pressed.connect(_on_class_picked.bind(cid))
		class_row.add_child(btn)


func _on_class_picked(cid: String) -> void:
	_mc_class_id = cid
	_mc_skin_idx = 0
	_refresh_mc()
	_refresh_roster()     # the per-class cap for companions counts the MC class
	_refresh_validity()


## Skins available to a class: the default (class id) first, then any extras.
func _class_skins(class_id: String) -> Array:
	var cd := load(CLASS_DIR + "%s.tres" % class_id) as ClassData
	var out: Array = [class_id]
	for s in cd.skins:
		if not out.has(s):
			out.append(s)
	return out


func _on_skin_step(step: int) -> void:
	var skins := _class_skins(_mc_class_id)
	_mc_skin_idx = wrapi(_mc_skin_idx + step, 0, skins.size())
	_refresh_mc()


func _refresh_mc() -> void:
	var skins := _class_skins(_mc_class_id)
	_mc_skin_idx = clampi(_mc_skin_idx, 0, skins.size() - 1)
	skin_label.text = tr("UI_CREATE_SKIN_N") % [_mc_skin_idx + 1, skins.size()]
	var multi := skins.size() > 1
	prev_skin_button.disabled = not multi
	next_skin_button.disabled = not multi
	# Preview through a throwaway Hero so HeroArt resolves the skin (with fallback).
	var cd := load(CLASS_DIR + "%s.tres" % _mc_class_id) as ClassData
	var preview := Hero.create(cd)
	preview.skin_id = skins[_mc_skin_idx]
	var tex := HeroArt.full_body_for(preview)
	if tex != null:
		preview_tex.texture = tex
		preview_tex.visible = true
		preview_bg.visible = false
	else:
		preview_tex.visible = false
		preview_bg.color = BattlerPanel.color_for_class(_mc_class_id)
		preview_bg.visible = true


# ── Companions ────────────────────────────────────────────────────────────────

func _build_roster() -> void:
	for cd in Party.roster():
		var btn := Button.new()
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = "%s\n%s" % [tr(cd.display_name), tr(cd.class_data.display_name)]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_companion_toggled.bind(cd.id))
		roster_grid.add_child(btn)
		_roster_buttons[cd.id] = btn


func _on_companion_toggled(cid: String) -> void:
	if _selected.has(cid):
		_selected.erase(cid)
	else:
		_selected.append(cid)
	_refresh_roster()
	_refresh_validity()


## Class-count map for the proposed party (main character + selected companions).
func _proposed_counts() -> Dictionary:
	var counts := {_mc_class_id: 1}
	for cid in _selected:
		var c: String = Party.character_by_id(cid).class_data.id
		counts[c] = int(counts.get(c, 0)) + 1
	return counts


func _refresh_roster() -> void:
	var counts := _proposed_counts()
	var full := _selected.size() >= Party.NUM_COMPANIONS
	for cid in _roster_buttons:
		var btn: Button = _roster_buttons[cid]
		var selected := _selected.has(cid)
		btn.button_pressed = selected
		if selected:
			btn.disabled = false
			continue
		# Unselected: disable when the party is full, or adding this hero would
		# break the per-class cap (which counts the main character).
		var c: String = Party.character_by_id(cid).class_data.id
		var would_exceed := int(counts.get(c, 0)) + 1 > Party.MAX_PER_CLASS
		btn.disabled = full or would_exceed


# ── Validity ──────────────────────────────────────────────────────────────────

func _refresh_validity() -> void:
	count_label.text = tr("UI_CREATE_COUNT") % _selected.size()
	var name_ok := not name_input.text.strip_edges().is_empty()
	var count_ok := _selected.size() == Party.NUM_COMPANIONS
	var caps_ok := true
	for c in _proposed_counts().values():
		if int(c) > Party.MAX_PER_CLASS:
			caps_ok = false
	if not name_ok:
		hint_label.text = tr("UI_CREATE_HINT_NAME")
	elif not caps_ok:
		hint_label.text = tr("UI_CREATE_HINT_CLASS")
	elif not count_ok:
		hint_label.text = tr("UI_CREATE_HINT_MORE") % (Party.NUM_COMPANIONS - _selected.size())
	else:
		hint_label.text = tr("UI_CREATE_READY")
	confirm_button.disabled = not (name_ok and count_ok and caps_ok)


func _on_confirm() -> void:
	# Guard: the button is only enabled when valid, but re-check before wiping.
	if confirm_button.disabled:
		return
	var skins := _class_skins(_mc_class_id)
	var skin_id: String = skins[clampi(_mc_skin_idx, 0, skins.size() - 1)]
	Party.build_custom_party(_mc_class_id, name_input.text, skin_id, _selected)
	GameState.start_new_game()
	GameState.save_game()
	Fade.change_scene(CITY_SCENE)
