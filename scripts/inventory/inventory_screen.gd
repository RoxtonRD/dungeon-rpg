## Inventory, equipment, and skill screen.
## Shows each hero's equipment slots, their skills (with SP upgrade buttons),
## and the shared party inventory for equipping / using items.
extends Control

const ITEM_DIR := "res://resources/items/"
const DUNGEON_SCENE := "res://scripts/dungeon/dungeon_map.tscn"

@onready var hero_tab_bar: HBoxContainer = %HeroTabBar
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
	for i in Party.heroes.size():
		var h: Hero = Party.heroes[i]
		var btn := Button.new()
		btn.text = h.class_data.display_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_hero_tab.bind(i))
		hero_tab_bar.add_child(btn)


func _on_hero_tab(idx: int) -> void:
	_selected_hero_idx = idx
	_refresh()


func _refresh() -> void:
	var hero: Hero = Party.heroes[_selected_hero_idx]
	_update_hero_info(hero)
	_rebuild_equipment_rows(hero)
	_rebuild_skill_rows(hero)
	_rebuild_item_list(hero)


func _update_hero_info(hero: Hero) -> void:
	hero_info_label.text = "%s  Nv.%d  HP: %d/%d  MP: %d/%d  SP: %d" % [
		hero.class_data.display_name, hero.level,
		hero.hp, hero.max_hp(),
		hero.mp, hero.max_mp(),
		hero.sp_available,
	]
	stats_label.text = "ATQ: %d   DEF: %d   MAG: %d   VEL: %d" % [
		hero.atk(), hero.def(), hero.mag(), hero.spd(),
	]


# ── Equipment slots ───────────────────────────────────────────────────────────

func _rebuild_equipment_rows(hero: Hero) -> void:
	for child in equip_rows.get_children():
		child.queue_free()

	var slot_labels: Dictionary = {
		"weapon": "Arma",
		"armor": "Armadura",
		"trinket": "Amuleto",
	}
	for slot in ["weapon", "armor", "trinket"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 48)

		var slot_lbl := Label.new()
		slot_lbl.text = slot_labels[slot]
		slot_lbl.custom_minimum_size = Vector2(90, 0)
		slot_lbl.add_theme_font_size_override("font_size", 16)
		slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(slot_lbl)

		var item: ItemData = hero.equipment[slot]
		var item_lbl := Label.new()
		item_lbl.text = item.display_name if item != null else "—"
		item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_lbl.add_theme_font_size_override("font_size", 16)
		item_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if item != null:
			item_lbl.tooltip_text = _item_description(item)
		row.add_child(item_lbl)

		if item != null:
			var unequip_btn := Button.new()
			unequip_btn.text = "Desequipar"
			unequip_btn.custom_minimum_size = Vector2(110, 0)
			unequip_btn.pressed.connect(_on_unequip.bind(slot))
			row.add_child(unequip_btn)

		equip_rows.add_child(row)


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

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 52)

		# Skill name + tier. Long-press the name to read the description.
		var tier := Party.get_skill_tier(hero, skill)
		var name_lbl := Label.new()
		name_lbl.text = "%s  T%d  ·  %d MP" % [skill.display_name, tier, skill.mp_cost]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.tooltip_text = skill.description
		row.add_child(name_lbl)

		# Upgrade button — only shown when the skill can ever be upgraded
		if skill.max_upgrade_level > 1:
			var up_btn := Button.new()
			up_btn.text = "Evoluir"
			up_btn.custom_minimum_size = Vector2(90, 0)
			up_btn.disabled = not Party.can_upgrade_skill(hero, skill)
			up_btn.pressed.connect(_on_upgrade_skill.bind(hero, skill))
			row.add_child(up_btn)

		skill_rows.add_child(row)


func _on_upgrade_skill(hero: Hero, skill: SkillData) -> void:
	if Party.upgrade_skill(hero, skill):
		_refresh()


# ── Inventory item list ───────────────────────────────────────────────────────

func _rebuild_item_list(hero: Hero) -> void:
	for child in item_list_vbox.get_children():
		child.queue_free()

	inv_section_label.text = "Inventário (%d)" % GameState.inventory.size()

	if GameState.inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Inventário vazio."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 16)
		item_list_vbox.add_child(empty_lbl)
		return

	for idx in GameState.inventory.size():
		var item_id: String = GameState.inventory[idx]
		var item := load(ITEM_DIR + item_id + ".tres") as ItemData
		if item == null:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 52)

		var name_lbl := Label.new()
		name_lbl.text = item.display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.tooltip_text = _item_description(item)
		row.add_child(name_lbl)

		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(100, 0)

		if item.slot == ItemData.Slot.CONSUMABLE:
			action_btn.text = "Usar"
			action_btn.disabled = not _can_use_consumable(hero, item)
			action_btn.pressed.connect(_on_use.bind(idx))
		else:
			action_btn.text = "Equipar"
			action_btn.disabled = not _can_equip(hero, item)
			action_btn.pressed.connect(_on_equip.bind(idx))

		row.add_child(action_btn)
		item_list_vbox.add_child(row)


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

## Builds a human-readable summary of an item from its stats / effects.
## ItemData has no authored description field in v1, so this is generated.
func _item_description(item: ItemData) -> String:
	var parts: Array[String] = []
	if item.slot == ItemData.Slot.CONSUMABLE:
		if item.use_heal > 0:
			parts.append("Cura %d HP" % item.use_heal)
		if item.use_mp > 0:
			parts.append("Restaura %d MP" % item.use_mp)
		if item.use_sp > 0:
			parts.append("+%d Ponto de Habilidade" % item.use_sp)
		if item.use_revive_party > 0.0:
			parts.append("Revive aliados caídos com %d%% HP" % roundi(item.use_revive_party * 100.0))
	else:
		var stats := _stat_mods_text(item)
		if not stats.is_empty():
			parts.append(stats)
		if item.class_restriction.size() > 0:
			var names: Array[String] = []
			for cid in item.class_restriction:
				names.append(_class_display_name(cid))
			parts.append("Classe: %s" % ", ".join(names))
	if parts.is_empty():
		return item.display_name
	return "\n".join(parts)


func _stat_mods_text(item: ItemData) -> String:
	var mods: Array[String] = []
	if item.mod_hp != 0:  mods.append("HP %+d" % item.mod_hp)
	if item.mod_mp != 0:  mods.append("MP %+d" % item.mod_mp)
	if item.mod_atk != 0: mods.append("ATQ %+d" % item.mod_atk)
	if item.mod_def != 0: mods.append("DEF %+d" % item.mod_def)
	if item.mod_mag != 0: mods.append("MAG %+d" % item.mod_mag)
	if item.mod_spd != 0: mods.append("VEL %+d" % item.mod_spd)
	return ", ".join(mods)


## Maps a class id to its display name using the live party (always has all 4).
func _class_display_name(class_id: String) -> String:
	for h in Party.heroes:
		if h.class_data.id == class_id:
			return h.class_data.display_name
	return class_id


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
			_flash_message("%s não tem habilidades para evoluir — +%d MP máximo!" % [
				hero.class_data.display_name, mp_gain])
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
	get_tree().change_scene_to_file(DUNGEON_SCENE)
