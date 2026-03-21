class_name BaseWeapon
extends Node3D

const _PROJ_SCENE: PackedScene = preload("res://scenes/weapons/projectile.tscn")

@export var weapon_id: StringName = &""

var car: Node3D
var level: int = 1
var base_damage: float = 1.0
var base_fire_rate: float = 1.0
var _timer: float = 0.0


func _process(delta: float) -> void:
	if not car:
		return
	_timer += delta
	var interval := 1.0 / (base_fire_rate * GameManager.fire_rate_multiplier)
	if _timer >= interval:
		_timer = 0.0
		fire()


func fire() -> void:
	pass


func level_up() -> void:
	level += 1
	_apply_level()


func _apply_level() -> void:
	pass


func get_damage() -> float:
	return base_damage * GameManager.damage_multiplier


func _spawn_projectile(dir: Vector3, speed: float, target: Node3D = null) -> void:
	var proj: Projectile = _PROJ_SCENE.instantiate()
	proj.damage = get_damage()
	proj.direction = dir
	proj.speed = speed
	proj.target = target
	get_tree().current_scene.add_child(proj)
	proj.global_position = car.global_position + dir * 2.5 + Vector3.UP * 0.5


func _update_collision_radius(area: Area3D, radius: float) -> void:
	var shape_node := area.get_node("CollisionShape3D") as CollisionShape3D
	if shape_node and shape_node.shape is SphereShape3D:
		(shape_node.shape as SphereShape3D).radius = radius
