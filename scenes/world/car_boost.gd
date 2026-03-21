class_name CarBoost
extends Node

## Boost component — attach as child of RaycastCar.
## Does NOT write max_speed or acceleration directly; CarGears reads
## `multiplier` and applies it so there is a single owner of those values.

const HOLD_REQUIRED:   float = 2.0
const BOOST_DURATION:  float = 4.0
const BOOST_MULTIPLIER: float = 2.5

var is_boosting: bool  = false
var multiplier:  float = 1.0
var hold_time:   float = 0.0
var boost_timer: float = 0.0

var _car: RaycastCar


func _ready() -> void:
	add_to_group("car_boost")
	_car = get_parent() as RaycastCar
	if not _car:
		push_error("CarBoost: parent is not RaycastCar")


func _process(delta: float) -> void:
	if not _car:
		return

	if Input.is_action_pressed("handbreak"):
		if not is_boosting:
			hold_time = minf(hold_time + delta, HOLD_REQUIRED)

	if Input.is_action_just_released("handbreak"):
		if not is_boosting and hold_time >= HOLD_REQUIRED:
			_start_boost()
		hold_time = 0.0

	if is_boosting:
		boost_timer -= delta
		if boost_timer <= 0.0:
			_end_boost()


func _start_boost() -> void:
	is_boosting = true
	multiplier  = BOOST_MULTIPLIER
	boost_timer = BOOST_DURATION


func _end_boost() -> void:
	is_boosting = false
	multiplier  = 1.0
