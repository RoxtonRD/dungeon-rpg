## Title screen.
## "Continuar" loads the existing save and drops straight into the dungeon map.
## "Nova Aventura" wipes any save, starts fresh, generates a level-1 dungeon.
extends Control

const DUNGEON_SCENE := "res://scripts/dungeon/dungeon_map.tscn"

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton


func _ready() -> void:
	SafeArea.apply($CenterContainer)
	continue_button.visible = GameState.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)


func _on_continue_pressed() -> void:
	if GameState.load_game():
		Fade.change_scene(DUNGEON_SCENE)
	else:
		# Corrupt / incompatible save — fall back to new game.
		_on_new_game_pressed()


func _on_new_game_pressed() -> void:
	Party.start_new_game()
	GameState.start_new_game()
	GameState.current_run = DungeonRun.generate(1)
	GameState.save_game()
	Fade.change_scene(DUNGEON_SCENE)
