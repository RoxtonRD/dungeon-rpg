## Settings screen (v2.0). Device-level options persisted in settings.cfg via
## the Settings autoload: interface language (applies immediately) and combat
## speed. Reached from the main menu; links onward to the credits screen.
extends Control

const MENU_SCENE := "res://scenes/main.tscn"
const CREDITS_SCENE := "res://scripts/menu/credits_screen.tscn"

@onready var lang_pt_button: Button = %LangPtButton
@onready var lang_en_button: Button = %LangEnButton
@onready var speed1_button: Button = %Speed1Button
@onready var speed15_button: Button = %Speed15Button
@onready var speed2_button: Button = %Speed2Button
@onready var credits_button: Button = %CreditsButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	SafeArea.apply($VBox)
	# Language toggles form a radio group; same for combat speed.
	var lang_group := ButtonGroup.new()
	lang_pt_button.button_group = lang_group
	lang_en_button.button_group = lang_group
	var speed_group := ButtonGroup.new()
	speed1_button.button_group = speed_group
	speed15_button.button_group = speed_group
	speed2_button.button_group = speed_group

	lang_pt_button.pressed.connect(_on_language.bind("pt_BR"))
	lang_en_button.pressed.connect(_on_language.bind("en"))
	speed1_button.pressed.connect(_on_speed.bind(1.0))
	speed15_button.pressed.connect(_on_speed.bind(1.5))
	speed2_button.pressed.connect(_on_speed.bind(2.0))
	credits_button.pressed.connect(func(): Fade.change_scene(CREDITS_SCENE))
	back_button.pressed.connect(func(): Fade.change_scene(MENU_SCENE))

	_reflect_state()


## Marks the buttons that match the currently-saved settings as pressed.
func _reflect_state() -> void:
	lang_pt_button.button_pressed = Settings.locale == "pt_BR"
	lang_en_button.button_pressed = Settings.locale == "en"
	speed1_button.button_pressed = is_equal_approx(Settings.combat_speed, 1.0)
	speed15_button.button_pressed = is_equal_approx(Settings.combat_speed, 1.5)
	speed2_button.button_pressed = is_equal_approx(Settings.combat_speed, 2.0)


func _on_language(locale: String) -> void:
	Settings.set_locale(locale)
	# Auto-translated Controls refresh on the locale change automatically;
	# nothing else on this screen needs manual re-text.


func _on_speed(speed: float) -> void:
	Settings.set_combat_speed(speed)
