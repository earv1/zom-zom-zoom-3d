class_name CarAirControl
extends Node

## Jump 1: car stays flat (auto-levels).
## Jump 2 (Space in air): unlocks air control + trick detection.
## Landing always zeroes angular momentum.

@export var jump_force: float = 8.0
@export var spin_speed: float = TAU * 1.2   # radians/sec — ~1.2 full rotations per second
@export var level_torque: float = 800.0
@export var level_damping: float = 8.0

signal trick_landed(trick_name: String)

var _car: RigidBody3D
var _wheels: Array[RayCast3D] = []

var _was_grounded := true
var _tricks_unlocked := false
var _trick_pitch_accum := 0.0
var _trick_roll_accum := 0.0
var _prev_pitch := 0.0
var _prev_roll := 0.0


func _ready() -> void:
	_car = get_parent() as RigidBody3D
	if not _car:
		push_error("CarAirControl: parent must be RigidBody3D")
		return
	for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var w := _car.get_node_or_null(wheel_name) as RayCast3D
		if w:
			_wheels.append(w)


func _is_grounded() -> bool:
	for w in _wheels:
		if w.is_colliding():
			return true
	return false


func _physics_process(delta: float) -> void:
	if not _car:
		return

	var grounded := _is_grounded()

	# ── Jump from ground ──────────────────────────────────────────────────────
	if grounded and Input.is_action_just_pressed("jump"):
		_car.apply_central_impulse(_car.global_basis.y * _car.mass * jump_force)

	# ── Takeoff: reset state ──────────────────────────────────────────────────
	if _was_grounded and not grounded:
		_tricks_unlocked = false
		_trick_pitch_accum = 0.0
		_trick_roll_accum = 0.0
		_prev_pitch = 0.0
		_prev_roll = 0.0

	# ── In air ───────────────────────────────────────────────────────────────
	if not grounded:
		if not _tricks_unlocked and Input.is_action_just_pressed("jump"):
			_tricks_unlocked = true

		if _tricks_unlocked:
			_do_air_control(delta)
		else:
			_do_auto_level(delta)

	# ── Landing ───────────────────────────────────────────────────────────────
	if not _was_grounded and grounded:
		_car.angular_velocity = Vector3.ZERO
		if _tricks_unlocked:
			_score_tricks()

	_was_grounded = grounded


func _do_auto_level(delta: float) -> void:
	var current_up := _car.global_basis.y
	var correction := current_up.cross(Vector3.UP)
	_car.apply_torque(correction * level_torque)
	_car.angular_velocity = _car.angular_velocity.lerp(Vector3.ZERO, level_damping * delta)


func _do_air_control(delta: float) -> void:
	var pitch := Input.get_axis("accelerate", "decelerate")
	var roll  := Input.get_axis("turn_left", "turn_right")

	# Only set angular velocity when input changes — don't override physics every frame
	if pitch != _prev_pitch or roll != _prev_roll:
		var local_angvel := _car.global_basis.inverse() * _car.angular_velocity
		local_angvel.x = pitch * spin_speed
		local_angvel.z = roll * spin_speed
		_car.angular_velocity = _car.global_basis * local_angvel
		_prev_pitch = pitch
		_prev_roll = roll

	# Accumulate actual angular velocity for trick detection
	var local_angvel := _car.global_basis.inverse() * _car.angular_velocity
	_trick_pitch_accum += rad_to_deg(local_angvel.x) * delta
	_trick_roll_accum  += rad_to_deg(local_angvel.z) * delta


func _score_tricks() -> void:
	var pitch_flips := int(abs(_trick_pitch_accum) / 360.0)
	var roll_flips  := int(abs(_trick_roll_accum)  / 360.0)

	for i in pitch_flips:
		trick_landed.emit("Backflip" if _trick_pitch_accum > 0 else "Frontflip")

	for i in roll_flips:
		trick_landed.emit("Left Flip" if _trick_roll_accum < 0 else "Right Flip")
