## Ramp: rises over one cell run (8 m). Pitch is configurable.
## Entry: south face (z=+4, y=0). Exit: north face (z=-4, y=+rise).
@tool
extends Node3D

const RibbonBuilder = preload("res://addons/track_editor/ribbon_builder.gd")
const TrackTheme = preload("res://addons/track_editor/track_theme.gd")
const STEPS := 14
const SLAB_T := 0.3
const RUN := 8.0
const RAIL_W := 0.15
const RAIL_H := 0.45

@export_storage var road_width := 6.0
@export_storage var pitch_deg := 30.0
@export_storage var theme_mode := TrackTheme.MODE_LINES
@export_storage var side_color_name := "yellow"

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

func apply_theme(mode: int, side_color: String) -> void:
	theme_mode = mode
	side_color_name = side_color
	for child in get_children():
		child.queue_free()
	_build()

func get_connection_anchors() -> Array:
	var rise := RUN * tan(deg_to_rad(pitch_deg))
	return [
		{"position": Vector3(0, 0, 4), "out_dir": Vector3(0, 0, 1)},
		{"position": _ramp_point(1.0, rise), "out_dir": _ramp_tangent(1.0, rise)},
	]

func _build() -> void:
	var rise := RUN * tan(deg_to_rad(pitch_deg))

	var road_mat := TrackTheme.road_material(theme_mode, side_color_name)
	var side_mat := TrackTheme.side_material(side_color_name)
	var line_mat := TrackTheme.line_material()

	var sb := StaticBody3D.new()
	add_child(sb)

	var points: Array = []
	var width_dirs: Array = []
	var widths: Array = []
	for i in range(STEPS):
		var ta := float(i) / STEPS
		points.append(_ramp_point(ta, rise))
		width_dirs.append(_section_right(ta, rise))
		widths.append(road_width)
	points.append(_ramp_point(1.0, rise))
	width_dirs.append(_section_right(1.0, rise))
	widths.append(road_width)

	RibbonBuilder.add_ribbon(
		self, sb, points, width_dirs, widths,
		road_mat, side_mat, line_mat,
		TrackTheme.show_sides(theme_mode), TrackTheme.show_lines(theme_mode),
		SLAB_T, RAIL_W, RAIL_H
	)

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
