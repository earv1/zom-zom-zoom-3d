extends Node3D

@export var car: Node3D

func _ready() -> void:
	for mesh in car.find_children("*", "MeshInstance3D", true):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
