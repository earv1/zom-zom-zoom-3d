class_name BossHitbox
extends AnimatableBody3D
## Solid, shootable body for a boss. It sits in the "enemies" group so the
## guns target it and weapons/rams call take_damage(), which it forwards.

signal hit(amount: int)


func _ready() -> void:
	add_to_group("enemies")
	sync_to_physics = false


## A ground pound on the boss takes this much (before ram upgrades): 1/20 of its health.
func pound_damage() -> int:
	return maxi(roundi(float(get_parent().get("max_health")) / 20.0), 1)


## Ramming the boss at speed takes this much (before ram upgrades): 1/50 of its health.
func ram_damage() -> int:
	return maxi(roundi(float(get_parent().get("max_health")) / 50.0), 1)


func take_damage(amount: int) -> void:
	var roll := GameManager.roll_hit(amount)
	var dealt := maxi(roundi(roll[0]), 1)
	DamageNumber.spawn(get_parent(), global_position + Vector3.UP * 8.0, dealt, roll[1])
	hit.emit(dealt)
