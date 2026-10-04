@tool
extends ParkPiece
## Bowl corner: the quarter pipe profile revolved 90 degrees around the cell's
## +X/+Z corner, so it joins a quarter pipe on the -Z edge to one on the -X edge.
## The bowl floor is toward +X/+Z.

@export_storage var radius := 5.0
@export_storage var height := 6.0
@export_storage var deck := 4.0


func get_param_defs() -> Array:
	return [
		{name = "radius", label = "Transition", min = 2.0, max = 8.0, step = 0.5, default = 5.0},
		{name = "height", label = "Height", min = 2.0, max = 14.0, step = 0.5, default = 6.0},
		{name = "deck", label = "Deck", min = 1.0, max = 6.0, step = 0.5, default = 4.0},
	]


func _build() -> void:
	var r := minf(radius, height)
	var profile := PackedVector2Array([Vector2(0.0, 0.0)])
	for i in 13:
		var t := PI * 0.5 * i / 12.0
		profile.append(Vector2(8.0 - r + sin(t) * r, r - cos(t) * r))
	if height > r + 0.01:
		profile.append(Vector2(8.0, height))
	profile.append(Vector2(8.0 + deck, height))
	var pivot := Transform3D(Basis(Vector3.UP, PI), Vector3(4.0, 0.0, 4.0))
	ParkGeometry.revolve(self, profile, PI * 0.5, 16, ParkGeometry.concrete(), 0.0, pivot)
