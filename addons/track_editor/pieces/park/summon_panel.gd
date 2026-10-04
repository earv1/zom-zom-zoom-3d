@tool
extends ParkPiece
## Boss summon panel (Risk of Rain teleporter style): a glowing rune disc with a
## beam of light you can see across the park. Drive through it to summon the
## next boss. The level listens for `summoned` on nodes in group "summon_panels"
## and sets the label / arms it with set_next().

signal summoned

@export_storage var size := 16.0

const RUNES := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;
uniform vec4 glow : source_color = vec4(1.0, 0.18, 0.08, 1.0);
uniform float armed = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + TIME * 0.6;
	float rim = smoothstep(0.86, 0.9, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float runes = smoothstep(0.62, 0.66, r) * (1.0 - smoothstep(0.78, 0.82, r)) * step(0.5, fract(a * 12.0 / 6.2831));
	float core = (1.0 - smoothstep(0.0, 0.3, r)) * (0.5 + 0.5 * sin(TIME * 4.0));
	ALBEDO = glow.rgb;
	ALPHA = (rim + runes * 0.8 + core * 0.6) * mix(0.25, 1.0, armed) * step(r, 1.0);
}
"""

var _label: Label3D
var _beam: MeshInstance3D
var _disc_mat: ShaderMaterial
var _armed := true


func get_param_defs() -> Array:
	return [{name = "size", label = "Size", min = 8.0, max = 32.0, step = 4.0, default = 16.0}]


func get_connection_anchors() -> Array:
	return []


func set_next(boss_name: String, armed: bool) -> void:
	_armed = armed
	if _label:
		_label.text = "SUMMON " + boss_name if armed else ""
	if _beam:
		_beam.visible = armed
	if _disc_mat:
		_disc_mat.set_shader_parameter("armed", 1.0 if armed else 0.0)


func _build() -> void:
	var disc := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(size, size)
	disc.mesh = quad
	_disc_mat = ShaderMaterial.new()
	_disc_mat.shader = Shader.new()
	_disc_mat.shader.code = RUNES
	disc.material_override = _disc_mat
	disc.position.y = 0.04
	add_child(disc)

	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = size * 0.12
	cyl.bottom_radius = size * 0.2
	cyl.height = 140.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam.mesh = cyl
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(1.0, 0.25, 0.1, 0.18)
	_beam.material_override = beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = 70.0
	add_child(_beam)

	_label = Label3D.new()
	_label.text = "SUMMON"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 120
	_label.pixel_size = 0.03
	_label.outline_size = 20
	_label.modulate = Color(1.0, 0.35, 0.2)
	_label.outline_modulate = Color(0.15, 0.0, 0.0)
	_label.position.y = 9.0
	add_child(_label)

	if not Engine.is_editor_hint():
		add_to_group("summon_panels")
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = size * 0.5
		shape.height = 5.0
		cs.shape = shape
		cs.position.y = 2.5
		area.add_child(cs)
		add_child(area)
		area.body_entered.connect(func(body: Node) -> void:
			if _armed and body.has_node("CarAirControl"):   # the player's car (no class ref: keeps this @tool script autoload-free)
				summoned.emit())
