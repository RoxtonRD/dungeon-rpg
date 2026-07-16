## The dungeon exploration screen (v2 Fase 1). Renders the current floor of
## the active DungeonRun as a grid of room chips with fog of war: explored
## rooms, the player's room, and adjacent-connected rooms are drawn;
## everything else is hidden. Tapping an adjacent connected room moves there
## and triggers its content — combat opens as a full-screen overlay,
## treasure/event/rest reuse the v1 popup overlays, stairs offer the descent.
extends Control

const COMBAT_SCENE := "res://scripts/combat/combat_screen.tscn"
const MENU_SCENE := "res://scenes/main.tscn"
const INVENTORY_SCENE := "res://scripts/inventory/inventory_screen.tscn"
const SHOP_SCENE := "res://scripts/shop/shop_screen.tscn"
const FORMATION_SCENE := "res://scripts/formation/formation_screen.tscn"
const ITEM_DIR := "res://resources/items/"

## Room chip sizing (px at base resolution). Cells shrink to fit wide floors.
const CELL_SIZE := 96
const CELL_GAP := 10

# ── Per-room-type styling. Variation names match the theme.tres definitions.
const ROOM_VARIATION: Dictionary = {
	DungeonRoom.RoomType.COMBAT:   "CombatNodeButton",
	DungeonRoom.RoomType.TREASURE: "TreasureNodeButton",
	DungeonRoom.RoomType.EVENT:    "EventNodeButton",
	DungeonRoom.RoomType.REST:     "RestNodeButton",
	DungeonRoom.RoomType.STAIRS:   "StairsNodeButton",
	DungeonRoom.RoomType.BOSS:     "BossNodeButton",
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
@onready var party_status: HBoxContainer = %PartyStatus
@onready var map_area: Control = %MapArea
@onready var inventory_button: Button = %InventoryButton
@onready var shop_button: Button = %ShopButton
@onready var formation_button: Button = %FormationButton
@onready var menu_button: Button = %MenuButton
@onready var end_panel: PanelContainer = %EndPanel
@onready var end_label: Label = %EndLabel
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

# Stairs popup
@onready var stairs_panel: PanelContainer = %StairsPanel
@onready var stairs_message_label: Label = %StairsMessageLabel
@onready var descend_button: Button = %DescendButton
@onready var stay_button: Button = %StayButton

# Shared themed background shown behind whichever popup is open.
@onready var popup_bg: TextureRect = %PopupBg

var run: DungeonRun
var _combat_overlay: CombatScreen = null
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
	descend_button.pressed.connect(_on_descend_pressed)
	stay_button.pressed.connect(_on_stay_pressed)
	end_panel.visible = false
	treasure_panel.visible = false
	event_panel.visible = false
	rest_panel.visible = false
	stairs_panel.visible = false
	popup_bg.visible = false
	# Rebuild the grid when the map area gets its real size (or resizes).
	map_area.resized.connect(_rebuild_map)
	# Defer setup so the scene tree is fully ready before building the map.
	call_deferred("_begin_run")


func _begin_run() -> void:
	run = GameState.current_run as DungeonRun
	if run == null:
		if Party.heroes.is_empty():
			# Safety net: allows this scene to be run directly via F6 for testing.
			Party.start_new_game()
			GameState.start_new_game()
		# No active run (new game or returned after victory/TPK): generate one
		# at the current dungeon level.
		run = DungeonRun.generate(GameState.dungeon_level)
		GameState.current_run = run
		GameState.save_game()
	_rebuild_map()


# ── Map rendering ─────────────────────────────────────────────────────────────

## Redraws the current floor. The layout is anchored to the bounding box of
## ALL rooms on the floor (stable as fog lifts); only visible rooms render.
func _rebuild_map() -> void:
	if run == null:
		return
	for child in map_area.get_children():
		child.queue_free()
	title_label.text = "Masmorra Nv %d — Andar %d/%d" % [
		run.level, run.current_floor + 1, DungeonRun.NUM_FLOORS]
	gold_label.text = "Ouro: %d" % GameState.gold
	_rebuild_party_bar()

	# Fixed bounding box over the whole floor, so positions don't shift.
	var all_rooms: Array = run.rooms_on_floor().values()
	var min_pos := Vector2i(999, 999)
	var max_pos := Vector2i(-999, -999)
	for room in all_rooms:
		min_pos = Vector2i(mini(min_pos.x, room.pos.x), mini(min_pos.y, room.pos.y))
		max_pos = Vector2i(maxi(max_pos.x, room.pos.x), maxi(max_pos.y, room.pos.y))
	var cols := max_pos.x - min_pos.x + 1
	var rows := max_pos.y - min_pos.y + 1

	# Shrink cells if the floor is wider/taller than the available area.
	var area := map_area.size
	var cell := CELL_SIZE
	if cols > 0 and rows > 0 and area.x > 0 and area.y > 0:
		cell = mini(cell, int((area.x - (cols - 1) * CELL_GAP) / cols))
		cell = mini(cell, int((area.y - (rows - 1) * CELL_GAP) / rows))
		cell = maxi(cell, 48)
	var grid_size := Vector2(
		cols * cell + (cols - 1) * CELL_GAP,
		rows * cell + (rows - 1) * CELL_GAP)
	var origin := (area - grid_size) * 0.5

	for room in run.visible_rooms():
		var btn := Button.new()
		var local := room.pos - min_pos
		btn.position = origin + Vector2(local) * (cell + CELL_GAP)
		btn.size = Vector2(cell, cell)
		btn.text = room.type_name()
		btn.add_theme_font_size_override("font_size", 14)
		btn.theme_type_variation = _variation_for(room)
		# Tappable: adjacent connected rooms (movement) and the current room
		# (re-trigger stairs / an unfinished fight after fleeing).
		btn.disabled = not (run.can_move_to(room.pos) or room.pos == run.player_pos)
		btn.pressed.connect(_on_room_pressed.bind(room.pos))
		map_area.add_child(btn)
		if room.pos == run.player_pos:
			btn.add_child(_make_player_marker())


func _variation_for(room: DungeonRoom) -> String:
	# Consumed content rooms read as plain empty chips; stairs/boss keep
	# their identity. EMPTY rooms use the base button style.
	if room.kind == DungeonRoom.RoomType.EMPTY or \
			(room.cleared and room.kind != DungeonRoom.RoomType.STAIRS \
			and room.kind != DungeonRoom.RoomType.BOSS):
		return ""
	return ROOM_VARIATION.get(room.kind, "")


## Gold border overlay marking the player's room. Mouse-transparent.
func _make_player_marker() -> Control:
	var marker := Panel.new()
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.86, 0.36)
	sb.set_corner_radius_all(5)
	marker.add_theme_stylebox_override("panel", sb)
	return marker


