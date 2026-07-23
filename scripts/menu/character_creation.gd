## Character creation (v2 Fase 2). Builds the party for a new game: the player
## configures all four heroes (name / class / skin), one slot at a time, with at
## most Party.MAX_PER_CLASS heroes of any one class. Reached from the main menu's
## New Adventure flow. Nothing is wiped until Begin — on confirm it builds the
## party, resets meta state and enters the city; Back leaves the save intact.
extends Control

const CITY_SCENE := "res://scripts/city/city_hub.tscn"
const MENU_SCENE := "res://scenes/main.tscn"
const CLASS_DIR := "res://resources/classes/"

## Class order shown in the picker.
const CLASS_IDS: Array[String] = ["warrior", "cleric", "rogue", "mage"]

@onready var slot_tabs: HBoxContainer = %SlotTabs
@onready var name_input: LineEdit = %NameInput
@onready var class_row: GridContainer = %ClassRow
@onready var skin_label: Label = %SkinLabel
@onready var prev_skin_button: Button = %PrevSkinButton
@onready var next_skin_button: Button = %NextSkinButton
@onready var preview_tex: TextureRect = %PreviewTex
@onready var preview_bg: ColorRect = %PreviewBg
@onready var hint_label: Label = %HintLabel
@onready var back_button: Button = %BackButton
@onready var confirm_button: Button = %ConfirmButton

# One entry per hero slot (0..PARTY_SIZE-1). Default classes are one-of-each so
# the starting party is already valid; names start empty.
var _names: Array[String] = ["", "", "", ""]
var _class_ids: Array[String] = ["warrior", "cleric", "rogue", "mage"]
var _skin_idx: Array[int] = [0, 0, 0, 0]
var _slot: int = 0

var _slot_buttons: Array[Button] = []
var _class_buttons: Dictionary = {}   # class_id -> Button


func _ready() -> void:
	SafeArea.apply($VBox)
	Backdrop.apply($Background, "create")
	preview_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_slot_tabs()
	_build_class_buttons()
	name_input.text_changed.connect(_on_name_changed)
	prev_skin_button.pressed.connect(_on_skin_step.bind(-1))
	next_skin_button.pressed.connect(_on_skin_step.bind(1))
	back_button.pressed.connect(func(): Fade.change_scene(MENU_SCENE))
	confirm_button.pressed.connect(_on_confirm)
	_select_slot(0)
	_refresh_validity()


# ── Slots ─────────────────────────────────────────────────────────────────────

func _build_slot_tabs() -> void:
	var group := ButtonGroup.new()
	for i in Party.PARTY_SIZE:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_text = true
		btn.pressed.connect(_select_slot.bind(i))
		slot_tabs.add_child(btn)
		_slot_buttons.append(btn)


## Tab caption: the hero's name, or "Hero N" until one is typed.
func _slot_title(i: int) -> String:
	var n := _names[i].strip_edges()
	return n if not n.is_empty() else tr("UI_CREATE_HERO_N") % (i + 1)


func _select_slot(i: int) -> void:
	_slot = i
	_slot_buttons[i].button_pressed = true
	name_input.text = _names[i]
	_refresh_editor()


# ── Editor (class / skin / preview for the current slot) ──────────────────────

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
		btn.pressed.connect(_on_class_picked.bind(cid))
		class_row.add_child(btn)
		_class_buttons[cid] = btn


func _on_class_picked(cid: String) -> void:
	_class_ids[_slot] = cid
	_skin_idx[_slot] = 0
	_refresh_editor()
	_refresh_validity()


func _class_skins(class_id: String) -> Array:
	return (load(CLASS_DIR + "%s.tres" % class_id) as ClassData).all_skins()


func _on_skin_step(step: int) -> void:
	var skins := _class_skins(_class_ids[_slot])
	_skin_idx[_slot] = wrapi(_skin_idx[_slot] + step, 0, skins.size())
	_refresh_editor()


## Class counts across every slot except `except_slot`.
func _class_counts_excluding(except_slot: int) -> Dictionary:
	var counts := {}
	for i in Party.PARTY_SIZE:
		if i == except_slot:
			continue
		var c := _class_ids[i]
		counts[c] = int(counts.get(c, 0)) + 1
	return counts


func _refresh_editor() -> void:
	# Class buttons reflect this slot's class; a class the OTHER three slots
	# already fill to the cap is locked (the current class is never locked).
	var others := _class_counts_excluding(_slot)
	for cid in _class_buttons:
		var btn: Button = _class_buttons[cid]
		btn.button_pressed = (cid == _class_ids[_slot])
		btn.disabled = cid != _class_ids[_slot] and int(others.get(cid, 0)) >= Party.MAX_PER_CLASS
	# Skin cycler.
	var skins := _class_skins(_class_ids[_slot])
	_skin_idx[_slot] = clampi(_skin_idx[_slot], 0, skins.size() - 1)
	skin_label.text = tr("UI_CREATE_SKIN_N") % [_skin_idx[_slot] + 1, skins.size()]
	var multi := skins.size() > 1
	prev_skin_button.disabled = not multi
	next_skin_button.disabled = not multi
	# Preview through a throwaway Hero so HeroArt resolves the skin (with fallback).
	var cd := load(CLASS_DIR + "%s.tres" % _class_ids[_slot]) as ClassData
	var preview := Hero.create(cd)
	preview.skin_id = skins[_skin_idx[_slot]]
	var tex := HeroArt.full_body_for(preview)
	if tex != null:
		preview_tex.texture = tex
		preview_tex.visible = true
		preview_bg.visible = false
	else:
		preview_tex.visible = false
		preview_bg.color = BattlerPanel.color_for_class(_class_ids[_slot])
		preview_bg.visible = true
	# Keep every tab caption in sync (class change can shift a name-less label).
	for i in Party.PARTY_SIZE:
		_slot_buttons[i].text = _slot_title(i)


func _on_name_changed(new_text: String) -> void:
	_names[_slot] = new_text
	_slot_buttons[_slot].text = _slot_title(_slot)
	_refresh_validity()


# ── Validity ──────────────────────────────────────────────────────────────────

func _refresh_validity() -> void:
	var all_named := true
	for n in _names:
		if n.strip_edges().is_empty():
			all_named = false
	var caps_ok := true
	var counts := {}
	for c in _class_ids:
		counts[c] = int(counts.get(c, 0)) + 1
		if int(counts[c]) > Party.MAX_PER_CLASS:
			caps_ok = false
	if not all_named:
		hint_label.text = tr("UI_CREATE_HINT_NAME")
	elif not caps_ok:
		hint_label.text = tr("UI_CREATE_HINT_CLASS")
	else:
		hint_label.text = tr("UI_CREATE_READY")
	confirm_button.disabled = not (all_named and caps_ok)


func _on_confirm() -> void:
	# Guard: the button is only enabled when valid, but re-check before wiping.
	if confirm_button.disabled:
		return
	var specs: Array = []
	for i in Party.PARTY_SIZE:
		var skins := _class_skins(_class_ids[i])
		specs.append({
			"name": _names[i],
			"class_id": _class_ids[i],
			"skin_id": skins[clampi(_skin_idx[i], 0, skins.size() - 1)],
		})
	Party.build_party(specs)
	GameState.start_new_game()
	GameState.save_game()
	Fade.change_scene(CITY_SCENE)
