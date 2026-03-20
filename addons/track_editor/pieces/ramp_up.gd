## Ramp: rises over one cell run (8 m). Pitch is configurable.
## Entry: south face (z=+4, y=0). Exit: north face (z=-4, y=+rise).
@tool
extends Node3D

const STEPS := 14
const SLAB_T := 0.3
const RUN := 8.0
const RAIL_W := 0.15
const RAIL_H := 0.45

@export_storage var road_width := 6.0
@export_storage var pitch_deg := 30.0

func _ready() -> void:
	_build()

func configure(params: Dictionary) -> void:
	road_width = params.get("road_width", road_width)
	pitch_deg = params.get("pitch_deg", pitch_deg)
	for child in get_children():
		child.queue_free()
	_build()

func get_config() -> Dictionary:
	return {road_width = road_width, pitch_deg = pitch_deg}

func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width", min = 6.0, max = 12.0, step = 6.0, default = 6.0},
		{name = "pitch_deg", label = "Pitch", min = 6.0, max = 42.0, step = 6.0, default = 30.0},
	]

func _build() -> void:
	var rise := RUN * tan(deg_to_rad(pitch_deg))

	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.28, 0.22, 0.22)
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.9, 0.9, 0.2)

	var sb := StaticBody3D.new()
	add_child(sb)

	for i in range(STEPS):
		var ta := float(i) / STEPS
		var tb := float(i + 1) / STEPS

		var a_center := _ramp_point(ta, rise)
		var b_center := _ramp_point(tb, rise)
		var a_right := _section_right(ta, rise)
		var b_right := _section_right(tb, rise)
		var half_w := road_width * 0.5

		var a_left_edge := a_center - a_right * half_w
		var a_right_edge := a_center + a_right * half_w
		var b_left_edge := b_center - b_right * half_w
		var b_right_edge := b_center + b_right * half_w

		var road := MeshInstance3D.new()
		road.mesh = _segment_mesh(a_left_edge, a_right_edge, b_left_edge, b_right_edge, SLAB_T)
		road.material_override = road_mat.duplicate()
		add_child(road)

		var cs := CollisionShape3D.new()
		var cps := ConvexPolygonShape3D.new()
		var down := Vector3(0, SLAB_T, 0)
		cps.points = PackedVector3Array([
			a_left_edge, a_right_edge, b_right_edge, b_left_edge,
			a_left_edge - down, a_right_edge - down, b_right_edge - down, b_left_edge - down,
		])
		cs.shape = cps
		sb.add_child(cs)

		var left_rail := MeshInstance3D.new()
		left_rail.mesh = _rail_segment_mesh(a_left_edge - a_right * (RAIL_W * 0.5), b_left_edge - b_right * (RAIL_W * 0.5), RAIL_W, RAIL_H)
		left_rail.material_override = rail_mat.duplicate()
		add_child(left_rail)

		var right_rail := MeshInstance3D.new()
		right_rail.mesh = _rail_segment_mesh(a_right_edge + a_right * (RAIL_W * 0.5), b_right_edge + b_right * (RAIL_W * 0.5), RAIL_W, RAIL_H)
		right_rail.material_override = rail_mat.duplicate()
		add_child(right_rail)

func _ramp_point(t: float, rise: float) -> Vector3:
	var profile_t := _skate_profile(t)
	return Vector3(0.0, profile_t * rise, 4.0 - t * RUN)

func _section_right(t: float, rise: float) -> Vector3:
	var tangent := _ramp_tangent(t, rise)
	return tangent.cross(Vector3.UP).normalized()

func _ramp_tangent(t: float, rise: float) -> Vector3:
	var dt := max(0.001, 1.0 / STEPS)
	var a := _ramp_point(max(0.0, t - dt), rise)
	var b := _ramp_point(min(1.0, t + dt), rise)
	return (b - a).normalized()

func _skate_profile(t: float) -> float:
	return 1.0 - cos(t * PI * 0.5)

func _segment_mesh(a_left: Vector3, a_right: Vector3, b_left: Vector3, b_right: Vector3, thick: float) -> ArrayMesh:
	var down := Vector3(0, thick, 0)
	var a_left_b := a_left - down
	var a_right_b := a_right - down
	var b_left_b := b_left - down
	var b_right_b := b_right - down
	var center := (a_left + a_right + b_left + b_right) * 0.25

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()

	_quad(verts, norms, a_left, a_right, b_right, b_left, Vector3.UP)
	_quad(verts, norms, a_left_b, b_left_b, b_right_b, a_right_b, _face_normal(a_left_b, b_left_b, b_right_b))
	_quad(verts, norms, a_left, a_left_b, b_left_b, b_left, _outward_normal(a_left, b_left, center))
	_quad(verts, norms, a_right, b_right, b_right_b, a_right_b, _outward_normal(a_right, b_right, center))
	_quad(verts, norms, a_left, a_right, a_right_b, a_left_b, _outward_normal(a_right, a_left, center))
	_quad(verts, norms, b_left, b_left_b, b_right_b, b_right, _outward_normal(b_left, b_right, center))

	return _build_array_mesh(verts, norms)

func _rail_segment_mesh(a_center: Vector3, b_center: Vector3, width: float, height: float) -> ArrayMesh:
	var up := Vector3.UP * height
	var right := (b_center - a_center).cross(Vector3.UP).normalized() * (width * 0.5)

	var a_left := a_center - right
	var a_right := a_center + right
	var b_left := b_center - right
	var b_right := b_center + right
	var center := (a_left + a_right + b_left + b_right) * 0.25 + up * 0.5

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()

	_quad(verts, norms, a_left + up, a_right + up, b_right + up, b_left + up, Vector3.UP)
	_quad(verts, norms, a_left, b_left, b_right, a_right, Vector3.DOWN)
	_quad(verts, norms, a_left + up, a_left, b_left, b_left + up, _outward_normal(a_left, b_left, center))
	_quad(verts, norms, a_right + up, b_right + up, b_right, a_right, _outward_normal(a_right, b_right, center))
	_quad(verts, norms, a_left + up, a_right + up, a_right, a_left, _outward_normal(a_right, a_left, center))
	_quad(verts, norms, b_left + up, b_left, b_right, b_right + up, _outward_normal(b_left, b_right, center))

	return _build_array_mesh(verts, norms)

func _build_array_mesh(verts: PackedVector3Array, norms: PackedVector3Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _quad(verts: PackedVector3Array, norms: PackedVector3Array,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	verts.append_array([a, b, c, a, c, d])
	for _i in range(6):
		norms.append(n.normalized())

func _face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (b - a).cross(c - a).normalized()

func _outward_normal(from: Vector3, to: Vector3, centroid: Vector3) -> Vector3:
	var edge := (to - from).normalized()
	var n := edge.cross(Vector3.UP).normalized()
	var mid := (from + to) * 0.5
	if n.dot(mid - centroid) < 0.0:
		n = -n
	return n
