@tool
extends Control

signal piece_selected(piece_name: String)
signal erase_mode_toggled(active: bool)

var _erase_btn: Button
var _piece_buttons: Dictionary = {}

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
	emit_signal("erase_mode_toggled", active)
