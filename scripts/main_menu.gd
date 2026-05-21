## Title screen. "Nova Aventura" starts a fresh game and drops the party into
## a freshly generated level-1 dungeon.
extends Control

const DUNGEON_SCENE := "res://scripts/dungeon/dungeon_map.tscn"

@onready var new_game_button: Button = %NewGameButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)


func _on_new_game_pressed() -> void:
	Party.start_new_game()
	GameState.start_new_game()
	GameState.current_run = DungeonRun.generate(1, 3)
	get_tree().change_scene_to_file(DUNGEON_SCENE)
