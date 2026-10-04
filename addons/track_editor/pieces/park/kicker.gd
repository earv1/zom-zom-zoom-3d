@tool
extends ParkPiece
## Launch ramp: a circular arc that starts flat at +Z and leaves the lip at
## `lip_angle` after `length` metres. Height follows from length and angle.

@export_storage var length := 10.0
@export_storage var lip_angle := 30.0
@export_storage var width_cells := 1


func get_param_defs() -> Array:
	return [
		{name = "length", label = "Length", min = 4.0, max = 32.0, step = 1.0, default = 10.0},
		{name = "lip_angle", label = "Lip angle", min = 10.0, max = 60.0, step = 2.5, default = 30.0},
		{name = "width_cells", label = "Width (cells)", min = 1.0, max = 6.0, step = 1.0, default = 1.0},
	]


func get_connection_anchors() -> Array:
	return [{"position": Vector3(0, 0, length * 0.5), "out_dir": Vector3(0, 0, 1)}]


func lip_height() -> float:
	var a := deg_to_rad(lip_angle)
	return length / sin(a) * (1.0 - cos(a))


func _build() -> void:
	var a := deg_to_rad(lip_angle)
	var r := length / sin(a)
	var surface := PackedVector2Array()
	for i in 17:
		var t := a * i / 16.0
		surface.append(Vector2(length * 0.5 - r * sin(t), r * (1.0 - cos(t))))
	var w := width_cells * 8.0
	ParkGeometry.extrude(self, surface, w, ParkGeometry.concrete())
	_coping(w, -length * 0.5, lip_height())
