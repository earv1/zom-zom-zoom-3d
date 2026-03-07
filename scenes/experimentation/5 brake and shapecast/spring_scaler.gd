@tool
extends MeshInstance3D

@export var wheel: Node3D
@export var offset: float = 0.65


func _process(_delta: float) -> void:
	if not wheel: return

	var diff = global_position - wheel.global_position
	scale.y = offset + diff.y
