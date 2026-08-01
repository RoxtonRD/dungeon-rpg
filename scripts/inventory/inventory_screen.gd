## Inventory, equipment, and skill screen.
## Shows each hero's equipment slots, their skills (with SP upgrade buttons),
## and the shared party inventory for equipping / using items.
extends Control

const ITEM_DIR := "res://resources/items/"

@onready var hero_tab_bar: HBoxContainer = %HeroTabBar
@onready var full_body_tex: TextureRect = %FullBodyTex
@onready var full_body_bg: ColorRect = %FullBodyBg
@onready var hero_info_label: Label = %HeroInfoLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var mp_bar: ProgressBar = %MpBar
@onready var stats_label: Label = %StatsLabel
@onready var equip_rows: VBoxContainer = %EquipmentRows
@onready var skill_rows: VBoxContainer = %SkillRows
@onready var inv_section_label: Label = %InvSectionLabel
@onready var item_list_vbox: VBoxContainer = %ItemListVBox
@onready var close_button: Button = %CloseButton
@onready var rename_input: LineEdit = %RenameInput
@onready var prev_skin_button: Button = %PrevSkinButton
@onready var next_skin_button: Button = %NextSkinButton
@onready var skin_count_label: Label = %SkinCountLabel
@onready var skin_status_label: Label = %SkinStatusLabel
@onready var skin_buy_button: Button = %SkinBuyButton

var _selected_hero_idx: int = 0
var _hero_tab_buttons: Array[Button] = []
## Skin ids the selected hero can browse (Skins.for_class) + the browsed index.
var _browse: Array = []
var _browse_idx: int = 0


func _ready() -> void:
	SafeArea.apply($VBox)
	# Pixel art: render the full-body image without linear-filter blur.
	full_body_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	close_button.pressed.connect(_on_close)
	rename_input.text_changed.connect(_on_rename_changed)
	prev_skin_button.pressed.connect(_on_skin_step.bind(-1))
	next_skin_button.pressed.connect(_on_skin_step.bind(1))
	skin_buy_button.pressed.connect(_on_skin_buy)
	# Safety net: allows this scene to be run directly for testing.
	if Party.heroes.is_empty():
		Party.start_new_game()
		GameState.start_new_game()
	_build_hero_tabs()
	_refresh()


func _build_hero_tabs() -> void:
	for child in hero_tab_bar.get_children():
		child.queue_free()
	_hero_tab_buttons.clear()
	# Toggle buttons in a shared group act as a radio: the selected tab keeps
	# the theme's "pressed" (gold) style so the active hero is obvious.
	var group := ButtonGroup.new()
	for i in Party.heroes.size():
		var h: Hero = Party.heroes[i]
		var btn := Button.new()
		btn.text = h.display_name()
		btn.custom_minimum_size = Vector2(0, 48)  # 48dp minimum touch target
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_group = group
		btn.button_pressed = (i == _selected_hero_idx)
		btn.pressed.connect(_on_hero_tab.bind(i))
		hero_tab_bar.add_child(btn)
		_hero_tab_buttons.append(btn)


func _on_hero_tab(idx: int) -> void:
	_selected_hero_idx = idx
	_refresh()


func _refresh() -> void:
	var hero: Hero = Party.heroes[_selected_hero_idx]
	# Heal saves that predate the surplus-SP fix: fold any stranded, unspendable
	# SP into max MP before drawing the SP count and skill rows.
	Party.reconcile_surplus_sp(hero)
	_refresh_appearance(hero)   # owns the full-body preview (browsed skin)
	_update_hero_info(hero)
	_rebuild_equipment_rows(hero)
	_rebuild_skill_rows(hero)
	_rebuild_item_list(hero)


# ── Appearance: rename + skin (cosmetic; class is never editable) ─────────────

## Refreshes the rename field and the skin browser for the selected hero. The
## browser cycles every skin the class can see (owned + locked, incl. common);
## the browsed skin is previewed, and equipped when owned.
func _refresh_appearance(hero: Hero) -> void:
	rename_input.text = hero.custom_name
	rename_input.placeholder_text = _default_name(hero)
	_browse = Skins.for_class(hero.class_data.id)
	_browse_idx = maxi(0, _browse.find(hero.effective_skin()))
	var multi := _browse.size() > 1
	prev_skin_button.disabled = not multi
	next_skin_button.disabled = not multi
	_show_browsed(hero)


