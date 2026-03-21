## 90-degree right turn.
## Entry: south face (z=+4), Exit: west face (x=-4).
## Built with triangular prism segments (apex at inner arc, base at outer arc).
@tool
extends Node3D

const TrackTheme = preload("res://addons/track_editor/track_theme.gd")

const STEPS := 10
const PIVOT := Vector3(-4.0, 0.0, 4.0)   # NW corner
const THICK := 0.3
const SWEEP := -PI * 0.5   # 0 → -90° (east to south from pivot)

@export_storage var radius     := 6.0
@export_storage var road_width := 6.0
@export_storage var theme_mode := TrackTheme.MODE_LINES
@export_storage var side_color_name := "yellow"

func _ready() -> void:
	_build()

func configure(params: Dictionary) -> void:
	radius     = params.get("radius",     radius)
	road_width = params.get("road_width", road_width)
	for child in get_children():
		child.queue_free()
	_build()

func get_config() -> Dictionary:
	return {road_width = road_width, radius = radius}

func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width",  min = 6.0, max = 12.0, step = 6.0, default = 6.0},
		{name = "radius",     label = "Radius", min = 6.0, max = 12.0, step = 6.0, default = 6.0},
	]

func apply_theme(mode: int, side_color: String) -> void:
	theme_mode = mode
	side_color_name = side_color
	for child in get_children():
		child.queue_free()
	_build()

func get_connection_anchors() -> Array:
	return [
		{"position": Vector3(0, 0, 4), "out_dir": Vector3(0, 0, 1)},
		{"position": Vector3(-4, 0, 0), "out_dir": Vector3(-1, 0, 0)},
	]

func _build() -> void:
	var inner_r := radius - road_width * 0.5
	var outer_r := radius + road_width * 0.5

	var road_mat := TrackTheme.road_material(theme_mode, side_color_name)
	var side_mat := TrackTheme.side_material(side_color_name)
	var line_mat := TrackTheme.line_material()

	var sb := StaticBody3D.new()
	add_child(sb)

	for i in range(STEPS):
		var a0 := SWEEP * float(i)       / STEPS
		var a1 := SWEEP * float(i + 1)   / STEPS

		var d0  := Vector3(cos(a0), 0.0, sin(a0))
		var d1  := Vector3(cos(a1), 0.0, sin(a1))
		var dm  := (d0 + d1).normalized()  # midpoint direction

		# triangle: apex at inner-arc midpoint, base at outer arc
		var pi_mid := PIVOT + dm * inner_r  # inner apex
		var po0    := PIVOT + d0 * outer_r  # outer start
		var po1    := PIVOT + d1 * outer_r  # outer end

		# road slab
		var mi := MeshInstance3D.new()
		mi.mesh = _triangle_mesh(pi_mid, po0, po1, THICK)
		mi.material_override = road_mat.duplicate()
		add_child(mi)

		if TrackTheme.show_sides(theme_mode):
			var kerb_inner_r := outer_r + 0.05
			var kerb_outer_r := outer_r + 0.45
			var ki_mid := PIVOT + dm * kerb_inner_r
			var ko0    := PIVOT + d0 * kerb_outer_r
			var ko1    := PIVOT + d1 * kerb_outer_r
			var mk := MeshInstance3D.new()
			mk.mesh = _triangle_mesh(ki_mid, ko0, ko1, THICK + 0.1)
			mk.material_override = side_mat.duplicate()
			add_child(mk)

		if TrackTheme.show_lines(theme_mode):
			var line_inner_r := radius - 0.12
			var line_outer_r := radius + 0.12
			var li_mid := PIVOT + dm * line_inner_r
			var lo0 := PIVOT + d0 * line_outer_r
			var lo1 := PIVOT + d1 * line_outer_r
			var line_mesh := MeshInstance3D.new()
			line_mesh.mesh = _triangle_mesh(li_mid, lo0, lo1, 0.02)
			line_mesh.material_override = line_mat.duplicate()
			line_mesh.position.y += 0.01
			add_child(line_mesh)

		# collision (convex hull of 6 corners — triangular prism)
		var cs  := CollisionShape3D.new()
		var cps := ConvexPolygonShape3D.new()
		cps.points = PackedVector3Array([
			pi_mid, po0, po1,
			pi_mid - Vector3(0, THICK, 0),
			po0    - Vector3(0, THICK, 0),
			po1    - Vector3(0, THICK, 0),
		])
		cs.shape = cps
		sb.add_child(cs)

# ── mesh builder ──────────────────────────────────────────────────────────────

## Builds a triangular prism from three top-face points (all at y=0),
## extruded downward by `thick`.
## apex = inner midpoint, base0/base1 = outer arc endpoints.
func _triangle_mesh(apex: Vector3, base0: Vector3, base1: Vector3,
		thick: float) -> ArrayMesh:
	var ba  := apex  - Vector3(0, thick, 0)
	var bb0 := base0 - Vector3(0, thick, 0)
	var bb1 := base1 - Vector3(0, thick, 0)

	var centroid := (apex + base0 + base1) / 3.0

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()

	# top face
	_tri(verts, norms, apex, base1, base0, Vector3.UP)
	# bottom face (reversed)
	_tri(verts, norms, ba, bb0, bb1, Vector3.DOWN)
	# side: apex → base0
	_quad(verts, norms, apex, base0, bb0, ba,
		_outward_normal(apex, base0, centroid))
	# side: base0 → base1  (outer edge)
	_quad(verts, norms, base0, base1, bb1, bb0,
		_outward_normal(base0, base1, centroid))
	# side: base1 → apex
	_quad(verts, norms, base1, apex, ba, bb1,
		_outward_normal(base1, apex, centroid))

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _tri(verts: PackedVector3Array, norms: PackedVector3Array,
		a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	verts.append_array([a, b, c])
	for _i in range(3):
		norms.append(n)

func _quad(verts: PackedVector3Array, norms: PackedVector3Array,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	verts.append_array([a, b, c,  a, c, d])
	for _i in range(6):
		norms.append(n)

func _outward_normal(from: Vector3, to: Vector3, centroid: Vector3) -> Vector3:
	var edge := (to - from).normalized()
	var n    := edge.cross(Vector3.UP).normalized()
	var mid  := (from + to) * 0.5
	# flip if pointing toward centroid instead of away
	if n.dot(mid - centroid) < 0.0:
		n = -n
	return n
