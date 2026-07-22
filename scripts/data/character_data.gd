@tool
## A premade roster character the player can pick as a companion. Bundles a
## default (localizable) name, a class and a starting skin. The main character is
## built freely at creation and has no CharacterData; companions each reference
## one. Authored as .tres assets under res://resources/characters/.
class_name CharacterData
extends Resource

## Stable internal key, e.g. "warrior_aldric". Used in save files — never translate.
@export var id: String = ""
## Default name shown in the UI — a translation key (e.g. "CHAR_ALDRIC"), not a
## literal. The player may override it with a typed name on the Hero.
@export var display_name: String = ""
## The class this character belongs to.
@export var class_data: ClassData
## Starting art skin id. Empty = the class default look.
@export var skin_id: String = ""
