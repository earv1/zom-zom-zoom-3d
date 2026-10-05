class_name BossFight
extends Node3D
## One boss encounter in the arena: owns a HadedaBoss, its hitbox, health bar and
## attack brain, and emits defeated() once the death sequence has played.
##
## Every boss: leap charges that mark their landing circle (orange -> red)
## ahead of where you're driving, so a fast car can't just outrun it; and the
## lava attack: stomps raise a lava lake over the whole arena floor (get up off
## it: ride the wall and the dome, or fly) while the boss flies above it.
## hadeda: melee (pecks, wing slam, beak burrow).
## zadeda: melee + pukes zombie rats.
## cydeda: melee, rats and the eye laser.

signal landed      ## the boss hit the ground after dropping in (shake cue)
signal defeated

const RUNNER := preload("res://scenes/enemy/runner.tscn")
const BOSS_SCALE := 5.0
const DROP_HEIGHT := 70.0
const NAMES: Array[String] = ["HADEDA", "ZADEDA", "CYDEDA"]
const MAX_HEALTH: Array[int] = [120, 180, 260]
const MELEE_RANGE := 17.0        ## world units in front of the boss
const STRIKE_RADIUS := 6.5       ## the car is hit within this of the beak tip / wing
const MELEE_DAMAGE := {&"peck_combo": 7, &"wing_slam": 14, &"drill_burrow": 16}
const STRIKE_BONE := {&"peck_combo": "drill", &"drill_burrow": "drill", &"wing_slam": "hand.R"}
const PUKE_FRAMES: Array[int] = [19, 29, 39]
const RATS_PER_HEAVE := 2
const MAX_RATS := 8
const WALK_ANIM_SPEED := 1.6
const TARGET_SHADER := preload("res://scenes/boss/laser_target.gdshader")
const LEAP_TELEGRAPH := 1.1     ## seconds the landing circle fills before the jump
const LEAP_AIR_TIME := 0.7
const LEAP_HEIGHT := 28.0
const LEAP_RADIUS := 20.0       ## landing circle: the car is hit inside it
const LEAP_DAMAGE := 18
const SLAM_FRAME_TIME := 20.0 / 24.0   ## wing_slam's hit frame (21) lands with the boss
const LAVA_SHADER := preload("res://scenes/boss/lava.gdshader")
const STOMP_FRAME_TIME := 19.0 / 24.0  ## stomp's slam frame (20)
const LAVA_REACH := BossArena.WALL_INNER   ## lava floods the whole floor, right up to the wall's inner face
const LAVA_DPS := 22.0
const LAVA_HEAT_HEIGHT := 5.0   ## burns this far above the surface too: quake hops don't dodge it
const LAVA_COOLDOWN := 18.0     ## seconds between lava attacks
const LAVA_WARN_TIME := 0.6     ## the lava zone blinks red this long before the first stomp
const LAVA_SPREAD_TIME := 3.0   ## lava wells up at the centre and reaches the wall in this long
const WAVE_SPEED := 32.0        ## stomp shockwave: a ring racing out along the ground (jump it)
const WAVE_BAND := 3.0          ## ...that hits a grounded car within this of the ring
const WAVE_DAMAGE := 12
const LAVA_WARN_BLINK := 0.18   ## seconds per blink half-cycle
const FLY_HEIGHT := 20.0
const FLY_RADIUS := 60.0
const TURN_SPEED := 1.8
const ATTACKS_BEFORE_REST := 3
const REST_TIME: Array[float] = [4.5, 4.0, 3.5]   ## per stage: the opening to get hits in

@export var stage := HadedaBoss.Stage.HADEDA
@export var car: Node3D
@export var arena_radius := 70.0
@export var auto_start := true    ## false: build it all now (e.g. hidden during the summon quake), start() later

var boss: HadedaBoss
var health := 0
var max_health := 0

