class_name CarDustTrail
extends Node

## Spawns dust particles behind rear wheels when grounded and moving.
## Particle color/amount adapts to current terrain type.

enum Terrain { DIRT }

const SPEED_MIN := 5.0   ## units/s — no dust below this
const SPEED_FULL := 40.0  ## units/s — full dust intensity

var terrain: Terrain = Terrain.DIRT

var _car: RigidBody3D
var _wheels: Array[RayCast3D] = []
var _emitters: Array[GPUParticles3D] = []

# Terrain-specific dust colors
const TERRAIN_COLORS := {
	Terrain.DIRT: Color(0.55, 0.40, 0.25, 0.7),
}


func _ready() -> void:
	_car = get_parent() as RigidBody3D
	if not _car:
		push_error("CarDustTrail: parent must be RigidBody3D")
		return

	# Use rear wheels for ground detection, but emit from a single wide emitter behind the car
	for wname in ["WheelRL", "WheelRR"]:
		var w := _car.get_node_or_null(wname) as RayCast3D
		if w:
			_wheels.append(w)

	var emitter := _create_emitter()
	_emitters.append(emitter)
	_car.add_child.call_deferred(emitter)


func _process(_delta: float) -> void:
	if not _car:
		return

	var speed := Vector2(_car.linear_velocity.x, _car.linear_velocity.z).length()
	var intensity := clampf((speed - SPEED_MIN) / (SPEED_FULL - SPEED_MIN), 0.0, 1.0)

	var emitter := _emitters[0]
	if not emitter.is_inside_tree():
		return

	# Check if any rear wheel is grounded
	var grounded := false
	for wheel in _wheels:
		var rw := wheel as RaycastWheel
		if wheel.is_colliding() or (rw and rw.shapecast and rw.shapecast.is_colliding()):
			grounded = true
			break

	emitter.emitting = grounded and speed > SPEED_MIN

	# Scale density with speed — amount_ratio doesn't restart the system
	emitter.amount_ratio = intensity

	# Scale velocity with speed — faster = more kick
	var mat := emitter.process_material as ParticleProcessMaterial
	mat.initial_velocity_max = lerpf(1.0, 6.0, intensity)

	# Always update position so last-emitted particles spawn in the right place
	var rear_center := _car.global_position + _car.global_basis.z * 1.5
	rear_center.y = 0.2
	emitter.global_position = rear_center
	emitter.global_basis = _car.global_basis


func _create_emitter() -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.top_level = true
	emitter.emitting = false
	emitter.amount = 512
	emitter.lifetime = 1.5
	emitter.fixed_fps = 30
	emitter.explosiveness = 0.0
	emitter.randomness = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1.4, 0.0, 0.4)
	mat.direction = Vector3(0, 2.0, 1)  # upward + backward
	mat.spread = 70.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -1.5, 0)
	mat.damping_min = 3.0
	mat.damping_max = 6.0
	# Wide size variance for cloudy, natural look
	mat.scale_min = 0.05
	mat.scale_max = 0.4
	mat.color = TERRAIN_COLORS[Terrain.DIRT]

	# Fade: hold opacity then fade out in last third
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.6))
	gradient.add_point(0.5, Color(1, 1, 1, 0.4))
	gradient.set_color(2, Color(1, 1, 1, 0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	# Grow: start small, puff out to full size
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.2))
	scale_curve.add_point(Vector2(0.3, 0.8))
	scale_curve.add_point(Vector2(1.0, 1.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex

	emitter.process_material = mat

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.3, 0.3)
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mesh_mat
	emitter.draw_pass_1 = mesh

	return emitter
