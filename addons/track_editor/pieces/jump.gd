## Jump pad: flat road with a curved lip to launch the car.
@tool
extends Node3D

const RibbonBuilder = preload("res://addons/track_editor/ribbon_builder.gd")
const TrackTheme = preload("res://addons/track_editor/track_theme.gd")
const SLAB_T := 0.3
const LIP_LEN := 2.0
const LIP_STEPS := 8
const RAIL_W := 0.15
const RAIL_H := 0.45
const DECK_LEN := 6.0

@export_storage var road_width := 6.0
@export_storage var lip_angle := 18.0
@export_storage var theme_mode := TrackTheme.MODE_LINES
@export_storage var side_color_name := "yellow"

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

func apply_theme(mode: int, side_color: String) -> void:
	theme_mode = mode
	side_color_name = side_color
	for child in get_children():
		child.queue_free()
	_build()

func get_connection_anchors() -> Array:
	var rise := LIP_LEN * tan(deg_to_rad(lip_angle))
	var lip_end := _lip_point(1.0, rise)
	var lip_tangent := (_lip_point(1.0, rise) - _lip_point(1.0 - (1.0 / LIP_STEPS), rise)).normalized()
	return [
		{"position": Vector3(0, 0, 4), "out_dir": Vector3(0, 0, 1)},
		{"position": lip_end, "out_dir": lip_tangent},
	]

func _build() -> void:
	var road_mat := TrackTheme.road_material(theme_mode, side_color_name)
	var lip_mat := TrackTheme.road_material(theme_mode, side_color_name)
	var side_mat := TrackTheme.side_material(side_color_name)
	var line_mat := TrackTheme.line_material()

	var sb := StaticBody3D.new()
	add_child(sb)

	# Main flat slab
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(road_width, SLAB_T, DECK_LEN)
	mi.mesh = bm
	mi.material_override = road_mat
	mi.position = Vector3(0, -SLAB_T * 0.5, 1.0)
	add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(road_width, SLAB_T, DECK_LEN)
	cs.shape = bs
	cs.position = Vector3(0, -SLAB_T * 0.5, 1.0)
	sb.add_child(cs)

	if TrackTheme.show_sides(theme_mode):
		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(RAIL_W * 2.0, RAIL_H, DECK_LEN)
			rail.mesh = rail_mesh
			rail.material_override = side_mat
			rail.position = Vector3(side * (road_width * 0.5 + RAIL_W), -SLAB_T * 0.5 + (RAIL_H - SLAB_T) * 0.5, 1.0)
			add_child(rail)

	if TrackTheme.show_lines(theme_mode):
		var center_line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(0.18, 0.02, DECK_LEN)
		center_line.mesh = line_mesh
		center_line.material_override = line_mat
		center_line.position = Vector3(0, 0.01, 1.0)
		add_child(center_line)

	# Curved launch lip over the front 2 meters.
	var rise := LIP_LEN * tan(deg_to_rad(lip_angle))
	var points: Array = [Vector3(0, 0, -2.0)]
	var width_dirs: Array = [Vector3.RIGHT]
	var widths: Array = [road_width]
	for i in range(LIP_STEPS):
		var t := float(i + 1) / LIP_STEPS
		points.append(_lip_point(t, rise))
		width_dirs.append(Vector3.RIGHT)
		widths.append(road_width)

	RibbonBuilder.add_ribbon(
		self, sb, points, width_dirs, widths,
		lip_mat, side_mat, line_mat,
		TrackTheme.show_sides(theme_mode), TrackTheme.show_lines(theme_mode),
		SLAB_T, RAIL_W, RAIL_H
	)

func _lip_point(t: float, rise: float) -> Vector3:
	var profile_t := 1.0 - cos(t * PI * 0.5)
	return Vector3(0.0, profile_t * rise, -2.0 - t * LIP_LEN)
