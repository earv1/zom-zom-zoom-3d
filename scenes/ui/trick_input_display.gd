extends Control

## Fighting-game style arrow sequence display for air tricks.
## Draws triangle arrows instead of Unicode glyphs for web compatibility.

const ARROW_SPACING := 72.0
const ARROW_SIZE := 24.0  # triangle half-size
const DISPLAY_TIME := 2.0
const FLASH_TIME := 0.4

# Direction vectors for triangle arrows: UP, RIGHT, DOWN, LEFT
const DIR_VECTORS := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

# CW sequence: Up→Right→Down→Left,  CCW: Up→Left→Down→Right
const CW_SEQ := [0, 1, 2, 3]
const CCW_SEQ := [0, 3, 2, 1]

var _steps_completed := 0
var _current_seq: Array = []
var _display_timer := 0.0
var _flash_timer := 0.0
var _flash_success := true
var _flash_index := -1
var _visible := false
var _spinning := false


func _process(delta: float) -> void:
	if _display_timer > 0.0:
		_display_timer -= delta
		if _display_timer <= 0.0:
			_visible = false
			_steps_completed = 0
			_current_seq = []
	if _flash_timer > 0.0:
		_flash_timer -= delta
	queue_redraw()


func on_trick_input(dir: int, success: bool, seq_index: int) -> void:
	_visible = true
	_display_timer = DISPLAY_TIME
	_flash_timer = FLASH_TIME
	_flash_success = success
	_flash_index = seq_index

	if success:
		_steps_completed = seq_index + 1
		if seq_index == 1:
			if dir == 1:  # Dir.RIGHT
				_current_seq = CW_SEQ
			elif dir == 3:  # Dir.LEFT
				_current_seq = CCW_SEQ
		elif seq_index == 0:
			_current_seq = []
	else:
		_display_timer = FLASH_TIME + 0.2


func on_sequence_reset() -> void:
	if _steps_completed > 0 and _flash_timer <= 0.0:
		_visible = false
	_steps_completed = 0
	_current_seq = []
	_spinning = false


func on_spin_started() -> void:
	_spinning = true
	_visible = true
	_display_timer = 0.0
	_steps_completed = 4


func on_spin_ended() -> void:
	_spinning = false
	_visible = false
	_steps_completed = 0
	_current_seq = []


func _draw() -> void:
	if not _visible:
		return

	var origin := Vector2(20 + ARROW_SIZE, 50)
	var seq: Array = _current_seq if _current_seq.size() == 4 else CW_SEQ

	for i in range(4):
		var center := origin + Vector2(i * ARROW_SPACING, 0)
		var color := _get_step_color(i)

		if _current_seq.size() == 0 and i >= 1 and _steps_completed <= 1:
			if i == 1:
				# Unknown direction — draw both L/R smaller
				_draw_arrow_triangle(center + Vector2(-14, 0), 3, color, 0.6)
				_draw_arrow_triangle(center + Vector2(14, 0), 1, color, 0.6)
				continue
			elif i == 3:
				# Draw "?" using font
				var font := ThemeDB.fallback_font
				draw_string(font, center + Vector2(-8, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, color)
				continue

		_draw_arrow_triangle(center, seq[i], color)

	if _spinning:
		var font := ThemeDB.fallback_font
		var label_pos := origin + Vector2(4 * ARROW_SPACING + 8, 8)
		draw_string(font, label_pos + Vector2(1, 1), "SPIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0, 0, 0, 0.6))
		draw_string(font, label_pos, "SPIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.3, 1.0, 0.8))


func _get_step_color(i: int) -> Color:
	if _spinning:
		return Color(0.3, 1.0, 0.5)
	elif i < _steps_completed:
		return Color(0.3, 1.0, 0.5)
	elif i == _flash_index and _flash_timer > 0.0:
		if _flash_success:
			return Color(0.3, 1.0, 0.5)
		else:
			return Color(1.0, 0.2, 0.2, _flash_timer / FLASH_TIME)
	elif i == _steps_completed:
		var pulse := 0.6 + sin(Time.get_ticks_msec() * 0.008) * 0.4
		return Color(1.0, 1.0, 1.0, pulse)
	else:
		return Color(1.0, 1.0, 1.0, 0.25)


func _draw_arrow_triangle(center: Vector2, dir_index: int, color: Color, scale := 1.0) -> void:
	var dir: Vector2 = DIR_VECTORS[dir_index]
	var perp := Vector2(-dir.y, dir.x)
	var s := ARROW_SIZE * scale

	var tip := center + dir * s
	var base_l := center - dir * s * 0.4 + perp * s * 0.7
	var base_r := center - dir * s * 0.4 - perp * s * 0.7
	var points := PackedVector2Array([tip, base_l, base_r])

	# Shadow
	var shadow_offset := Vector2(2, 2)
	draw_colored_polygon(
		PackedVector2Array([tip + shadow_offset, base_l + shadow_offset, base_r + shadow_offset]),
		Color(0, 0, 0, 0.5 * color.a)
	)
	# Fill
	draw_colored_polygon(points, color)
	# Outline
	draw_polyline(PackedVector2Array([tip, base_l, base_r, tip]), Color(0, 0, 0, 0.8 * color.a), 2.0, true)
