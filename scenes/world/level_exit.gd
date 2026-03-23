class_name LevelExit
extends Node3D

## Visible pillar of light marking the level exit.
## Requires minimum level to activate.

const TRIGGER_RADIUS := 8.0
const REQUIRED_LEVEL := 5

var _mesh: MeshInstance3D
var _glow: MeshInstance3D
var _car: Node3D
var _time := 0.0
var _active := false
var _mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D


func _ready() -> void:
	_setup_visuals()


func set_car(car: Node3D) -> void:
	_car = car


func _process(delta: float) -> void:
	_time += delta

	# Check if level requirement met
	var was_active := _active
	_active = GameManager.current_level >= REQUIRED_LEVEL

	if _active != was_active:
		_update_colors()

	if _mesh:
		_mesh.position.y = 2.0 + sin(_time * 2.0) * 0.3
	if _glow:
		_glow.position.y = 1.0
		var s := 1.0 + sin(_time * 3.0) * 0.15
		_glow.scale = Vector3(s, 1.0, s)


func is_active() -> bool:
	return _active


func _update_colors() -> void:
	if _active:
		if _mat:
			_mat.albedo_color = Color(0.2, 1.0, 0.4, 0.6)
			_mat.emission = Color(0.2, 1.0, 0.4)
		if _glow_mat:
			_glow_mat.albedo_color = Color(0.2, 1.0, 0.4, 0.3)
			_glow_mat.emission = Color(0.2, 1.0, 0.4)
	else:
		if _mat:
			_mat.albedo_color = Color(0.5, 0.5, 0.5, 0.3)
			_mat.emission = Color(0.3, 0.3, 0.3)
			_mat.emission_energy_multiplier = 1.0
		if _glow_mat:
			_glow_mat.albedo_color = Color(0.5, 0.5, 0.5, 0.15)
			_glow_mat.emission = Color(0.3, 0.3, 0.3)
			_glow_mat.emission_energy_multiplier = 0.5


func _setup_visuals() -> void:
	# Main beacon cylinder
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Mesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.8
	cyl.height = 4.0
	mesh_inst.mesh = cyl
	mesh_inst.position.y = 2.0

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.5, 0.5, 0.5, 0.3)
	_mat.emission_enabled = true
	_mat.emission = Color(0.3, 0.3, 0.3)
	_mat.emission_energy_multiplier = 1.0
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = _mat
	add_child(mesh_inst)
	_mesh = mesh_inst

	# Glow ring on ground
	var glow_inst := MeshInstance3D.new()
	glow_inst.name = "Glow"
	var torus := CylinderMesh.new()
	torus.top_radius = 5.0
	torus.bottom_radius = 5.0
	torus.height = 0.1
	glow_inst.mesh = torus
	glow_inst.position.y = 1.0

	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.5, 0.5, 0.5, 0.15)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(0.3, 0.3, 0.3)
	_glow_mat.emission_energy_multiplier = 0.5
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_inst.material_override = _glow_mat
	add_child(glow_inst)
	_glow = glow_inst
