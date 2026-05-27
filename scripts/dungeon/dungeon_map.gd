## The dungeon map screen. Renders the active DungeonRun (from GameState) as
## stacked floors of node buttons, lets the player pick a reachable node, and
## launches combat as a full-screen overlay for COMBAT/BOSS nodes.
## Treasure/Event/Rest nodes show inline popup overlays.
extends Control

const COMBAT_SCENE := "res://scripts/combat/combat_screen.tscn"
const MENU_SCENE := "res://scenes/main.tscn"
const INVENTORY_SCENE := "res://scripts/inventory/inventory_screen.tscn"
const SHOP_SCENE := "res://scripts/shop/shop_screen.tscn"
const FORMATION_SCENE := "res://scripts/formation/formation_screen.tscn"
const ITEM_DIR := "res://resources/items/"

# ── Per-node-type styling. Variation names match the theme.tres definitions.
const NODE_VARIATION: Dictionary = {
	DungeonNode.NodeType.COMBAT:   "CombatNodeButton",
	DungeonNode.NodeType.TREASURE: "TreasureNodeButton",
	DungeonNode.NodeType.EVENT:    "EventNodeButton",
	DungeonNode.NodeType.REST:     "RestNodeButton",
	DungeonNode.NodeType.BOSS:     "BossNodeButton",
}
# ── Popup backgrounds (treasure / rest / event). ──────────────────────────────
const BG_TREASURE: Texture2D = preload("res://assets/backgrounds/bg_treasure.png")
const BG_REST: Texture2D = preload("res://assets/backgrounds/bg_rest.png")
## Event id → background. Keys match the "id" field set in DungeonRun events.
const EVENT_BG: Dictionary = {
	"fountain": preload("res://assets/backgrounds/bg_event_fountain.png"),
	"merchant": preload("res://assets/backgrounds/bg_event_merchant.png"),
	"altar":    preload("res://assets/backgrounds/bg_event_altar.png"),
	"chest":    preload("res://assets/backgrounds/bg_event_chest.png"),
}

@onready var title_label: Label = %TitleLabel
@onready var gold_label: Label = %GoldLabel
@onready var party_status: Label = %PartyStatus
@onready var map_area: VBoxContainer = %MapArea
@onready var inventory_button: Button = %InventoryButton
@onready var shop_button: Button = %ShopButton
@onready var formation_button: Button = %FormationButton
@onready var menu_button: Button = %MenuButton
@onready var end_panel: PanelContainer = %EndPanel
@onready var end_label: Label = %EndLabel
@onready var end_next_button: Button = %EndNextButton
@onready var end_menu_button: Button = %EndMenuButton

# Treasure popup
@onready var treasure_panel: PanelContainer = %TreasurePanel
@onready var treasure_gold_label: Label = %TreasureGoldLabel
@onready var treasure_item_label: Label = %TreasureItemLabel
@onready var treasure_continue_button: Button = %TreasureContinueButton

# Event popup
@onready var event_panel: PanelContainer = %EventPanel
@onready var event_title_label: Label = %EventTitleLabel
@onready var event_desc_label: Label = %EventDescLabel
@onready var event_option1_button: Button = %EventOption1Button
@onready var event_option2_button: Button = %EventOption2Button
@onready var event_result_label: Label = %EventResultLabel
@onready var event_continue_button: Button = %EventContinueButton

# Rest popup
@onready var rest_panel: PanelContainer = %RestPanel
@onready var rest_continue_button: Button = %RestContinueButton

# Shared themed background shown behind whichever popup is open.
@onready var popup_bg: TextureRect = %PopupBg

var run: DungeonRun
var _pending_node: DungeonNode = null
var _combat_overlay: CombatScreen = null
var _node_buttons: Dictionary = {}
var _current_event: Dictionary = {}


