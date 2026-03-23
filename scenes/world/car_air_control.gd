class_name CarAirControl
extends Node

## Jump from ground, then do directional tricks in the air.
## Full sequence required: Up→Right→Down→Left = clockwise 360.
## Full sequence required: Up→Left→Down→Right = counter-clockwise 360.
## Landing always zeroes angular momentum.

@export var jump_force: float = 10.0
@export var spin_duration: float = 0.5  # seconds per 360
@export var level_torque: float = 800.0
@export var level_damping: float = 8.0

signal trick_landed(trick_name: String, spin_count: int)
signal trick_input(dir: Dir, success: bool, seq_index: int)
signal trick_sequence_reset()
signal trick_spin_started()
signal trick_spin_ended()

enum State { GROUNDED, AIRBORNE, SPINNING }
enum Dir { UP, RIGHT, DOWN, LEFT, NONE }

var state: State = State.GROUNDED

var _car: RigidBody3D
var _wheels: Array[RayCast3D] = []
var _spin_dir := 0  # -1 CCW, 1 CW
var _spin_progress := 0.0
var _spin_count := 0
var _seq_index := 0  # 0-3: which direction in the sequence we expect next
var _last_dir: Dir = Dir.NONE
var _chain_queued := false
var _seq_timer := 0.0
const SEQ_TIMEOUT := 1.5  # seconds to complete the sequence


func _ready() -> void:
	_car = get_parent() as RigidBody3D
	if not _car:
		push_error("CarAirControl: parent must be RigidBody3D")
		return
	_car.contact_monitor = true
	_car.max_contacts_reported = 4
	for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var w := _car.get_node_or_null(wheel_name) as RayCast3D
		if w:
			_wheels.append(w)


func _any_contact() -> bool:
	for w in _wheels:
		if w.is_colliding():
			return true
	if _car.get_contact_count() > 0:
		return true
	return false


func _physics_process(delta: float) -> void:
	if not _car:
		return

	match state:
		State.GROUNDED:
			_tick_grounded()
		State.AIRBORNE:
			_tick_airborne(delta)
		State.SPINNING:
			_tick_spinning(delta)


# ── GROUNDED ──────────────────────────────────────────────────────────────────

func _tick_grounded() -> void:
	if Input.is_action_just_pressed("jump"):
		_car.apply_central_impulse(_car.global_basis.y * _car.mass * jump_force)

	if not _any_contact():
		state = State.AIRBORNE
		_reset_trick_state()


func _enter_grounded() -> void:
	if _spin_count > 0:
		var name_str := "CW Spin" if _spin_dir > 0 else "CCW Spin"
		trick_landed.emit(name_str, _spin_count)
	_car.angular_velocity = Vector3.ZERO
	_reset_trick_state()


# ── AIRBORNE ──────────────────────────────────────────────────────────────────

func _tick_airborne(delta: float) -> void:
	if _any_contact():
		_enter_grounded()
		state = State.GROUNDED
		return

	_read_sequence_input(delta)
	_do_auto_level(delta)


func _read_sequence_input(delta: float) -> void:
	# Timeout the sequence if too slow
	if _seq_index > 0:
		_seq_timer += delta
		if _seq_timer > SEQ_TIMEOUT:
			_seq_index = 0
			_spin_dir = 0
			_seq_timer = 0.0
			trick_sequence_reset.emit()

	var dir := _get_just_pressed()
	if dir != Dir.NONE:
		_advance_sequence(dir)


