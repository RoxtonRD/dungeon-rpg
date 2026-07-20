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

## Delay between consecutive enemy actions, in seconds. FLAG: tune me (0.6–0.8).
const ENEMY_TURN_DELAY: float = 0.8
## Pause after the player's own action resolves so they can read it. FLAG: tune me.
const PLAYER_ACTION_DELAY: float = 0.5
## Delay after a turn begins before processing it (lets the highlight register).
const TURN_LEAD_DELAY: float = 0.6
## Chance for a boss kill to drop a Tomo de Maestria (tome_sp). FLAG: tune me.
const BOSS_TOME_DROP_CHANCE: float = 0.25

## Boss background; the default combat background is set in the .tscn.
const BG_BOSS: Texture2D = preload("res://assets/backgrounds/bg_boss.png")


## Base delays scaled by the player's combat-speed setting (1x / 1.5x / 2x).
func _delay(base: float) -> float:
	return base / Settings.combat_speed

@onready var background: TextureRect = $Background
@onready var back_party_col: VBoxContainer = %BackPartyCol
@onready var front_party_col: VBoxContainer = %FrontPartyCol
@onready var front_enemy_col: VBoxContainer = %FrontEnemyCol
@onready var back_enemy_col: VBoxContainer = %BackEnemyCol
@onready var log_label: RichTextLabel = %LogLabel
@onready var skill_grid: GridContainer = %SkillGrid
@onready var target_prompt: Label = %TargetPrompt
@onready var flee_button: Button = %FleeButton
@onready var cancel_button: Button = %CancelButton
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
	SafeArea.apply($VBox)
	flee_button.pressed.connect(_on_flee_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	end_panel.visible = false
	target_prompt.visible = false
	cancel_button.visible = false
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
	# Swap to the boss background when the encounter contains a boss.
	if _encounter_has_boss():
		background.texture = BG_BOSS
	_populate_panels()
	state.log_appended.connect(_on_log_appended)
	state.hp_changed.connect(_on_hp_changed)
	state.damage_popup.connect(_on_damage_popup)
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
		if state.party[i].is_front_row():
			front_party_col.add_child(p)
		else:
			back_party_col.add_child(p)
	for i in state.enemies.size():
		var p := BattlerPanel.new()
		p.set_battler(state.enemies[i])
		p.tapped.connect(_on_panel_tapped)
		_enemy_panels.append(p)
		if state.enemies[i].is_front_row():
			front_enemy_col.add_child(p)
		else:
			back_enemy_col.add_child(p)


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

func _on_log_appended(line: String, kind: CombatState.LogKind) -> void:
	log_label.append_text(_colorize_log_line(line, kind) + "\n")


## Colours a log line by its category (language-independent), mirroring the
## floating-number palette: crits gold, damage warm red, heals green,
## barriers blue. INFO lines keep the theme's default color.
func _colorize_log_line(line: String, kind: CombatState.LogKind) -> String:
	match kind:
		CombatState.LogKind.CRIT:
			return "[color=#ffd159]%s[/color]" % line
		CombatState.LogKind.HEAL:
			return "[color=#80ff8c]%s[/color]" % line
		CombatState.LogKind.BARRIER:
			return "[color=#9eb3ff]%s[/color]" % line
		CombatState.LogKind.DAMAGE:
			return "[color=#ff9d80]%s[/color]" % line
	return line


func _on_hp_changed(b: Battler) -> void:
	_panel_for(b).refresh()


func _on_damage_popup(b: Battler, amount: int, kind: CombatState.PopupKind) -> void:
	var color: Color
	var text: String
	var tint: Color
	match kind:
		CombatState.PopupKind.HEAL:
			color = Color(0.5, 1.0, 0.55)      # green number
			text = "+%d" % amount
			tint = Color(1.0, 1.0, 1.0, 0.40)  # white wash
		CombatState.PopupKind.MAG:
			color = Color(0.62, 0.7, 1.0)      # blue number
			text = str(amount)
			tint = Color(0.9, 0.15, 0.15, 0.5) # red wash
		_:  # PHYS
			color = Color(1.0, 0.85, 0.45)     # warm number
			text = str(amount)
			tint = Color(0.9, 0.15, 0.15, 0.5) # red wash
	var panel := _panel_for(b)
	panel.flash_hit(tint)
	panel.show_popup(text, color)


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
	await get_tree().create_timer(_delay(TURN_LEAD_DELAY)).timeout
	while not state.ended and state.current_actor != null \
			and state.current_actor.side == Battler.Side.ENEMY:
		_panel_for(state.current_actor).flash_active()
		state.step()
		_refresh_all_panels()
		await get_tree().create_timer(_delay(ENEMY_TURN_DELAY)).timeout
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
	cancel_button.visible = false
	flee_button.visible = true
	flee_button.disabled = false
	_populate_skill_buttons()


func _populate_skill_buttons() -> void:
	_clear_skill_buttons()
	var hero: Hero = state.current_actor.hero
	for skill in hero.class_data.skills:
		# Hide skills the hero hasn't unlocked yet (consistent with Personagens).
		if hero.level < skill.unlock_level:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 96)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = hero.mp < skill.mp_cost
		btn.pressed.connect(_on_skill_pressed.bind(skill))

		# Icon + label overlay. Children ignore the mouse so the button stays
		# clickable as a whole.
		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 6
		hbox.offset_right = -6
		hbox.add_theme_constant_override("separation", 8)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hbox)
		
		if hero.mp < skill.mp_cost:
			hbox.add_child(_make_icon(skill.icon_or_null(), 96,0.25))
		else:
			hbox.add_child(_make_icon(skill.icon_or_null(), 96,1.0))

		var label := Label.new()
		label.text = _label_for_skill(hero, skill)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 14)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(label)

		skill_grid.add_child(btn)


