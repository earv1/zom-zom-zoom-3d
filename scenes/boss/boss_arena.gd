class_name BossArena
extends Node3D
## Ring arena that rises out of the desert for boss fights: a sandstone wall with
## a banked inner slope you can ride, obelisks with glowing crystals, and a
## cracked clay floor. rise()/sink() animate it out of / into the ground with a
## rumble jitter; the level adds the screen shake.

signal risen
signal sunk

@export var radius := 140.0
@export var wall_height := 10.0
@export var segments := 80
@export var ground_y := 0.0      ## height of the ground the arena stands on

const BURY := 16.0
const WALL_INNER := 2.0          ## the outer wall's inner face sits this far past radius

const FLOOR_SHADER := """
shader_type spatial;
uniform vec3 clay : source_color = vec3(0.70, 0.50, 0.34);
uniform vec3 crack : source_color = vec3(0.38, 0.23, 0.15);
uniform vec3 ring : source_color = vec3(0.86, 0.66, 0.44);
varying vec3 p;
vec2 h2(vec2 x) { return fract(sin(vec2(dot(x, vec2(127.1, 311.7)), dot(x, vec2(269.5, 183.3)))) * 43758.5453); }
void vertex() { p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - MODEL_MATRIX[3].xyz; }
void fragment() {
	// voronoi cell edges = mud cracks
	vec2 g = p.xz / 5.0;
	vec2 i = floor(g);
	float d1 = 9.0, d2 = 9.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 c = i + vec2(float(x), float(y));
		float d = length(g - c - h2(c));
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	float cracks = 1.0 - smoothstep(0.02, 0.07, d2 - d1);
	float r = length(p.xz);
	float rings = smoothstep(0.6, 0.0, abs(fract(r / 14.0) - 0.5) * 14.0 - 6.4);
	vec3 col = mix(clay, ring, rings * 0.45);
	ALBEDO = mix(col, crack, cracks * 0.8);
	ROUGHNESS = 0.95;
}
"""

var _t := 0.0
var _from := 0.0
var _to := 0.0
var _duration := 0.0
var _moving := false


func _ready() -> void:
	_build()
	position.y = ground_y - BURY
	visible = false


func rise(duration: float = 2.0) -> void:
	visible = true
	_animate(ground_y - BURY, ground_y, duration)


func sink(duration: float = 2.0) -> void:
	_animate(ground_y, ground_y - BURY, duration)


func _animate(from: float, to: float, duration: float) -> void:
	_from = from
	_to = to
	_duration = duration
	_t = 0.0
	_moving = true


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	_t = minf(_t + delta, _duration)
	var k := smoothstep(0.0, 1.0, _t / _duration)
	var rumble := 0.25 * sin(_t * 47.0) * (1.0 - k)
	position.y = lerpf(_from, _to, k) + rumble
	if _t >= _duration:
		_moving = false
		position.y = _to
		if _to < _from:
			visible = false
			sunk.emit()
		else:
			risen.emit()


func _build() -> void:
	var stone := _mat(Color(0.74, 0.47, 0.30))
	var stone_dark := _mat(Color(0.60, 0.36, 0.23))
	var body := StaticBody3D.new()
	add_child(body)

	var floor_mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius + 2.0
	disc.bottom_radius = radius + 2.0
	disc.height = 0.3
	disc.radial_segments = 64
	floor_mi.mesh = disc
	floor_mi.position.y = -0.13           # top sits 2 cm above the ground it stands on
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = Shader.new()
	floor_mat.shader.code = FLOOR_SHADER
	floor_mi.material_override = floor_mat
	add_child(floor_mi)

	var seg_w := TAU * (radius + 2.0) / segments * 1.08
	for i in segments:
		var a := TAU * i / segments
		var out := Vector3(sin(a), 0.0, cos(a))
		var facing := Basis.looking_at(-out)
		var mat := stone if i % 2 == 0 else stone_dark
		var h := wall_height * (1.0 + 0.12 * sin(i * 2.7))
		# outer wall
		_block(body, Vector3(seg_w, h, 3.0), Transform3D(facing, out * (radius + 3.5) + Vector3.UP * h * 0.5), mat)
		# banked inner slope (about 35 degrees) the car can ride up
		var bank := facing * Basis(Vector3.RIGHT, deg_to_rad(-35.0))
		_block(body, Vector3(seg_w, 0.8, 9.0), Transform3D(bank, out * (radius - 1.5) + Vector3.UP * 2.3), mat)
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var out := Vector3(sin(a), 0.0, cos(a))
		_block(body, Vector3(4.0, 22.0, 4.0), Transform3D(Basis(Vector3.UP, a), out * (radius + 4.0) + Vector3.UP * 11.0), stone_dark)
		var crystal := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(2.4, 3.6, 2.4)
		crystal.mesh = prism
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.2, 0.12)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.15, 0.05)
		glow.emission_energy_multiplier = 3.0
		crystal.material_override = glow
		crystal.position = out * (radius + 4.0) + Vector3.UP * 23.8
		add_child(crystal)


func _block(body: StaticBody3D, size: Vector3, xform: Transform3D, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.transform = xform
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xform
	body.add_child(cs)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	return m
