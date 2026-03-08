class_name UpgradeCard
extends Button

signal card_selected(upgrade: Resource)

var _upgrade: Resource


func setup(upgrade: Resource) -> void:
	_upgrade = upgrade
	custom_minimum_size = Vector2(200, 300)

	# Build inner layout manually so text wraps nicely
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 16.0
	vbox.offset_top = 16.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -16.0
	vbox.set("theme_override_constants/separation", 12)
	add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = upgrade.display_name
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.3)
	vbox.add_child(sep)

	var desc_lbl := Label.new()
	desc_lbl.text = upgrade.description
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# Normal style
	var normal := StyleBoxFlat.new()
	normal.bg_color = upgrade.icon_color.darkened(0.3)
	normal.border_color = upgrade.icon_color
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(12)
	add_theme_stylebox_override("normal", normal)

	# Hover style — brighter
	var hover := StyleBoxFlat.new()
	hover.bg_color = upgrade.icon_color.darkened(0.05)
	hover.border_color = Color.WHITE
	hover.set_border_width_all(3)
	hover.set_corner_radius_all(12)
	add_theme_stylebox_override("hover", hover)

	# Pressed style
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = upgrade.icon_color.lightened(0.1)
	pressed_style.set_corner_radius_all(12)
	add_theme_stylebox_override("pressed", pressed_style)

	pressed.connect(func() -> void: card_selected.emit(_upgrade))
