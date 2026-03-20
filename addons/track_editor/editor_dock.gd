@tool
extends Control

signal piece_selected(piece_name: String)
signal erase_mode_toggled(active: bool)
signal edit_mode_changed(active: bool)
signal piece_params_changed(params: Dictionary)
signal connect_mode_toggled(active: bool)

var _erase_btn: Button
var _edit_btn: Button
var _connect_btn: Button
var _connect_label: Label
var _piece_buttons: Dictionary = {}
var edit_mode := false
var _props_container: VBoxContainer
var _current_params: Dictionary = {}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title := Label.new()
	title.text = "Track Editor"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	root.add_child(HSeparator.new())

	_edit_btn = Button.new()
	_edit_btn.text = "● Edit Mode OFF"
	_edit_btn.toggle_mode = true
	_edit_btn.toggled.connect(_on_edit_toggled)
	root.add_child(_edit_btn)

	root.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "R = rotate  RMB = erase"
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	root.add_child(hint)

	root.add_child(HSeparator.new())

	var pieces_label := Label.new()
	pieces_label.text = "Pieces"
	root.add_child(pieces_label)

	var grid := GridContainer.new()
	grid.columns = 2
	root.add_child(grid)

	var pieces := [
		["straight", "Straight"],
		["curve",    "Curve 90°"],
		["ramp_up",  "Ramp Up"],
		["loop",     "Loop"],
		["bank",     "Bank Turn"],
		["jump",     "Jump Pad"],
	]

	for p in pieces:
		var btn := Button.new()
		btn.text = p[1]
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_piece_btn_pressed.bind(p[0], btn))
		grid.add_child(btn)
		_piece_buttons[p[0]] = btn

	root.add_child(HSeparator.new())

	_erase_btn = Button.new()
	_erase_btn.text = "Erase Mode"
	_erase_btn.toggle_mode = true
	_erase_btn.toggled.connect(_on_erase_toggled)
	root.add_child(_erase_btn)

	_connect_btn = Button.new()
	_connect_btn.text = "Connect Pieces"
	_connect_btn.toggle_mode = true
	_connect_btn.toggled.connect(_on_connect_toggled)
	root.add_child(_connect_btn)

	_connect_label = Label.new()
	_connect_label.text = ""
	_connect_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	root.add_child(_connect_label)

	root.add_child(HSeparator.new())

	var props_label := Label.new()
	props_label.text = "Properties"
	root.add_child(props_label)

	_props_container = VBoxContainer.new()
	root.add_child(_props_container)

	# select straight by default
	_select_piece("straight")

func _on_piece_btn_pressed(piece_name: String, btn: Button) -> void:
	_select_piece(piece_name)

func _select_piece(piece_name: String) -> void:
	for key in _piece_buttons:
		_piece_buttons[key].button_pressed = (key == piece_name)
	if _erase_btn:
		_erase_btn.button_pressed = false
	emit_signal("piece_selected", piece_name)

func _on_erase_toggled(active: bool) -> void:
	if active:
		for key in _piece_buttons:
			_piece_buttons[key].button_pressed = false
		if _connect_btn:
			_connect_btn.button_pressed = false
	emit_signal("erase_mode_toggled", active)

func _on_connect_toggled(active: bool) -> void:
	if active:
		if _erase_btn:
			_erase_btn.button_pressed = false
		_connect_label.text = "Click first piece"
	else:
		_connect_label.text = ""
	emit_signal("connect_mode_toggled", active)

func set_connect_status(text: String) -> void:
	if _connect_label:
		_connect_label.text = text

func set_connect_active(active: bool) -> void:
	if _connect_btn:
		_connect_btn.button_pressed = active
	if not active and _connect_label:
		_connect_label.text = ""

func _on_edit_toggled(active: bool) -> void:
	edit_mode = active
	_edit_btn.text = "● Edit Mode ON" if active else "● Edit Mode OFF"
	emit_signal("edit_mode_changed", active)

# ── property sliders ──────────────────────────────────────────────────────────

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

		# Set value before connecting to avoid triggering value_changed on init
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
