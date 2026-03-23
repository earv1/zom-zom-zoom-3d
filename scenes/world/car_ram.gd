## Ram component — attach as a child of the Car RigidBody3D.
## Deals speed-scaled damage to any enemy that enters the front zone,
## and shows an animated air-wave ring effect when above the speed threshold.
extends Node3D

const RAM_SPEED_MIN  := 55.6   ## units/s (~200 km/h) — below this, no ram damage
const BASE_DAMAGE    := 20
const MAX_DAMAGE     := 60
const KNOCK_FORCE    := 2.5    ## multiplied by speed
const SPEED_PENALTY  := 2.78   ## units/s (~10 km/h) lost per ram hit
const RING_COUNT     := 3
const RING_CYCLE     := 0.35   ## seconds per ring pass

@onready var _area: Area3D = $Area3D

var _car: RigidBody3D
var _rings: Array[MeshInstance3D] = []
var _ring_phases: Array[float] = []
var is_ramming := false


func _ready() -> void:
	_car = get_parent() as RigidBody3D
	_area.body_entered.connect(_on_body_entered)
	_build_rings()


func _process(delta: float) -> void:
	if not _car:
		return
	var speed := _car.linear_velocity.length()
	var was_ramming := is_ramming
	is_ramming = speed >= RAM_SPEED_MIN
	_area.monitoring = is_ramming
	if is_ramming != was_ramming:
		pass
	_update_rings(delta, speed)


# ── Visual ───────────────────────────────────────────────────────────────────

func _build_rings() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color  = Color(0.45, 0.85, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission      = Color(0.3, 0.7, 1.0)
	mat.cull_mode     = BaseMaterial3D.CULL_DISABLED

	for i in RING_COUNT:
		var torus := TorusMesh.new()
		torus.inner_radius  = 0.75
		torus.outer_radius  = 1.0
		torus.rings         = 6
		torus.ring_segments = 16

		var mi := MeshInstance3D.new()
		mi.mesh              = torus
		mi.material_override = mat.duplicate()
		mi.rotation_degrees.x = 90.0   # face -Z (car forward)
		add_child(mi)
		_rings.append(mi)
		_ring_phases.append(float(i) / RING_COUNT)


func _update_rings(delta: float, speed: float) -> void:
	var intensity := clampf((speed - RAM_SPEED_MIN) / 30.0, 0.0, 1.0)
	for i in _rings.size():
		var ring := _rings[i]
		if not is_ramming:
			ring.visible = false
			continue
		ring.visible = true
		_ring_phases[i] = fmod(_ring_phases[i] + delta / RING_CYCLE, 1.0)
		var t := _ring_phases[i]
		# Travel from bumper outward along -Z
		ring.position.z = lerpf(-0.3, -3.0, t)
		var s := lerpf(0.5, 2.2, t)
		ring.scale = Vector3(s, s, s)
		var m := ring.material_override as StandardMaterial3D
		m.albedo_color.a = lerpf(0.75, 0.0, t) * intensity


# ── Damage ───────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if not is_ramming or not _car:
		return
	if body == _car or not body.has_method("take_damage"):
		return
	var speed := _car.linear_velocity.length()
	var t      := clampf((speed - RAM_SPEED_MIN) / (120.0 - RAM_SPEED_MIN), 0.0, 1.0)
	var damage := int(lerpf(BASE_DAMAGE, MAX_DAMAGE, t))
	body.take_damage(damage)

	if body is RigidBody3D:
		var away: Vector3 = (body as RigidBody3D).global_position - _car.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			body.apply_central_impulse(away.normalized() * speed * KNOCK_FORCE)
