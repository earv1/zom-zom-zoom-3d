## Bezier connector between two track pieces.
## start_pos / end_pos are world-space (TrackRoot assumed at origin).
## The node's own position is set to start_pos; all geometry is local to that.
@tool
extends Node3D

const RibbonBuilder = preload("res://addons/track_editor/ribbon_builder.gd")
const TrackTheme = preload("res://addons/track_editor/track_theme.gd")
const STEPS  := 24
const SLAB_T := 0.3
const KERB_W := 0.35
const KERB_H := 0.1
const DEBUG_RAISE      := 0.35
const DEBUG_LINE_WIDTH := 0.3   # world-space half-width of debug ribbon segments

@export_storage var start_pos  := Vector3.ZERO
@export_storage var start_dir  := Vector3(0, 0, 1)
@export_storage var end_pos    := Vector3(8, 0, 0)
@export_storage var end_dir    := Vector3(1, 0, 0)
@export_storage var road_width := 6.0
@export_storage var start_width := 6.0
@export_storage var end_width := 6.0
@export_storage var theme_mode := TrackTheme.MODE_LINES
@export_storage var side_color_name := "yellow"
@export var debug_show_bezier := false:
	set(value):
		debug_show_bezier = value
		if is_node_ready():
			for child in get_children():
				child.queue_free()
			_build()

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

func apply_theme(mode: int, side_color: String) -> void:
	theme_mode = mode
	side_color_name = side_color
	for child in get_children():
		child.queue_free()
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	var sampled := _sample_path(STEPS)
	var points: Array = sampled.get("points", [])
	var width_dirs: Array = sampled.get("width_dirs", [])
	if points.is_empty() or width_dirs.size() != points.size():
		return

	if debug_show_bezier:
		var controls: Array = sampled.get("controls", [])
		_add_debug_bezier(points, controls)
		return

	var mat := TrackTheme.road_material(theme_mode, side_color_name)
	var side_mat := TrackTheme.side_material(side_color_name)
	var line_mat := TrackTheme.line_material()

	var sb := StaticBody3D.new()
	add_child(sb)

	var widths: Array = []
	for i in range(points.size()):
		var t: float = float(i) / max(1, points.size() - 1)
		widths.append(_width_at(t))

	RibbonBuilder.add_ribbon(
		self, sb, points, width_dirs, widths,
		mat, side_mat, line_mat,
		TrackTheme.show_sides(theme_mode), TrackTheme.show_lines(theme_mode),
		SLAB_T, KERB_W, KERB_H
	)

func sample_centerline(steps: int = STEPS) -> Array:
	var local_points: Array = _sample_path(steps).get("points", [])
	var world_points: Array = []
	for point in local_points:
		world_points.append((point as Vector3) + start_pos)
	return world_points

func sample_width_dirs(steps: int = STEPS) -> Array:
	return _sample_path(steps).get("width_dirs", [])

func sample_debug_controls(steps: int = STEPS) -> Array:
	var local_controls: Array = _sample_path(steps).get("controls", [])
	var world_controls: Array = []
	for point in local_controls:
		world_controls.append((point as Vector3) + start_pos)
	return world_controls

func _sample_path(steps: int) -> Dictionary:
	if steps < 1:
		return {}
	if _should_use_flush_approach_path():
		return _sample_flush_approach_path(steps)
	if _should_use_straight_centerline():
		var straight_points := _sample_straight_centerline(steps)
		return {
			"points": _to_local_points(straight_points),
			"width_dirs": _constant_width_dirs(steps, _straight_width_dir()),
			"controls": _to_local_points([
				start_pos,
				start_pos.lerp(end_pos, 1.0 / 3.0),
				start_pos.lerp(end_pos, 2.0 / 3.0),
				end_pos,
			]),
		}
	return _sample_guided_turn_path(steps)

func _should_use_straight_centerline() -> bool:
	var chord_vec := end_pos - start_pos
	if chord_vec.length() < 0.01:
		return false
	var planar_changed_axes := 0
	if absf(chord_vec.x) > 0.001:
		planar_changed_axes += 1
	if absf(chord_vec.z) > 0.001:
		planar_changed_axes += 1
	return planar_changed_axes <= 1

func _should_use_flush_approach_path() -> bool:
	var chord_vec := end_pos - start_pos
	return _should_use_straight_centerline() and absf(chord_vec.y) > 0.001 and (absf(chord_vec.x) > 0.001 or absf(chord_vec.z) > 0.001)

func _sample_flush_approach_path(steps: int) -> Dictionary:
	var planar_start := start_dir
	planar_start.y = 0.0
	var planar_chord := end_pos - start_pos
	planar_chord.y = 0.0
	if planar_chord.length_squared() < 0.0001:
		planar_chord = planar_start
	var chord_dir := planar_chord.normalized()
	if planar_start.length_squared() < 0.0001 or planar_start.normalized().dot(chord_dir) < 0.2:
		planar_start = chord_dir
	else:
		planar_start = planar_start.normalized()
	var planar_end := end_dir
	planar_end.y = 0.0
	if planar_end.length_squared() < 0.0001 or planar_end.normalized().dot(chord_dir) < 0.2:
		planar_end = chord_dir
	else:
		planar_end = planar_end.normalized()

	var approach_len := min(2.0, planar_chord.length() * 0.35)
	var p0: Vector3 = start_pos
	var p1: Vector3 = start_pos + planar_start * approach_len
	var p2: Vector3 = end_pos - planar_end * approach_len
	var p3: Vector3 = end_pos
	var world_points := _sample_polyline([p0, p1, p2, p3], steps)
	return {
		"points": _to_local_points(world_points),
		"width_dirs": _constant_width_dirs(steps, _straight_width_dir()),
		"controls": _to_local_points([p0, p1, p2, p3]),
	}

