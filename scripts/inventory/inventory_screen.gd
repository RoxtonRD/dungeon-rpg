## Inventory, equipment, and skill screen.
## Shows each hero's equipment slots, their skills (with SP upgrade buttons),
## and the shared party inventory for equipping / using items.
extends Control

const ITEM_DIR := "res://resources/items/"

@onready var hero_tab_bar: HBoxContainer = %HeroTabBar
@onready var full_body_tex: TextureRect = %FullBodyTex
@onready var full_body_bg: ColorRect = %FullBodyBg
@onready var hero_info_label: Label = %HeroInfoLabel
@onready var stats_label: Label = %StatsLabel
@onready var equip_rows: VBoxContainer = %EquipmentRows
@onready var skill_rows: VBoxContainer = %SkillRows
@onready var inv_section_label: Label = %InvSectionLabel
@onready var item_list_vbox: VBoxContainer = %ItemListVBox
@onready var close_button: Button = %CloseButton

var _selected_hero_idx: int = 0


func _ready() -> void:
	SafeArea.apply($VBox)
	# Pixel art: render the full-body image without linear-filter blur.
	full_body_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	close_button.pressed.connect(_on_close)
	# Safety net: allows this scene to be run directly for testing.
	if Party.heroes.is_empty():
		Party.start_new_game()
		GameState.start_new_game()
	_build_hero_tabs()
	_refresh()


func _build_hero_tabs() -> void:
	for child in hero_tab_bar.get_children():
		child.queue_free()
	# Toggle buttons in a shared group act as a radio: the selected tab keeps
	# the theme's "pressed" (gold) style so the active hero is obvious.
	var group := ButtonGroup.new()
	for i in Party.heroes.size():
		var h: Hero = Party.heroes[i]
		var btn := Button.new()
		btn.text = tr(h.class_data.display_name)
		btn.custom_minimum_size = Vector2(0, 48)  # 48dp minimum touch target
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_group = group
		btn.button_pressed = (i == _selected_hero_idx)
		btn.pressed.connect(_on_hero_tab.bind(i))
		hero_tab_bar.add_child(btn)


func _on_hero_tab(idx: int) -> void:
	_selected_hero_idx = idx
	_refresh()


func _refresh() -> void:
	var hero: Hero = Party.heroes[_selected_hero_idx]
	# Heal saves that predate the surplus-SP fix: fold any stranded, unspendable
	# SP into max MP before drawing the SP count and skill rows.
	Party.reconcile_surplus_sp(hero)
	_refresh_full_body(hero)
	_update_hero_info(hero)
	_rebuild_equipment_rows(hero)
	_rebuild_skill_rows(hero)
	_rebuild_item_list(hero)


## Shows the hero's full-body Texture2D if present; otherwise falls back to a
## class-tinted ColorRect placeholder (same pattern as combat portraits).
## Loads from assets/full_body — the single source hero image; portraits are
## AtlasTexture head-crops of this same file.
func _refresh_full_body(hero: Hero) -> void:
	var class_id := hero.class_data.id
	var path := "res://assets/full_body/%s.png" % class_id
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex != null:
		full_body_tex.texture = tex
		full_body_tex.visible = true
		full_body_bg.visible = false
	else:
		full_body_tex.visible = false
		full_body_bg.color = BattlerPanel.color_for_class(class_id)
		full_body_bg.visible = true


func _update_hero_info(hero: Hero) -> void:
	hero_info_label.text = tr("UI_HERO_INFO") % [
		tr(hero.class_data.display_name), hero.level,
		hero.hp, hero.max_hp(),
		hero.mp, hero.max_mp(),
		hero.sp_available,
	]
	stats_label.text = "%s: %d   %s: %d   %s: %d   %s: %d" % [
		tr("STAT_ATK"), hero.atk(), tr("STAT_DEF"), hero.def(),
		tr("STAT_MAG"), hero.mag(), tr("STAT_SPD"), hero.spd(),
	]


# ── Equipment slots ───────────────────────────────────────────────────────────

