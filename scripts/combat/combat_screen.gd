## Portrait combat screen. Owns a CombatState and reflects it through
## BattlerPanels, a skill bar, an action log and an end-of-combat panel.
## Pacing is driven by `_process_turn`, which steps enemy actions one at
## a time with a brief delay so the player can read each event.
##
## When run directly via F6, the scene bootstraps a default test party
## (Party.start_new_game) plus three weak enemies. Step 5 (dungeon flow)
## will instantiate the scene and call `setup()` with the real party and
## encounter before _ready fires (use call_deferred or set state first).
class_name CombatScreen
extends Control

## Emitted when the player dismisses the end panel. Carries the
## CombatState.Result int so a host scene (the dungeon map) can react.
signal combat_finished(result: int)

const TEST_ENEMY_PATHS: Array[String] = [
	"res://resources/enemies/goblin.tres",
	"res://resources/enemies/wolf.tres",
	"res://resources/enemies/bat.tres",
]

## Delay between consecutive enemy actions, in seconds.
const ENEMY_TURN_DELAY: float = 0.6
## Delay after a turn begins before processing it (lets the highlight register).
const TURN_LEAD_DELAY: float = 0.25

@onready var enemy_row: HBoxContainer = %EnemyRow
@onready var party_row: HBoxContainer = %PartyRow
@onready var log_label: RichTextLabel = %LogLabel
@onready var skill_grid: GridContainer = %SkillGrid
@onready var target_prompt: Label = %TargetPrompt
@onready var flee_button: Button = %FleeButton
@onready var end_panel: PanelContainer = %EndPanel
@onready var result_label: Label = %ResultLabel
@onready var rewards_label: Label = %RewardsLabel
@onready var continue_button: Button = %ContinueButton

var state: CombatState

var _party_panels: Array[BattlerPanel] = []
var _enemy_panels: Array[BattlerPanel] = []
var _pending_skill: SkillData = null
var _picking_target: bool = false
var _pending_result: int = 0
var _pending_rewards: Dictionary = {}


