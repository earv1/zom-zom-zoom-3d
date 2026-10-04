@tool
extends ParkPiece
## Funbox / pyramid: flat top with a ramp down every side.

@export_storage var top := 8.0
@export_storage var height := 2.5
@export_storage var slope := 6.0


func get_param_defs() -> Array:
	return [
		{name = "top", label = "Top size", min = 2.0, max = 32.0, step = 1.0, default = 8.0},
		{name = "height", label = "Height", min = 0.5, max = 10.0, step = 0.5, default = 2.5},
		{name = "slope", label = "Ramp length", min = 2.0, max = 20.0, step = 1.0, default = 6.0},
	]


func _build() -> void:
	var t := top * 0.5
	var b := t + slope
	var pts := PackedVector3Array([
		Vector3(-t, height, -t), Vector3(t, height, -t), Vector3(t, height, t), Vector3(-t, height, t),
		Vector3(-b, 0, -b), Vector3(b, 0, -b), Vector3(b, 0, b), Vector3(-b, 0, b),
	])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in [[0, 1, 2, 3], [4, 5, 1, 0], [5, 6, 2, 1], [6, 7, 3, 2], [7, 4, 0, 3], [7, 6, 5, 4]]:
		for k in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_vertex(pts[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ParkGeometry.concrete()
	add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	cs.shape = shape
	sb.add_child(cs)
	add_child(sb)
