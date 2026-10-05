@tool
extends ParkPiece
## Pound pad: a floating block with a glowing target on top. Ground-pound it
## and it springs the car up `bounce` metres and pushes it `push` m/s along the
## pad's facing (-Z, the arrow), toward the next pad: the platformer hop of the
## Ground Pound skill. Rolling onto it gently does nothing. Origin = top centre.

@export_storage var size := 12.0
@export_storage var thickness := 3.0
@export_storage var bounce := 22.0
@export_storage var push := 14.0

const TARGET := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;
uniform vec4 glow : source_color = vec4(1.0, 0.55, 0.1, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float rings = step(0.5, fract(r * 3.0 - TIME * 0.8)) * (1.0 - smoothstep(0.85, 0.95, r));
	float bull = 1.0 - smoothstep(0.16, 0.2, r);
	ALBEDO = glow.rgb;
	ALPHA = (rings * 0.45 + bull) * step(r, 1.0);
}
"""


func get_param_defs() -> Array:
	return [
		{name = "size", label = "Size", min = 6.0, max = 32.0, step = 2.0, default = 12.0},
		{name = "thickness", label = "Thickness", min = 1.0, max = 8.0, step = 1.0, default = 3.0},
		{name = "bounce", label = "Bounce (m)", min = 6.0, max = 60.0, step = 2.0, default = 22.0},
		{name = "push", label = "Push (m/s)", min = 0.0, max = 40.0, step = 2.0, default = 14.0},
	]


func get_connection_anchors() -> Array:
	return []


## What a ground pound on this pad does to the car: rise this high, moving this fast sideways.
func pound_launch() -> Dictionary:
	var ahead := -global_basis.z
	ahead.y = 0.0
	return {height = bounce, push = ahead.normalized() * push}


func _build() -> void:
	ParkGeometry.box(self, Vector3(size, thickness, size), Vector3(0, -thickness * 0.5, 0), ParkGeometry.concrete())
	var target := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * size * 0.9
	target.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = TARGET
	target.material_override = mat
	target.position.y = 0.04
	target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(target)
	if push > 0.0:                                     # arrow toward where it throws you
		var arrow := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(size * 0.3, 0.1, size * 0.25)
		arrow.mesh = prism
		var amat := StandardMaterial3D.new()
		amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		amat.albedo_color = Color(1.0, 0.85, 0.3)
		arrow.material_override = amat
		arrow.rotation_degrees.x = -90.0
		arrow.position = Vector3(0, 0.08, -size * 0.32)
		add_child(arrow)
