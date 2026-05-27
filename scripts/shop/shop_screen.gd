## Fixed-tier v1 shop. Players can buy from a curated catalogue and sell
## any item in the shared inventory at 50% of its buy price.
extends Control

const ITEM_DIR := "res://resources/items/"
const DUNGEON_SCENE := "res://scripts/dungeon/dungeon_map.tscn"

## The v1 shop catalogue — one of each, fixed tier.
const SHOP_ITEMS: Array[String] = [
	# Consumables
	"potion_heal",
	"potion_mana",
	"elixir_full",
	"elixir_revival",
	# Weapons
	"sword_rusty",
	"sword_iron",
	"staff_apprentice",
	"staff_runed",
	"dagger_shadow",
	# Armour
	"armor_cloth",
	"armor_leather",
	"armor_chain",
	# Trinkets
	"ring_might",
	"ring_focus",
	"amulet_swift",
	"amulet_ward",
]

@onready var gold_label: Label = %GoldLabel
@onready var buy_tab_button: Button = %BuyTabButton
@onready var sell_tab_button: Button = %SellTabButton
@onready var item_list_vbox: VBoxContainer = %ItemListVBox
@onready var close_button: Button = %CloseButton

var _mode: String = "buy"   # "buy" | "sell"


func _ready() -> void:
	SafeArea.apply($VBox)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	# Safety net: allows this scene to be run directly for testing.
	if Party.heroes.is_empty():
		Party.start_new_game()
		GameState.start_new_game()
	buy_tab_button.pressed.connect(_on_tab.bind("buy"))
	sell_tab_button.pressed.connect(_on_tab.bind("sell"))
	close_button.pressed.connect(_on_close)
	_refresh()


func _on_tab(mode: String) -> void:
	_mode = mode
	_refresh()


func _refresh() -> void:
	gold_label.text = "Ouro: %d" % GameState.gold
	buy_tab_button.disabled = (_mode == "buy")
	sell_tab_button.disabled = (_mode == "sell")
	if _mode == "buy":
		_rebuild_buy_list()
	else:
		_rebuild_sell_list()


# ── Buy tab ───────────────────────────────────────────────────────────────────

func _rebuild_buy_list() -> void:
	_clear_list()
	for item_id in SHOP_ITEMS:
		var item := load(ITEM_DIR + item_id + ".tres") as ItemData
		if item == null:
			continue
		var row := _make_row()
		row.add_child(_make_icon(item.icon_or_null()))

		var name_lbl := Label.new()
		name_lbl.text = item.display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "%d ✦" % item.value
		price_lbl.custom_minimum_size = Vector2(60, 0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(price_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "Comprar"
		buy_btn.custom_minimum_size = Vector2(100, 0)
		buy_btn.disabled = GameState.gold < item.value
		buy_btn.pressed.connect(_on_buy.bind(item_id, item.value))
		row.add_child(buy_btn)

		_add_entry(row, item.short_description())


func _on_buy(item_id: String, price: int) -> void:
	if GameState.gold < price:
		return
	GameState.gold -= price
	GameState.add_item(item_id)
	_refresh()


# ── Sell tab ──────────────────────────────────────────────────────────────────

func _rebuild_sell_list() -> void:
	_clear_list()
	if GameState.inventory.is_empty():
		var lbl := Label.new()
		lbl.text = "Inventário vazio."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		item_list_vbox.add_child(lbl)
		return

	for idx in GameState.inventory.size():
		var item_id: String = GameState.inventory[idx]
		var item := load(ITEM_DIR + item_id + ".tres") as ItemData
		if item == null:
			continue
		var sell_price: int = maxi(1, item.value / 2)
		var row := _make_row()
		row.add_child(_make_icon(item.icon_or_null()))

		var name_lbl := Label.new()
		name_lbl.text = item.display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "%d ✦" % sell_price
		price_lbl.custom_minimum_size = Vector2(60, 0)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(price_lbl)

		var sell_btn := Button.new()
		sell_btn.text = "Vender"
		sell_btn.custom_minimum_size = Vector2(100, 0)
		sell_btn.pressed.connect(_on_sell.bind(idx))
		row.add_child(sell_btn)

		_add_entry(row, item.short_description())


func _on_sell(inv_idx: int) -> void:
	var item_id: String = GameState.inventory[inv_idx]
	var item := load(ITEM_DIR + item_id + ".tres") as ItemData
	if item == null:
		return
	GameState.gold += maxi(1, item.value / 2)
	GameState.inventory.remove_at(inv_idx)
	_refresh()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _clear_list() -> void:
	for child in item_list_vbox.get_children():
		child.queue_free()


func _make_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 44)
	return row


## Wraps a top row plus an always-visible description line into one list entry.
func _add_entry(top_row: Control, desc: String) -> void:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	entry.add_child(top_row)
	if not desc.is_empty():
		entry.add_child(_make_desc_label(desc))
	item_list_vbox.add_child(entry)


## Returns a square icon Control: a TextureRect when `tex` is non-null, else
## a small neutral ColorRect placeholder. mouse_filter set to IGNORE.
func _make_icon(tex: Texture2D, size: int = 64) -> Control:
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(size, size)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect
	var bg := ColorRect.new()
	bg.color = Color(0.25, 0.25, 0.32)
	bg.custom_minimum_size = Vector2(size, size)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


## Small, dimmed description line shown under an item row.
func _make_desc_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.68, 0.70, 0.78))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _on_close() -> void:
	get_tree().change_scene_to_file(DUNGEON_SCENE)