## The name the hero shows when custom_name is cleared (the class name).
func _default_name(hero: Hero) -> String:
	return tr(hero.class_data.display_name)


## Live rename: a typed name overrides the display name immediately. Cleared =
## back to the default. Persisted on close.
func _on_rename_changed(new_text: String) -> void:
	var hero: Hero = Party.heroes[_selected_hero_idx]
	hero.custom_name = new_text.strip_edges()
	_hero_tab_buttons[_selected_hero_idx].text = hero.display_name()


func _on_skin_step(step: int) -> void:
	var hero: Hero = Party.heroes[_selected_hero_idx]
	_browse_idx = wrapi(_browse_idx + step, 0, _browse.size())
	_show_browsed(hero)
	# Persist only when the browsed skin was owned (i.e. actually equipped).
	if Skins.is_owned(Skins.full_id(hero.class_data.id, _browse[_browse_idx])):
		GameState.save_game()


## Previews the browsed skin, equips it when owned, and drives the lock/buy line.
func _show_browsed(hero: Hero) -> void:
	var skin: String = _browse[_browse_idx]
	var full: String = Skins.full_id(hero.class_data.id, skin)
	var owned := Skins.is_owned(full)
	if owned:
		# Store "" for the class default ("1"); a common id keeps its full form.
		hero.skin_id = "" if skin == "1" else skin
	_render_full_body(hero.class_data.id, skin)
	skin_count_label.text = tr("UI_CREATE_SKIN_N") % [_browse_idx + 1, _browse.size()]
	_update_skin_status(full, owned)


## Sets the status line + buy button for the browsed skin. A plain free class
## skin has no catalog entry, so it shows nothing.
func _update_skin_status(full: String, owned: bool) -> void:
	var m: SkinData = Skins.meta(full)
	skin_buy_button.visible = false
	if owned:
		skin_status_label.text = tr(m.display_name) if m != null else ""
		return
	match m.unlock:
		SkinData.Unlock.GOLD:
			skin_status_label.text = "%s — %d ✦" % [tr(m.display_name), m.price]
			skin_buy_button.text = tr("UI_SKIN_BUY") % m.price
			skin_buy_button.disabled = GameState.gold < m.price
			skin_buy_button.visible = true
		SkinData.Unlock.LEVEL:
			skin_status_label.text = tr("UI_SKIN_LOCKED_LEVEL") % [tr(m.display_name), m.level_req]
		SkinData.Unlock.EVENT:
			skin_status_label.text = "%s — %s" % [tr(m.display_name), tr("UI_SKIN_EVENT")]
		_:
			skin_status_label.text = tr(m.display_name)


func _on_skin_buy() -> void:
	var hero: Hero = Party.heroes[_selected_hero_idx]
	var full: String = Skins.full_id(hero.class_data.id, _browse[_browse_idx])
	var m: SkinData = Skins.meta(full)
	if m == null or m.unlock != SkinData.Unlock.GOLD or GameState.gold < m.price:
		return
	GameState.gold -= m.price
	GameState.unlock_skin(full)   # saves owned_skins
	_show_browsed(hero)           # now owned -> equips + refreshes the line
	GameState.save_game()         # persist the equip + gold spend
	_update_hero_info(hero)       # gold changed


## Renders an arbitrary skin's full body into the preview (temp Hero for HeroArt),
## or a class-tinted placeholder when no art exists.
func _render_full_body(class_id: String, skin: String) -> void:
	var h := Hero.create(load("res://resources/classes/%s.tres" % class_id) as ClassData)
	h.skin_id = "" if skin == "1" else skin
	var tex := HeroArt.full_body_for(h)
	if tex != null:
		full_body_tex.texture = tex
		full_body_tex.visible = true
		full_body_bg.visible = false
	else:
		full_body_tex.visible = false
		full_body_bg.color = BattlerPanel.color_for_class(class_id)
		full_body_bg.visible = true


