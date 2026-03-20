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

	var mat := TrackTheme.road_material()
	var kerb_mat := TrackTheme.kerb_material()

	var sb := StaticBody3D.new()
	add_child(sb)

	var points: Array = []
	var width_dirs: Array = []
	var widths: Array = []
	for i in range(STEPS):
		var ta := float(i) / STEPS
		points.append(_bezier(p0, p1, p2, p3, ta) - start_pos)
		width_dirs.append(_section_right(p0, p1, p2, p3, ta))
		widths.append(_width_at(ta))
	points.append(_bezier(p0, p1, p2, p3, 1.0) - start_pos)
	width_dirs.append(_section_right(p0, p1, p2, p3, 1.0))
	widths.append(_width_at(1.0))

	RibbonBuilder.add_ribbon(self, sb, points, width_dirs, widths, mat, kerb_mat, SLAB_T, KERB_W, KERB_H)

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
