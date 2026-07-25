@tool
## The list of skins that need metadata (common + locked skins). Loaded once by
## the Skins autoload. A single resource (not a scanned folder) so it is
## export-safe. Authored at resources/skins/catalog.tres.
class_name SkinCatalog
extends Resource

@export var entries: Array[SkinData] = []
