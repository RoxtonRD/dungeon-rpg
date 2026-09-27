## Reusable widget for one battler (party or enemy). Shows a portrait
## (TextureRect when a Texture2D is assigned to ClassData/EnemyData, otherwise
## a coloured ColorRect placeholder), name, HP bar, an MP or Rage bar (none for
## enemies or a hero with no MP) and active statuses.
## Tapping the panel emits `tapped` when the panel is in selectable mode.
class_name BattlerPanel
extends PanelContainer

signal tapped(battler: Battler)

## Rage bar fill: orange, so it never reads as the blue MP bar.
const RAGE_FILL_COLOR := Color(0.95, 0.5, 0.1)
## Floating-text outline: near-black and thick, so numbers read on any card.
const POPUP_OUTLINE_COLOR := Color(0.02, 0.02, 0.03)
const POPUP_OUTLINE_SIZE := 9
## Hit feedback timings at 1x combat speed (scaled by Settings.combat_speed).
const HIT_WASH_TIME := 0.6
const SHAKE_TIME := 0.3
const SHAKE_PX := 6.0
## Popups hold this long before fading, then fade over POPUP_FADE_TIME.
const POPUP_HOLD_TIME := 1.2
const POPUP_FADE_TIME := 0.4
## Vertical gap between stacked status popups from the same action.
const STATUS_POPUP_STEP := 26.0
## Offsets for numbers that overlap in time (multi-hit on one card): each
## extra number steps sideways and down so it never touches the previous one.
const NUMBER_POPUP_OFFSETS: Array[Vector2] = [
	Vector2(0, 0), Vector2(-42, 20), Vector2(42, 20), Vector2(-21, 40), Vector2(21, 40)
]

var battler: Battler = null

var _vbox: VBoxContainer
## Placeholder portrait shown when no Texture2D portrait is available.
var _portrait_bg: ColorRect
## Real portrait, shown instead of _portrait_bg when a texture is assigned.
var _portrait_tex: TextureRect
var _name_label: Label
var _hp_label: Label
var _hp_bar: ProgressBar
var _mp_label: Label
var _mp_bar: ProgressBar
## Fill style swapped onto _mp_bar when it shows Rage instead of MP.
var _rage_fill: StyleBoxFlat
var _status_label: Label
## Transient border glow shown while this battler is acting. Its own modulate
## is animated independently, so panel refreshes don't interrupt the flash.
var _glow: Panel
var _flash_tween: Tween
## Full-card colour wash on hit (red = damage, white = heal).
var _hit_overlay: ColorRect
var _hit_tween: Tween
var _shake_tween: Tween
## Resting x while a shake runs, so a shake restarted mid-way stays centred.
var _shake_base_x: float = 0.0
## Outline marking this battler as the target of the action being shown.
var _target_mark: Panel
var _target_mark_style: StyleBoxFlat
var _mark_tween: Tween
## Free-positioning layer for floating text. PanelContainer lays out its direct
## children, so popups live inside this plain Control instead.
var _fx_layer: Control
## Status popups currently on screen, so a new one stacks below the last.
var _status_popups_live: int = 0
## Damage/heal numbers currently on screen, so a multi-hit's numbers sit side
## by side instead of on top of each other.
var _number_popups_live: int = 0

var _selectable: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(130, 185)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_style(false)
	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)

	var portrait_box := CenterContainer.new()
	_vbox.add_child(portrait_box)

	_portrait_bg = ColorRect.new()
	_portrait_bg.custom_minimum_size = Vector2(80, 80)
	_portrait_bg.color = Color(0.3, 0.3, 0.4)
	portrait_box.add_child(_portrait_bg)

	_portrait_tex = TextureRect.new()
	_portrait_tex.custom_minimum_size = Vector2(80, 80)
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Pixel art: keep portraits crisp at small sizes (no linear-filter blur).
	_portrait_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_tex.visible = false
	portrait_box.add_child(_portrait_tex)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_name_label)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 8)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.show_percentage = false
	_hp_bar.theme_type_variation = "HpBar"
	_vbox.add_child(_hp_bar)

	_mp_label = Label.new()
	_mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mp_label.add_theme_font_size_override("font_size", 12)
	_vbox.add_child(_mp_label)

	_mp_bar = ProgressBar.new()
	_mp_bar.custom_minimum_size = Vector2(0, 8)
	_mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mp_bar.show_percentage = false
	_mp_bar.theme_type_variation = "MpBar"
	_vbox.add_child(_mp_bar)

	_rage_fill = StyleBoxFlat.new()
	_rage_fill.bg_color = RAGE_FILL_COLOR
	_rage_fill.set_corner_radius_all(2)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vbox.add_child(_status_label)

	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

	# Hit-flash wash over the whole card; colour set per hit, hidden at rest.
	_hit_overlay = ColorRect.new()
	_hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_overlay.modulate.a = 0.0
	add_child(_hit_overlay)

	# Acting-glow overlay (border only), transparent until flash_active().
	_glow = Panel.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_sb := StyleBoxFlat.new()
	glow_sb.draw_center = false
	glow_sb.set_border_width_all(4)
	glow_sb.border_color = Color(1.0, 0.88, 0.45)
	glow_sb.set_corner_radius_all(4)
	_glow.add_theme_stylebox_override("panel", glow_sb)
	_glow.modulate.a = 0.0
	add_child(_glow)

	# Target outline, drawn just outside the card edge; hidden at rest.
	_target_mark = Panel.new()
	_target_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_mark_style = StyleBoxFlat.new()
	_target_mark_style.draw_center = false
	_target_mark_style.set_border_width_all(5)
	_target_mark_style.set_expand_margin_all(3)
	_target_mark_style.set_corner_radius_all(6)
	_target_mark.add_theme_stylebox_override("panel", _target_mark_style)
	_target_mark.modulate.a = 0.0
	add_child(_target_mark)

	_fx_layer = Control.new()
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)