func _rebuild_equipment_rows(hero: Hero) -> void:
	for child in equip_rows.get_children():
		child.queue_free()

	var slot_labels: Dictionary = {
		"weapon": tr("UI_SLOT_WEAPON"),
		"armor": tr("UI_SLOT_ARMOR"),
		"trinket": tr("UI_SLOT_TRINKET"),
	}
	for slot in ["weapon", "armor", "trinket"]:
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 44)

		var slot_lbl := Label.new()
		slot_lbl.text = slot_labels[slot]
		slot_lbl.custom_minimum_size = Vector2(90, 0)
		slot_lbl.add_theme_font_size_override("font_size", 16)
		slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(slot_lbl)

		var item: ItemData = hero.equipment[slot]
		if item != null:
			row.add_child(_make_icon(item.icon_or_null()))
		var item_lbl := Label.new()
		item_lbl.text = tr(item.display_name) if item != null else "—"
		item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_lbl.add_theme_font_size_override("font_size", 16)
		item_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(item_lbl)

		if item != null:
			var unequip_btn := Button.new()
			unequip_btn.text = tr("UI_UNEQUIP")
			unequip_btn.custom_minimum_size = Vector2(110, 0)
			unequip_btn.pressed.connect(_on_unequip.bind(slot))
			row.add_child(unequip_btn)

		entry.add_child(row)
		if item != null:
			var desc := item.short_description()
			if not desc.is_empty():
				entry.add_child(_make_desc_label(desc))
		equip_rows.add_child(entry)


func _on_unequip(slot: String) -> void:
	var hero: Hero = Party.heroes[_selected_hero_idx]
	var item: ItemData = hero.equipment[slot]
	if item == null:
		return
	GameState.add_item(item.id)
	hero.equipment[slot] = null
	hero.hp = mini(hero.hp, hero.max_hp())
	hero.mp = mini(hero.mp, hero.max_mp())
	_refresh()


# ── Skill rows ────────────────────────────────────────────────────────────────

func _rebuild_skill_rows(hero: Hero) -> void:
	for child in skill_rows.get_children():
		child.queue_free()

	for skill in hero.class_data.skills:
		# Only show skills the hero has already unlocked.
		if hero.level < skill.unlock_level:
			continue

		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 44)
		row.add_child(_make_icon(skill.icon_or_null()))

		# Skill name + tier
		var tier := Party.get_skill_tier(hero, skill)
		var name_lbl := Label.new()
		name_lbl.text = "%s  T%d  ·  %d MP" % [tr(skill.display_name), tier, skill.mp_cost]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(name_lbl)

		# Upgrade button — only shown when the skill can ever be upgraded
		if skill.max_upgrade_level > 1:
			var up_btn := Button.new()
			up_btn.text = tr("UI_UPGRADE")
			up_btn.custom_minimum_size = Vector2(90, 0)
			up_btn.disabled = not Party.can_upgrade_skill(hero, skill)
			up_btn.pressed.connect(_on_upgrade_skill.bind(hero, skill))
			row.add_child(up_btn)

		entry.add_child(row)
		if not skill.description.is_empty():
			entry.add_child(_make_desc_label(tr(skill.description)))
		skill_rows.add_child(entry)


func _on_upgrade_skill(hero: Hero, skill: SkillData) -> void:
	if Party.upgrade_skill(hero, skill):
		_refresh()


# ── Inventory item list ───────────────────────────────────────────────────────

func _rebuild_item_list(hero: Hero) -> void:
	for child in item_list_vbox.get_children():
		child.queue_free()

	inv_section_label.text = tr("UI_INVENTORY_N") % GameState.inventory.size()

	if GameState.inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = tr("UI_INVENTORY_EMPTY")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 16)
		item_list_vbox.add_child(empty_lbl)
		return

	for idx in GameState.inventory.size():
		var item_id: String = GameState.inventory[idx]
		var item := load(ITEM_DIR + item_id + ".tres") as ItemData
		if item == null:
			continue

		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 44)
		row.add_child(_make_icon(item.icon_or_null()))

		var name_lbl := Label.new()
		name_lbl.text = tr(item.display_name)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(name_lbl)

		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(100, 0)

		if item.slot == ItemData.Slot.CONSUMABLE:
			action_btn.text = tr("UI_USE")
			action_btn.disabled = not _can_use_consumable(hero, item)
			action_btn.pressed.connect(_on_use.bind(idx))
		else:
			action_btn.text = tr("UI_EQUIP")
			action_btn.disabled = not _can_equip(hero, item)
			action_btn.pressed.connect(_on_equip.bind(idx))

		row.add_child(action_btn)
		entry.add_child(row)
		var desc := item.short_description()
		if not desc.is_empty():
			entry.add_child(_make_desc_label(desc))
		item_list_vbox.add_child(entry)


