## Banked turn: flat entry/exit, road surface tilted inward.
@tool
extends Node3D

const TrackTheme = preload("res://addons/track_editor/track_theme.gd")

@export_storage var road_width := 6.0
@export_storage var bank_angle := 30.0
@export_storage var theme_mode := TrackTheme.MODE_LINES
@export_storage var side_color_name := "yellow"

func _ready() -> void:
	_build()

func configure(params: Dictionary) -> void:
	road_width = params.get("road_width", road_width)
	bank_angle = params.get("bank_angle", bank_angle)
	for child in get_children():
		child.queue_free()
	_build()

func get_config() -> Dictionary:
	return {road_width = road_width, bank_angle = bank_angle}

func get_param_defs() -> Array:
	return [
		{name = "road_width", label = "Width",  min = 6.0, max = 12.0, step = 6.0, default = 6.0},
		{name = "bank_angle", label = "Bank Angle", min = 6.0, max = 60.0, step = 6.0, default = 30.0},
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
		{"position": Vector3(0, 0, -4), "out_dir": Vector3(0, 0, -1)},
	]

func _build() -> void:
	var road_mat := TrackTheme.road_material(theme_mode, side_color_name)
	var side_mat := TrackTheme.side_material(side_color_name)
	var line_mat := TrackTheme.line_material()

	# Road slab tilted around Z axis
	var slab_w := road_width + 0.5
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(slab_w, 0.3, 8.0)
	mi.mesh = bm
	mi.material_override = road_mat
	mi.rotation.z = deg_to_rad(-bank_angle)
	mi.position = Vector3(0, 0.3, 0)
	add_child(mi)

	if TrackTheme.show_lines(theme_mode):
		var line := MeshInstance3D.new()
		var lbm := BoxMesh.new()
		lbm.size = Vector3(0.18, 0.02, 8.0)
		line.mesh = lbm
		line.material_override = line_mat
		line.rotation.z = deg_to_rad(-bank_angle)
		line.position = Vector3(0, 0.46, 0)
		add_child(line)

	# Outer wall
	if TrackTheme.show_sides(theme_mode):
		var wm  := MeshInstance3D.new()
		var wbm := BoxMesh.new()
		wbm.size = Vector3(0.3, 2.5, 8.0)
		wm.mesh = wbm
		wm.material_override = side_mat
		wm.position = Vector3(road_width * 0.5 + 0.5, 1.2, 0)
		add_child(wm)

	# Collision
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(slab_w, 0.3, 8.0)
	cs.shape = bs
	cs.rotation.z = deg_to_rad(-bank_angle)
	cs.position = Vector3(0, 0.3, 0)
	sb.add_child(cs)
	add_child(sb)
