## The city hub (v2 Fase 2) — home base between dungeons. Offers the
## Mercado, Personagens, Formação and the dungeon entrance. "Entrar na
## Masmorra" resumes the active run when one exists (app quit mid-run),
## otherwise generates a fresh dungeon at the current dungeon_level.
##
## Background reuses the merchant-stall art as a placeholder until real city
## art exists — drop assets/backgrounds/bg_city.png in and Backdrop.apply()
## (called in _ready) picks it up automatically, no scene edit needed.
extends Control

const DUNGEON_SCENE := "res://scripts/dungeon/dungeon_map.tscn"
const MENU_SCENE := "res://scenes/main.tscn"
const INVENTORY_SCENE := "res://scripts/inventory/inventory_screen.tscn"
const SHOP_SCENE := "res://scripts/shop/shop_screen.tscn"
const FORMATION_SCENE := "res://scripts/formation/formation_screen.tscn"
const CITY_SCENE := "res://scripts/city/city_hub.tscn"

@onready var gold_label: Label = %GoldLabel
@onready var party_status: HBoxContainer = %PartyStatus
@onready var enter_button: Button = %EnterButton
@onready var market_button: Button = %MarketButton
@onready var characters_button: Button = %CharactersButton
@onready var formation_button: Button = %FormationButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	SafeArea.apply($VBox)
	Backdrop.apply($Background, "city")
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	# Safety net: allows this scene to be run directly via F6 for testing.
	if Party.heroes.is_empty():
		Party.start_new_game()
		GameState.start_new_game()
	enter_button.pressed.connect(_on_enter_pressed)
	market_button.pressed.connect(_on_market_pressed)
	characters_button.pressed.connect(_on_characters_pressed)
	formation_button.pressed.connect(_on_formation_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	_refresh()


func _refresh() -> void:
	gold_label.text = tr("UI_GOLD") % GameState.gold
	PartyBar.fill(party_status)
	if GameState.current_run != null:
		enter_button.text = tr("UI_RESUME_DUNGEON") % (GameState.current_run as DungeonRun).level
	else:
		enter_button.text = tr("UI_ENTER_DUNGEON") % GameState.dungeon_level


func _on_enter_pressed() -> void:
	if GameState.current_run == null:
		GameState.current_run = DungeonRun.generate(GameState.dungeon_level)
		GameState.save_game()
	Fade.change_scene(DUNGEON_SCENE)


func _on_market_pressed() -> void:
	Fade.change_scene(SHOP_SCENE)


func _on_characters_pressed() -> void:
	GameState.nav_return_scene = CITY_SCENE
	Fade.change_scene(INVENTORY_SCENE)


func _on_formation_pressed() -> void:
	GameState.nav_return_scene = CITY_SCENE
	Fade.change_scene(FORMATION_SCENE)


func _on_menu_pressed() -> void:
	Fade.change_scene(MENU_SCENE)