var _hitbox: BossHitbox
var _ui: CanvasLayer
var _bar: ProgressBar
var _state := &"drop"            # drop -> intro -> fight -> dying
var _cooldown := 1.5
var _last_clip := &""
var _hits_done := {}
var _pukes_done := {}
var _rats: Array[Node] = []
var _flinch := 0.0
var _busy := false              # mid leap combo / lava attack: the brain waits
var lava_duration := 8.0        ## seconds the lava stays up
var _lava: MeshInstance3D
var _lava_hurt := 0.0
var _lava_ready_at := 0.0
var _flying := false
var _fly_angle := 0.0
var _attacks_since_rest := 0
var resting := false


func _ready() -> void:
	max_health = roundi(MAX_HEALTH[stage] * GameManager.enemy_scale("enemy_health_exp"))
	health = max_health

	boss = HadedaBoss.new()
	boss.stage = stage
	boss.target = car
	boss.scale = Vector3.ONE * BOSS_SCALE
	add_child(boss)
	boss.attack_finished.connect(_on_attack_finished)

	_hitbox = BossHitbox.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 3.4
	shape.height = 12.0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3.UP * 6.0
	_hitbox.add_child(cs)
	_hitbox.hit.connect(_on_hit)
	add_child(_hitbox)

	_build_ui()
	if auto_start:
		start()
	else:                                   # built and drawn (shaders compile) but idle until start()
		_ui.visible = false
		set_physics_process(false)