func _label_for_skill(hero: Hero, skill: SkillData) -> String:
	var name_part := tr(skill.display_name)
	var tier := Party.get_skill_tier(hero, skill)
	if tier > 1:
		name_part += " (T%d)" % tier
	var label := "%s · %d MP" % [name_part, skill.mp_cost]
	if hero.level < skill.unlock_level:
		label += tr("UI_SKILL_LOCKED") % skill.unlock_level
	return label


func _clear_skill_buttons() -> void:
	for child in skill_grid.get_children():
		child.queue_free()


## Returns a square icon Control: a TextureRect when `tex` is non-null, else a
## small neutral ColorRect placeholder. mouse_filter set to IGNORE.
func _make_icon(tex: Texture2D, size: int = 64, alpha: float = 1) -> Control:
	
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(size, size)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.self_modulate.a = alpha
		return rect
	var bg := ColorRect.new()
	bg.color = Color(0.25, 0.25, 0.32)
	bg.custom_minimum_size = Vector2(size, size)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


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
	flee_button.visible = false
	cancel_button.visible = true
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
	cancel_button.visible = false
	flee_button.disabled = true
	if state.current_actor != null:
		_panel_for(state.current_actor).flash_active()
	state.player_action(skill, target)
	_refresh_all_panels()
	await get_tree().create_timer(_delay(PLAYER_ACTION_DELAY)).timeout
	_process_turn()


# ── Buttons ───────────────────────────────────────────────────────────────────

func _on_cancel_pressed() -> void:
	## Return to the skill grid without spending the turn.
	for p in _all_panels():
		p.set_selectable(false)
	_show_player_turn_ui()


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
	Fade.change_scene("res://scenes/main.tscn")


# ── End panel ─────────────────────────────────────────────────────────────────

## True when any enemy in the current encounter was a boss.
func _encounter_has_boss() -> bool:
	for e in state.enemies:
		if e.enemy_data != null and e.enemy_data.is_boss:
			return true
	return false


func _tome_display_name() -> String:
	var tome := load("res://resources/items/tome_sp.tres") as ItemData
	return tr(tome.display_name) if tome != null else tr("ITEM_TOME_SP")


func _show_end_panel() -> void:
	_clear_skill_buttons()
	for p in _all_panels():
		p.set_selectable(false)
		p.set_active(false)
	target_prompt.visible = false
	cancel_button.visible = false
	flee_button.disabled = true
	var result_names := ["—", tr("UI_RESULT_VICTORY"), tr("UI_RESULT_DEFEAT"), tr("UI_RESULT_FLEE")]
	result_label.text = result_names[_pending_result]
	if _pending_result == CombatState.Result.VICTORY:
		GameState.gold += int(_pending_rewards["gold"])
		var lines: Array[String] = []
		lines.append(tr("UI_REWARDS") % [_pending_rewards["xp"], _pending_rewards["gold"]])
		for h in Party.heroes:
			# Downed heroes still earn XP, at half rate, so a hero KO'd early in a
			# run doesn't spiral levels behind the survivors. A level-up must not
			# revive them, though — award_xp()'s level_up() full-heals, so we
			# re-down them afterwards to preserve the "dead until rest/item" rule.
			var was_down := not h.is_alive()
			var xp_award := int(_pending_rewards["xp"])
			if was_down:
				xp_award /= 2
			var prev_level := h.level
			var prev_bonus_mp := h.bonus_mp
			var unlocked: Array[SkillData] = Party.award_xp(h, xp_award)
			if was_down:
				h.hp = 0
			if h.level > prev_level:
				lines.append(tr("UI_LEVEL_UP") % [tr(h.class_data.display_name), h.level])
				for skill in unlocked:
					lines.append(tr("UI_NEW_SKILL") % tr(skill.display_name))
			if h.bonus_mp > prev_bonus_mp:
				lines.append(tr("UI_SP_CONVERT") % [
					tr(h.class_data.display_name), h.bonus_mp - prev_bonus_mp])
		# Rare boss-only drop: a Tomo de Maestria.
		if _encounter_has_boss() and randf() < BOSS_TOME_DROP_CHANCE:
			GameState.add_item("tome_sp")
			lines.append(tr("UI_TOME_DROP") % _tome_display_name())
		rewards_label.text = "\n".join(lines)
		_refresh_all_panels()
	elif _pending_result == CombatState.Result.DEFEAT:
		rewards_label.text = tr("UI_DEFEATED_TEXT")
	else:
		rewards_label.text = ""
	end_panel.visible = true
