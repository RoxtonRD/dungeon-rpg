@tool
## A catalog entry for a hero skin that needs metadata — a common (class-neutral)
## skin, or any skin locked behind an unlock source. Plain free per-class numbered
## skins are drop-in and need no SkinData. Authored in resources/skins/catalog.tres.
class_name SkinData
extends Resource

## How the skin becomes usable.
enum Unlock {
	FREE,   ## available from the start
	GOLD,   ## bought on the Characters screen for `price`
	LEVEL,  ## granted when any hero reaches `level_req`
	EVENT,  ## granted by an in-game event (rare room/boss) via GameState.unlock_skin
}

## Full skin id: "common/<name>" (any class) or "<class>/<n>" (that class only),
## matching the art path under assets/heroes/. Used in save files — never translate.
@export var id: String = ""
## Name shown in the UI — a translation key, not a literal.
@export var display_name: String = ""
@export var unlock: Unlock = Unlock.FREE
## Gold cost when unlock == GOLD.
@export var price: int = 0
## Hero level that grants it when unlock == LEVEL.
@export var level_req: int = 0
