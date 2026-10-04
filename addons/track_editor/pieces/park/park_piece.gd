@tool
class_name ParkPiece
extends Node3D
## Base for skatepark pieces. Subclasses declare their settings as
## @export_storage vars, list them in get_param_defs() (shown in the track
## editor dock) and build their geometry in _build(). Origin = centre of the
## cell the piece is placed on; the riding approach is from +Z unless noted.

@export_storage var theme_mode := TrackTheme.MODE_LINES
@export_storage var side_color_name := "yellow"


func _ready() -> void:
	_build()


func configure(params: Dictionary) -> void:
	for key in params:
		set(key, params[key])
	_rebuild()


func get_config() -> Dictionary:
	var config := {}
	for def in get_param_defs():
		config[def.name] = get(def.name)
	return config


func get_param_defs() -> Array:
	return []


func apply_theme(mode: int, side_color: String) -> void:
	theme_mode = mode
	side_color_name = side_color
	_rebuild()


func get_connection_anchors() -> Array:
	return [{"position": Vector3(0, 0, 4), "out_dir": Vector3(0, 0, 1)}]


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_build()


func _build() -> void:
	pass


## Coping rail along x at (z, y).
func _coping(width: float, z: float, y: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.14
	cyl.height = width
	cyl.radial_segments = 8
	mi.mesh = cyl
	mi.material_override = ParkGeometry.coping()
	mi.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, y, z))
	add_child(mi)
