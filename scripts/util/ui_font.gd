## Drop-in custom font support.
##
## The project theme (assets/ui/theme.tres) sets no font, so the game uses
## Godot's built-in one. Drop a font file into assets/fonts/ named `main.ttf`
## (or .otf / .woff2) and it becomes the font everywhere — no scene or theme
## edits. Nothing there = the built-in font, so this never breaks a build.
##
## Applied once at boot by the Settings autoload, before any scene loads.
## Mirrors the Backdrop / HeroArt drop-in convention.
class_name UiFont
extends RefCounted

const FONT_DIR := "res://assets/fonts/"
## Probed in order; the first that exists wins. `main` is the documented name.
const CANDIDATES: Array[String] = [
	"main.ttf",
	"main.otf",
	"main.woff2",
]


## Loads the drop-in font (if any) and installs it as the project theme's
## default. Returns the path used, or "" when no font file is present.
static func apply() -> String:
	var theme_path := str(ProjectSettings.get_setting("gui/theme/custom", ""))
	if theme_path.is_empty():
		return ""
	var theme := load(theme_path) as Theme
	if theme == null:
		return ""
	for name in CANDIDATES:
		var path := FONT_DIR + name
		if not ResourceLoader.exists(path):
			continue
		var font := load(path) as Font
		if font == null:
			continue
		# Mutating the loaded Theme instance is enough: every scene references
		# this same cached resource, so the font applies project-wide.
		theme.default_font = font
		return path
	return ""
