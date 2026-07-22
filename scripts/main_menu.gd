## Title screen.
## "Continuar" loads the existing save and drops into the city hub.
## "Nova Aventura" (behind a typed confirmation when a save exists) opens
## character creation, which builds the party and starts the fresh game.
extends Control

const CITY_SCENE := "res://scripts/city/city_hub.tscn"
const SETTINGS_SCENE := "res://scripts/menu/settings_screen.tscn"
const CREATE_SCENE := "res://scripts/menu/character_creation.tscn"

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var settings_button: Button = %SettingsButton

# Typed-confirmation modal shown before a new game wipes an existing save.
@onready var reset_confirm: Control = %ResetConfirm
@onready var reset_prompt_label: Label = %PromptLabel
@onready var reset_input: LineEdit = %ResetInput
@onready var reset_confirm_button: Button = %ResetConfirmButton
@onready var reset_cancel_button: Button = %ResetCancelButton


func _ready() -> void:
	SafeArea.apply($CenterContainer)
	Backdrop.apply($Background, "menu")
	continue_button.visible = GameState.has_save()
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(func(): Fade.change_scene(SETTINGS_SCENE))
	reset_input.text_changed.connect(_on_reset_input_changed)
	reset_confirm_button.pressed.connect(_on_reset_confirmed)
	reset_cancel_button.pressed.connect(_on_reset_cancelled)
	reset_confirm.visible = false


func _on_continue_pressed() -> void:
	if GameState.load_game():
		Fade.change_scene(CITY_SCENE)
	else:
		# Corrupt / incompatible save — nothing worth protecting, reset silently.
		_start_new_game()


## A save exists → require the typed confirmation before wiping it. No save →
## nothing to lose, so start fresh immediately.
func _on_new_game_pressed() -> void:
	if GameState.has_save():
		_show_reset_confirm()
	else:
		_start_new_game()


## New adventure → character creation. The party build + meta reset + save all
## happen there on confirm, so the existing save is untouched until the player
## commits (and stays intact if they back out of creation).
func _start_new_game() -> void:
	Fade.change_scene(CREATE_SCENE)


# ── Reset confirmation modal ──────────────────────────────────────────────────

func _show_reset_confirm() -> void:
	# Compose the prompt here (not in _ready) so it always reflects the current
	# locale, even if the language changed since the scene loaded.
	reset_prompt_label.text = tr("UI_RESET_CONFIRM_PROMPT") % tr("UI_RESET_CONFIRM_WORD")
	reset_input.text = ""
	reset_confirm_button.disabled = true
	reset_confirm.visible = true
	reset_input.grab_focus()


## Case-insensitive, whitespace-tolerant match against the localized word.
func _reset_word_matches() -> bool:
	return reset_input.text.strip_edges().to_lower() == tr("UI_RESET_CONFIRM_WORD").to_lower()


func _on_reset_input_changed(_new_text: String) -> void:
	reset_confirm_button.disabled = not _reset_word_matches()


func _on_reset_confirmed() -> void:
	# Guard: the button can only be enabled when the word matches, but re-check
	# so a stray call can never wipe a save without the typed confirmation.
	if not _reset_word_matches():
		return
	_start_new_game()


func _on_reset_cancelled() -> void:
	reset_confirm.visible = false
