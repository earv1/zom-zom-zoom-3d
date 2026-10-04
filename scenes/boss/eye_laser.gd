class_name EyeLaser
extends Node3D
## Eye laser with a ground target circle that hunts its target.
##
## start() runs CHARGE -> FIRE -> END. While charging, the circle locks on and
## chases the target; while firing, the beam runs from origin() to the circle
## and the target takes damage whenever it is inside the circle. The circle is
## slower than the car, so driving away is how you dodge it. Everything is
## computed at runtime: the owner only supplies the beam origin and a target.

signal state_changed(new_state: State)
signal target_hit(amount: int)

enum State { IDLE, CHARGE, FIRE, END }

@export var target: Node3D
@export var radius := 6.0                ## circle radius in world units
@export var charge_time := 1.5           ## matches the boss's laser_charge clip
@export var fire_time := 3.0
@export var end_time := 0.5
@export var track_speed := 26.0          ## circle chase speed while charging (the car tops out at 60)
@export var fire_track_speed := 15.0     ## slower while the beam is live
@export var damage_per_second := 25.0
@export var damage_tick := 5             ## damage is dealt in chunks of this size
@export var damages_player := true       ## route hits to GameManager.take_damage
@export var snap_to_ground := true       ## raycast the circle onto the terrain
@export var beam_width := 0.3
@export var color := Color(1.0, 0.12, 0.05)

## Beam origin in global space; the boss points this at its laser_eye bone.
var origin: Callable = func() -> Vector3: return global_position

var state := State.IDLE
var circle_center := Vector3.ZERO

var _t := 0.0
var _damage_owed := 0.0
var _ground_normal := Vector3.UP
var _circle: MeshInstance3D
var _circle_mat: ShaderMaterial
var _beam: MeshInstance3D
var _beam_glow: MeshInstance3D
var _light: OmniLight3D
var _sparks: CPUParticles3D


func _ready() -> void:
	_circle = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_circle.mesh = quad
	_circle_mat = ShaderMaterial.new()
	_circle_mat.shader = preload("res://scenes/boss/laser_target.gdshader")
	_circle_mat.set_shader_parameter("color", color)
	_circle.material_override = _circle_mat
	_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_circle.top_level = true
	add_child(_circle)

	_beam = _make_beam(Color(color.lightened(0.7), 0.95))
	_beam_glow = _make_beam(Color(color, 0.35))

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 6.0
	_light.omni_range = radius * 1.6
	_light.top_level = true
	add_child(_light)

	_sparks = CPUParticles3D.new()
	_sparks.amount = 48
	_sparks.lifetime = 0.45
	_sparks.emitting = false
	_sparks.direction = Vector3.UP
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 6.0
	_sparks.initial_velocity_max = 14.0
	_sparks.gravity = Vector3(0, -30, 0)
	_sparks.scale_amount_min = 0.15
	_sparks.scale_amount_max = 0.3
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3.ONE * 0.5
	spark_mesh.material = _additive(Color(1.0, 0.6, 0.3, 1.0))
	_sparks.mesh = spark_mesh
	_sparks.top_level = true
	add_child(_sparks)

	_update_visuals()


func start(duration: float = -1.0) -> void:
	if duration > 0.0:
		fire_time = duration
	circle_center = target.global_position if is_instance_valid(target) else global_position
	_snap_to_ground()
	_enter(State.CHARGE)


func stop() -> void:
	if state == State.CHARGE or state == State.FIRE:
		_enter(State.END)


func is_active() -> bool:
	return state != State.IDLE


func target_in_circle() -> bool:
	if not is_instance_valid(target):
		return false
	var d := target.global_position - circle_center
	return Vector2(d.x, d.z).length() <= radius and absf(d.y) < radius


