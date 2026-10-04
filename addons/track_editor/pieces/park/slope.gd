@tool
extends ParkPiece
## Straight ramp from the floor up to `height` over `length`, eased at both
## ends. Entry at +Z (floor), exit at -Z (top). Pairs with deck.

@export_storage var length := 16.0
@export_storage var height := 4.0
@export_storage var width_cells := 2


func get_param_defs() -> Array:
	return [
		{name = "length", label = "Length", min = 4.0, max = 48.0, step = 4.0, default = 16.0},
		{name = "height", label = "Height", min = 1.0, max = 24.0, step = 1.0, default = 4.0},
		{name = "width_cells", label = "Width (cells)", min = 1.0, max = 8.0, step = 1.0, default = 2.0},
	]


func get_connection_anchors() -> Array:
	return [
		{"position": Vector3(0, 0, length * 0.5), "out_dir": Vector3(0, 0, 1)},
		{"position": Vector3(0, height, -length * 0.5), "out_dir": Vector3(0, 0, -1)},
	]


func _build() -> void:
	var surface := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		surface.append(Vector2(length * 0.5 - t * length, height * (t * t * (3.0 - 2.0 * t))))
	ParkGeometry.extrude(self, surface, width_cells * 8.0, ParkGeometry.concrete())