## Begins the fight: the boss drops in from above and the health bar shows.
func start() -> void:
	_ui.visible = true
	set_physics_process(true)
	boss.position = Vector3.UP * DROP_HEIGHT
	if is_instance_valid(car):
		var to_car := car.global_position - global_position
		boss.rotation.y = atan2(to_car.x, to_car.z)
	var drop := create_tween()
	drop.tween_property(boss, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_callback(_on_landed)


func _physics_process(delta: float) -> void:
	_hitbox.global_position = boss.global_position   # rides with the boss (flying too), never a pillar left on the ground
	_hitbox.rotation.y = boss.rotation.y
	if _flinch > 0.0:
		_flinch = maxf(_flinch - delta * 4.0, 0.0)
		boss.scale = Vector3.ONE * BOSS_SCALE * (1.0 + 0.035 * _flinch)
	_tick_lava(delta)
	if _flying:
		_fly(delta)
	if _state != &"fight" or not is_instance_valid(car) or _busy:
		return

	var clip := boss.current_clip()
	if clip != _last_clip:
		_last_clip = clip
		_hits_done.clear()
		_pukes_done.clear()
	_check_melee(clip)
	_check_puke(clip)
	if boss.laser.is_active():
		return

	_cooldown -= delta
	var to_car := car.global_position - boss.global_position
	to_car.y = 0.0
	var dist := to_car.length()
	if clip == &"idle" or clip == &"walk":
		boss.rotation.y = rotate_toward(boss.rotation.y, atan2(to_car.x, to_car.z), TURN_SPEED * delta)
		var facing := _forward().dot(to_car.normalized())
		if _cooldown <= 0.0 and _choose_attack(dist, facing):
			return
		if dist > MELEE_RANGE * 0.8:
			if clip != &"walk":
				boss.play(&"walk", 0.2, WALK_ANIM_SPEED)
			var step := _forward() * HadedaBoss.WALK_SPEED * BOSS_SCALE * WALK_ANIM_SPEED * delta
			var next := boss.position + step
			if Vector2(next.x, next.z).length() < arena_radius - 14.0:
				boss.position = next
		elif clip == &"walk":
			boss.play(&"idle", 0.25)


func _choose_attack(dist: float, facing: float) -> bool:
	if _attacks_since_rest >= ATTACKS_BEFORE_REST:
		_rest()
		return true
	_attacks_since_rest += 1
	var options: Array[StringName] = [&"leap", &"shockwave", &"shockwave"]
	if Time.get_ticks_msec() * 0.001 >= _lava_ready_at:
		options.append(&"lava")
	if dist >= MELEE_RANGE:
		options.append_array([&"leap", &"leap"])          # out of reach: close the gap
	if dist < MELEE_RANGE and facing > 0.75:
		options.append_array([&"peck_combo", &"peck_combo", &"wing_slam", &"drill_burrow"])
	if stage >= HadedaBoss.Stage.ZADEDA and _alive_rats() < MAX_RATS:
		options.append(&"puke")
		if dist >= MELEE_RANGE:
			options.append(&"puke")
	if stage == HadedaBoss.Stage.CYDEDA and dist > 20.0:
		options.append_array([&"laser", &"laser", &"laser"])
	if options.is_empty():
		return false
	var pick: StringName = options.pick_random()
	if pick == &"leap":
		_leap_combo(randi_range(2, 2 + mini(stage, 1)))
		return true
	if pick == &"lava":
		_lava_attack()
		return true
	if pick == &"shockwave":
		_stomp_wave(1 + mini(stage, 2))
		return true
	if pick == &"laser":
		boss.fire_laser(randf_range(2.5, 3.5))
	else:
		boss.play(pick)
	_cooldown = randf_range(1.0, 2.2) * (1.0 - 0.15 * stage)
	return true


## Winded after a run of attacks: stands still panting and does nothing, so the
## car can get in close and hit it.
func _rest() -> void:
	_busy = true
	resting = true
	_attacks_since_rest = 0
	boss.play(&"idle", 0.4, 0.45)
	var label := Label3D.new()
	label.text = "WINDED!"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 96
	label.pixel_size = 0.04
	label.outline_size = 18
	label.modulate = Color(1.0, 0.9, 0.3)
	label.outline_modulate = Color(0.2, 0.1, 0.0)
	add_child(label)
	label.position = boss.position + Vector3.UP * 34.0
	var sag := create_tween().set_loops(int(REST_TIME[stage] / 1.2))   # slow pant
	sag.tween_property(boss, "position:y", -0.8, 0.6).set_trans(Tween.TRANS_SINE)
	sag.tween_property(boss, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(REST_TIME[stage], false).timeout
	sag.kill()
	label.queue_free()
	boss.position.y = 0.0
	resting = false
	_busy = false
	_cooldown = 0.6
	if _state == &"fight":
		boss.play(&"idle", 0.25)


func _leap_combo(count: int) -> void:
	_busy = true
	for i in count:
		if _state != &"fight" or not is_instance_valid(car):
			break
		await _leap()
	_busy = false
	_cooldown = randf_range(0.8, 1.6)
	if _state == &"fight":
		boss.play(&"idle", 0.25)


## Marks a landing circle ahead of the car, fills it, then jumps there and slams.
func _leap() -> void:
	# aim where the car will be when the boss lands (warning circle + flight), on its current course
	var ahead := car.global_position + Vector3(car.linear_velocity.x, 0.0, car.linear_velocity.z) * (LEAP_TELEGRAPH + LEAP_AIR_TIME)
	var land := to_local(ahead)
	land.y = 0.0
	var reach := arena_radius - 20.0
	if Vector2(land.x, land.z).length() > reach:
		land = Vector3(land.x, 0.0, land.z).normalized() * reach

	var marker := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * LEAP_RADIUS * 2.0
	marker.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = TARGET_SHADER
	marker.material_override = mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position = land + Vector3.UP * 0.15
	add_child(marker)

	var to := land - boss.position
	if Vector2(to.x, to.z).length() > 0.1:
		boss.rotation.y = atan2(to.x, to.z)
	boss.play(&"scream", 0.15)
	var fill := create_tween()
	fill.tween_method(func(p: float) -> void:
		mat.set_shader_parameter("progress", p)
		mat.set_shader_parameter("color", Color(1.0, 0.6, 0.1).lerp(Color(1.0, 0.08, 0.04), p)),
		0.0, 1.0, LEAP_TELEGRAPH)
	await fill.finished

	var start := boss.position
	boss.play(&"wing_slam", 0.05, SLAM_FRAME_TIME / LEAP_AIR_TIME)
	var hop := create_tween()
	hop.tween_method(func(t: float) -> void:
		boss.position = start.lerp(land, t) + Vector3.UP * LEAP_HEIGHT * 4.0 * t * (1.0 - t),
		0.0, 1.0, LEAP_AIR_TIME)
	await hop.finished
	boss.position = land
	landed.emit()
	mat.set_shader_parameter("firing", 1.0)
	var hit := car.global_position - to_global(land)
	if Vector2(hit.x, hit.z).length() < LEAP_RADIUS and absf(hit.y) < 8.0:
		GameManager.take_damage(roundi(LEAP_DAMAGE * GameManager.enemy_scale("enemy_damage_exp")))
		var body := car as RigidBody3D
		if body:
			body.apply_central_impulse((Vector3(hit.x, 0.0, hit.z).normalized() * 16.0 + Vector3.UP * 9.0) * body.mass)
	var fade := create_tween()
	fade.tween_method(func(f: float) -> void: mat.set_shader_parameter("fade", f), 1.0, 0.0, 0.4)
	fade.tween_callback(marker.queue_free)
	await get_tree().create_timer(0.35, false).timeout


## Stomps raise a lava lake over the arena floor; the boss flies above it until it sinks.
func _lava_attack() -> void:
	_busy = true
	_lava_ready_at = Time.get_ticks_msec() * 0.001 + LAVA_COOLDOWN + lava_duration
	var warning := _lava_warning()
	boss.play(&"scream", 0.15)
	await get_tree().create_timer(LAVA_WARN_TIME, false).timeout
	for i in 1 + mini(stage, 1):
		if _state != &"fight":
			break
		boss.play(&"stomp", 0.1, 1.4)
		await get_tree().create_timer(STOMP_FRAME_TIME / 1.4, false).timeout
		landed.emit()                                     # ground shake
		_lava_burst(boss.bone_position("toes.R"))
		_shockwave()
		await get_tree().create_timer(0.5, false).timeout
	warning.queue_free()
	if _state != &"fight":
		_busy = false
		return

	_lava = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = arena_radius + LAVA_REACH
	disc.bottom_radius = disc.top_radius
	disc.height = 0.4
	disc.radial_segments = 64
	_lava.mesh = disc
	var mat := ShaderMaterial.new()
	mat.shader = LAVA_SHADER
	_lava.material_override = mat
	_lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lava.position.y = -1.5
	_lava.scale = Vector3(0.04, 1.0, 0.04)              # wells up at the centre...
	add_child(_lava)
	var rise := create_tween().set_parallel()
	rise.tween_property(_lava, "position:y", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
	rise.tween_property(_lava, "scale", Vector3.ONE, LAVA_SPREAD_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)   # ...and floods out to the wall
	rise.tween_property(boss, "position:y", FLY_HEIGHT, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	boss.play(&"fly", 0.3)
	_fly_angle = atan2(boss.position.z, boss.position.x)
	_flying = true
	if is_instance_valid(car):                        # take-off would scoop up a car in its path
		_hitbox.add_collision_exception_with(car)
	await get_tree().create_timer(lava_duration, false).timeout

	var sink := create_tween().set_parallel()
	sink.tween_property(_lava, "position:y", -1.5, 1.6).set_trans(Tween.TRANS_SINE)
	await sink.finished
	_lava.queue_free()
	_lava = null
	_flying = false
	var land := create_tween()
	land.tween_property(boss, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await land.finished
	if is_instance_valid(car):
		_hitbox.remove_collision_exception_with(car)
	landed.emit()
	if _state == &"fight":
		boss.play(&"idle", 0.25)
	_busy = false


## Stomps `count` times, each sending a shockwave ring out along the floor.
func _stomp_wave(count: int) -> void:
	_busy = true
	for i in count:
		if _state != &"fight":
			break
		boss.play(&"stomp", 0.1, 1.2)
		await get_tree().create_timer(STOMP_FRAME_TIME / 1.2, false).timeout
		landed.emit()
		_shockwave()
		await get_tree().create_timer(0.7, false).timeout
	_busy = false
	_cooldown = randf_range(0.6, 1.2)
	if _state == &"fight":
		boss.play(&"idle", 0.25)


## A ring of dust and rock racing out from the boss's feet along the ground to
## the wall. A car on the ground where it passes is hit (once); jump it (Space)
## or be in the air.
func _shockwave() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 64
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.2, 0.85)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var centre := Vector3(boss.position.x, 0.6, boss.position.z)
	ring.position = centre
	var hit := [false]
	var reach := arena_radius + LAVA_REACH
	var grow := create_tween()
	grow.tween_method(func(r: float) -> void:
		ring.scale = Vector3(r, 12.0, r)                    # a 1.2 m tall band of dust
		mat.albedo_color.a = 0.85 * (1.0 - r / reach * 0.6)
		if hit[0] or not is_instance_valid(car):
			return
		var local := to_local(car.global_position)
		var d := Vector2(local.x - centre.x, local.z - centre.z).length()
		if absf(d - r) < WAVE_BAND and local.y < 2.2:      # on the ground where the ring is
			hit[0] = true
			GameManager.take_damage(roundi(WAVE_DAMAGE * GameManager.enemy_scale("enemy_damage_exp")))
			var body := car as RigidBody3D
			if body:
				var out := Vector3(local.x - centre.x, 0.0, local.z - centre.z).normalized()
				body.apply_central_impulse((out * 10.0 + Vector3.UP * 6.0) * body.mass),
		2.0, reach, reach / WAVE_SPEED)
	grow.tween_callback(ring.queue_free)


## Blinking red over the floor the lava will cover (all of it), so the player
## has time to get up the wall or into the air.
func _lava_warning() -> MeshInstance3D:
	var zone := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = arena_radius + LAVA_REACH
	disc.bottom_radius = disc.top_radius
	disc.height = 0.05
	disc.radial_segments = 64
	zone.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.08, 0.02, 0.0)
	zone.material_override = mat
	zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.position.y = 0.12
	add_child(zone)
	var blink := zone.create_tween().set_loops()
	blink.tween_property(mat, "albedo_color:a", 0.45, LAVA_WARN_BLINK)
	blink.tween_property(mat, "albedo_color:a", 0.08, LAVA_WARN_BLINK)
	return zone


func _fly(delta: float) -> void:
	_fly_angle += delta * 0.35
	var flat := Vector2(boss.position.x, boss.position.z)
	var r := move_toward(flat.length(), FLY_RADIUS, 15.0 * delta)
	var next := Vector2(cos(_fly_angle), sin(_fly_angle)) * r
	var heading := next - flat
	boss.position = Vector3(next.x, boss.position.y, next.y)
	if heading.length() > 0.01:
		boss.rotation.y = atan2(heading.x, heading.y)


## The car burns while over the lava and near its surface.
func _tick_lava(delta: float) -> void:
	if not _lava or _lava.position.y < 0.0 or not is_instance_valid(car):
		return
	var local := to_local(car.global_position)
	var radius := (_lava.mesh as CylinderMesh).top_radius * _lava.scale.x   # only as far as it has spread
	if Vector2(local.x, local.z).length() < radius and local.y < _lava.position.y + LAVA_HEAT_HEIGHT:
		_lava_hurt += LAVA_DPS * GameManager.enemy_scale("enemy_damage_exp") * delta
		while _lava_hurt >= 5.0:
			_lava_hurt -= 5.0
			GameManager.take_damage(5)


func _lava_burst(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 60
	p.lifetime = 1.4
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 24.0
	p.gravity = Vector3(0, -30, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.08)
	mesh.material = mat
	p.mesh = mesh
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


func _check_melee(clip: StringName) -> void:
	var window := boss.hit_window()
	if window < 0 or _hits_done.has(window) or not STRIKE_BONE.has(clip):
		return
	var strike := boss.bone_position(STRIKE_BONE[clip])
	var d := car.global_position - strike
	if Vector2(d.x, d.z).length() > STRIKE_RADIUS or absf(d.y) > 8.0:
		return
	_hits_done[window] = true
	GameManager.take_damage(MELEE_DAMAGE[clip])
	if car is RigidBody3D:
		var away := car.global_position - boss.global_position
		away.y = 0.0
		var body := car as RigidBody3D
		body.apply_central_impulse((away.normalized() * 14.0 + Vector3.UP * 7.0) * body.mass)


func _check_puke(clip: StringName) -> void:
	if clip != &"puke":
		return
	var frame := boss.clip_frame()
	for f in PUKE_FRAMES:
		if frame >= f and not _pukes_done.has(f):
			_pukes_done[f] = true
			_puke_rats()


func _puke_rats() -> void:
	var mouth := boss.bone_position("jaw")
	_vomit_burst(mouth)
	if _alive_rats() >= MAX_RATS:
		return
	for i in RATS_PER_HEAVE:
		var rat := RUNNER.instantiate() as BaseEnemy
		get_parent().add_child(rat)
		rat.global_position = mouth + _forward() * 3.0 + Vector3(randf_range(-2, 2), 0.0, randf_range(-2, 2))
		rat.reset_for_spawn(car)
		_rats.append(rat)


func _vomit_burst(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 40
	p.lifetime = 0.9
	p.direction = (_forward() + Vector3.DOWN * 0.6).normalized()
	p.spread = 25.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector3(0, -25, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.75, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.45, 0.05)
	mesh.material = mat
	p.mesh = mesh
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


func _alive_rats() -> int:
	_rats = _rats.filter(func(r: Node) -> bool: return is_instance_valid(r) and not r.get("_dead"))
	return _rats.size()


func _forward() -> Vector3:
	var f := boss.global_basis.z
	f.y = 0.0
	return f.normalized()


func _on_landed() -> void:
	landed.emit()
	_state = &"intro"
	boss.play(&"scream", 0.1)


func _on_attack_finished(clip: StringName) -> void:
	if _state == &"intro" and clip == &"scream":
		_state = &"fight"


func _on_hit(amount: int) -> void:
	if _state != &"fight" and _state != &"intro":
		return
	health = maxi(health - amount, 0)
	_bar.value = health
	_flinch = 1.0
	if health == 0:
		_die()


func _die() -> void:
	_state = &"dying"
	boss.laser.stop()
	boss.play(&"scream", 0.1)
	for rat in _rats:
		if is_instance_valid(rat) and not rat.get("_dead"):
			rat.call("die")
	GameManager.earn(StringName("boss_" + NAMES[stage].to_lower()))
	GameManager.bosses_defeated += 1
	_hitbox.collision_layer = 0
	var fall := create_tween()
	fall.tween_interval(1.3)
	fall.tween_property(boss, "rotation:z", 1.35, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(boss, "position:y", -2.0, 1.2)
	fall.tween_callback(func() -> void: landed.emit())
	fall.tween_property(boss, "position:y", -30.0, 2.0).set_ease(Tween.EASE_IN)
	fall.tween_callback(func() -> void:
		_ui.queue_free()
		defeated.emit())


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 2
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-260, 54)
	box.custom_minimum_size = Vector2(520, 0)
	var title := Label.new()
	title.text = NAMES[stage]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
	box.add_child(title)
	_bar = ProgressBar.new()
	_bar.max_value = max_health
	_bar.value = health
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(520, 16)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.12, 0.08)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)
	_ui.add_child(box)
	add_child(_ui)
