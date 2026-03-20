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

@export_storage var road_width := 6.0
@export_storage var lip_angle := 18.0

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

func _build() -> void:
	var road_mat := TrackTheme.road_material(true)
	var lip_mat := TrackTheme.road_material(true)
	var rail_mat := TrackTheme.kerb_material()

	var sb := StaticBody3D.new()
	add_child(sb)

	# Main flat slab
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(road_width, SLAB_T, 6.0)
	mi.mesh = bm
	mi.material_override = road_mat
	mi.position = Vector3(0, -SLAB_T * 0.5, 1.0)
	add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(road_width, SLAB_T, 6.0)
	cs.shape = bs
	cs.position = Vector3(0, -SLAB_T * 0.5, 1.0)
	sb.add_child(cs)

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

	RibbonBuilder.add_ribbon(self, sb, points, width_dirs, widths, lip_mat, rail_mat, SLAB_T, RAIL_W, RAIL_H)

func _lip_point(t: float, rise: float) -> Vector3:
	var profile_t := 1.0 - cos(t * PI * 0.5)
	return Vector3(0.0, profile_t * rise, -2.0 - t * LIP_LEN)
