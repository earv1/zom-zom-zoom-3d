## Bezier connector between two track pieces.
## start_pos / end_pos are world-space (TrackRoot assumed at origin).
## The node's own position is set to start_pos; all geometry is local to that.
@tool
extends Node3D

const STEPS  := 24
const SLAB_T := 0.3
const KERB_W := 0.35
const KERB_H := 0.1

@export_storage var start_pos  := Vector3.ZERO
@export_storage var start_dir  := Vector3(0, 0, 1)
@export_storage var end_pos    := Vector3(8, 0, 0)
@export_storage var end_dir    := Vector3(1, 0, 0)
@export_storage var road_width := 6.0
@export_storage var start_width := 6.0
@export_storage var end_width := 6.0

func _ready() -> void:
	_build()

func configure(params: Dictionary) -> void:
	road_width = params.get("road_width", road_width)
	start_width = road_width
	end_width = road_width
	for child in get_children():
		child.queue_free()
	_build()

func get_config() -> Dictionary:
	return {road_width = road_width}

func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width", min = 6.0, max = 12.0, step = 6.0, default = 6.0},
	]

func _build() -> void:
	var chord := (end_pos - start_pos).length()
	if chord < 0.01:
		return

	var dir_alignment := clampf(start_dir.normalized().dot(end_dir.normalized()), -1.0, 1.0)
	var alignment_t := (dir_alignment + 1.0) * 0.5
	var handle_scale := lerpf(0.2, 0.38, alignment_t)
	var tension := clampf(chord * handle_scale, 2.0, chord * 0.5)
	var p0 := start_pos
	var p1 := start_pos + start_dir * tension
	var p2 := end_pos   - end_dir   * tension
	var p3 := end_pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.22, 0.22)
	var kerb_mat := StandardMaterial3D.new()
	kerb_mat.albedo_color = Color(0.9, 0.9, 0.2)

	var sb := StaticBody3D.new()
	add_child(sb)

	for i in range(STEPS):
		var ta   := float(i)       / STEPS
		var tb   := float(i + 1)   / STEPS

		# Use exact section endpoints instead of midpoint-aligned boxes so
		# neighboring segments share vertices and don't open gaps on curves.
		var wa := _bezier(p0, p1, p2, p3, ta) - start_pos
		var wb := _bezier(p0, p1, p2, p3, tb) - start_pos

		var right_a := _section_right(p0, p1, p2, p3, ta)
		var right_b := _section_right(p0, p1, p2, p3, tb)
		var half_w_a := _width_at(ta) * 0.5
		var half_w_b := _width_at(tb) * 0.5

		var a_left  := wa - right_a * half_w_a
		var a_right := wa + right_a * half_w_a
		var b_left  := wb - right_b * half_w_b
		var b_right := wb + right_b * half_w_b

		var mi := MeshInstance3D.new()
		mi.mesh = _segment_mesh(a_left, a_right, b_left, b_right, SLAB_T)
		mi.material_override = mat.duplicate()
		add_child(mi)

		var a_left_kerb_in  := a_left
		var a_left_kerb_out := a_left - right_a * KERB_W
		var b_left_kerb_in  := b_left
		var b_left_kerb_out := b_left - right_b * KERB_W
		var left_kerb := MeshInstance3D.new()
		left_kerb.mesh = _segment_mesh(a_left_kerb_out, a_left_kerb_in, b_left_kerb_out, b_left_kerb_in, KERB_H)
		left_kerb.material_override = kerb_mat.duplicate()
		add_child(left_kerb)

		var a_right_kerb_in  := a_right
		var a_right_kerb_out := a_right + right_a * KERB_W
		var b_right_kerb_in  := b_right
		var b_right_kerb_out := b_right + right_b * KERB_W
		var right_kerb := MeshInstance3D.new()
		right_kerb.mesh = _segment_mesh(a_right_kerb_in, a_right_kerb_out, b_right_kerb_in, b_right_kerb_out, KERB_H)
		right_kerb.material_override = kerb_mat.duplicate()
		add_child(right_kerb)

		var cs := CollisionShape3D.new()
		var cps := ConvexPolygonShape3D.new()
		var down := Vector3(0, SLAB_T, 0)
		cps.points = PackedVector3Array([
			a_left, a_right, b_right, b_left,
			a_left - down, a_right - down, b_right - down, b_left - down,
		])
		cs.shape = cps
		sb.add_child(cs)

func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var mt := 1.0 - t
	return mt*mt*mt*p0 + 3.0*mt*mt*t*p1 + 3.0*mt*t*t*p2 + t*t*t*p3

func _bezier_derivative(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var mt := 1.0 - t
	return 3.0 * mt * mt * (p1 - p0) + 6.0 * mt * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)

func _section_right(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var tangent := _bezier_derivative(p0, p1, p2, p3, t)
	tangent.y = 0.0
	if tangent.length_squared() < 0.0001:
		return Vector3.RIGHT
	return tangent.normalized().cross(Vector3.UP).normalized()

func _width_at(t: float) -> float:
	return lerpf(start_width, end_width, t)

func _segment_mesh(a_left: Vector3, a_right: Vector3, b_left: Vector3, b_right: Vector3, thick: float) -> ArrayMesh:
	var down := Vector3(0, thick, 0)
	var a_left_b := a_left - down
	var a_right_b := a_right - down
	var b_left_b := b_left - down
	var b_right_b := b_right - down

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()

	# Top and bottom need winding that matches the face normal so they light
	# the same way as the BoxMesh-based track pieces.
	_quad(verts, norms, a_left, b_left, b_right, a_right, Vector3.UP)
	_quad(verts, norms, a_left_b, a_right_b, b_right_b, b_left_b, Vector3.DOWN)
	# Left side
	_quad(verts, norms, a_left, b_left, b_left_b, a_left_b,
		_outward_normal(a_left, b_left, (a_left + b_left + b_right + a_right) * 0.25))
	# Right side
	_quad(verts, norms, a_right, a_right_b, b_right_b, b_right,
		_outward_normal(a_right, b_right, (a_left + b_left + b_right + a_right) * 0.25))
	# Start cap
	_quad(verts, norms, a_left, a_left_b, a_right_b, a_right,
		_outward_normal(a_left, a_right, (a_left + b_left + b_right + a_right) * 0.25))
	# End cap
	_quad(verts, norms, b_left, b_right, b_right_b, b_left_b,
		_outward_normal(b_right, b_left, (a_left + b_left + b_right + a_right) * 0.25))

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
		norms.append(n)

func _outward_normal(from: Vector3, to: Vector3, centroid: Vector3) -> Vector3:
	var edge := (to - from).normalized()
	var n := edge.cross(Vector3.UP).normalized()
	var mid := (from + to) * 0.5
	if n.dot(mid - centroid) < 0.0:
		n = -n
	return n
