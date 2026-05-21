## The dungeon map screen. Renders the active DungeonRun (from GameState) as
## stacked floors of node buttons, lets the player pick a reachable node, and
## launches combat as a full-screen overlay for COMBAT/BOSS nodes. Non-combat
## nodes are stubbed here — slice (c) adds their treasure/event/rest popups.
extends Control

const COMBAT_SCENE := "res://scripts/combat/combat_screen.tscn"
const MENU_SCENE := "res://scenes/main.tscn"

@onready var title_label: Label = %TitleLabel
@onready var gold_label: Label = %GoldLabel
@onready var party_status: Label = %PartyStatus
@onready var map_area: VBoxContainer = %MapArea
@onready var menu_button: Button = %MenuButton
@onready var end_panel: PanelContainer = %EndPanel
@onready var end_label: Label = %EndLabel
@onready var end_menu_button: Button = %EndMenuButton

var run: DungeonRun
var _pending_node: DungeonNode = null
var _combat_overlay: CombatScreen = null
var _node_buttons: Dictionary = {}


func _ready() -> void:
	menu_button.pressed.connect(_on_menu_pressed)
	end_menu_button.pressed.connect(_on_menu_pressed)
	end_panel.visible = false
	# Defer setup so the scene tree is fully ready before building the map
	# (mirrors CombatScreen, which builds its panels after _ready).
	call_deferred("_begin_run")


func _begin_run() -> void:
	run = GameState.current_run as DungeonRun
	if run == null:
		# Safety net so this scene can be run directly for testing.
		Party.start_new_game()
		GameState.start_new_game()
		run = DungeonRun.generate(1, 3)
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
	match node.kind:
		DungeonNode.NodeType.COMBAT:
			_start_combat(run.roll_encounter(node.floor_index), node)
		DungeonNode.NodeType.BOSS:
			_start_combat(run.roll_boss(), node)
		_:
			# TREASURE / EVENT / REST — slice (c) adds the popups; for now
			# resolve with no effect so the run stays fully traversable.
			_resolve_and_advance(node)


func _start_combat(encounter: Array[EnemyData], node: DungeonNode) -> void:
	_pending_node = node
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


func _resolve_and_advance(node: DungeonNode) -> void:
	run.advance_to(node)
	_pending_node = null
	_refresh()
	if run.is_complete():
		_end_run(true)


func _end_run(victory: bool) -> void:
	GameState.current_run = null
	end_label.text = "Masmorra concluída!" if victory else "O grupo foi derrotado."
	end_panel.visible = true


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
