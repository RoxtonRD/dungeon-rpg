## Hero art resolver.
##
## A hero's appearance is keyed by a numbered skin within its class folder
## (Hero.effective_skin() — the chosen skin number, or "1", the default look).
## This centralizes the image lookups so alternate skins are pure drop-in: add
## the next numbered file and it is discovered automatically, with graceful
## fallback to skin 1 so nothing ever renders blank. Mirrors the Backdrop loader.
##
## Skin art convention (see assets/heroes/README.md):
##   assets/heroes/<class>/<n>.png            — per-class skin (n = 1, 2, 3 …)
##   assets/heroes/<class>/<n>_portrait.tres  — its AtlasTexture head-crop
##   assets/heroes/common/<name>.png          — class-neutral common skin
##   assets/heroes/common/<name>_portrait.tres
##
## A skin id is a bare number ("2", per-class) or "common/<name>" (any class);
## both map straight to a path under assets/heroes/. The tint placeholder stays
## keyed by class via BattlerPanel.color_for_class().
class_name HeroArt
extends RefCounted

const HERO_DIR := "res://assets/heroes/"


## Resolves a skin id to its art subpath. A bare number is class-relative
## ("<class>/<n>"); a "common/…" id is used as-is.
static func _subpath(hero: Hero, skin: String) -> String:
	return skin if skin.begins_with("common/") else "%s/%s" % [hero.class_data.id, skin]


## Combat/formation panel portrait: the skin's head-crop if present, else skin 1's,
## else the class's authored portrait (last-ditch), else null (tinted placeholder).
static func portrait_for(hero: Hero) -> Texture2D:
	for skin in [hero.effective_skin(), "1"]:
		var path := "%s%s_portrait.tres" % [HERO_DIR, _subpath(hero, skin)]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return hero.class_data.portrait


## Character-screen full-body image: the skin's image if present, else skin 1's,
## else null (caller shows a tinted placeholder).
static func full_body_for(hero: Hero) -> Texture2D:
	for skin in [hero.effective_skin(), "1"]:
		var path := "%s%s.png" % [HERO_DIR, _subpath(hero, skin)]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null