func _update_hero_info(hero: Hero) -> void:
	# "Name — Class", or just the class when the hero was never renamed (in which
	# case display_name() already returns the class name and would read twice).
	var class_name_str := tr(hero.class_data.display_name)
	var title := hero.display_name()
	if title != class_name_str:
		title = "%s — %s" % [title, class_name_str]
	hero_info_label.text = tr("UI_HERO_INFO") % [
		title, hero.level,
		hero.hp, hero.max_hp(),
		hero.mp, hero.max_mp(),
		hero.sp_available,
	]
	hp_bar.max_value = maxi(1, hero.max_hp())
	hp_bar.value = hero.hp
	mp_bar.max_value = maxi(1, hero.max_mp())
	mp_bar.value = hero.mp
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
		if item != null:
			item_lbl.add_theme_color_override("font_color", item.tier_color())
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

		# Cast button — healing magic is usable outside combat, spending MP.
		# Turns the healers into the party's sustain engine between fights.
		if skill.skill_type == SkillData.SkillType.HEAL:
			var cast_btn := Button.new()
			cast_btn.text = tr("UI_USE")
			cast_btn.custom_minimum_size = Vector2(80, 0)
			cast_btn.disabled = not _can_cast_heal(hero, skill)
			cast_btn.pressed.connect(_on_cast_heal.bind(hero, skill))
			row.add_child(cast_btn)

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


# ── Out-of-combat healing ─────────────────────────────────────────────────────

## Living allies below full HP — who an out-of-combat heal would actually help.
## Downed heroes are excluded: only a revive brings them back.
func _heal_targets() -> Array[Hero]:
	var out: Array[Hero] = []
	for h in Party.heroes:
		if h.is_alive() and h.hp < h.max_hp():
			out.append(h)
	return out


func _can_cast_heal(hero: Hero, skill: SkillData) -> bool:
	if not hero.is_alive() or hero.mp < skill.mp_cost:
		return false
	return not _heal_targets().is_empty()


## Casts a healing skill outside combat: spends MP and applies the same direct
## heal combat uses (CombatState._apply_heal). ALLIES skills hit every wounded
## living ally; single-target ones go to the most wounded. The heal-over-time
## rider is combat-only, so it is not applied here.
func _on_cast_heal(hero: Hero, skill: SkillData) -> void:
	if not _can_cast_heal(hero, skill):
		return
	var scaled := Party.get_upgraded_skill(hero, skill)
	var targets := _heal_targets()
	if skill.target != SkillData.TargetType.ALLIES:
		var lowest: Hero = targets[0]
		for t in targets:
			if t.hp < lowest.hp:
				lowest = t
		targets = [lowest] as Array[Hero]
	hero.mp -= scaled.mp_cost
	var amount := int(floor(float(hero.mag()) * scaled.power + 5.0))
	for t in targets:
		t.hp = mini(t.max_hp(), t.hp + amount)
	GameState.save_game()
	_refresh()


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
		name_lbl.add_theme_color_override("font_color", item.tier_color())
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
	# Heal/mana only apply to a living hero — a healing potion must never double
	# as a resurrection (that made the revival elixir pointless). Combat already
	# enforces this via CombatState.item_targets(), which lists living allies.
	if item.use_heal > 0 and hero.is_alive() and hero.hp < hero.max_hp():
		return true
	if item.use_mp > 0 and hero.is_alive() and hero.mp < hero.max_mp():
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
	# Never consume an item that would have no effect (e.g. a healing potion on
	# a downed hero, which the is_alive() guards below now correctly refuse).
	if not _can_use_consumable(hero, item):
		return
	# Guarded by is_alive() so healing can never resurrect — only a revive item can.
	if item.use_heal > 0 and hero.is_alive():
		hero.hp = mini(hero.max_hp(), hero.hp + item.use_heal)
	if item.use_mp > 0 and hero.is_alive():
		hero.mp = mini(hero.max_mp(), hero.mp + item.use_mp)
	if item.use_sp > 0:
		var mp_gain := Party.award_sp(hero, item.use_sp)
		if mp_gain > 0:
			_flash_message(tr("UI_SP_CONVERT") % [
				hero.display_name(), mp_gain])
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
	# Persist appearance edits (rename) and any equipment changes before leaving.
	GameState.save_game()
	# Back to whichever screen opened us (city hub by default).
	Fade.change_scene(GameState.nav_return_scene)
