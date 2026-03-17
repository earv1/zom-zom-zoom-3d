class_name CarBlobShadow
extends Node3D

@export var max_distance: float = 8.0
@export var shadow_length: float = 3.0  # footprint when car is flat (car's length)
@export var shadow_width: float = 2.0   # footprint side-to-side (car's width)
@export var shadow_height: float = 1.5  # contributes when car is vertical (car's height)
@export var shadow_opacity: float = 0.5

var _car: RigidBody3D
var _ray: RayCast3D
var _mesh: MeshInstance3D
var _quad: QuadMesh


func _ready() -> void:
	_car = get_parent() as RigidBody3D
	# Detach from car's transform so rotation/scale don't affect us
	top_level = true

	_ray = RayCast3D.new()
	_ray.target_position = Vector3.DOWN * max_distance
	_ray.enabled = true
	add_child(_ray)

	_quad = QuadMesh.new()
	_quad.size = Vector2(shadow_width, shadow_length)

	_mesh = MeshInstance3D.new()
	_mesh.mesh = _quad
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = _build_material()
	add_child(_mesh)


func _build_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float opacity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 2.0;
	float alpha = (1.0 - smoothstep(0.5, 1.0, dist)) * opacity;
	ALBEDO = vec3(0.0);
	ALPHA = alpha;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("opacity", shadow_opacity)
	return mat


func _physics_process(_delta: float) -> void:
	# Follow car position in world space (ignoring its rotation)
	global_position = _car.global_position

	if not _ray.is_colliding():
		_mesh.visible = false
		return

	var hit_point := _ray.get_collision_point()
	var hit_normal := _ray.get_collision_normal()
	_mesh.visible = true
	_mesh.global_position = hit_point + hit_normal * 0.02

	# ── Shadow dimensions based on car rotation ───────────────────────────────
	# Project each car axis onto the horizontal plane.
	# The car's forward (Z) and height (Y) axes both contribute to shadow length;
	# the car's right (X) and height (Y) axes both contribute to shadow width.
	# Result: flat = oval, mid-flip = circle, upside-down = oval again.
	var car_basis := _car.global_basis
	var z_flat := Vector3(car_basis.z.x, 0.0, car_basis.z.z)
	var x_flat := Vector3(car_basis.x.x, 0.0, car_basis.x.z)
	var y_flat := Vector3(car_basis.y.x, 0.0, car_basis.y.z)

	# Horizontal forward direction — fall back to y_flat when car is vertical
	var fwd_flat := z_flat if z_flat.length_squared() > 0.01 else y_flat
	if fwd_flat.length_squared() < 0.001:
		fwd_flat = Vector3.FORWARD
	fwd_flat = fwd_flat.normalized()
	var right_flat := Vector3.UP.cross(fwd_flat).normalized()

	# How much the car's up axis spills into each horizontal direction
	var y_along_fwd   := absf(y_flat.dot(fwd_flat))
	var y_along_right := absf(y_flat.dot(right_flat))

	var cur_length := shadow_length * z_flat.length() + shadow_height * y_along_fwd
	var cur_width  := shadow_width  * x_flat.length() + shadow_height * y_along_right
	_quad.size = Vector2(cur_width, cur_length)

	# ── Orient quad flat on surface, aligned with car's horizontal forward ────
	var up    := hit_normal
	var right := up.cross(fwd_flat).normalized()
	var fwd   := right.cross(up).normalized()
	_mesh.global_transform.basis = Basis(right, up, -fwd).rotated(right, -PI * 0.5)
