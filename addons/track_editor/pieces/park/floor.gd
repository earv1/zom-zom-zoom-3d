@tool
extends ParkPiece
## Flat concrete floor, width x depth cells, centred on the placed cell.

@export_storage var width_cells := 3
@export_storage var depth_cells := 3


func get_param_defs() -> Array:
	return [
		{name = "width_cells", label = "Width (cells)", min = 1.0, max = 12.0, step = 1.0, default = 3.0},
		{name = "depth_cells", label = "Depth (cells)", min = 1.0, max = 12.0, step = 1.0, default = 3.0},
	]


func get_connection_anchors() -> Array:
	var hd := depth_cells * 4.0
	return [
		{"position": Vector3(0, 0, hd), "out_dir": Vector3(0, 0, 1)},
		{"position": Vector3(0, 0, -hd), "out_dir": Vector3(0, 0, -1)},
	]


func _build() -> void:
	ParkGeometry.box(self, Vector3(width_cells * 8.0, 0.3, depth_cells * 8.0), Vector3(0, -0.15, 0), ParkGeometry.concrete())
