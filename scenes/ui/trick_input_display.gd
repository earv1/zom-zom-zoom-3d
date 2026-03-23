extends Control

## Fighting-game style arrow sequence display for air tricks.
## Shows 4 arrow slots: completed steps glow green, current step pulses,
## failed input flashes red, idle steps are dim.

const ARROW_SPACING := 72.0
const ARROW_SIZE := 56.0
const DISPLAY_TIME := 2.0  # seconds to stay visible after last input
const FLASH_TIME := 0.4

# Arrow glyphs indexed by CarAirControl.Dir enum order: UP, RIGHT, DOWN, LEFT
const ARROWS := ["↑", "→", "↓", "←"]

# CW sequence: Up→Right→Down→Left,  CCW: Up→Left→Down→Right
const CW_SEQ := [0, 1, 2, 3]   # Dir.UP, RIGHT, DOWN, LEFT
const CCW_SEQ := [0, 3, 2, 1]  # Dir.UP, LEFT, DOWN, RIGHT

var _steps_completed := 0
var _current_seq: Array = []  # which sequence we're showing
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
		# Determine sequence direction after step 1
		if seq_index == 1:
			if dir == 1:  # Dir.RIGHT
				_current_seq = CW_SEQ
			elif dir == 3:  # Dir.LEFT
				_current_seq = CCW_SEQ
		elif seq_index == 0:
			_current_seq = []  # direction not yet known
	else:
		# Failed — flash then reset
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
	_display_timer = 0.0  # stay visible while spinning
	_steps_completed = 4


func on_spin_ended() -> void:
	_spinning = false
	_visible = false
	_steps_completed = 0
	_current_seq = []


func _draw() -> void:
	if not _visible:
		return

	var font := ThemeDB.fallback_font
	var fsize := int(ARROW_SIZE)
	var origin := Vector2(20, 50)

	# If no direction chosen yet (only UP pressed), show both possible sequences dimly
	var seq: Array = _current_seq if _current_seq.size() == 4 else CW_SEQ

	for i in range(4):
		var pos := origin + Vector2(i * ARROW_SPACING, 0)
		var glyph: String = ARROWS[seq[i]]
		var color: Color

		if _spinning:
			# All green while spinning
			color = Color(0.3, 1.0, 0.5)
		elif i < _steps_completed:
			# Completed step — green
			color = Color(0.3, 1.0, 0.5)
		elif i == _flash_index and _flash_timer > 0.0:
			if _flash_success:
				color = Color(0.3, 1.0, 0.5)
			else:
				# Failed — red flash
				var t := _flash_timer / FLASH_TIME
				color = Color(1.0, 0.2, 0.2, t)
		elif i == _steps_completed:
			# Current expected step — pulsing white
			var pulse := 0.6 + sin(Time.get_ticks_msec() * 0.008) * 0.4
			color = Color(1.0, 1.0, 1.0, pulse)
		else:
			# Future step — dim
			color = Color(1.0, 1.0, 1.0, 0.25)

		# If direction unknown, show "?" for steps 1 and 3
		if _current_seq.size() == 0 and i >= 1 and _steps_completed <= 1:
			if i == 1:
				glyph = "←/→"
				# Draw smaller
				var small_size := int(ARROW_SIZE * 0.6)
				var text_w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size).x
				draw_string(font, pos + Vector2(-text_w * 0.3, 0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size, color)
				continue
			elif i == 2:
				glyph = ARROWS[2]  # DOWN is always step 2
			elif i == 3:
				glyph = "?"

		# Shadow
		draw_string(font, pos + Vector2(1, 1), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0, 0, 0, 0.6 * color.a))
		# Glyph
		draw_string(font, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, color)

	# Label
	if _spinning:
		var label_pos := origin + Vector2(4 * ARROW_SPACING + 8, 0)
		draw_string(font, label_pos + Vector2(1, 1), "SPIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0, 0, 0, 0.6))
		draw_string(font, label_pos, "SPIN!", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.3, 1.0, 0.8))
