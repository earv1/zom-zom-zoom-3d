class_name Garlic
extends BaseWeapon

@onready var _area: Area3D = $Area3D
@onready var _disc: MeshInstance3D = $Disc

var _radius: float = 6.0


func _ready() -> void:
	base_damage = 2.0
	base_fire_rate = 2.0
	_update_radius()
	# Detach disc from car hierarchy so it sits flat on the ground.
	_disc.top_level = true


func _process(delta: float) -> void:
	super._process(delta)
	if car:
		_disc.global_position = Vector3(car.global_position.x, 0.05, car.global_position.z)


func _update_radius() -> void:
	_update_collision_radius(_area, _radius)

	if not _disc:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = _radius
	cyl.bottom_radius = _radius
	cyl.height = 0.05
	cyl.radial_segments = 48
	cyl.rings = 1
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.9, 0.25, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	cyl.surface_set_material(0, mat)
	_disc.mesh = cyl


func fire() -> void:
	for body in _area.get_overlapping_bodies():
		if body is BaseEnemy:
			body.take_damage(int(get_damage()))


func _apply_level() -> void:
	match level:
		2:
			_radius += 3.0
			_update_radius()
		3:
			base_damage = 6.0