func _advance_sequence(dir: Dir) -> void:
	# Sequence step 0: must be UP
	if _seq_index == 0:
		if dir == Dir.UP:
			_seq_index = 1
			_seq_timer = 0.0
			trick_input.emit(dir, true, 0)
		else:
			trick_input.emit(dir, false, 0)
		return

	# Step 1: RIGHT or LEFT determines direction
	if _seq_index == 1:
		if dir == Dir.RIGHT:
			_spin_dir = -1  # CW visual: Up→Right→Down→Left
			_seq_index = 2
			trick_input.emit(dir, true, 1)
		elif dir == Dir.LEFT:
			_spin_dir = 1  # CCW visual: Up→Left→Down→Right
			_seq_index = 2
			trick_input.emit(dir, true, 1)
		else:
			trick_input.emit(dir, false, 1)
			_seq_index = 0
			trick_sequence_reset.emit()
		return

	# Step 2: must be DOWN
	if _seq_index == 2:
		if dir == Dir.DOWN:
			_seq_index = 3
			trick_input.emit(dir, true, 2)
		else:
			trick_input.emit(dir, false, 2)
			_seq_index = 0
			_spin_dir = 0
			trick_sequence_reset.emit()
		return

	# Step 3: must be LEFT (CW) or RIGHT (CCW)
	if _seq_index == 3:
		var expected: Dir = Dir.RIGHT if _spin_dir > 0 else Dir.LEFT
		if dir == expected:
			trick_input.emit(dir, true, 3)
			# Full sequence complete — start spinning!
			_start_spin()
		else:
			trick_input.emit(dir, false, 3)
			_seq_index = 0
			_spin_dir = 0
			trick_sequence_reset.emit()


func _start_spin() -> void:
	_spin_progress = 0.0
	_spin_count = 0
	_chain_queued = false
	_seq_index = 0
	_last_dir = Dir.NONE
	state = State.SPINNING
	trick_spin_started.emit()


# ── SPINNING ──────────────────────────────────────────────────────────────────

func _tick_spinning(delta: float) -> void:
	if _any_contact():
		_enter_grounded()
		state = State.GROUNDED
		return

	var rate := TAU / spin_duration
	_spin_progress += delta / spin_duration

	# Yaw spin
	_car.angular_velocity = Vector3.UP * rate * float(_spin_dir)

	# Keep car level during spin
	var current_up := _car.global_basis.y
	var correction := current_up.cross(Vector3.UP)
	_car.apply_torque(correction * level_torque * 2.0)

	# Check for chain input during spin
	_read_chain_input()

	if _spin_progress >= 1.0:
		_spin_count += 1
		_spin_progress -= 1.0

		if _chain_queued:
			_chain_queued = false
		else:
			_car.angular_velocity = Vector3.ZERO
			state = State.AIRBORNE
			trick_spin_ended.emit()
			_seq_index = 0
			_last_dir = Dir.NONE


func _read_chain_input() -> void:
	var cur_dir := _get_just_pressed()
	if cur_dir == Dir.NONE:
		return

	# Same 4-step sequence to queue another spin
	if _seq_index == 0 and cur_dir == Dir.UP:
		_seq_index = 1
	elif _seq_index == 1:
		var expected_2: Dir = Dir.LEFT if _spin_dir > 0 else Dir.RIGHT
		if cur_dir == expected_2:
			_seq_index = 2
		else:
			_seq_index = 0
	elif _seq_index == 2 and cur_dir == Dir.DOWN:
		_seq_index = 3
	elif _seq_index == 3:
		var expected_4: Dir = Dir.RIGHT if _spin_dir > 0 else Dir.LEFT
		if cur_dir == expected_4:
			_chain_queued = true
			_seq_index = 0
		else:
			_seq_index = 0
	else:
		_seq_index = 0


# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_just_pressed() -> Dir:
	if Input.is_action_just_pressed("accelerate"):
		return Dir.UP
	elif Input.is_action_just_pressed("decelerate"):
		return Dir.DOWN
	elif Input.is_action_just_pressed("turn_right"):
		return Dir.RIGHT
	elif Input.is_action_just_pressed("turn_left"):
		return Dir.LEFT
	return Dir.NONE


func _reset_trick_state() -> void:
	_spin_dir = 0
	_spin_progress = 0.0
	_spin_count = 0
	_seq_index = 0
	_last_dir = Dir.NONE
	_chain_queued = false
	_seq_timer = 0.0
	trick_sequence_reset.emit()


func _do_auto_level(delta: float) -> void:
	var current_up := _car.global_basis.y
	var correction := current_up.cross(Vector3.UP)
	_car.apply_torque(correction * level_torque)
	_car.angular_velocity = _car.angular_velocity.lerp(Vector3.ZERO, level_damping * delta)
