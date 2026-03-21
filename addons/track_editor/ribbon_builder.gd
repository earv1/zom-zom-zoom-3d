@tool
extends RefCounted

class_name TrackRibbonBuilder

static func add_ribbon(parent: Node3D, static_body: StaticBody3D, points: Array, width_dirs: Array,
		widths: Array, road_mat: Material, side_mat: Material, line_mat: Material,
		show_sides: bool, show_lines: bool,
		slab_t: float = 0.3, kerb_w: float = 0.35, kerb_h: float = 0.1) -> void:
	if points.size() < 2 or width_dirs.size() != points.size() or widths.size() != points.size():
		return

	var aligned_width_dirs: Array = []
	for i in range(width_dirs.size()):
		var dir := (width_dirs[i] as Vector3).normalized()
		if i > 0:
			var prev: Vector3 = aligned_width_dirs[i - 1]
			if prev.dot(dir) < 0.0:
				dir = -dir
		aligned_width_dirs.append(dir)

	var first_half_w := float(widths[0]) * 0.5
	var last_half_w := float(widths[widths.size() - 1]) * 0.5
	var first_dir: Vector3 = aligned_width_dirs[0]
	var last_dir: Vector3 = aligned_width_dirs[aligned_width_dirs.size() - 1]
	var first_center: Vector3 = points[0]
	var last_center: Vector3 = points[points.size() - 1]

	for i in range(points.size() - 1):
		var a_center: Vector3 = points[i]
		var b_center: Vector3 = points[i + 1]
		var a_width_dir: Vector3 = aligned_width_dirs[i]
		var b_width_dir: Vector3 = aligned_width_dirs[i + 1]
		var a_half_w := float(widths[i]) * 0.5
		var b_half_w := float(widths[i + 1]) * 0.5

		var a_left := a_center - a_width_dir * a_half_w
		var a_right := a_center + a_width_dir * a_half_w
		var b_left := b_center - b_width_dir * b_half_w
		var b_right := b_center + b_width_dir * b_half_w

		var road := MeshInstance3D.new()
		road.mesh = _segment_mesh(a_left, a_right, b_left, b_right, slab_t, false, false)
		road.material_override = road_mat.duplicate()
		parent.add_child(road)

		if show_sides:
			var left_kerb := MeshInstance3D.new()
			left_kerb.mesh = _segment_mesh(a_left - a_width_dir * kerb_w, a_left, b_left - b_width_dir * kerb_w, b_left, kerb_h, false, false)
			left_kerb.material_override = side_mat.duplicate()
			parent.add_child(left_kerb)

			var right_kerb := MeshInstance3D.new()
			right_kerb.mesh = _segment_mesh(a_right, a_right + a_width_dir * kerb_w, b_right, b_right + b_width_dir * kerb_w, kerb_h, false, false)
			right_kerb.material_override = side_mat.duplicate()
			parent.add_child(right_kerb)

		if show_lines:
			var stripe_half_w: float = min(a_half_w, b_half_w) * 0.08
			var stripe_raise := Vector3.UP * 0.01
			var line := MeshInstance3D.new()
			line.mesh = _segment_mesh(
				a_center - a_width_dir * stripe_half_w + stripe_raise,
				a_center + a_width_dir * stripe_half_w + stripe_raise,
				b_center - b_width_dir * stripe_half_w + stripe_raise,
				b_center + b_width_dir * stripe_half_w + stripe_raise,
				0.02,
				false,
				false
			)
			line.material_override = line_mat.duplicate()
			parent.add_child(line)

		var cs := CollisionShape3D.new()
		var cps := ConvexPolygonShape3D.new()
		var down := Vector3(0, slab_t, 0)
		cps.points = PackedVector3Array([
			a_left, a_right, b_right, b_left,
			a_left - down, a_right - down, b_right - down, b_left - down,
		])
		cs.shape = cps
		static_body.add_child(cs)

	_add_cap(parent, road_mat, first_center - first_dir * first_half_w, first_center + first_dir * first_half_w, slab_t, true)
	_add_cap(parent, road_mat, last_center - last_dir * last_half_w, last_center + last_dir * last_half_w, slab_t, false)
	if show_sides:
		_add_cap(parent, side_mat, first_center - first_dir * (first_half_w + kerb_w), first_center - first_dir * first_half_w, kerb_h, true)
		_add_cap(parent, side_mat, first_center + first_dir * first_half_w, first_center + first_dir * (first_half_w + kerb_w), kerb_h, true)
		_add_cap(parent, side_mat, last_center - last_dir * (last_half_w + kerb_w), last_center - last_dir * last_half_w, kerb_h, false)
		_add_cap(parent, side_mat, last_center + last_dir * last_half_w, last_center + last_dir * (last_half_w + kerb_w), kerb_h, false)

static func _segment_mesh(a_left: Vector3, a_right: Vector3, b_left: Vector3, b_right: Vector3, thick: float,
		cap_start: bool, cap_end: bool) -> ArrayMesh:
	var down := Vector3(0, thick, 0)
	var a_left_b := a_left - down
	var a_right_b := a_right - down
	var b_left_b := b_left - down
	var b_right_b := b_right - down
	var center := (a_left + a_right + b_left + b_right) * 0.25

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()

	_quad(verts, norms, a_left, b_left, b_right, a_right, Vector3.UP)
	_quad(verts, norms, a_left_b, a_right_b, b_right_b, b_left_b, Vector3.DOWN)
	_quad(verts, norms, a_left, b_left, b_left_b, a_left_b, _outward_normal(a_left, b_left, center))
	_quad(verts, norms, a_right, a_right_b, b_right_b, b_right, _outward_normal(a_right, b_right, center))
	if cap_start:
		_quad(verts, norms, a_left, a_left_b, a_right_b, a_right, _outward_normal(a_left, a_right, center))
	if cap_end:
		_quad(verts, norms, b_left, b_right, b_right_b, b_left_b, _outward_normal(b_right, b_left, center))

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

static func _add_cap(parent: Node3D, mat: Material, left: Vector3, right: Vector3, thick: float, start_cap: bool) -> void:
	var down := Vector3(0, thick, 0)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var center := (left + right) * 0.5
	if start_cap:
		_quad(verts, norms, left, left - down, right - down, right, _outward_normal(left, right, center + Vector3.BACK))
	else:
		_quad(verts, norms, left, right, right - down, left - down, _outward_normal(right, left, center + Vector3.FORWARD))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat.duplicate()
	parent.add_child(mi)

static func _quad(verts: PackedVector3Array, norms: PackedVector3Array,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	verts.append_array([a, b, c, a, c, d])
	for _i in range(6):
		norms.append(n.normalized())

static func _outward_normal(from: Vector3, to: Vector3, centroid: Vector3) -> Vector3:
	var edge := (to - from).normalized()
	var n := edge.cross(Vector3.UP).normalized()
	var mid := (from + to) * 0.5
	if n.dot(mid - centroid) < 0.0:
		n = -n
	return n
