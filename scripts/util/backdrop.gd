## Screen background helper.
##
## Every screen ships with a Background TextureRect whose texture is set in its
## .tscn — often a placeholder borrowed from another screen. Backdrop.apply()
## upgrades that node to the screen's *own* art if the artist has provided it:
## drop a PNG named `bg_<key>.png` into assets/backgrounds/ and it is picked up
## automatically, with no scene or code changes. Until that file exists the
## scene's placeholder texture is left untouched, so no screen ever goes blank.
##
## See assets/backgrounds/README.md for the per-screen key list.
class_name Backdrop
extends RefCounted

const DIR := "res://assets/backgrounds/"


## Sets `bg`'s texture to assets/backgrounds/bg_<key>.png when that file exists;
## otherwise leaves the node as-is so its placeholder texture shows through.
static func apply(bg: TextureRect, key: String) -> void:
	if bg == null:
		return
	var path := "%sbg_%s.png" % [DIR, key]
	if ResourceLoader.exists(path):
		bg.texture = load(path) as Texture2D
