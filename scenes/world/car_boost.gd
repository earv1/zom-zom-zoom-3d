class_name CarBoost
extends Node

const HOLD_REQUIRED: float = 2.0
const BOOST_DURATION: float = 4.0
const BOOST_MULTIPLIER: float = 2.5

var _car: RaycastCar
var _hold_time: float = 0.0
var _boost_timer: float = 0.0
var _is_boosting: bool = false
var _original_max_speed: float
var _original_acceleration: float


func _ready() -> void:
	_car = get_parent() as RaycastCar
	_original_max_speed = _car.max_speed
	_original_acceleration = _car.acceleration


func _process(delta: float) -> void:
	if Input.is_action_pressed("handbreak"):
		if not _is_boosting:
			_hold_time += delta
			if _hold_time >= HOLD_REQUIRED:
				_start_boost()
	else:
		_hold_time = 0.0

	if _is_boosting:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_end_boost()


func _start_boost() -> void:
	_is_boosting = true
	_hold_time = 0.0
	_boost_timer = BOOST_DURATION
	_car.max_speed = _original_max_speed * BOOST_MULTIPLIER
	_car.acceleration = _original_acceleration * BOOST_MULTIPLIER


func _end_boost() -> void:
	_is_boosting = false
	_car.max_speed = _original_max_speed
	_car.acceleration = _original_acceleration
