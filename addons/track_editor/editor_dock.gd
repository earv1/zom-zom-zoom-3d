@tool
extends Control

signal piece_selected(piece_name: String)
signal erase_mode_toggled(active: bool)
signal edit_mode_changed(active: bool)
signal piece_params_changed(params: Dictionary)
signal connect_mode_toggled(active: bool)
signal rotate_requested(step: int)
signal selection_cleared()
signal delete_selection_requested()
signal test_requested()
signal category_changed(category_name: String)
signal connect_from_selection_requested()
signal cancel_requested()
signal layer_changed(delta: int)

const PIECES := [
	{"name": "straight", "label": "Straight", "tag": "Core", "desc": "Fast starter"},
	{"name": "curve", "label": "Curve 90°", "tag": "Core", "desc": "Quarter turn"},
	{"name": "ramp_up", "label": "Ramp Up", "tag": "Flow", "desc": "Gain height"},
	{"name": "bank", "label": "Bank Turn", "tag": "Flow", "desc": "Carry speed"},
	{"name": "jump", "label": "Jump Pad", "tag": "Stunts", "desc": "Launch section"},
	{"name": "loop", "label": "Loop", "tag": "Stunts", "desc": "Big commit"},
]

var _erase_btn: Button
var _edit_btn: Button
var _connect_btn: Button
var _connect_label: Label
var _mode_label: Label
var _selection_label: Label
var _rotation_label: Label
var _layer_label: Label
var _status_label: Label
var _hover_label: Label
var _context_label: Label
var _clear_selection_btn: Button
var _delete_selection_btn: Button
var _rotate_btn: Button
var _test_btn: Button
var _connect_from_selection_btn: Button
var _cancel_btn: Button
var _piece_buttons: Dictionary = {}
var _category_buttons: Dictionary = {}
var _piece_grid: GridContainer
var edit_mode := false
var _props_container: VBoxContainer
var _current_params: Dictionary = {}
var _selected_piece_name := "straight"
var _rotation_turns := 0
var _current_category := "All"

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var title := Label.new()
	title.text = "Track Editor"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	_mode_label = Label.new()
	_mode_label.text = "Mode: Browse"
	_mode_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	root.add_child(_mode_label)

	root.add_child(HSeparator.new())

	var flow_title := Label.new()
	flow_title.text = "Quick Actions"
	root.add_child(flow_title)

	var quick_actions := GridContainer.new()
	quick_actions.columns = 2
	root.add_child(quick_actions)

	_edit_btn = Button.new()
	_edit_btn.text = "Edit OFF"
	_edit_btn.toggle_mode = true
	_edit_btn.toggled.connect(_on_edit_toggled)
	quick_actions.add_child(_edit_btn)

	_test_btn = Button.new()
	_test_btn.text = "Test Drive"
	_test_btn.pressed.connect(func() -> void:
		emit_signal("test_requested")
	)
	quick_actions.add_child(_test_btn)

	_rotate_btn = Button.new()
	_rotate_btn.text = "Rotate 90°"
	_rotate_btn.pressed.connect(func() -> void:
		emit_signal("rotate_requested", 1)
	)
	quick_actions.add_child(_rotate_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.pressed.connect(func() -> void:
		emit_signal("cancel_requested")
	)
	quick_actions.add_child(_cancel_btn)

	_connect_from_selection_btn = Button.new()
	_connect_from_selection_btn.text = "Connect From"
	_connect_from_selection_btn.pressed.connect(func() -> void:
		emit_signal("connect_from_selection_requested")
	)
	quick_actions.add_child(_connect_from_selection_btn)

	_delete_selection_btn = Button.new()
	_delete_selection_btn.text = "Delete"
	_delete_selection_btn.disabled = true
	_delete_selection_btn.pressed.connect(func() -> void:
		emit_signal("delete_selection_requested")
	)
	quick_actions.add_child(_delete_selection_btn)

	_clear_selection_btn = Button.new()
	_clear_selection_btn.text = "Clear Selection"
	_clear_selection_btn.disabled = true
	_clear_selection_btn.pressed.connect(func() -> void:
		emit_signal("selection_cleared")
	)
	quick_actions.add_child(_clear_selection_btn)

	_erase_btn = Button.new()
	_erase_btn.text = "Erase"
	_erase_btn.toggle_mode = true
	_erase_btn.toggled.connect(_on_erase_toggled)
	quick_actions.add_child(_erase_btn)

	_connect_btn = Button.new()
	_connect_btn.text = "Connect"
	_connect_btn.toggle_mode = true
	_connect_btn.toggled.connect(_on_connect_toggled)
	quick_actions.add_child(_connect_btn)

	var spacer := Control.new()
	quick_actions.add_child(spacer)

	_rotation_label = Label.new()
	_rotation_label.text = "Facing: North"
	root.add_child(_rotation_label)

	var layer_row := HBoxContainer.new()
	root.add_child(layer_row)

	var layer_down := Button.new()
	layer_down.text = "Layer -"
	layer_down.pressed.connect(func() -> void:
		emit_signal("layer_changed", -1)
	)
	layer_row.add_child(layer_down)

	_layer_label = Label.new()
	_layer_label.text = "Layer: 0 (0m)"
	_layer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer_row.add_child(_layer_label)

	var layer_up := Button.new()
	layer_up.text = "Layer +"
	layer_up.pressed.connect(func() -> void:
		emit_signal("layer_changed", 1)
	)
	layer_row.add_child(layer_up)

	_context_label = Label.new()
	_context_label.text = "Enable edit mode to start building."
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_label.add_theme_color_override("font_color", Color(0.84, 0.84, 0.84))
	root.add_child(_context_label)

	_hover_label = Label.new()
	_hover_label.text = "Cursor: waiting"
	_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
	root.add_child(_hover_label)

	_connect_label = Label.new()
	_connect_label.text = ""
	_connect_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	root.add_child(_connect_label)

	root.add_child(HSeparator.new())

	var palette_title := Label.new()
	palette_title.text = "Piece Palette"
	root.add_child(palette_title)

	var categories := HBoxContainer.new()
	root.add_child(categories)
	for category_name in ["All", "Core", "Flow", "Stunts"]:
		var btn := Button.new()
		btn.text = category_name
		btn.toggle_mode = true
		btn.pressed.connect(_on_category_pressed.bind(category_name))
		categories.add_child(btn)
		_category_buttons[category_name] = btn

	_piece_grid = GridContainer.new()
	_piece_grid.columns = 2
	root.add_child(_piece_grid)
	_build_piece_palette()

	root.add_child(HSeparator.new())

	var selection_title := Label.new()
	selection_title.text = "Selection"
	root.add_child(selection_title)

	_selection_label = Label.new()
	_selection_label.text = "Nothing selected"
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	root.add_child(_selection_label)

	root.add_child(HSeparator.new())

	var props_label := Label.new()
	props_label.text = "Piece Settings"
	root.add_child(props_label)

	_props_container = VBoxContainer.new()
	root.add_child(_props_container)

	root.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.text = "Pick a piece, then enable edit mode."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	root.add_child(_status_label)

	_on_category_pressed("All")
	_select_piece("straight")
	set_rotation_turns(0)
	set_context_state({
		"title": "Browse pieces or enable edit mode.",
		"hover": "Cursor: waiting",
		"can_connect_from_selection": false,
		"can_cancel": false,
	})

func _build_piece_palette() -> void:
	for child in _piece_grid.get_children():
		child.queue_free()
	_piece_buttons.clear()

	for piece in PIECES:
		if _current_category != "All" and piece.tag != _current_category:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 62)
		btn.toggle_mode = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = "%s\n%s • %s" % [piece.label, piece.tag, piece.desc]
		btn.pressed.connect(_on_piece_btn_pressed.bind(piece.name))
		_piece_grid.add_child(btn)
		_piece_buttons[piece.name] = btn