func set_battler(b: Battler) -> void:
	battler = b
	refresh()


func refresh() -> void:
	if battler == null:
		return
	_name_label.text = battler.display_name()
	_hp_label.text = "HP %d/%d" % [battler.get_hp(), battler.max_hp]
	_hp_bar.max_value = max(1, battler.max_hp)
	_hp_bar.value = battler.get_hp()

	# Portrait — show Texture2D if one is assigned, otherwise placeholder.
	var portrait_tex: Texture2D = null
	if battler.side == Battler.Side.PARTY:
		_portrait_bg.color = color_for_class(battler.hero.class_data.id)
		portrait_tex = HeroArt.portrait_for(battler.hero)
		_refresh_resource_bar()
	else:
		_portrait_bg.color = Color(0.45, 0.2, 0.2)
		portrait_tex = battler.enemy_data.portrait
		_mp_label.visible = false
		_mp_bar.visible = false

	if portrait_tex != null:
		_portrait_tex.texture = portrait_tex
		_portrait_tex.visible = true
		_portrait_bg.visible = false
	else:
		_portrait_tex.visible = false
		_portrait_bg.visible = true

	_status_label.text = _format_statuses(battler)
	# Dim dead battlers; reset modulate otherwise (selectable mode tints separately).
	modulate = Color(0.4, 0.4, 0.4) if not battler.is_alive() else Color.WHITE


## The bar under HP: Rage for a rage class, MP for everyone else, hidden when
## the hero has no MP at all.
func _refresh_resource_bar() -> void:
	if battler.uses_rage():
		_mp_label.visible = true
		_mp_bar.visible = true
		_mp_label.text = "%s %d/%d" % [tr("RES_RAGE"), battler.rage, Battler.RAGE_MAX]
		_mp_bar.max_value = Battler.RAGE_MAX
		_mp_bar.value = battler.rage
		_mp_bar.add_theme_stylebox_override("fill", _rage_fill)
		return
	_mp_bar.remove_theme_stylebox_override("fill")
	var mp_max := battler.hero.max_mp()
	_mp_label.visible = mp_max > 0
	_mp_bar.visible = mp_max > 0
	_mp_label.text = "%s %d/%d" % [tr("RES_MP"), battler.hero.mp, mp_max]
	_mp_bar.max_value = max(1, mp_max)
	_mp_bar.value = battler.hero.mp


func set_active(active: bool) -> void:
	_apply_style(active)


## Full-card colour wash on hit. `tint` carries the base alpha (red for
## damage, white for heal); it starts at full strength, holds a moment and
## fades out.
func flash_hit(tint: Color) -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_overlay.color = tint
	_hit_overlay.modulate.a = 1.0
	_hit_tween = create_tween()
	_hit_tween.tween_property(_hit_overlay, "modulate:a", 0.0, _t(HIT_WASH_TIME)).set_ease(
		Tween.EASE_IN
	)


## Small horizontal shake when this battler takes damage.
func shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	else:
		_shake_base_x = position.x
	var step := _t(SHAKE_TIME) / 5.0
	_shake_tween = create_tween()
	for dx in [SHAKE_PX, -SHAKE_PX, SHAKE_PX * 0.6, -SHAKE_PX * 0.4, 0.0]:
		_shake_tween.tween_property(self, "position:x", _shake_base_x + dx, step)
	# The column owns our position; let it put us back exactly.
	_shake_tween.tween_callback(_resort_parent)


func _resort_parent() -> void:
	var parent := get_parent() as Container
	if parent != null:
		parent.queue_sort()


## Outlines this battler as a target of the action on screen.
func mark_target(color: Color) -> void:
	if _mark_tween != null and _mark_tween.is_valid():
		_mark_tween.kill()
	_target_mark_style.border_color = color
	_target_mark.modulate.a = 1.0


func is_target_marked() -> bool:
	return _target_mark.modulate.a > 0.0


