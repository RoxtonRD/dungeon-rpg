## The debug cheat panel (D-015): a small corner button that shows or hides
## a panel of DevTools actions, on a high CanvasLayer so it sits over every
## screen. Created by the DevTools autoload in debug builds only. Every
## button calls the DevTools API and shows the returned message.
##
## Dev-only UI, so English-only hardcoded text is allowed here (D-015).
extends CanvasLayer

## Minimum height of every touch control, so it is usable with a thumb.
const TOUCH_HEIGHT := 64
## Extra vertical gap between dropdown entries (the default rows are ~27 px).
const POPUP_ROW_GAP := 32

## Enemy ids queued for the next fight.
var _queue: Array[String] = []

@onready var toggle_button: Button = %ToggleButton
@onready var panel: PanelContainer = %Panel
@onready var output_label: Label = %Output
@onready var classes_edit: LineEdit = %ClassesEdit
@onready var level_option: OptionButton = %LevelOption
@onready var item_option: OptionButton = %ItemOption
@onready var dungeon_option: OptionButton = %DungeonOption
@onready var enemy_option: OptionButton = %EnemyOption
@onready var queue_label: Label = %QueueLabel
@onready var floor_buttons: HBoxContainer = %FloorButtons


func _ready() -> void:
	panel.visible = false
	for i in Party.LEVEL_CAP:
		level_option.add_item(str(i + 1))
	for i in 5:
		dungeon_option.add_item(str(i + 1))
	for id in DevTools.list_items():
		item_option.add_item(id)
	for id in DevTools.list_enemies():
		enemy_option.add_item(id)
	_make_thumb_sized(panel)

	toggle_button.pressed.connect(_on_toggle_pressed)
	%CloseButton.pressed.connect(_on_toggle_pressed)
	%QuickPartyButton.pressed.connect(_on_quick_party_pressed)
	%SetLevelButton.pressed.connect(func(): _show(DevTools.set_level(_level())))
	%HealButton.pressed.connect(func(): _show(DevTools.heal_party()))
	%Gold100Button.pressed.connect(func(): _show(DevTools.add_gold(100)))
	%Gold1000Button.pressed.connect(func(): _show(DevTools.add_gold(1000)))
	%AddItem1Button.pressed.connect(_on_add_item_pressed.bind(1))
	%AddItem5Button.pressed.connect(_on_add_item_pressed.bind(5))
	%StartRunButton.pressed.connect(_on_start_run_pressed)
	%RevealButton.pressed.connect(func(): _show(DevTools.reveal_floor()))
	for i in floor_buttons.get_child_count():
		(floor_buttons.get_child(i) as Button).pressed.connect(_on_floor_pressed.bind(i + 1))
	%AddEnemyButton.pressed.connect(_on_add_enemy_pressed)
	%ClearQueueButton.pressed.connect(_on_clear_queue_pressed)
	%FightButton.pressed.connect(_on_fight_pressed)
	_refresh_queue()


## Gives every button and input under `node` a thumb-sized minimum height,
## and spaces out dropdown lists so each entry is a thumb-sized target.
func _make_thumb_sized(node: Node) -> void:
	for child in node.get_children():
		if child is Button or child is LineEdit:
			var c := child as Control
			c.custom_minimum_size.y = maxf(c.custom_minimum_size.y, TOUCH_HEIGHT)
		if child is OptionButton:
			var option := child as OptionButton
			option.get_popup().add_theme_constant_override("v_separation", POPUP_ROW_GAP)
			# Open on release: a long list is drawn over the button, and opening
			# on press let the same tap's release pick whatever row was under it.
			option.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		_make_thumb_sized(child)


func _show(message: String) -> void:
	output_label.text = message
	print("[DevTools] ", message)


func _level() -> int:
	return level_option.selected + 1


func _on_toggle_pressed() -> void:
	panel.visible = not panel.visible


func _on_quick_party_pressed() -> void:
	var ids: Array = []
	for part in classes_edit.text.split(",", false):
		ids.append(part.strip_edges())
	_show(DevTools.quick_party(ids, _level()))


func _on_add_item_pressed(qty: int) -> void:
	if item_option.selected < 0:
		return
	_show(DevTools.add_item(item_option.get_item_text(item_option.selected), qty))


func _on_start_run_pressed() -> void:
	_show(DevTools.start_run(dungeon_option.selected + 1))


func _on_floor_pressed(n: int) -> void:
	_show(DevTools.goto_floor(n))


func _on_add_enemy_pressed() -> void:
	if enemy_option.selected < 0 or _queue.size() >= DevTools.MAX_ENEMIES:
		return
	_queue.append(enemy_option.get_item_text(enemy_option.selected))
	_refresh_queue()


func _on_clear_queue_pressed() -> void:
	_queue.clear()
	_refresh_queue()


## Fights the queued enemies, or just the picked one if the queue is empty.
## Closes the panel on success so the fight is visible.
func _on_fight_pressed() -> void:
	var ids: Array = _queue.duplicate()
	if ids.is_empty() and enemy_option.selected >= 0:
		ids.append(enemy_option.get_item_text(enemy_option.selected))
	var message := DevTools.start_fight(ids)
	_show(message)
	if not message.begins_with("Error"):
		panel.visible = false


func _refresh_queue() -> void:
	if _queue.is_empty():
		queue_label.text = "Queue: empty (Fight uses the picked enemy)"
	else:
		queue_label.text = "Queue: " + ", ".join(_queue)
