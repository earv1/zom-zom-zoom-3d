class_name RingFire
extends BaseWeapon

@onready var _area: Area3D = $Area3D

var _radius: float = 4.0


func _ready() -> void:
	base_damage = 0.5
	base_fire_rate = 2.0
	_update_shape()


func _update_shape() -> void:
	var shape_node := _area.get_node("CollisionShape3D") as CollisionShape3D
	if shape_node and shape_node.shape is SphereShape3D:
		(shape_node.shape as SphereShape3D).radius = _radius


func fire() -> void:
	for body in _area.get_overlapping_bodies():
		if body is BaseEnemy:
			body.take_damage(int(get_damage()))


func _apply_level() -> void:
	match level:
		2:
			_radius += 2.0
			_update_shape()
		3:
			base_damage = 1.5
