## Hero art resolver.
##
## A hero's appearance is keyed by skin id (Hero.effective_skin() — the chosen
## skin, or the class id as the default look). This centralizes the image lookups
## that used to be class-keyed, so alternate skins can be added by dropping files
## in, with graceful fallback to the class default (nothing ever renders blank).
## Mirrors the Backdrop loader in scripts/util/backdrop.gd.
##
## Skin art convention (see assets/full_body/README.md):
##   assets/full_body/<skin>.png                   — full-body image (character screen)
##   assets/portraits/heroes/<skin>_portrait.tres  — AtlasTexture crop (combat/formation)
##
## The tint placeholder stays keyed by class via BattlerPanel.color_for_class().
class_name HeroArt
extends RefCounted

const FULL_BODY_DIR := "res://assets/full_body/"
const PORTRAIT_DIR := "res://assets/portraits/heroes/"


## Combat/formation panel portrait: the skin's portrait atlas if present, else the
## class's authored portrait, else null (caller shows a tinted placeholder).
static func portrait_for(hero: Hero) -> Texture2D:
	var path := "%s%s_portrait.tres" % [PORTRAIT_DIR, hero.effective_skin()]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return hero.class_data.portrait


## Character-screen full-body image: the skin's image if present, else the class
## default image, else null (caller shows a tinted placeholder).
static func full_body_for(hero: Hero) -> Texture2D:
	for key in [hero.effective_skin(), hero.class_data.id]:
		var path := "%s%s.png" % [FULL_BODY_DIR, key]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null