func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		return
	_t += delta
	match state:
		State.CHARGE:
			_chase(track_speed, delta)
			if _t >= charge_time:
				_enter(State.FIRE)
		State.FIRE:
			_chase(fire_track_speed, delta)
			_hurt(delta)
			if _t >= fire_time:
				_enter(State.END)
		State.END:
			if _t >= end_time:
				_enter(State.IDLE)
	_update_visuals()


func _enter(new_state: State) -> void:
	state = new_state
	_t = 0.0
	_damage_owed = 0.0
	_sparks.emitting = new_state == State.FIRE
	_update_visuals()
	state_changed.emit(new_state)


func _chase(speed: float, delta: float) -> void:
	if not is_instance_valid(target):
		return
	var to_target := target.global_position - circle_center
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > 0.001:
		circle_center += to_target / dist * minf(dist, speed * delta)
	circle_center.y = target.global_position.y
	_snap_to_ground()


func _hurt(delta: float) -> void:
	if not target_in_circle():
		return
	_damage_owed += damage_per_second * delta
	while _damage_owed >= damage_tick:
		_damage_owed -= damage_tick
		target_hit.emit(damage_tick)
		if damages_player:
			GameManager.take_damage(damage_tick)


func _snap_to_ground() -> void:
	if not snap_to_ground or not is_inside_tree():
		return
	var hit := _ray(circle_center + Vector3.UP * 40.0, circle_center + Vector3.DOWN * 80.0)
	if hit:
		circle_center.y = hit.position.y
		_ground_normal = hit.normal
	else:
		_ground_normal = Vector3.UP


## Raycast that ignores the target and enemies, so the circle sits on terrain.
func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var exclude: Array[RID] = []
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	for _i in 4:
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit and hit.collider is Node and (hit.collider as Node).is_in_group("enemies"):
			exclude.append(hit.rid)
			continue
		return hit
	return {}


func _update_visuals() -> void:
	var charging := state == State.CHARGE
	var firing := state == State.FIRE
	_circle.visible = state != State.IDLE
	if _circle.visible:
		var n := _ground_normal
		var x := n.cross(Vector3.FORWARD if absf(n.z) < 0.99 else Vector3.RIGHT).normalized()
		var z := x.cross(n)
		_circle.global_transform = Transform3D(Basis(x * radius, n, z * radius), circle_center + n * 0.08)
		var fade := 1.0
		if charging:
			fade = clampf(_t / 0.2, 0.0, 1.0)
		elif state == State.END:
			fade = 1.0 - clampf(_t / end_time, 0.0, 1.0)
		_circle_mat.set_shader_parameter("progress", clampf(_t / charge_time, 0.0, 1.0) if charging else 1.0)
		_circle_mat.set_shader_parameter("firing", 1.0 if firing else 0.0)
		_circle_mat.set_shader_parameter("fade", fade)

	# a thin flickering sighting beam in the last moments of the charge, then the real one
	var sighting := charging and _t > charge_time - 0.35
	var show_beam := firing or sighting
	_beam.visible = show_beam
	_beam_glow.visible = firing
	_light.visible = firing
	if not show_beam:
		return
	var from: Vector3 = origin.call()
	var to := circle_center
	var hit := _ray(from, to) if is_inside_tree() else {}
	if hit:
		to = hit.position
	var flicker := 1.0 + 0.18 * sin(Time.get_ticks_msec() * 0.045)
	var width := beam_width * (flicker if firing else 0.25 * float(int(_t * 30.0) % 2))
	_place_beam(_beam, from, to, width)
	_place_beam(_beam_glow, from, to, width * 2.6)
	_light.global_position = to + Vector3.UP * 1.0
	_sparks.global_position = to


func _make_beam(c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 10
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	mi.mesh = cyl
	mi.material_override = _additive(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.visible = false
	add_child(mi)
	return mi


func _place_beam(mi: MeshInstance3D, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.01 or r <= 0.0:
		mi.visible = false
		return
	var y := d / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x * r, y * length, z * r), (a + b) * 0.5)


func _additive(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m
