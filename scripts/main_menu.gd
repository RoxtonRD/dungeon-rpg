## Title screen.
## "Continuar" loads the existing save and drops into the city hub.
## "Nova Aventura" wipes any save and starts fresh in the city; the first
## dungeon is generated when the player enters it from the hub.
extends Control

const CITY_SCENE := "res://scripts/city/city_hub.tscn"
const SETTINGS_SCENE := "res://scripts/menu/settings_screen.tscn"

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var settings_button: Button = %SettingsButton


func _ready() -> void:
	SafeArea.apply($CenterContainer)
	continue_button.visible = GameState.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(func(): Fade.change_scene(SETTINGS_SCENE))


func _on_continue_pressed() -> void:
	if GameState.load_game():
		Fade.change_scene(CITY_SCENE)
	else:
		# Corrupt / incompatible save — fall back to new game.
		_on_new_game_pressed()


func _on_new_game_pressed() -> void:
	Party.start_new_game()
	GameState.start_new_game()
	GameState.save_game()
	Fade.change_scene(CITY_SCENE)
