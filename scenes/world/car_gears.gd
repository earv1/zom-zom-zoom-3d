@tool
class_name CarGears
extends Node

## Gear system — attach as child of RaycastCar.
## Gear max speeds are fractions of the car's base max_speed, so the system
## self-calibrates regardless of how the car is tuned.
## Owns max_speed and acceleration each frame; CarBoost feeds in a multiplier.
## acceleration_preview is a read-only inspector curve showing the full profile.

signal gear_changed(from: int, to: int)

# Calibration tool: scripts/calibrate_gears.py — simulates 0→100 and 0→250 km/h,
# plots a velocity-time chart, and solves for accel_scale values to hit timing targets.
# Run with: python3 scripts/calibrate_gears.py

# [speed_frac: fraction of base max_speed, accel_scale: multiplier on base acceleration]
const GEARS := [
	{&"speed_frac": 0.06, &"accel_scale": 1.30},  # 1 — very short launch gear
	{&"speed_frac": 0.15, &"accel_scale": 1.15},  # 2 — still building
	{&"speed_frac": 0.42, &"accel_scale": 1.05},  # 3 — 100 km/h lives here
	{&"speed_frac": 0.72, &"accel_scale": 1.313},  # 4 — long pull (overdrive thrust)
	{&"speed_frac": 1.00, &"accel_scale": 1.170},  # 5 — sustained top-end
]

const UPSHIFT_THRESHOLD   := 0.92  # shift up at 92% of gear's max_speed
const DOWNSHIFT_THRESHOLD := 0.75  # shift down at 75% of previous gear's max_speed
                                   # gap between thresholds prevents gear hunting

@export var acceleration_preview: Curve:
	get: return _preview_curve
	set(_v): _rebuild_preview()

var current_gear: int = 0

var _car: RaycastCar
var _boost: CarBoost
var _air_control: CarAirControl
var _base_acceleration: float
var _base_max_speed: float
var _preview_curve: Curve = Curve.new()


func _ready() -> void:
	_rebuild_preview()
	if Engine.is_editor_hint():
		return

	_car = get_parent() as RaycastCar
	if not _car:
		push_error("CarGears: parent must be RaycastCar")
		return

	_base_acceleration = _car.acceleration
	_base_max_speed    = _car.max_speed

	for child in _car.get_children():
		if child is CarBoost:
			_boost = child as CarBoost
		elif child is CarAirControl:
			_air_control = child as CarAirControl

	_apply_gear()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _car:
		return

	# Don't auto-shift while airborne — prevents gear hunting on landing
	if _air_control and _air_control.state != CarAirControl.State.GROUNDED:
		_apply_gear()
		return

	# Horizontal speed only — excludes suspension bounce on Y axis
	var vel   := _car.linear_velocity
	var speed := Vector2(vel.x, vel.z).length()

	_try_shift(speed)
	_apply_gear()


# ── Shifting ──────────────────────────────────────────────────────────────────

func _try_shift(speed: float) -> void:
	var gear_max: float = _base_max_speed * float(GEARS[current_gear][&"speed_frac"])

	# Upshift
	if current_gear < GEARS.size() - 1:
		if speed >= gear_max * UPSHIFT_THRESHOLD:
			_shift(current_gear + 1)
			return

	# Downshift
	if current_gear > 0:
		var prev_max: float = _base_max_speed * float(GEARS[current_gear - 1][&"speed_frac"])
		if speed < prev_max * DOWNSHIFT_THRESHOLD:
			_shift(current_gear - 1)


func _shift(to: int) -> void:
	var from := current_gear
	current_gear = to
	gear_changed.emit(from, to)


# ── Apply ─────────────────────────────────────────────────────────────────────

func _apply_gear() -> void:
	var gear: Dictionary = GEARS[current_gear]
	var mult: float      = _boost.multiplier if _boost and _boost.is_boosting else 1.0
	_car.max_speed    = _base_max_speed  * float(gear[&"speed_frac"])  * mult
	_car.acceleration = _base_acceleration * float(gear[&"accel_scale"]) * mult


# ── Preview curve ─────────────────────────────────────────────────────────────

func _rebuild_preview() -> void:
	_preview_curve.clear_points()
	_preview_curve.min_value = 0.0
	_preview_curve.max_value = 1.0

	var max_scale: float = float(GEARS[0][&"accel_scale"])

	for i in GEARS.size():
		var gear: Dictionary = GEARS[i]
		var x_start: float = float(GEARS[i - 1][&"speed_frac"]) if i > 0 else 0.0
		var x_end:   float = float(gear[&"speed_frac"])
		var y:       float = float(gear[&"accel_scale"]) / max_scale

		# Flat plateau for this gear
		_preview_curve.add_point(Vector2(x_start, y), 0.0, 0.0,
			Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)

		if i < GEARS.size() - 1:
			# Step down just before next gear — two close points simulate a cliff
			_preview_curve.add_point(Vector2(x_end - 0.001, y), 0.0, 0.0,
				Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