func _on_piece_btn_pressed(piece_name: String) -> void:
	_select_piece(piece_name)

func _on_category_pressed(category_name: String) -> void:
	_current_category = category_name
	for key in _category_buttons:
		_category_buttons[key].button_pressed = (key == category_name)
	_build_piece_palette()
	if _piece_buttons.has(_selected_piece_name):
		_piece_buttons[_selected_piece_name].button_pressed = true
	emit_signal("category_changed", category_name)

func _select_piece(piece_name: String) -> void:
	_selected_piece_name = piece_name
	for key in _piece_buttons:
		_piece_buttons[key].button_pressed = (key == piece_name)
	if _erase_btn:
		_erase_btn.button_pressed = false
	emit_signal("piece_selected", piece_name)
	set_status("Placement piece: %s" % piece_name.capitalize())
	_update_mode_label()

func _on_erase_toggled(active: bool) -> void:
	if active:
		for key in _piece_buttons:
			_piece_buttons[key].button_pressed = false
		if _connect_btn:
			_connect_btn.button_pressed = false
	emit_signal("erase_mode_toggled", active)
	set_status("Click a placed piece to remove it." if active else "Erase mode disabled.")
	_update_mode_label()

func _on_connect_toggled(active: bool) -> void:
	if active:
		if _erase_btn:
			_erase_btn.button_pressed = false
		_connect_label.text = "Click first piece"
	else:
		_connect_label.text = ""
	emit_signal("connect_mode_toggled", active)
	set_status("Select two pieces to create a connector." if active else "Connect mode disabled.")
	_update_mode_label()