## Removes the target outline, fading over `fade` seconds (0 = at once).
func clear_target_mark(fade: float = 0.0) -> void:
	if _mark_tween != null and _mark_tween.is_valid():
		_mark_tween.kill()
	if fade <= 0.0:
		_target_mark.modulate.a = 0.0
		return
	_mark_tween = create_tween()
	_mark_tween.tween_property(_target_mark, "modulate:a", 0.0, fade)


## Brief warm border glow on whoever is currently acting; fades on its own.
func flash_active() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_glow.modulate.a = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(_glow, "modulate:a", 0.0, 0.5)


## Floating combat number that rises from the portrait, holds, then fades.
## `color` distinguishes physical / magic damage and healing (set by the
## caller). A crit is larger, with a "CRIT!" label above it.
func show_popup(text: String, color: Color, crit: bool = false) -> void:
	var off := NUMBER_POPUP_OFFSETS[_number_popups_live % NUMBER_POPUP_OFFSETS.size()]
	_number_popups_live += 1
	var lbl := _make_popup_label(text, color, 40 if crit else 32)
	var tw := _float_label(lbl, (30.0 if crit else 26.0) + off.y, 40.0, off.x)
	tw.chain().tween_callback(func(): _number_popups_live = maxi(0, _number_popups_live - 1))
	if crit:
		var crit_lbl := _make_popup_label(tr("UI_POPUP_CRIT"), Color(1.0, 0.82, 0.25), 22)
		_float_label(crit_lbl, -8.0 + off.y, 40.0, off.x)


## Status text ("DEF +5", "Taunting", ...) shown lower on the card than the
## damage number, so both stay readable. Several from one action stack.
func show_status_popup(text: String, color: Color) -> void:
	var lbl := _make_popup_label(text, color, 20)
	var slot := _status_popups_live
	_status_popups_live += 1
	var tw := _float_label(lbl, 96.0 + slot * STATUS_POPUP_STEP, 24.0)
	tw.chain().tween_callback(func(): _status_popups_live = maxi(0, _status_popups_live - 1))


func _make_popup_label(text: String, color: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", POPUP_OUTLINE_COLOR)
	lbl.add_theme_constant_override("outline_size", POPUP_OUTLINE_SIZE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 100
	return lbl


## Adds `lbl` centred on the card (shifted by `dx`) at `y`, rises it by
## `rise`, holds it readable, then fades and frees it. Returns the tween.
func _float_label(lbl: Label, y: float, rise: float, dx: float = 0.0) -> Tween:
	_fx_layer.add_child(lbl)
	lbl.size = lbl.get_combined_minimum_size()
	lbl.position = Vector2((size.x - lbl.size.x) * 0.5 + dx, y)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", y - rise, _t(0.5)).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, _t(POPUP_FADE_TIME)).set_delay(_t(POPUP_HOLD_TIME))
	tw.chain().tween_callback(lbl.queue_free)
	return tw


## A feedback duration scaled by the combat-speed setting.
func _t(base: float) -> float:
	return base / Settings.combat_speed


func set_selectable(selectable: bool) -> void:
	_selectable = selectable
	if battler != null and battler.is_alive():
		modulate = Color(1.25, 1.25, 0.85) if selectable else Color.WHITE


func _on_gui_input(event: InputEvent) -> void:
	if not _selectable:
		return
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if pressed:
		tapped.emit(battler)


func _apply_style(active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.20, 0.26) if active else Color(0.13, 0.13, 0.17)
	sb.set_corner_radius_all(4)
	if active:
		sb.set_border_width_all(3)
		sb.border_color = Color(1.0, 0.86, 0.36)
	add_theme_stylebox_override("panel", sb)


## Placeholder portrait tints, keyed by class id. Static so other screens
## (e.g. the formation screen) can reuse the same colours for their fallbacks.
static func color_for_class(class_id: String) -> Color:
	match class_id:
		"warrior":
			return Color(0.65, 0.32, 0.32)
		"cleric":
			return Color(0.62, 0.58, 0.30)
		"rogue":
			return Color(0.32, 0.55, 0.32)
		"mage":
			return Color(0.34, 0.36, 0.70)
		"conjurer":
			return Color(0.24, 0.55, 0.58)
		"alchemist":
			return Color(0.70, 0.48, 0.22)
	return Color(0.3, 0.3, 0.4)


func _format_statuses(b: Battler) -> String:
	return format_statuses(b.statuses)


## Shared formatter for a status list — also used by the party bar, which shows
## the same effects while exploring (they persist outside combat).
static func format_statuses(statuses: Array) -> String:
	var s := ""
	for st in statuses:
		if not s.is_empty():
			s += ", "
		if st.kind == CombatStatus.Kind.BARRIER:
			s += TranslationServer.translate("UI_STATUS_BARRIER")
		else:
			# source_name is a skill display_name, i.e. a translation key.
			s += "%s (%d)" % [TranslationServer.translate(st.source_name), st.duration]
	return s
