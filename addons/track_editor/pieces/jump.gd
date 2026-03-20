## Jump pad: flat road with a curved lip to launch the car.
@tool
extends Node3D

const SLAB_T := 0.3
const LIP_LEN := 2.0
const LIP_STEPS := 8
const RAIL_W := 0.15
const RAIL_H := 0.45

@export_storage var road_width := 6.0
@export_storage var lip_angle := 18.0

func _ready() -> void:
	_build()

func configure(params: Dictionary) -> void:
	road_width = params.get("road_width", road_width)
	lip_angle = params.get("lip_angle", lip_angle)
	for child in get_children():
		child.queue_free()
	_build()

func get_config() -> Dictionary:
	return {road_width = road_width, lip_angle = lip_angle}

func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width", min = 6.0, max = 12.0, step = 6.0, default = 6.0},
		{name = "lip_angle", label = "Lip Angle", min = 6.0, max = 42.0, step = 6.0, default = 18.0},
	]

func _build() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.28, 0.22, 0.22)
	var lip_mat := StandardMaterial3D.new()
	lip_mat.albedo_color = Color(0.28, 0.22, 0.22)
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.9, 0.9, 0.2)

	var sb := StaticBody3D.new()
	add_child(sb)

	# Main flat slab
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(road_width, SLAB_T, 6.0)
	mi.mesh = bm
	mi.material_override = road_mat
	mi.position = Vector3(0, -SLAB_T * 0.5, 1.0)
	add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(road_width, SLAB_T, 6.0)
	cs.shape = bs
	cs.position = Vector3(0, -SLAB_T * 0.5, 1.0)
	sb.add_child(cs)

	for side in [-1.0, 1.0]:
		var flat_rail := MeshInstance3D.new()
		flat_rail.mesh = _rail_segment_mesh(
			Vector3(side * (road_width * 0.5 + RAIL_W * 0.5), 0.0, 4.0),
			Vector3(side * (road_width * 0.5 + RAIL_W * 0.5), 0.0, -2.0),
			RAIL_W,
			RAIL_H
		)
		flat_rail.material_override = rail_mat.duplicate()
		add_child(flat_rail)

	# Curved launch lip over the front 2 meters.
	var rise := LIP_LEN * tan(deg_to_rad(lip_angle))
	for i in range(LIP_STEPS):
		var ta := float(i) / LIP_STEPS
		var tb := float(i + 1) / LIP_STEPS

		var a_center := _lip_point(ta, rise)
		var b_center := _lip_point(tb, rise)
		var half_w := road_width * 0.5

		var a_left := a_center + Vector3(-half_w, 0, 0)
		var a_right := a_center + Vector3(half_w, 0, 0)
		var b_left := b_center + Vector3(-half_w, 0, 0)
		var b_right := b_center + Vector3(half_w, 0, 0)

		var lip := MeshInstance3D.new()
		lip.mesh = _segment_mesh(a_left, a_right, b_left, b_right, SLAB_T)
		lip.material_override = lip_mat.duplicate()
		add_child(lip)

		var left_rail := MeshInstance3D.new()
		left_rail.mesh = _rail_segment_mesh(
			a_left + Vector3(-RAIL_W * 0.5, 0, 0),
			b_left + Vector3(-RAIL_W * 0.5, 0, 0),
			RAIL_W,
			RAIL_H
		)
		left_rail.material_override = rail_mat.duplicate()
		add_child(left_rail)

		var right_rail := MeshInstance3D.new()
		right_rail.mesh = _rail_segment_mesh(
			a_right + Vector3(RAIL_W * 0.5, 0, 0),
			b_right + Vector3(RAIL_W * 0.5, 0, 0),
			RAIL_W,
			RAIL_H
		)
		right_rail.material_override = rail_mat.duplicate()
		add_child(right_rail)

		var lip_cs := CollisionShape3D.new()
		var cps := ConvexPolygonShape3D.new()
		var down := Vector3(0, SLAB_T, 0)
		cps.points = PackedVector3Array([
			a_left, a_right, b_right, b_left,
			a_left - down, a_right - down, b_right - down, b_left - down,
		])
		lip_cs.shape = cps
		sb.add_child(lip_cs)

func _lip_point(t: float, rise: float) -> Vector3:
	var profile_t := 1.0 - cos(t * PI * 0.5)
	return Vector3(0.0, profile_t * rise, -2.0 - t * LIP_LEN)

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

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

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