func _can_equip(hero: Hero, item: ItemData) -> bool:
	if item.class_restriction.size() > 0:
		if not item.class_restriction.has(hero.class_data.id):
			return false
	return true


func _can_use_consumable(hero: Hero, item: ItemData) -> bool:
	if item.use_heal > 0 and hero.hp < hero.max_hp():
		return true
	if item.use_mp > 0 and hero.mp < hero.max_mp():
		return true
	if item.use_sp > 0:
		return true
	if item.use_revive_party > 0:
		for h in Party.heroes:
			if not h.is_alive():
				return true
	return false


# ── Descriptions ──────────────────────────────────────────────────────────────

## Returns a square icon Control: a TextureRect when `tex` is non-null, else
## a small neutral ColorRect placeholder. mouse_filter set to IGNORE so the
## icon never absorbs row taps.
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


## Small, dimmed, always-visible description line shown under a skill or item.
func _make_desc_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.68, 0.70, 0.78))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


# ── Actions ───────────────────────────────────────────────────────────────────

func _on_equip(inv_idx: int) -> void:
	var item_id: String = GameState.inventory[inv_idx]
	var item := load(ITEM_DIR + item_id + ".tres") as ItemData
	if item == null:
		return
	var hero: Hero = Party.heroes[_selected_hero_idx]
	var slot: String = _slot_key_for(item)
	var current: ItemData = hero.equipment[slot]
	if current != null:
		GameState.add_item(current.id)
	hero.equipment[slot] = item
	GameState.inventory.remove_at(inv_idx)
	_refresh()


func _on_use(inv_idx: int) -> void:
	var item_id: String = GameState.inventory[inv_idx]
	var item := load(ITEM_DIR + item_id + ".tres") as ItemData
	if item == null:
		return
	var hero: Hero = Party.heroes[_selected_hero_idx]
	if item.use_heal > 0:
		hero.hp = mini(hero.max_hp(), hero.hp + item.use_heal)
	if item.use_mp > 0:
		hero.mp = mini(hero.max_mp(), hero.mp + item.use_mp)
	if item.use_sp > 0:
		var mp_gain := Party.award_sp(hero, item.use_sp)
		if mp_gain > 0:
			_flash_message(tr("UI_SP_CONVERT") % [
				tr(hero.class_data.display_name), mp_gain])
	if item.use_revive_party > 0:
		for h in Party.heroes:
			if not h.is_alive():
				h.hp = maxi(1, roundi(h.max_hp() * item.use_revive_party))
	GameState.inventory.remove_at(inv_idx)
	_refresh()


func _slot_key_for(item: ItemData) -> String:
	match item.slot:
		ItemData.Slot.WEAPON:  return "weapon"
		ItemData.Slot.ARMOR:   return "armor"
		ItemData.Slot.TRINKET: return "trinket"
	return "weapon"


## Transient on-screen message (the Personagens screen has no combat log).
## Used to report SP→MP conversion when a Tomo de Maestria is consumed.
func _flash_message(text: String) -> void:
	var toast := Label.new()
	toast.text = text
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_font_size_override("font_size", 16)
	toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -220
	toast.offset_right = 220
	toast.offset_top = 90
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(toast, "modulate:a", 0.0, 0.8)
	tw.tween_callback(toast.queue_free)


func _on_close() -> void:
	# Back to whichever screen opened us (city hub by default).
	Fade.change_scene(GameState.nav_return_scene)