func _ready() -> void:
	SafeArea.apply($VBox)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	inventory_button.pressed.connect(_on_inventory_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	formation_button.pressed.connect(_on_formation_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	end_menu_button.pressed.connect(_on_menu_pressed)
	treasure_continue_button.pressed.connect(_on_treasure_continue)
	event_option1_button.pressed.connect(_on_event_option.bind(0))
	event_option2_button.pressed.connect(_on_event_option.bind(1))
	event_continue_button.pressed.connect(_on_event_continue)
	rest_continue_button.pressed.connect(_on_rest_continue)
	end_next_button.pressed.connect(_on_next_dungeon_pressed)
	end_panel.visible = false
	treasure_panel.visible = false
	event_panel.visible = false
	rest_panel.visible = false
	popup_bg.visible = false
	# Defer setup so the scene tree is fully ready before building the map.
	call_deferred("_begin_run")


func _begin_run() -> void:
	run = GameState.current_run as DungeonRun
	if run == null:
		if Party.heroes.is_empty():
			# Safety net: allows this scene to be run directly via F6 for testing.
			Party.start_new_game()
			GameState.start_new_game()
		# No active run (new game or returned from menu after victory/TPK):
		# generate one at the current dungeon level.
		run = DungeonRun.generate(GameState.dungeon_level, 3)
		GameState.current_run = run
	_build_map()
	_refresh()


func _build_map() -> void:
	for child in map_area.get_children():
		child.queue_free()
	_node_buttons.clear()
	for f in run.floors.size():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		map_area.add_child(row)
		for node in run.floors[f]:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(150, 70)
			btn.theme_type_variation = NODE_VARIATION.get(node.kind, "")
			btn.pressed.connect(_on_node_pressed.bind(node))
			row.add_child(btn)
			_node_buttons[node] = btn


func _refresh() -> void:
	title_label.text = "Masmorra — Nível %d" % run.level
	gold_label.text = "Ouro: %d" % GameState.gold
	party_status.text = _party_summary()
	var reachable_floor := run.current_floor + 1
	for node in _node_buttons:
		var btn: Button = _node_buttons[node]
		var label: String = node.type_name()
		if node.visited:
			label = "✓ " + label
		btn.text = label
		btn.disabled = node.floor_index != reachable_floor


func _party_summary() -> String:
	var s := ""
	for h in Party.heroes:
		if not s.is_empty():
			s += "    "
		s += "%s %d/%d" % [h.class_data.display_name, h.hp, h.max_hp()]
	return s


func _on_node_pressed(node: DungeonNode) -> void:
	if node.floor_index != run.current_floor + 1:
		return
	_pending_node = node
	match node.kind:
		DungeonNode.NodeType.COMBAT:
			_start_combat(run.roll_encounter(node.floor_index), node)
		DungeonNode.NodeType.BOSS:
			_start_combat(run.roll_boss(), node)
		DungeonNode.NodeType.TREASURE:
			_show_treasure_popup()
		DungeonNode.NodeType.EVENT:
			_show_event_popup()
		DungeonNode.NodeType.REST:
			_show_rest_popup()


# ── Combat ────────────────────────────────────────────────────────────────────

func _start_combat(encounter: Array[EnemyData], node: DungeonNode) -> void:
	var scene := load(COMBAT_SCENE) as PackedScene
	_combat_overlay = scene.instantiate() as CombatScreen
	add_child(_combat_overlay)
	_combat_overlay.combat_finished.connect(_on_combat_finished)
	_combat_overlay.setup(Party.heroes, encounter)


func _on_combat_finished(result: int) -> void:
	if _combat_overlay != null:
		_combat_overlay.queue_free()
		_combat_overlay = null
	match result:
		CombatState.Result.VICTORY:
			_resolve_and_advance(_pending_node)
		CombatState.Result.DEFEAT:
			_end_run(false)
		_:  # FLEE — return to the map without advancing
			_pending_node = null
			_refresh()


# ── Treasure popup ────────────────────────────────────────────────────────────

func _show_treasure_popup() -> void:
	var result: Dictionary = run.resolve_treasure()
	treasure_gold_label.text = "Você ganhou %d ouro!" % result["gold"]
	var items: Array = result["items"]
	if items.is_empty():
		treasure_item_label.visible = false
	else:
		var item_id: String = items[0]
		var item := load(ITEM_DIR + item_id + ".tres") as ItemData
		var item_name: String = item.display_name if item != null else item_id
		treasure_item_label.text = "Item encontrado: %s" % item_name
		treasure_item_label.visible = true
	popup_bg.texture = BG_TREASURE
	popup_bg.visible = true
	treasure_panel.visible = true


func _on_treasure_continue() -> void:
	treasure_panel.visible = false
	popup_bg.visible = false
	_resolve_and_advance(_pending_node)


# ── Event popup ───────────────────────────────────────────────────────────────

func _show_event_popup() -> void:
	_current_event = run.roll_event()
	event_title_label.text = _current_event["title"]
	event_desc_label.text = _current_event["desc"]
	var options: Array = _current_event["options"]
	_setup_event_button(event_option1_button, options[0])
	_setup_event_button(event_option2_button, options[1])
	event_result_label.visible = false
	event_continue_button.visible = false
	event_option1_button.visible = true
	event_option2_button.visible = true
	popup_bg.texture = EVENT_BG.get(_current_event.get("id", ""), null)
	popup_bg.visible = popup_bg.texture != null
	event_panel.visible = true


func _setup_event_button(btn: Button, option: Dictionary) -> void:
	btn.text = option["text"]
	btn.disabled = not option["available"]


func _on_event_option(index: int) -> void:
	var options: Array = _current_event["options"]
	var effect: Callable = options[index]["effect"]
	event_result_label.text = effect.call()
	event_result_label.visible = true
	event_option1_button.visible = false
	event_option2_button.visible = false
	event_continue_button.visible = true


func _on_event_continue() -> void:
	event_panel.visible = false
	popup_bg.visible = false
	_resolve_and_advance(_pending_node)


# ── Rest popup ────────────────────────────────────────────────────────────────

func _show_rest_popup() -> void:
	run.resolve_rest()
	popup_bg.texture = BG_REST
	popup_bg.visible = true
	rest_panel.visible = true


func _on_rest_continue() -> void:
	rest_panel.visible = false
	popup_bg.visible = false
	_resolve_and_advance(_pending_node)


# ── Common ────────────────────────────────────────────────────────────────────

func _resolve_and_advance(node: DungeonNode) -> void:
	run.advance_to(node)
	_pending_node = null
	_refresh()
	if run.is_complete():
		_end_run(true)
	else:
		GameState.save_game()


func _end_run(victory: bool) -> void:
	if victory:
		GameState.dungeon_level += 1
		GameState.current_run = null
		GameState.save_game()
		end_label.text = "Masmorra concluída!"
		end_next_button.visible = true
	else:
		# TPK rule: revive at 25 % HP, lose 20 % gold, then save and return.
		GameState.apply_tpk_penalty()
		GameState.save_game()
		end_label.text = "O grupo foi derrotado.\nRevividos com 25%% HP.\n20%% do ouro perdido."
		end_next_button.visible = false
	end_panel.visible = true


func _on_next_dungeon_pressed() -> void:
	run = DungeonRun.generate(GameState.dungeon_level, 3)
	GameState.current_run = run
	GameState.save_game()
	end_panel.visible = false
	_build_map()
	_refresh()


func _on_inventory_pressed() -> void:
	get_tree().change_scene_to_file(INVENTORY_SCENE)


func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file(SHOP_SCENE)


func _on_formation_pressed() -> void:
	get_tree().change_scene_to_file(FORMATION_SCENE)


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
