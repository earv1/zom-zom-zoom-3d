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

enum State { GROUNDED, AIRBORNE, TRICKS }

var state: State = State.GROUNDED

var _car: RigidBody3D
var _wheels: Array[RayCast3D] = []
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

	match state:
		State.GROUNDED:
			_tick_grounded(grounded)
		State.AIRBORNE:
			_tick_airborne(delta, grounded)
		State.TRICKS:
			_tick_tricks(delta, grounded)


# ── GROUNDED ──────────────────────────────────────────────────────────────────

func _tick_grounded(grounded: bool) -> void:
	if Input.is_action_just_pressed("jump"):
		_car.apply_central_impulse(_car.global_basis.y * _car.mass * jump_force)

	if not grounded:
		_transition(State.AIRBORNE)


func _enter_grounded() -> void:
	_car.angular_velocity = Vector3.ZERO


# ── AIRBORNE ──────────────────────────────────────────────────────────────────

func _tick_airborne(delta: float, grounded: bool) -> void:
	if grounded:
		_transition(State.GROUNDED)
		return

	if Input.is_action_just_pressed("jump"):
		_transition(State.TRICKS)
		return

	_do_auto_level(delta)


func _enter_airborne() -> void:
	_trick_pitch_accum = 0.0
	_trick_roll_accum  = 0.0
	_prev_pitch = 0.0
	_prev_roll  = 0.0


# ── TRICKS ────────────────────────────────────────────────────────────────────

func _tick_tricks(delta: float, grounded: bool) -> void:
	if grounded:
		_score_tricks()
		_transition(State.GROUNDED)
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

	if pitch != _prev_pitch or roll != _prev_roll:
		var local_angvel := _car.global_basis.inverse() * _car.angular_velocity
		local_angvel.x = pitch * spin_speed
		local_angvel.z = roll  * spin_speed
		_car.angular_velocity = _car.global_basis * local_angvel
		_prev_pitch = pitch
		_prev_roll  = roll

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
