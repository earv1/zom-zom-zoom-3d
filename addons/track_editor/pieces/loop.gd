## Full vertical loop — helical so exit is offset by one cell (8 m in Z).
## Entry: east face  (x=+4, y=0, z=0)
## Exit:  west face  (x=-4, y=0, z=+8)  →  place next piece one cell over in Z.
@tool
extends Node3D

const RibbonBuilder = preload("res://addons/track_editor/ribbon_builder.gd")
const TrackTheme = preload("res://addons/track_editor/track_theme.gd")
const LOOP_STEPS := 36
const APPROACH_STEPS := 4
const EXIT_STEPS := 4
const SLAB_T := 0.3
const KERB_W := 0.35
const KERB_H := 0.1

@export_storage var radius := 18.0
@export_storage var road_width := 6.0

func _ready() -> void:
	_build()

func configure(params: Dictionary) -> void:
	radius = params.get("radius", radius)
	road_width = params.get("road_width", road_width)
	for child in get_children():
		child.queue_free()
	_build()

func get_config() -> Dictionary:
	return {road_width = road_width, radius = radius}

func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width", min = 6.0, max = 12.0, step = 6.0, default = 6.0},
		{name = "radius", label = "Radius", min = 6.0, max = 42.0, step = 6.0, default = 18.0},
	]

func _build() -> void:
	var road_mat := TrackTheme.road_material()
	var kerb_mat := TrackTheme.kerb_material()

	var sb := StaticBody3D.new()
	add_child(sb)

	var points: Array = []
	var width_dirs: Array = []
	var widths: Array = []

	_append_flat_section(points, width_dirs, widths, Vector3(4, 0, 0), Vector3(0, 0, 0), APPROACH_STEPS, false)

	for i in range(LOOP_STEPS):
		var t := float(i + 1) / LOOP_STEPS
		var a := TAU * t
		points.append(_arc(a))
		width_dirs.append(_helix_width(a))
		widths.append(road_width)

	_append_flat_section(points, width_dirs, widths, Vector3(0, 0, road_width), Vector3(-4, 0, road_width), EXIT_STEPS, true)

	RibbonBuilder.add_ribbon(self, sb, points, width_dirs, widths, road_mat, kerb_mat, SLAB_T, KERB_W, KERB_H)

func _append_flat_section(points: Array, width_dirs: Array, widths: Array,
		start: Vector3, finish: Vector3, steps: int, skip_first: bool) -> void:
	for i in range(steps):
		if skip_first and i == 0:
			continue
		var t := float(i) / steps
		points.append(start.lerp(finish, t))
		width_dirs.append(Vector3(0, 0, 1))
		widths.append(road_width)
	points.append(finish)
	width_dirs.append(Vector3(0, 0, 1))
	widths.append(road_width)

func _arc(a: float) -> Vector3:
	return Vector3(
		-radius * sin(a),
		radius * (1.0 - cos(a)),
		road_width * a / TAU
	)

func _helix_tangent(a: float) -> Vector3:
	return Vector3(-radius * cos(a), radius * sin(a), road_width / TAU).normalized()

func _helix_inward(a: float) -> Vector3:
	return Vector3(sin(a), cos(a), 0.0)

func _helix_width(a: float) -> Vector3:
	return _helix_tangent(a).cross(_helix_inward(a)).normalized()