func _ready() -> void:
	flee_button.pressed.connect(_on_flee_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	end_panel.visible = false
	target_prompt.visible = false
	# Defer the default bootstrap so external callers can call setup() first.
	call_deferred("_bootstrap_if_needed")


func _bootstrap_if_needed() -> void:
	if state != null:
		return
	if Party.heroes.is_empty():
		Party.start_new_game()
	var enemies: Array[EnemyData] = []
	for path in TEST_ENEMY_PATHS:
		enemies.append(load(path) as EnemyData)
	setup(Party.heroes, enemies)
	# Standalone (F6) run: no host listening, so return to the title screen.
	combat_finished.connect(_on_standalone_finished)


## External entry point. Call after add_child(combat_scene) and before
## _ready's deferred bootstrap fires.
func setup(heroes: Array[Hero], enemies: Array[EnemyData]) -> void:
	if state != null:
		return
	state = CombatState.build(heroes, enemies)
	_populate_panels()
	state.log_appended.connect(_on_log_appended)
	state.hp_changed.connect(_on_hp_changed)
	state.turn_started.connect(_on_turn_started)
	state.combat_ended.connect(_on_combat_ended)
	state.start()
	_process_turn()


# ── Setup ─────────────────────────────────────────────────────────────────────

func _populate_panels() -> void:
	for i in state.party.size():
		var p := BattlerPanel.new()
		p.set_battler(state.party[i])
		p.tapped.connect(_on_panel_tapped)
		_party_panels.append(p)
		party_row.add_child(p)
	for i in state.enemies.size():
		var p := BattlerPanel.new()
		p.set_battler(state.enemies[i])
		p.tapped.connect(_on_panel_tapped)
		_enemy_panels.append(p)
		enemy_row.add_child(p)


func _panel_for(b: Battler) -> BattlerPanel:
	if b.side == Battler.Side.PARTY:
		return _party_panels[b.index]
	return _enemy_panels[b.index]


func _all_panels() -> Array[BattlerPanel]:
	var all: Array[BattlerPanel] = []
	all.append_array(_party_panels)
	all.append_array(_enemy_panels)
	return all


func _refresh_all_panels() -> void:
	for p in _all_panels():
		p.refresh()


# ── State signals ─────────────────────────────────────────────────────────────

func _on_log_appended(line: String) -> void:
	log_label.append_text(line + "\n")


func _on_hp_changed(b: Battler) -> void:
	_panel_for(b).refresh()


func _on_turn_started(b: Battler) -> void:
	for p in _all_panels():
		p.set_active(false)
	_panel_for(b).set_active(true)


func _on_combat_ended(r: CombatState.Result, rewards: Dictionary) -> void:
	# Defer the end-panel reveal so _process_turn can pause briefly first,
	# letting the player read the final action's log line.
	_pending_result = r
	_pending_rewards = rewards


# ── Turn pacing ───────────────────────────────────────────────────────────────

func _process_turn() -> void:
	await get_tree().create_timer(TURN_LEAD_DELAY).timeout
	while not state.ended and state.current_actor != null \
			and state.current_actor.side == Battler.Side.ENEMY:
		state.step()
		_refresh_all_panels()
		await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	if state.ended:
		_show_end_panel()
		return
	if state.current_actor != null:
		_show_player_turn_ui()


# ── Player turn UI ────────────────────────────────────────────────────────────

func _show_player_turn_ui() -> void:
	_picking_target = false
	_pending_skill = null
	target_prompt.visible = false
	flee_button.disabled = false
	_populate_skill_buttons()


func _populate_skill_buttons() -> void:
	_clear_skill_buttons()
	var hero: Hero = state.current_actor.hero
	for skill in hero.class_data.skills:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = _label_for_skill(hero, skill)
		btn.disabled = hero.level < skill.unlock_level or hero.mp < skill.mp_cost
		btn.pressed.connect(_on_skill_pressed.bind(skill))
		skill_grid.add_child(btn)


func _label_for_skill(hero: Hero, skill: SkillData) -> String:
	var name_part := skill.display_name
	var tier := Party.get_skill_tier(hero, skill)
	if tier > 1:
		name_part += " (T%d)" % tier
	var label := "%s · %d MP" % [name_part, skill.mp_cost]
	if hero.level < skill.unlock_level:
		label += " [Nv %d]" % skill.unlock_level
	return label


func _clear_skill_buttons() -> void:
	for child in skill_grid.get_children():
		child.queue_free()


# ── Targeting flow ────────────────────────────────────────────────────────────

func _on_skill_pressed(skill: SkillData) -> void:
	if state.ended:
		return
	if state.skill_is_auto_targeted(skill):
		_resolve_player_action(skill, null)
		return
	var targets := state.valid_targets_for(state.current_actor, skill)
	if targets.is_empty():
		# No valid targets (e.g. Reviver with nobody fallen). Stay on the skill menu.
		return
	_pending_skill = skill
	_picking_target = true
	target_prompt.visible = true
	_clear_skill_buttons()
	for panel in _all_panels():
		panel.set_selectable(targets.has(panel.battler))


func _on_panel_tapped(b: Battler) -> void:
	if not _picking_target or _pending_skill == null:
		return
	var targets := state.valid_targets_for(state.current_actor, _pending_skill)
	if not targets.has(b):
		return
	var skill := _pending_skill
	_pending_skill = null
	_picking_target = false
	target_prompt.visible = false
	for p in _all_panels():
		p.set_selectable(false)
	_resolve_player_action(skill, b)


func _resolve_player_action(skill: SkillData, target: Battler) -> void:
	_clear_skill_buttons()
	flee_button.disabled = true
	state.player_action(skill, target)
	_refresh_all_panels()
	_process_turn()


# ── Buttons ───────────────────────────────────────────────────────────────────

func _on_flee_pressed() -> void:
	if state.ended or state.current_actor == null:
		return
	if state.current_actor.side != Battler.Side.PARTY:
		return
	_clear_skill_buttons()
	flee_button.disabled = true
	state.player_flee()
	_refresh_all_panels()
	_process_turn()


func _on_continue_pressed() -> void:
	combat_finished.emit(_pending_result)


func _on_standalone_finished(_result: int) -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ── End panel ─────────────────────────────────────────────────────────────────

func _show_end_panel() -> void:
	_clear_skill_buttons()
	for p in _all_panels():
		p.set_selectable(false)
		p.set_active(false)
	target_prompt.visible = false
	flee_button.disabled = true
	var result_names := ["—", "VITÓRIA", "DERROTA", "FUGA"]
	result_label.text = result_names[_pending_result]
	if _pending_result == CombatState.Result.VICTORY:
		rewards_label.text = "+%d XP   +%d ouro" % [_pending_rewards["xp"], _pending_rewards["gold"]]
		GameState.gold += int(_pending_rewards["gold"])
		for h in Party.heroes:
			if h.is_alive():
				Party.award_xp(h, int(_pending_rewards["xp"]))
		_refresh_all_panels()
	elif _pending_result == CombatState.Result.DEFEAT:
		rewards_label.text = "O grupo foi derrotado."
	else:
		rewards_label.text = ""
	end_panel.visible = true
