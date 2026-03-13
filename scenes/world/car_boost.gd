class_name CarBoost
extends Node

const HOLD_REQUIRED: float = 2.0
const BOOST_DURATION: float = 4.0
const BOOST_MULTIPLIER: float = 2.5

var _car: RaycastCar
var hold_time: float = 0.0
var boost_timer: float = 0.0
var is_boosting: bool = false
var _original_max_speed: float
var _original_acceleration: float


func _ready() -> void:
	add_to_group("car_boost")
	_car = get_parent() as RaycastCar
	if not _car:
		call_deferred(&"_init_car")
		return
	_init_car()


func _init_car() -> void:
	if not _car:
		_car = get_parent() as RaycastCar
	if not _car:
		push_error("CarBoost: parent is not RaycastCar")
		return
	_original_max_speed = _car.max_speed
	_original_acceleration = _car.acceleration


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
	boost_timer = BOOST_DURATION
	_car.max_speed = _original_max_speed * BOOST_MULTIPLIER
	_car.acceleration = _original_acceleration * BOOST_MULTIPLIER


func _end_boost() -> void:
	is_boosting = false
	_car.max_speed = _original_max_speed
	_car.acceleration = _original_acceleration
