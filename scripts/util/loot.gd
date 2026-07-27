## Depth-scaled loot resolver for combat drops.
##
## Items carry fixed tiers (ItemData.Tier); a single shared pool is grouped by
## tier and drops are weighted by dungeon depth — deeper runs skew toward higher
## tiers. Static util (mirrors HeroArt / Backdrop; no autoload). Export-safe: the
## droppable set is a hardcoded id list, never a directory scan.
class_name Loot
extends RefCounted

const ITEM_DIR := "res://resources/items/"

## Every item a fight may drop. Excludes tome_sp (a boss special) and pure
## starter consumables are welcome to appear. Add new droppable items here.
const DROPPABLE: Array[String] = [
	"sword_rusty", "staff_apprentice", "armor_cloth", "potion_heal", "potion_mana",
	"sword_iron", "armor_leather", "ring_might", "ring_focus", "amulet_swift",
	"elixir_full", "dagger_iron", "robe_silk",
	"sword_steel", "dagger_shadow", "staff_runed", "armor_chain", "amulet_ward",
	"ring_arcane", "elixir_revival", "sword_flame", "ring_vitality",
	"staff_arcane", "armor_plate", "crown_kings",
]

## Common-fight chance to drop one item. FLAG: tune me.
const DROP_CHANCE := 0.35
const NUM_TIERS := 4

## Cached tier → [item ids], built once from DROPPABLE.
static var _by_tier: Array = []


static func _pools() -> Array:
	if _by_tier.is_empty():
		var groups: Array = []
		for i in NUM_TIERS:
			groups.append([])
		for id in DROPPABLE:
			var it := load(ITEM_DIR + id + ".tres") as ItemData
			if it != null:
				groups[int(it.tier)].append(id)
		_by_tier = groups
	return _by_tier


## Tier weights [Common, Uncommon, Rare, Epic] for a normal fight at a given
## dungeon level: common falls off and higher tiers rise with depth.
static func _tier_weights(dungeon_level: int) -> Array:
	var d := float(maxi(0, dungeon_level - 1))
	return [maxf(0.05, 0.70 - 0.10 * d), 0.25 + 0.02 * d, 0.05 + 0.05 * d, 0.03 * d]


## Boss weights — shifted up, never Common, guaranteed to yield something.
static func _boss_weights(dungeon_level: int) -> Array:
	var d := float(maxi(0, dungeon_level - 1))
	return [0.0, maxf(0.10, 0.55 - 0.08 * d), 0.35 + 0.03 * d, 0.10 + 0.05 * d]


## Rolls a finished fight's drops. Boss → 1 guaranteed from the boss pool; a
## common fight → DROP_CHANCE for 1. Returns item ids (may be empty).
static func roll_drops(dungeon_level: int, is_boss: bool) -> Array[String]:
	var out: Array[String] = []
	var id := ""
	if is_boss:
		id = _roll_one(_boss_weights(dungeon_level))
	elif randf() < DROP_CHANCE:
		id = _roll_one(_tier_weights(dungeon_level))
	if id != "":
		out.append(id)
	return out


## Picks a tier by weight, then a random item from it; falls back to the nearest
## non-empty tier (down, then up) so a sparse tier never yields nothing.
static func _roll_one(weights: Array) -> String:
	var pools := _pools()
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return ""
	var r := randf() * total
	var tier := 0
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i])
		if r < acc:
			tier = i
			break
	for t in range(tier, -1, -1):
		if not pools[t].is_empty():
			return pools[t][randi() % pools[t].size()]
	for t in range(tier + 1, pools.size()):
		if not pools[t].is_empty():
			return pools[t][randi() % pools[t].size()]
	return ""
