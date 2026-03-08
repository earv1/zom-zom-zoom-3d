class_name XpOrb
extends Node3D

var car: Node3D
var xp_value: int = 5
var _collecting: bool = false


func _process(delta: float) -> void:
	if not car:
		return
	var dist := global_position.distance_to(car.global_position)
	if dist < GameManager.pickup_radius or _collecting:
		_collecting = true
		global_position = global_position.lerp(car.global_position, delta * 8.0)
		if global_position.distance_to(car.global_position) < 0.8:
			GameManager.add_xp(xp_value)
			queue_free()
