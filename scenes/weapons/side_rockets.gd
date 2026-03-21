class_name SideRockets
extends BaseWeapon


func _ready() -> void:
	base_damage = 2.0
	base_fire_rate = 0.8


func fire() -> void:
	_spawn_projectile(car.global_basis.x, 35.0)
	_spawn_projectile(-car.global_basis.x, 35.0)


func _apply_level() -> void:
	match level:
		2:
			base_damage = 3.5
