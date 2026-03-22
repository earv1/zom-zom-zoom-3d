class_name XpOrb
extends Node3D

var car: Node3D
var xp_value: int = 5


func _process(delta: float) -> void:
	if not car:
		return
	var to_car := car.global_position - global_position
	var dist := to_car.length()
	if dist < 1.0:
		GameManager.add_xp(xp_value)
		queue_free()
		return
	global_position += to_car.normalized() * minf(dist, 120.0 * delta)
