## Formation screen. Shows the party split into front / back rows and lets
## the player move heroes between them. Saves on confirm.
## Rule: each row must have at least one hero.
extends Control

const DUNGEON_SCENE := "res://scripts/dungeon/dungeon_map.tscn"

@onready var front_slots: VBoxContainer = %FrontSlots
@onready var back_slots: VBoxContainer = %BackSlots
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
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
	btn.custom_minimum_size = Vector2(0, 72)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Two-line label: class name + HP/MP
	var row_indicator := "→ Trás" if hero.row == 0 else "→ Frente"
	btn.text = "%s\n%d/%d HP   %s" % [
		hero.class_data.display_name, hero.hp, hero.max_hp(), row_indicator
	]
	btn.pressed.connect(_on_hero_pressed.bind(hero))
	return btn


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
