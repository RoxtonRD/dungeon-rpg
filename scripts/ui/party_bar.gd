## Shared builder for the compact party status strip: one column per hero
## with their name, a red HP bar and an MP bar below it, each with its
## current/max text. Used by the dungeon map and the city hub headers.
class_name PartyBar
extends RefCounted


## Clears `container` and fills it with one entry per party hero.
static func fill(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()
	for h in Party.heroes:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)

		var name_lbl := Label.new()
		name_lbl.text = h.display_name()
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

		var mp_bar := ProgressBar.new()
		mp_bar.theme_type_variation = "MpBar"
		mp_bar.custom_minimum_size = Vector2(0, 10)
		mp_bar.show_percentage = false
		mp_bar.max_value = maxi(1, h.max_mp())
		mp_bar.value = h.mp
		col.add_child(mp_bar)

		var mp_lbl := Label.new()
		mp_lbl.text = "%d/%d" % [h.mp, h.max_mp()]
		mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mp_lbl.add_theme_font_size_override("font_size", 11)
		mp_lbl.modulate = Color(0.8, 0.8, 0.85)
		col.add_child(mp_lbl)

		container.add_child(col)
