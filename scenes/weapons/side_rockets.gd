class_name SideRockets
extends BaseWeapon

const _PROJ_SCENE: PackedScene = preload("res://scenes/weapons/projectile.tscn")


func _ready() -> void:
	base_damage = 2.0
	base_fire_rate = 0.8


func fire() -> void:
	_fire_dir(car.global_basis.x)
	_fire_dir(-car.global_basis.x)


func _fire_dir(dir: Vector3) -> void:
	var proj: Projectile = _PROJ_SCENE.instantiate()
	proj.damage = get_damage()
	proj.direction = dir
	proj.speed = 35.0
	get_tree().current_scene.add_child(proj)
	# Spawn 2.5 units to the side to clear the car's collision shape
	proj.global_position = car.global_position + dir * 2.5 + Vector3.UP * 0.5


func _apply_level() -> void:
	match level:
		2:
			base_damage = 3.5
