class_name CarAirControl
extends Node

## Jump 1: car stays flat (auto-levels).
## Jump 2 (Space in air): unlocks air control + trick detection.
## Landing always zeroes angular momentum.

@export var jump_force: float = 8.0
@export var spin_accel: float = TAU * 2.25    # radians/sec² — how fast spin ramps up
@export var max_spin_speed: float = TAU * 1.125  # radians/sec — cap so it doesn't go crazy
@export var level_torque: float = 800.0
@export var level_damping: float = 8.0

signal trick_landed(trick_name: String)

enum State { GROUNDED, AIRBORNE, TRICKS }

var state: State = State.GROUNDED

var _car: RigidBody3D
var _wheels: Array[RayCast3D] = []
var _trick_pitch_accum := 0.0
var _trick_roll_accum := 0.0


func _ready() -> void:
	_car = get_parent() as RigidBody3D
	if not _car:
		push_error("CarAirControl: parent must be RigidBody3D")
		return
	# Enable contact monitoring so we can detect body-to-ground collisions
	_car.contact_monitor = true
	_car.max_contacts_reported = 4
	for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var w := _car.get_node_or_null(wheel_name) as RayCast3D
		if w:
			_wheels.append(w)


func _any_contact() -> bool:
	# Wheels touching ground
	for w in _wheels:
		if w.is_colliding():
			return true
	# Car body touching anything (roof/side hits ground)
	if _car.get_contact_count() > 0:
		return true
	return false


func _all_grounded() -> bool:
	for w in _wheels:
		if not w.is_colliding():
			return false
	return true


func _physics_process(delta: float) -> void:
	if not _car:
		return

	match state:
		State.GROUNDED:
			_tick_grounded()
		State.AIRBORNE:
			_tick_airborne(delta)
		State.TRICKS:
			_tick_tricks(delta)


# ── GROUNDED ──────────────────────────────────────────────────────────────────

func _tick_grounded() -> void:
	if Input.is_action_just_pressed("jump"):
		_car.apply_central_impulse(_car.global_basis.y * _car.mass * jump_force)

	if not _any_contact():
		_transition(State.AIRBORNE)


func _enter_grounded() -> void:
	_car.angular_velocity = Vector3.ZERO


# ── AIRBORNE ──────────────────────────────────────────────────────────────────

func _tick_airborne(delta: float) -> void:
	if _all_grounded():
		_transition(State.GROUNDED)
		return

	if Input.is_action_just_pressed("jump"):
		_transition(State.TRICKS)
		return

	_do_auto_level(delta)


func _enter_airborne() -> void:
	_trick_pitch_accum = 0.0
	_trick_roll_accum  = 0.0


# ── TRICKS ────────────────────────────────────────────────────────────────────

func _tick_tricks(delta: float) -> void:
	# Any ground contact (wheels OR car body) instantly kills trick mode
	if _any_contact():
		_score_tricks()
		# Must wait for all 4 wheels down before fully grounded
		_transition(State.AIRBORNE)
		return

	_do_air_control(delta)


func _enter_tricks() -> void:
	pass


# ── Transitions ───────────────────────────────────────────────────────────────

func _transition(next: State) -> void:
	state = next
	match next:
		State.GROUNDED: _enter_grounded()
		State.AIRBORNE: _enter_airborne()
		State.TRICKS:   _enter_tricks()


# ── Behaviours ────────────────────────────────────────────────────────────────

func _do_auto_level(delta: float) -> void:
	var current_up := _car.global_basis.y
	var correction := current_up.cross(Vector3.UP)
	_car.apply_torque(correction * level_torque)
	_car.angular_velocity = _car.angular_velocity.lerp(Vector3.ZERO, level_damping * delta)


func _do_air_control(delta: float) -> void:
	var pitch := Input.get_axis("accelerate", "decelerate")
	var roll  := Input.get_axis("turn_left", "turn_right")

	var local_angvel := _car.global_basis.inverse() * _car.angular_velocity

	# Accelerate spin with input, decelerate when released
	if absf(pitch) > 0.01:
		local_angvel.x += pitch * spin_accel * delta
	else:
		local_angvel.x = move_toward(local_angvel.x, 0.0, spin_accel * 0.5 * delta)

	if absf(roll) > 0.01:
		local_angvel.z += roll * spin_accel * delta
	else:
		local_angvel.z = move_toward(local_angvel.z, 0.0, spin_accel * 0.5 * delta)

	# Cap so it doesn't go out of control
	local_angvel.x = clampf(local_angvel.x, -max_spin_speed, max_spin_speed)
	local_angvel.z = clampf(local_angvel.z, -max_spin_speed, max_spin_speed)

	_car.angular_velocity = _car.global_basis * local_angvel

	_trick_pitch_accum += rad_to_deg(local_angvel.x) * delta
	_trick_roll_accum  += rad_to_deg(local_angvel.z) * delta


func _score_tricks() -> void:
	var pitch_flips := int(abs(_trick_pitch_accum) / 360.0)
	var roll_flips  := int(abs(_trick_roll_accum)  / 360.0)

	for i in pitch_flips:
		trick_landed.emit("Backflip" if _trick_pitch_accum > 0 else "Frontflip")

	for i in roll_flips:
		trick_landed.emit("Left Flip" if _trick_roll_accum < 0 else "Right Flip")
