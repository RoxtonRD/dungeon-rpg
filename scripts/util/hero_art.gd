## Hero art resolver.
##
## A hero's appearance is keyed by a numbered skin within its class folder
## (Hero.effective_skin() — the chosen skin number, or "1", the default look).
## This centralizes the image lookups so alternate skins are pure drop-in: add
## the next numbered file and it is discovered automatically, with graceful
## fallback to skin 1 so nothing ever renders blank. Mirrors the Backdrop loader.
##
## Skin art convention (see assets/heroes/README.md), per class folder:
##   assets/heroes/<class>/<n>.png            — full-body image (n = 1, 2, 3 …)
##   assets/heroes/<class>/<n>_portrait.tres  — AtlasTexture head-crop of it
##
## The tint placeholder stays keyed by class via BattlerPanel.color_for_class().
class_name HeroArt
extends RefCounted

const HERO_DIR := "res://assets/heroes/"


## Combat/formation panel portrait: the skin's head-crop if present, else skin 1's,
## else the class's authored portrait (last-ditch), else null (tinted placeholder).
static func portrait_for(hero: Hero) -> Texture2D:
	var dir := HERO_DIR + hero.class_data.id + "/"
	for skin in [hero.effective_skin(), "1"]:
		var path := "%s%s_portrait.tres" % [dir, skin]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return hero.class_data.portrait


## Character-screen full-body image: the skin's image if present, else skin 1's,
## else null (caller shows a tinted placeholder).
static func full_body_for(hero: Hero) -> Texture2D:
	var dir := HERO_DIR + hero.class_data.id + "/"
	for skin in [hero.effective_skin(), "1"]:
		var path := "%s%s.png" % [dir, skin]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null
