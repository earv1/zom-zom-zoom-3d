class_name Projectile
extends Area3D

var speed: float = 40.0
var damage: float = 1.0
var direction: Vector3 = Vector3.FORWARD
var target: Node3D = null
var homing_strength: float = 5.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func _process(delta: float) -> void:
	if is_instance_valid(target):
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		to_target = to_target.normalized()
		var dir_flat := direction
		dir_flat.y = 0.0
		direction = dir_flat.lerp(to_target, homing_strength * delta).normalized()
	global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if body is BaseEnemy:
		body.take_damage(int(damage))
		queue_free()