func _sample_guided_turn_path(steps: int) -> Dictionary:
	var chord_vec := end_pos - start_pos
	if chord_vec.length() < 0.01:
		return {}

	var chord := chord_vec.length()
	# Scale guide length with chord so short connectors don't overshoot
	var guide_len := clampf(chord * 0.3, 0.5, 4.0)
	# Cubic Bezier: derivative at t=0 = 3*(p1-p0) ∝ start_dir,
	# derivative at t=1 = 3*(p3-p2) ∝ end_dir — guarantees flush junctions.
	var p0: Vector3 = start_pos
	var p1: Vector3 = start_pos + start_dir.normalized() * guide_len
	var p2: Vector3 = end_pos   - end_dir.normalized()   * guide_len
	var p3: Vector3 = end_pos

	var guides: Array = [p0, p1, p2, p3]
	var points: Array = []
	var width_dirs: Array = []
	for i in range(steps + 1):
		var t: float = float(i) / steps
		var world_point := _sample_cubic_bezier(p0, p1, p2, p3, t)
		var tangent := _sample_cubic_bezier_derivative(p0, p1, p2, p3, t)
		points.append(world_point - start_pos)
		width_dirs.append(_width_dir_from_tangent(tangent))
	return {"points": points, "width_dirs": width_dirs, "controls": _to_local_points(guides)}

func _sample_straight_centerline(steps: int) -> Array:
	var points: Array = []
	for i in range(steps + 1):
		var t := float(i) / steps
		points.append(start_pos.lerp(end_pos, t))
	return points

func _sample_polyline(world_points: Array, steps: int) -> Array:
	if world_points.size() < 2:
		return world_points
	var lengths: Array = [0.0]
	var total := 0.0
	for i in range(world_points.size() - 1):
		total += (world_points[i + 1] - world_points[i]).length()
		lengths.append(total)
	var sampled: Array = []
	for i in range(steps + 1):
		var target := total * float(i) / steps
		for seg in range(world_points.size() - 1):
			var a_len: float = lengths[seg]
			var b_len: float = lengths[seg + 1]
			if target <= b_len or seg == world_points.size() - 2:
				var seg_len := max(0.001, b_len - a_len)
				var local_t := clampf((target - a_len) / seg_len, 0.0, 1.0)
				sampled.append((world_points[seg] as Vector3).lerp(world_points[seg + 1] as Vector3, local_t))
				break
	return sampled

func _straight_width_dir() -> Vector3:
	var planar := end_pos - start_pos
	planar.y = 0.0
	if planar.length_squared() < 0.0001:
		planar = start_dir
		planar.y = 0.0
	if planar.length_squared() < 0.0001:
		return Vector3.RIGHT
	return planar.normalized().cross(Vector3.UP).normalized()

func _constant_width_dirs(steps: int, dir: Vector3) -> Array:
	var dirs: Array = []
	for _i in range(steps + 1):
		dirs.append(dir)
	return dirs

func _to_local_points(world_points: Array) -> Array:
	var local_points: Array = []
	for point in world_points:
		local_points.append((point as Vector3) - start_pos)
	return local_points

func _width_dir_from_tangent(tangent: Vector3) -> Vector3:
	tangent.y = 0.0
	if tangent.length_squared() < 0.0001:
		return Vector3.RIGHT
	return tangent.normalized().cross(Vector3.UP).normalized()

func _sample_cubic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return u*u*u * p0 + 3.0*u*u*t * p1 + 3.0*u*t*t * p2 + t*t*t * p3

func _sample_cubic_bezier_derivative(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return 3.0 * (u*u*(p1 - p0) + 2.0*u*t*(p2 - p1) + t*t*(p3 - p2))

func _width_at(t: float) -> float:
	return lerpf(start_width, end_width, t)

func _add_debug_bezier(centerline_points: Array, control_points: Array) -> void:
	_add_debug_line(centerline_points, Color(0.05, 0.25, 0.85), "DebugCenterline")
	_add_debug_line(control_points, Color(1.0, 0.45, 0.2), "DebugControls")
	for i in range(control_points.size()):
		_add_debug_marker(control_points[i], Color(1.0, 0.8, 0.2), "DebugPoint%d" % i)

func _add_debug_line(points: Array, color: Color, node_name: String) -> void:
	if points.size() < 2:
		return
	var verts := PackedVector3Array()
	var raise := Vector3.UP * DEBUG_RAISE
	for i in range(points.size() - 1):
		var a: Vector3 = (points[i] as Vector3) + raise
		var b: Vector3 = (points[i + 1] as Vector3) + raise
		var along := b - a
		if along.length_squared() < 0.00001:
			continue
		var right := along.normalized().cross(Vector3.UP)
		if right.length_squared() < 0.00001:
			right = along.normalized().cross(Vector3.FORWARD)
		right = right.normalized() * DEBUG_LINE_WIDTH
		verts.append_array([
			a - right, a + right, b + right,
			a - right, b + right, b - right,
		])
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)

func _add_debug_marker(pos: Vector3, color: Color, node_name: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos + Vector3.UP * DEBUG_RAISE
	add_child(mi)
