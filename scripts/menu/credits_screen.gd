## Credits screen (v2.0). Static themed layout; returns to the settings screen.
extends Control

const SETTINGS_SCENE := "res://scripts/menu/settings_screen.tscn"

@onready var back_button: Button = %BackButton


func _ready() -> void:
	SafeArea.apply($VBox)
	back_button.pressed.connect(func(): Fade.change_scene(SETTINGS_SCENE))
