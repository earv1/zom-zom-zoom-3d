class_name LevelExit
extends Node3D

## Visible pillar of light marking the level exit.

const TRIGGER_RADIUS := 8.0

var _mesh: MeshInstance3D
var _glow: MeshInstance3D
var _car: Node3D
var _time := 0.0


func _ready() -> void:
	_setup_visuals()


func set_car(car: Node3D) -> void:
	_car = car


func _process(delta: float) -> void:
	_time += delta
	# Gentle bob
	if _mesh:
		_mesh.position.y = 2.0 + sin(_time * 2.0) * 0.3
	if _glow:
		_glow.position.y = 1.0
		var s := 1.0 + sin(_time * 3.0) * 0.15
		_glow.scale = Vector3(s, 1.0, s)


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

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.0, 0.4)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.6
	mesh_inst.material_override = mat
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

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.2, 1.0, 0.4, 0.3)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.2, 1.0, 0.4)
	glow_mat.emission_energy_multiplier = 2.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_inst.material_override = glow_mat
	add_child(glow_inst)
	_glow = glow_inst
