class_name PauseMenu
extends CanvasLayer
## P / Esc pauses the run and shows what you've got: every upgrade you own as
## its icon with a level badge (hover for what it does), your weapons, and
## totals. Doesn't open over a store (that already pauses with its own shelf).

const MENU := "res://scenes/ui/level_select.tscn"
const WEAPON_ICONS := {
	&"front_gun": "gun", &"garlic": "garlic", &"side_rockets": "rocket", &"ring_fire": "flame_ring",
}

var _panel: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		for key in [KEY_P, KEY_ESCAPE]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event("pause", ev)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open():
		close()
	elif not get_tree().paused:                      # not over a store or another pause
		open()
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel != null


func open() -> void:
	get_tree().paused = true
	_panel = _build()
	add_child(_panel)


func close() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	get_tree().paused = false


## Owned upgrades: [{upgrade, level}], run ones first, then the garage.
static func owned() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in Economy.upgrades():
		var level := GameManager.level_of(u.id)
		if level > 0:
			out.append({upgrade = u, level = level})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.upgrade.store == &"garage") == false and (b.upgrade.store == &"garage") == true)
	return out


func _build() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(centre)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 12)
	centre.add_child(box)

	box.add_child(_label("PAUSED", 44, Color(1.0, 0.85, 0.55)))
	var have := owned()
	var levels := 0
	for o in have:
		levels += int(o.level)
	box.add_child(_label("SCRAP %s     HEALTH %d / %d     %d upgrades, %d levels" % [
		Num.short(GameManager.scrap), GameManager.current_health, GameManager.max_health, have.size(), levels], 18, Color.WHITE))

	box.add_child(_label("UPGRADES  (hover for details)", 20, Color(0.9, 0.8, 0.6)))
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	if have.is_empty():
		box.add_child(_label("Nothing yet: drive into a store to buy upgrades.", 16, Color(0.8, 0.8, 0.8)))
	for o in have:
		var u: Dictionary = o.upgrade
		var badge := "%d/%d" % [o.level, u.max_level] if u.max_level > 1 else ""   # how many of it you have
		grid.add_child(_tile(Economy.icon(u), Economy.rarity_color(u.rarity), badge,
			"%s   (%s)\nLevel %d / %d\n%s" % [u.name, String(u.store).to_upper(), o.level, u.max_level, u.description]))

	box.add_child(_label("WEAPONS", 20, Color(0.9, 0.8, 0.6)))
	var weapons := HBoxContainer.new()
	weapons.add_theme_constant_override("separation", 8)
	box.add_child(weapons)
	for w in GameManager.unlocked_weapons:
		var level: int = GameManager.weapon_levels.get(w, 1)
		var icon := load("res://assets/icons/upgrades/%s.svg" % WEAPON_ICONS.get(w, "gun")) as Texture2D
		weapons.add_child(_tile(icon, Color(1.0, 0.6, 0.4), "Lv %d" % level,
			"%s\nLevel %d" % [String(w).replace("_", " ").capitalize(), level]))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var resume := Button.new()
	resume.text = "RESUME"
	resume.custom_minimum_size = Vector2(180, 44)
	resume.pressed.connect(close)
	buttons.add_child(resume)
	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.custom_minimum_size = Vector2(180, 44)
	menu.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU))
	buttons.add_child(menu)
	resume.grab_focus.call_deferred()
	return dim


## An icon tile with a level badge; hovering shows `tip`.
func _tile(icon: Texture2D, tint: Color, badge: String, tip: String) -> Control:
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(64, 64)
	tile.tooltip_text = tip
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.07, 0.95)
	style.border_color = tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	tile.add_theme_stylebox_override("panel", style)
	var tex := TextureRect.new()
	tex.texture = icon
	tex.modulate = tint
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 8
	tex.offset_top = 8
	tex.offset_right = -8
	tex.offset_bottom = -8
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(tex)
	if badge != "":
		var l := _label(badge, 13, Color.WHITE)
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		l.grow_vertical = Control.GROW_DIRECTION_BEGIN
		l.offset_right = -3
		l.offset_bottom = -1
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(l)
	return tile


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l
