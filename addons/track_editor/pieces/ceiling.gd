## Half loop into a ceiling road: drive in, curve up and over, and come out
## upside down on a straight ceiling `ceiling_length` long, `2 * radius` up.
## It can drift sideways (`exit_offset`) as it climbs, but keep that small: a
## big drift over a half turn twists the road across your path and throws you
## off. With no drift the ceiling runs back over the approach, so put what you
## drop onto past the run-up. Sticky track, so the car holds on upside down.
## Entry: east face (x=+4, y=0, z=0), heading -X.
## Exit:  ceiling end (x=ceiling_length, y=2*radius, z=exit_offset), heading +X, inverted.
@tool
extends Node3D

const RibbonBuilder = preload("res://addons/track_editor/ribbon_builder.gd")
const TrackTheme = preload("res://addons/track_editor/track_theme.gd")
const ARC_STEPS := 18
const APPROACH_STEPS := 4
const CEILING_STEPS := 8
const SLAB_T := 0.3
const KERB_W := 0.35
const KERB_H := 0.1

@export_storage var radius := 26.0
@export_storage var exit_offset := 0.0
@export_storage var ceiling_length := 96.0
@export_storage var road_width := 24.0
@export_storage var theme_mode := TrackTheme.MODE_LINES
@export_storage var side_color_name := "yellow"


func _ready() -> void:
	_build()


func configure(params: Dictionary) -> void:
	for key in params:
		set(key, params[key])
	for child in get_children():
		child.queue_free()
	_build()


func get_config() -> Dictionary:
	return {road_width = road_width, radius = radius, exit_offset = exit_offset, ceiling_length = ceiling_length}


func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width", min = 6.0, max = 24.0, step = 6.0, default = 24.0},
		{name = "radius", label = "Radius", min = 6.0, max = 30.0, step = 2.0, default = 14.0},
		{name = "exit_offset", label = "Sideways offset", min = 0.0, max = 48.0, step = 8.0, default = 0.0},
		{name = "ceiling_length", label = "Ceiling length", min = 16.0, max = 200.0, step = 8.0, default = 96.0},
	]


func apply_theme(mode: int, side_color: String) -> void:
	theme_mode = mode
	side_color_name = side_color
	for child in get_children():
		child.queue_free()
	_build()


func get_connection_anchors() -> Array:
	return [
		{"position": Vector3(4, 0, 0), "out_dir": Vector3(1, 0, 0)},
		{"position": Vector3(ceiling_length, 2.0 * radius, exit_offset), "out_dir": Vector3(1, 0, 0)},
	]


func _build() -> void:
	var road_mat := TrackTheme.road_material(theme_mode, side_color_name)
	var side_mat := TrackTheme.side_material(side_color_name)
	var line_mat := TrackTheme.line_material()
	var sb := StaticBody3D.new()
	sb.add_to_group("sticky_track")      # the car's gravity follows this surface (RaycastCar)
	add_child(sb)

	var points: Array = []
	var width_dirs: Array = []
	var widths: Array = []
	for i in APPROACH_STEPS + 1:
		points.append(Vector3(4, 0, 0).lerp(Vector3.ZERO, float(i) / APPROACH_STEPS))
		width_dirs.append(Vector3(0, 0, 1))
		widths.append(road_width)
	for i in ARC_STEPS:
		var a := PI * float(i + 1) / ARC_STEPS
		points.append(_arc(a))
		width_dirs.append(_width_dir(a))
		widths.append(road_width)
	var top := _arc(PI)
	for i in CEILING_STEPS:
		points.append(top + Vector3(ceiling_length * float(i + 1) / CEILING_STEPS, 0, 0))
		width_dirs.append(Vector3(0, 0, 1))
		widths.append(road_width)
	RibbonBuilder.add_ribbon(
		self, sb, points, width_dirs, widths,
		road_mat, side_mat, line_mat,
		TrackTheme.show_sides(theme_mode), TrackTheme.show_lines(theme_mode),
		SLAB_T, KERB_W, KERB_H
	)


func _arc(a: float) -> Vector3:
	return Vector3(-radius * sin(a), radius * (1.0 - cos(a)), exit_offset * a / PI)


func _width_dir(a: float) -> Vector3:
	var tangent := Vector3(-radius * cos(a), radius * sin(a), exit_offset / PI).normalized()
	var inward := Vector3(sin(a), cos(a), 0.0)
	return tangent.cross(inward).normalized()
