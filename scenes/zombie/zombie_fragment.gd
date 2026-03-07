extends RigidBody3D

const LIFETIME := 3.0

func _ready() -> void:
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
