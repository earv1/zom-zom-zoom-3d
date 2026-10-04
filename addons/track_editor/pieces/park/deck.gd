@tool
extends ParkPiece
## Raised deck (multi-level platform) with coping round the edge.

@export_storage var width_cells := 2
@export_storage var depth_cells := 2
@export_storage var height := 4.0


func get_param_defs() -> Array:
	return [
		{name = "width_cells", label = "Width (cells)", min = 1.0, max = 8.0, step = 1.0, default = 2.0},
		{name = "depth_cells", label = "Depth (cells)", min = 1.0, max = 8.0, step = 1.0, default = 2.0},
		{name = "height", label = "Height", min = 1.0, max = 24.0, step = 1.0, default = 4.0},
	]


func get_connection_anchors() -> Array:
	var hd := depth_cells * 4.0
	return [
		{"position": Vector3(0, height, hd), "out_dir": Vector3(0, 0, 1)},
		{"position": Vector3(0, height, -hd), "out_dir": Vector3(0, 0, -1)},
	]


func _build() -> void:
	var w := width_cells * 8.0
	var d := depth_cells * 8.0
	ParkGeometry.box(self, Vector3(w, height, d), Vector3(0, height * 0.5, 0), ParkGeometry.concrete())
	for z in [-d * 0.5, d * 0.5]:
		_coping(w, z, height)
