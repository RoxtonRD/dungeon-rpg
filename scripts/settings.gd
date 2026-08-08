## Autoload "Settings". Device-level preferences, separate from game saves:
## stored in user://settings.cfg (ConfigFile). Applies the locale at boot,
## before any scene loads.
##
## First launch (no settings.cfg): locale defaults to the system language
## when it is Portuguese or English, otherwise English.
extends Node

const SETTINGS_PATH := "user://settings.cfg"
const LOCALES := ["pt_BR", "en"]
const COMBAT_SPEEDS := [1.0, 1.5, 2.0]

var locale: String = "en"
## Multiplier applied to combat pacing (delays are divided by this).
var combat_speed: float = 1.0


func _ready() -> void:
	_load()
	TranslationServer.set_locale(locale)
	# Drop-in custom font, if one was placed in assets/fonts/ (see UiFont).
	# Done here because this autoload already runs before any scene loads.
	UiFont.apply()


func set_locale(new_locale: String) -> void:
	if not new_locale in LOCALES:
		return
	locale = new_locale
	TranslationServer.set_locale(locale)
	_save()


func set_combat_speed(speed: float) -> void:
	if not speed in COMBAT_SPEEDS:
		return
	combat_speed = speed
	_save()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		# First launch: follow the system language when we support it.
		locale = "pt_BR" if OS.get_locale_language() == "pt" else "en"
		return
	locale = str(cfg.get_value("general", "locale", "en"))
	if not locale in LOCALES:
		locale = "en"
	combat_speed = float(cfg.get_value("general", "combat_speed", 1.0))
	if not combat_speed in COMBAT_SPEEDS:
		combat_speed = 1.0


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", locale)
	cfg.set_value("general", "combat_speed", combat_speed)
	cfg.save(SETTINGS_PATH)
