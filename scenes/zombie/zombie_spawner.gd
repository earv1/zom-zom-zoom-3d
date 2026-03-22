extends Node3D

@export var car: Node3D
@export var zombie_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var spawn_radius: float = 40.0

var _timer: float = 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn()


func _spawn() -> void:
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius
	var pos := car.global_position + offset
	pos.y += 10.0  # drop from above so it lands on terrain

	var zombie: RigidBody3D = zombie_scene.instantiate()
	zombie.car = car
	add_child(zombie)
	zombie.global_position = pos