## Builds one compact entry per hero: class name + a red HP bar + HP text.
func _rebuild_party_bar() -> void:
	for child in party_status.get_children():
		child.queue_free()
	for h in Party.heroes:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)

		var name_lbl := Label.new()
		name_lbl.text = h.class_data.display_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		col.add_child(name_lbl)

		var bar := ProgressBar.new()
		bar.theme_type_variation = "HpBar"
		bar.custom_minimum_size = Vector2(0, 10)
		bar.show_percentage = false
		bar.max_value = maxi(1, h.max_hp())
		bar.value = h.hp
		col.add_child(bar)

		var hp_lbl := Label.new()
		hp_lbl.text = "%d/%d" % [h.hp, h.max_hp()]
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.add_theme_font_size_override("font_size", 11)
		hp_lbl.modulate = Color(0.8, 0.8, 0.85)
		col.add_child(hp_lbl)

		party_status.add_child(col)


# ── Movement & room content ───────────────────────────────────────────────────

func _on_room_pressed(pos: Vector2i) -> void:
	if pos == run.player_pos:
		# Re-trigger the room the player is standing on (stairs choice again,
		# or re-engage content after fleeing a fight).
		_trigger_room(run.current_room())
		return
	if not run.can_move_to(pos):
		return
	run.move_to(pos)
	GameState.save_game()
	_rebuild_map()
	_trigger_room(run.current_room())


func _trigger_room(room: DungeonRoom) -> void:
	if room.kind == DungeonRoom.RoomType.STAIRS:
		_show_stairs_popup()
		return
	if not room.has_content():
		return
	match room.kind:
		DungeonRoom.RoomType.COMBAT:
			_start_combat(run.roll_encounter(run.current_floor))
		DungeonRoom.RoomType.BOSS:
			_start_combat(run.roll_boss())
		DungeonRoom.RoomType.TREASURE:
			_show_treasure_popup()
		DungeonRoom.RoomType.EVENT:
			_show_event_popup()
		DungeonRoom.RoomType.REST:
			_show_rest_popup()


## Marks the player's room consumed, persists, and redraws.
func _clear_current_room() -> void:
	run.current_room().cleared = true
	GameState.save_game()
	_rebuild_map()


# ── Combat ────────────────────────────────────────────────────────────────────

func _start_combat(encounter: Array[EnemyData]) -> void:
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
			var was_boss := run.current_room().kind == DungeonRoom.RoomType.BOSS
			_clear_current_room()
			if was_boss:
				_end_run(true)
		CombatState.Result.DEFEAT:
			_end_run(false)
		_:  # FLEE — stay in the room; content remains and can be re-engaged.
			# Persist HP/MP spent in the fled fight (movement saves don't
			# cover damage taken after the last save point).
			GameState.save_game()
			_rebuild_map()


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
	_clear_current_room()


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
	_clear_current_room()


# ── Rest popup ────────────────────────────────────────────────────────────────

func _show_rest_popup() -> void:
	run.resolve_rest()
	popup_bg.texture = BG_REST
	popup_bg.visible = true
	rest_panel.visible = true


func _on_rest_continue() -> void:
	rest_panel.visible = false
	popup_bg.visible = false
	_clear_current_room()


# ── Stairs popup ──────────────────────────────────────────────────────────────

func _show_stairs_popup() -> void:
	stairs_message_label.text = "Descer para o andar %d?" % (run.current_floor + 2)
	stairs_panel.visible = true


func _on_descend_pressed() -> void:
	stairs_panel.visible = false
	run.descend()
	GameState.save_game()
	_rebuild_map()


func _on_stay_pressed() -> void:
	stairs_panel.visible = false


# ── Run end ───────────────────────────────────────────────────────────────────

func _end_run(victory: bool) -> void:
	if victory:
		GameState.dungeon_level += 1
		GameState.current_run = null
		GameState.save_game()
		# Fase 2 will route this to the city hub; the menu stands in for now.
		end_label.text = "Masmorra concluída!\nO grupo retorna à cidade."
	else:
		# TPK rule: revive at 25 % HP, lose 20 % gold, then save and return.
		GameState.apply_tpk_penalty()
		GameState.save_game()
		end_label.text = "O grupo foi derrotado.\nRevividos com 25%% HP.\n20%% do ouro perdido."
	end_panel.visible = true


func _on_inventory_pressed() -> void:
	Fade.change_scene(INVENTORY_SCENE)


func _on_shop_pressed() -> void:
	Fade.change_scene(SHOP_SCENE)


func _on_formation_pressed() -> void:
	Fade.change_scene(FORMATION_SCENE)


func _on_menu_pressed() -> void:
	Fade.change_scene(MENU_SCENE)
