## Formation screen. Shows the party split into front / back rows and lets
## the player move heroes between them. Saves on confirm.
## Rule: each row must have at least one hero.
extends Control

const DUNGEON_SCENE := "res://scripts/dungeon/dungeon_map.tscn"

@onready var front_slots: VBoxContainer = %FrontSlots
@onready var back_slots: VBoxContainer = %BackSlots
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	SafeArea.apply($VBox)
	# Safety net: allows this scene to be run directly for testing.
	if Party.heroes.is_empty():
		Party.start_new_game()
		GameState.start_new_game()
	confirm_button.pressed.connect(_on_confirm)
	_refresh()


func _refresh() -> void:
	_clear(front_slots)
	_clear(back_slots)
	for hero in Party.heroes:
		var btn := _make_hero_button(hero)
		if hero.row == 0:   # FRONT
			front_slots.add_child(btn)
		else:               # BACK
			back_slots.add_child(btn)
	# Show placeholder when a column is empty.
	_maybe_add_empty_label(front_slots)
	_maybe_add_empty_label(back_slots)


func _make_hero_button(hero: Hero) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 150)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_hero_pressed.bind(hero))

	# Portrait + text laid over the button. Inner controls ignore the mouse so
	# the whole button stays clickable.
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12
	hbox.offset_right = -12
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	var portrait := _make_portrait(hero)
	hbox.add_child(portrait)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Autowrap so the row indicator never clips, regardless of column width.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row_indicator := "→ Trás" if hero.row == 0 else "→ Frente"
	label.text = "%s\n%d/%d HP\n%s" % [
		hero.class_data.display_name, hero.hp, hero.max_hp(), row_indicator
	]
	hbox.add_child(label)

	return btn


## Builds a square portrait control: the class Texture2D if one is assigned,
## otherwise a colour placeholder tinted per class (shared with combat panels).
func _make_portrait(hero: Hero) -> Control:
	var portrait_size := Vector2(110, 110)
	if hero.class_data.portrait != null:
		var tex := TextureRect.new()
		tex.custom_minimum_size = portrait_size
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture = hero.class_data.portrait
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tex
	var rect := ColorRect.new()
	rect.custom_minimum_size = portrait_size
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.color = BattlerPanel.color_for_class(hero.class_data.id)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _maybe_add_empty_label(container: VBoxContainer) -> void:
	if container.get_child_count() == 0:
		var lbl := Label.new()
		lbl.text = "(vazio)"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(0.5, 0.5, 0.5, 1)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(lbl)


func _on_hero_pressed(hero: Hero) -> void:
	if hero.row == 0:   # FRONT → try to move to BACK
		# Need at least 1 other hero remaining in front.
		var others_in_front := 0
		for h in Party.heroes:
			if h != hero and h.row == 0:
				others_in_front += 1
		if others_in_front == 0:
			return   # Would empty the front row — disallow
		hero.row = 1
	else:              # BACK → try to move to FRONT
		var others_in_back := 0
		for h in Party.heroes:
			if h != hero and h.row == 1:
				others_in_back += 1
		if others_in_back == 0:
			return   # Would empty the back row — disallow
		hero.row = 0
	_refresh()


func _clear(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_confirm() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file(DUNGEON_SCENE)
