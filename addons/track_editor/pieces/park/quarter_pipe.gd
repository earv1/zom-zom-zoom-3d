@tool
extends ParkPiece
## Quarter pipe: flat run-in from +Z, curved transition up to a vertical wall
## at the back of the cell (z = -4), a deck on top and a steel coping.

@export_storage var radius := 5.0
@export_storage var height := 6.0
@export_storage var width_cells := 2
@export_storage var deck := 3.0


func get_param_defs() -> Array:
	return [
		{name = "radius", label = "Transition", min = 2.0, max = 8.0, step = 0.5, default = 5.0},
		{name = "height", label = "Height", min = 2.0, max = 14.0, step = 0.5, default = 6.0},
		{name = "width_cells", label = "Width (cells)", min = 1.0, max = 8.0, step = 1.0, default = 2.0},
		{name = "deck", label = "Deck", min = 1.0, max = 6.0, step = 0.5, default = 3.0},
	]


func _build() -> void:
	var w := width_cells * 8.0
	var r := minf(radius, height)
	var surface := PackedVector2Array([Vector2(4.0, 0.0)])
	surface.append_array(ParkGeometry.transition(-4.0 + r, r, height))
	surface.append(Vector2(-4.0 - deck, height))
	ParkGeometry.extrude(self, surface, w, ParkGeometry.concrete())
	_coping(w, -4.0, height)
