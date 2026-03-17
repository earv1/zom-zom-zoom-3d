## 90-degree right turn.
## Entry: south face (z=+4), Exit: west face (x=-4).
## Built with trapezoidal prism segments (no gaps).
@tool
extends Node3D

const STEPS   := 10
const PIVOT   := Vector3(-4.0, 0.0, 4.0)   # NW corner
const RADIUS  := 4.0
const ROAD_W  := 6.0
const INNER_R := RADIUS - ROAD_W * 0.5     # 1.0
const OUTER_R := RADIUS + ROAD_W * 0.5     # 7.0
const THICK   := 0.3
const SWEEP   := -PI * 0.5   # 0 → -90° (east to south from pivot)

func _ready() -> void:
	_build()

func _build() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.22, 0.22, 0.22)
	var kerb_mat := StandardMaterial3D.new()
	kerb_mat.albedo_color = Color(0.9, 0.9, 0.2)

	var sb := StaticBody3D.new()
	add_child(sb)

	for i in range(STEPS):
		var a0 := SWEEP * float(i)       / STEPS
		var a1 := SWEEP * float(i + 1)   / STEPS

		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))

		# four corners of this trapezoid slab (top face at y=0)
		var pi0 := PIVOT + d0 * INNER_R   # inner start
		var po0 := PIVOT + d0 * OUTER_R   # outer start
		var pi1 := PIVOT + d1 * INNER_R   # inner end
		var po1 := PIVOT + d1 * OUTER_R   # outer end

		# road slab
		var mi := MeshInstance3D.new()
		mi.mesh = _trapezoid_mesh(pi0, po0, po1, pi1, THICK)
		mi.material_override = road_mat.duplicate()
		add_child(mi)

		# outer kerb strip
		var kerb_inner_r := OUTER_R + 0.05
		var kerb_outer_r := OUTER_R + 0.45
		var ki0 := PIVOT + d0 * kerb_inner_r
		var ko0 := PIVOT + d0 * kerb_outer_r
		var ki1 := PIVOT + d1 * kerb_inner_r
		var ko1 := PIVOT + d1 * kerb_outer_r
		var mk  := MeshInstance3D.new()
		mk.mesh = _trapezoid_mesh(ki0, ko0, ko1, ki1, THICK + 0.1)
		mk.material_override = kerb_mat.duplicate()
		add_child(mk)

		# collision (convex hull of 8 corners)
		var cs  := CollisionShape3D.new()
		var cps := ConvexPolygonShape3D.new()
		cps.points = PackedVector3Array([
			pi0, po0, pi1, po1,
			pi0 - Vector3(0, THICK, 0),
			po0 - Vector3(0, THICK, 0),
			pi1 - Vector3(0, THICK, 0),
			po1 - Vector3(0, THICK, 0),
		])
		cs.shape = cps
		sb.add_child(cs)

# ── mesh builder ──────────────────────────────────────────────────────────────

## Builds a trapezoidal prism from four top-face points (all at y=0),
## extruded downward by `thick`.
## Winding: pi0 = inner-start, po0 = outer-start, po1 = outer-end, pi1 = inner-end
func _trapezoid_mesh(pi0: Vector3, po0: Vector3, po1: Vector3, pi1: Vector3,
		thick: float) -> ArrayMesh:
	var bi0 := pi0 - Vector3(0, thick, 0)
	var bo0 := po0 - Vector3(0, thick, 0)
	var bi1 := pi1 - Vector3(0, thick, 0)
	var bo1 := po1 - Vector3(0, thick, 0)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()

	# top
	_quad(verts, norms, pi0, pi1, po1, po0, Vector3.UP)
	# bottom
	_quad(verts, norms, bo0, bo1, bi1, bi0, Vector3.DOWN)
	# inner side
	_quad(verts, norms, pi1, pi0, bi0, bi1,
		_side_normal(pi0, pi1, true))
	# outer side
	_quad(verts, norms, po0, po1, bo1, bo0,
		_side_normal(po0, po1, false))
	# start cap
	_quad(verts, norms, po0, pi0, bi0, bo0,
		_cap_normal(pi0, po0, true))
	# end cap
	_quad(verts, norms, pi1, po1, bo1, bi1,
		_cap_normal(pi1, po1, false))

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _quad(verts: PackedVector3Array, norms: PackedVector3Array,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	verts.append_array([a, b, c,  a, c, d])
	for _i in range(6):
		norms.append(n)

func _side_normal(from: Vector3, to: Vector3, inward: bool) -> Vector3:
	var edge := (to - from).normalized()
	var n    := edge.cross(Vector3.UP).normalized()
	return n if not inward else -n

func _cap_normal(inner: Vector3, outer: Vector3, start: bool) -> Vector3:
	var edge := (outer - inner).normalized()
	var n    := Vector3.UP.cross(edge).normalized()
	return n if start else -n
