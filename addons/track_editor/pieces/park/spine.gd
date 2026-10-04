@tool
extends ParkPiece
## Spine: two transitions back to back meeting at a coping ridge at z = 0.

@export_storage var radius := 3.5
@export_storage var width_cells := 2


func get_param_defs() -> Array:
	return [
		{name = "radius", label = "Transition", min = 1.5, max = 4.0, step = 0.5, default = 3.5},
		{name = "width_cells", label = "Width (cells)", min = 1.0, max = 8.0, step = 1.0, default = 2.0},
	]


func get_connection_anchors() -> Array:
	return [
		{"position": Vector3(0, 0, 4), "out_dir": Vector3(0, 0, 1)},
		{"position": Vector3(0, 0, -4), "out_dir": Vector3(0, 0, -1)},
	]


func _build() -> void:
	var w := width_cells * 8.0
	var r := radius
	var front := ParkGeometry.transition(r, r, r)   # (r, 0) curving up to (0, r)
	var surface := PackedVector2Array([Vector2(4.0, 0.0)])
	surface.append_array(front)
	for i in range(front.size() - 2, -1, -1):        # mirror down the back
		surface.append(Vector2(-front[i].x, front[i].y))
	surface.append(Vector2(-4.0, 0.0))
	ParkGeometry.extrude(self, surface, w, ParkGeometry.concrete())
	_coping(w, 0.0, r)
