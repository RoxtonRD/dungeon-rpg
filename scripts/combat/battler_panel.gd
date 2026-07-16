## Reusable widget for one battler (party or enemy). Shows a portrait
## (TextureRect when a Texture2D is assigned to ClassData/EnemyData, otherwise
## a coloured ColorRect placeholder), name, HP/MP bars and active statuses.
## Tapping the panel emits `tapped` when the panel is in selectable mode.
class_name BattlerPanel
extends PanelContainer

signal tapped(battler: Battler)

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
var _status_label: Label
## Transient border glow shown while this battler is acting. Its own modulate
## is animated independently, so panel refreshes don't interrupt the flash.
var _glow: Panel
var _flash_tween: Tween
## Full-card colour wash on hit (red = damage, white = heal).
var _hit_overlay: ColorRect
var _hit_tween: Tween

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
		portrait_tex = battler.hero.class_data.portrait
		_mp_label.visible = true
		_mp_bar.visible = true
		var mp_max := battler.hero.max_mp()
		_mp_label.text = "MP %d/%d" % [battler.hero.mp, mp_max]
		_mp_bar.max_value = max(1, mp_max)
		_mp_bar.value = battler.hero.mp
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


func set_active(active: bool) -> void:
	_apply_style(active)


## Brief full-card colour wash on hit. `tint` carries the base alpha (red for
## damage, white for heal); this flashes it on and fades it out.
func flash_hit(tint: Color) -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_overlay.color = tint
	_hit_overlay.modulate.a = 1.0
	_hit_tween = create_tween()
	_hit_tween.tween_property(_hit_overlay, "modulate:a", 0.0, 0.35)


## Brief warm border glow on whoever is currently acting; fades on its own.
func flash_active() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_glow.modulate.a = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(_glow, "modulate:a", 0.0, 0.5)


## Floating combat number that rises from the panel and fades out. `color`
## distinguishes physical / magic damage and healing (set by the caller).
func show_popup(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 100
	add_child(lbl)
	lbl.position = Vector2(size.x * 0.5 - 20.0, 30.0)
	# Rise slowly, hold readable, then fade — keeps the number legible.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 56.0, 1.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.9)
	tw.chain().tween_callback(lbl.queue_free)


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
		"warrior": return Color(0.65, 0.32, 0.32)
		"cleric":  return Color(0.62, 0.58, 0.30)
		"rogue":   return Color(0.32, 0.55, 0.32)
		"mage":    return Color(0.34, 0.36, 0.70)
	return Color(0.3, 0.3, 0.4)


func _format_statuses(b: Battler) -> String:
	var s := ""
	for st in b.statuses:
		if not s.is_empty():
			s += ", "
		if st.kind == CombatStatus.Kind.BARRIER:
			s += "BARREIRA"
		else:
			s += "%s (%d)" % [st.source_name, st.duration]
	return s