func set_connect_status(text: String) -> void:
	if _connect_label:
		_connect_label.text = text

func set_connect_active(active: bool) -> void:
	if _connect_btn:
		_connect_btn.button_pressed = active
	if not active and _connect_label:
		_connect_label.text = ""
	_update_mode_label()

func _on_edit_toggled(active: bool) -> void:
	edit_mode = active
	_edit_btn.text = "Edit ON" if active else "Edit OFF"
	emit_signal("edit_mode_changed", active)
	set_status("Edit mode enabled." if active else "Edit mode disabled.")
	_update_mode_label()

func show_params(param_defs: Array, current: Dictionary) -> void:
	_current_params = current.duplicate()
	clear_params()
	for def in param_defs:
		var hbox := HBoxContainer.new()

		var lbl := Label.new()
		lbl.text = def.label
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		var slider := HSlider.new()
		slider.min_value = def.min
		slider.max_value = def.max
		slider.step = def.step
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 80
		hbox.add_child(slider)

		var val_lbl := Label.new()
		val_lbl.text = "%.1f" % current.get(def.name, def.default)
		val_lbl.custom_minimum_size.x = 36
		hbox.add_child(val_lbl)

		slider.value = current.get(def.name, def.default)

		var param_name: String = def.name
		slider.value_changed.connect(func(v: float) -> void:
			val_lbl.text = "%.1f" % v
			_current_params[param_name] = v
			_emit_params()
		)

		_props_container.add_child(hbox)

func clear_params() -> void:
	if _props_container == null:
		return
	for child in _props_container.get_children():
		child.queue_free()

func _emit_params() -> void:
	emit_signal("piece_params_changed", _current_params)

func set_rotation_turns(turns: int) -> void:
	_rotation_turns = posmod(turns, 4)
	if _rotation_label == null:
		return
	var names := ["North", "East", "South", "West"]
	_rotation_label.text = "Facing: %s" % names[_rotation_turns]

func set_layer(layer_index: int, world_y: float) -> void:
	if _layer_label:
		_layer_label.text = "Layer: %d (%.0fm)" % [layer_index, world_y]

func set_selection_info(text: String, has_selection: bool) -> void:
	if _selection_label:
		_selection_label.text = text
	if _clear_selection_btn:
		_clear_selection_btn.disabled = not has_selection
	if _delete_selection_btn:
		_delete_selection_btn.disabled = not has_selection

func set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text

func set_context_state(data: Dictionary) -> void:
	if _context_label:
		_context_label.text = data.get("title", _context_label.text)
	if _hover_label:
		_hover_label.text = data.get("hover", _hover_label.text)
	if _connect_from_selection_btn:
		_connect_from_selection_btn.disabled = not data.get("can_connect_from_selection", false)
	if _cancel_btn:
		_cancel_btn.disabled = not data.get("can_cancel", false)
	if _rotate_btn:
		_rotate_btn.disabled = not data.get("can_rotate", true)

func _update_mode_label() -> void:
	if _mode_label == null:
		return
	if not edit_mode:
		_mode_label.text = "Mode: Browse"
	elif _connect_btn and _connect_btn.button_pressed:
		_mode_label.text = "Mode: Connect"
	elif _erase_btn and _erase_btn.button_pressed:
		_mode_label.text = "Mode: Erase"
	else:
		_mode_label.text = "Mode: Place %s" % _selected_piece_name.capitalize()
