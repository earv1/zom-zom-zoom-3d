class_name CarAirControl
extends Node

## Jump from ground, then do directional tricks in the air.
## Full sequence required: Up→Right→Down→Left = clockwise 360.
## Full sequence required: Up→Left→Down→Right = counter-clockwise 360.
## Landing always zeroes angular momentum.
## In the air: steer to glide like a slow banking plane, hold Shift for tricks,
## hold Ctrl to dive. Hitting the ground fast enough is a ground pound: a
## shockwave that damages and scatters enemies (and the boss) around you.

@export var jump_force: float = 10.0
@export var spin_duration: float = 0.5  # seconds per 360
@export var level_torque: float = 800.0
@export var level_damping: float = 8.0

signal trick_landed(trick_name: String, spin_count: int)
signal trick_input(dir: Dir, success: bool, seq_index: int)
signal trick_sequence_reset()
signal trick_spin_started()
signal trick_spin_ended()
signal ground_pounded(strength: float, hits: int)

enum State { GROUNDED, AIRBORNE, SPINNING }
enum Dir { UP, RIGHT, DOWN, LEFT, NONE }

var state: State = State.GROUNDED

var _car: RigidBody3D
var _wheels: Array[RayCast3D] = []
var _spin_dir := 0  # -1 CCW, 1 CW
var _spin_progress := 0.0
var _spin_count := 0
var _seq_index := 0  # 0-3: which direction in the sequence we expect next
var _last_dir: Dir = Dir.NONE
var _chain_queued := false
var _seq_timer := 0.0
const SEQ_TIMEOUT := 1.5  # seconds to complete the sequence



const GLIDE_TURN_RATE := deg_to_rad(18.0)   ## how fast steering bends the flight path (rad/s)
const GLIDE_BANK := deg_to_rad(28.0)        ## roll into the turn at full steer
const GLIDE_MAX_PITCH := deg_to_rad(35.0)   ## nose follows the flight path up to this
const GLIDE_STIFFNESS := 3.0                ## how firmly the car settles into its flight attitude
const RIDE_HEIGHT := 0.56                   ## car origin to the ground when sitting on its wheels
const GLIDE_MIN_HEIGHT := 6.0              ## flight controls only take over with this much air under the car (small hops stay physical)
const GLIDE_PITCH_RATE := deg_to_rad(25.0)  ## W/S bend the flight path down/up this fast (rad/s)
const GLIDE_PITCH_TILT := deg_to_rad(15.0)  ## ...and tilt the nose this much past the flight path
const STALL_SPEED := 14.0                   ## nose-up (S) with forward speed below this stalls the car...
const STALL_TIME := 1.4                     ## ...as does holding nose-up this long
const STALL_ACCEL := 85.0                   ## stalled: plunge nose-first into a ground pound (m/s^2)
const STALL_NOSE := deg_to_rad(70.0)        ## nose-down angle while plunging
const DIVE_ACCEL := 60.0                    ## extra downward acceleration while holding Ctrl (m/s^2)
const POUND_MIN_SPEED := 22.0               ## landing this fast (m/s down) is a ground pound
const POUND_FULL_SPEED := 52.0              ## ...and this fast is a full-strength one
const POUND_RADIUS := Vector2(10.0, 26.0)   ## shockwave radius, weakest .. strongest
const POUND_DAMAGE := Vector2(3.0, 14.0)    ## damage, weakest .. strongest (x ram upgrades)
const POUND_BOSS_REACH := 25.0              ## a boss counts as caught this far above/below the car
const POUND_BOUNCE_HEIGHT := 40.0           ## pounding a boss springs the car about this high (near the dome roof)

var _fall_speed := 0.0
var _climb_time := 0.0
var _shadow: CarBlobShadow   ## its world-down ray doubles as the fall sensor
var _belly: RayCast3D        ## out of the car's underside: when flight controls may engage
var _cushioned_speed := 0.0   ## real fall speed before _guard_tunnel slowed it (keeps the pound strength)
var stalled := false
var flying := false              ## flight mode (glide / pitch / bank / stall) is in control; the HUD shows it

func _ready() -> void:
	if not InputMap.has_action("dive"):          # Ctrl dives (registered here, not in project.godot)
		InputMap.add_action("dive")
		var ctrl := InputEventKey.new()
		ctrl.physical_keycode = KEY_CTRL
		InputMap.action_add_event("dive", ctrl)
	_car = get_parent() as RigidBody3D
	if not _car:
		push_error("CarAirControl: parent must be RigidBody3D")
		return
	_car.contact_monitor = true
	_car.max_contacts_reported = 4
	_shadow = _car.get_node_or_null("BlobShadow") as CarBlobShadow
	_belly = RayCast3D.new()
	_belly.target_position = Vector3.DOWN * (RIDE_HEIGHT + GLIDE_MIN_HEIGHT + 0.5)
	_belly.add_exception(_car)
	_car.add_child.call_deferred(_belly)
	for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var w := _car.get_node_or_null(wheel_name) as RayCast3D
		if w:
			_wheels.append(w)


func _any_contact() -> bool:
	for w in _wheels:
		if w.is_colliding():
			return true
	if _car.get_contact_count() > 0:
		return true
	return false


func _physics_process(delta: float) -> void:
	if not _car:
		return

	match state:
		State.GROUNDED:
			_tick_grounded()
		State.AIRBORNE:
			_tick_airborne(delta)
		State.SPINNING:
			_tick_spinning(delta)


# ── GROUNDED ──────────────────────────────────────────────────────────────────

func _tick_grounded() -> void:
	if Input.is_action_just_pressed("jump"):
		_car.apply_central_impulse(_car.global_basis.y * _car.mass * jump_force)

	if not _any_contact():
		state = State.AIRBORNE
		_climb_time = 0.0
		_cushioned_speed = 0.0
		stalled = false
		_reset_trick_state()


func _enter_grounded() -> void:
	_set_flying(false)
	if _fall_speed >= POUND_MIN_SPEED:
		_ground_pound(_fall_speed)
	_fall_speed = 0.0
	_cushioned_speed = 0.0
	if _spin_count > 0:
		var name_str := "CW Spin" if _spin_dir > 0 else "CCW Spin"
		trick_landed.emit(name_str, _spin_count)
	_car.angular_velocity = Vector3.ZERO
	_reset_trick_state()


# ── AIRBORNE ──────────────────────────────────────────────────────────────────

## Flight mode on/off. Leaving it drops everything it was doing: the stall, the
## climb timer and the attitude spin it was steering, so nothing lingers once
## the car is near the ground again (or tricking, or landed).
func _set_flying(on: bool) -> void:
	if on == flying:
		return
	flying = on
	if not on:
		stalled = false
		_climb_time = 0.0
		_car.angular_velocity = Vector3.ZERO

func _tick_airborne(delta: float) -> void:
	if _any_contact():
		_enter_grounded()
		state = State.GROUNDED
		return

	if Input.is_action_pressed("dive"):        # hold Ctrl to dive
		_car.apply_central_force(Vector3.DOWN * _car.mass * DIVE_ACCEL)
	if Input.is_action_pressed("handbreak"):   # hold Shift for tricks (not flight)
		_set_flying(false)
		_read_sequence_input(delta)
		_do_auto_level(delta)
	else:
		_set_flying(_height_above_ground() >= GLIDE_MIN_HEIGHT)
		if flying:                             # everything flight-related lives in here
			if stalled:
				_plunge(delta)
			else:
				_glide(delta)
	_fall_speed = maxf(-_car.linear_velocity.y, _cushioned_speed)   # speed we'd hit the ground at next frame
	_guard_tunnel(delta)


func _read_sequence_input(delta: float) -> void:
	# Timeout the sequence if too slow
	if _seq_index > 0:
		_seq_timer += delta
		if _seq_timer > SEQ_TIMEOUT:
			_seq_index = 0
			_spin_dir = 0
			_seq_timer = 0.0
			trick_sequence_reset.emit()

	var dir := _get_just_pressed()
	if dir != Dir.NONE:
		_advance_sequence(dir)


func _advance_sequence(dir: Dir) -> void:
	# Sequence step 0: must be UP
	if _seq_index == 0:
		if dir == Dir.UP:
			_seq_index = 1
			_seq_timer = 0.0
			trick_input.emit(dir, true, 0)
		else:
			trick_input.emit(dir, false, 0)
		return

	# Step 1: RIGHT or LEFT determines direction
	if _seq_index == 1:
		if dir == Dir.RIGHT:
			_spin_dir = -1  # CW visual: Up→Right→Down→Left
			_seq_index = 2
			trick_input.emit(dir, true, 1)
		elif dir == Dir.LEFT:
			_spin_dir = 1  # CCW visual: Up→Left→Down→Right
			_seq_index = 2
			trick_input.emit(dir, true, 1)
		else:
			trick_input.emit(dir, false, 1)
			_seq_index = 0
			trick_sequence_reset.emit()
		return

	# Step 2: must be DOWN
	if _seq_index == 2:
		if dir == Dir.DOWN:
			_seq_index = 3
			trick_input.emit(dir, true, 2)
		else:
			trick_input.emit(dir, false, 2)
			_seq_index = 0
			_spin_dir = 0
			trick_sequence_reset.emit()
		return

	# Step 3: must be LEFT (CW) or RIGHT (CCW)
	if _seq_index == 3:
		var expected: Dir = Dir.RIGHT if _spin_dir > 0 else Dir.LEFT
		if dir == expected:
			trick_input.emit(dir, true, 3)
			# Full sequence complete — start spinning!
			_start_spin()
		else:
			trick_input.emit(dir, false, 3)
			_seq_index = 0
			_spin_dir = 0
			trick_sequence_reset.emit()


func _start_spin() -> void:
	_spin_progress = 0.0
	_spin_count = 0
	_chain_queued = false
	_seq_index = 0
	_last_dir = Dir.NONE
	state = State.SPINNING
	trick_spin_started.emit()


# ── SPINNING ──────────────────────────────────────────────────────────────────

func _tick_spinning(delta: float) -> void:
	if _any_contact():
		_enter_grounded()
		state = State.GROUNDED
		return

	var rate := TAU / spin_duration
	_spin_progress += delta / spin_duration

	# Yaw spin
	_car.angular_velocity = Vector3.UP * rate * float(_spin_dir)

	# Keep car level during spin
	var current_up := _car.global_basis.y
	var correction := current_up.cross(Vector3.UP)
	_car.apply_torque(correction * level_torque * 2.0)

	# Check for chain input during spin
	_read_chain_input()

	if _spin_progress >= 1.0:
		_spin_count += 1
		_spin_progress -= 1.0

		if _chain_queued:
			_chain_queued = false
		else:
			_car.angular_velocity = Vector3.ZERO
			state = State.AIRBORNE
			trick_spin_ended.emit()
			_seq_index = 0
			_last_dir = Dir.NONE


func _read_chain_input() -> void:
	var cur_dir := _get_just_pressed()
	if cur_dir == Dir.NONE:
		return

	# Same 4-step sequence to queue another spin
	if _seq_index == 0 and cur_dir == Dir.UP:
		_seq_index = 1
	elif _seq_index == 1:
		var expected_2: Dir = Dir.LEFT if _spin_dir > 0 else Dir.RIGHT
		if cur_dir == expected_2:
			_seq_index = 2
		else:
			_seq_index = 0
	elif _seq_index == 2 and cur_dir == Dir.DOWN:
		_seq_index = 3
	elif _seq_index == 3:
		var expected_4: Dir = Dir.RIGHT if _spin_dir > 0 else Dir.LEFT
		if cur_dir == expected_4:
			_chain_queued = true
			_seq_index = 0
		else:
			_seq_index = 0
	else:
		_seq_index = 0


# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_just_pressed() -> Dir:
	if Input.is_action_just_pressed("accelerate"):
		return Dir.UP
	elif Input.is_action_just_pressed("decelerate"):
		return Dir.DOWN
	elif Input.is_action_just_pressed("turn_right"):
		return Dir.RIGHT
	elif Input.is_action_just_pressed("turn_left"):
		return Dir.LEFT
	return Dir.NONE


func _reset_trick_state() -> void:
	_spin_dir = 0
	_spin_progress = 0.0
	_spin_count = 0
	_seq_index = 0
	_last_dir = Dir.NONE
	_chain_queued = false
	_seq_timer = 0.0
	trick_sequence_reset.emit()


## Shockwave on a hard landing: damage and knockback scale with impact speed.
func _ground_pound(speed: float) -> void:
	var t := clampf((speed - POUND_MIN_SPEED) / (POUND_FULL_SPEED - POUND_MIN_SPEED), 0.0, 1.0)
	var radius := lerpf(POUND_RADIUS.x, POUND_RADIUS.y, t)
	var damage := maxi(roundi(lerpf(POUND_DAMAGE.x, POUND_DAMAGE.y, t) * GameManager.stats.get("ram_mult", 1.0)), 1)
	var centre := _car.global_position
	var hits := 0
	var hit_boss := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Node3D
		if not enemy or not enemy.is_visible_in_tree() or not enemy.has_method("take_damage"):
			continue
		var off := enemy.global_position - centre
		var is_boss := enemy.has_method("pound_damage")
		# a boss is tall: landing on its head is still a hit
		if Vector2(off.x, off.z).length() > radius or absf(off.y) > (POUND_BOSS_REACH if is_boss else 10.0):
			continue
		if is_boss:
			enemy.call("take_damage", maxi(roundi(enemy.call("pound_damage") * GameManager.stats.get("ram_mult", 1.0)), 1))
			hit_boss = true
		else:
			enemy.call("take_damage", damage)
		hits += 1
		if enemy is RigidBody3D and is_instance_valid(enemy) and enemy.can_process() and enemy.get("_dead") != true:
			var push := Vector3(off.x, 0.0, off.z).normalized() * 14.0 + Vector3.UP * 8.0
			(enemy as RigidBody3D).apply_central_impulse(push * (enemy as RigidBody3D).mass)
	GameManager.earn(&"ground_pound", Economy.source_base(&"ground_pound") * (1.0 + 0.5 * hits))
	_shockwave(centre, radius)
	var g := _car.get_gravity().length()
	var pad := _pound_pad_below()
	if pad:        # a pound pad springs you up and on toward the next one
		var launch: Dictionary = pad.call("pound_launch")
		_car.linear_velocity = (launch.push as Vector3) + Vector3.UP * sqrt(2.0 * g * float(launch.height))
	elif hit_boss: # spring off the boss back up toward the dome roof, ready for another dive
		_car.linear_velocity = Vector3(_car.linear_velocity.x * 0.3, sqrt(2.0 * g * POUND_BOUNCE_HEIGHT), _car.linear_velocity.z * 0.3)
	ground_pounded.emit(t, hits)


## The pound pad the car just landed on, if any (straight down, then the wheels).
func _pound_pad_below() -> Node:
	var hits: Array = []
	if _shadow:
		hits.append(_shadow.ground_collider())
	for w in _wheels:
		if w.is_colliding():
			hits.append(w.get_collider())
	for hit in hits:
		var node := hit as Node
		for i in 3:                                   # collider -> (body) -> piece
			if node == null:
				break
			if node.has_method("pound_launch"):
				return node
			node = node.get_parent()
	return null


func _shockwave(at: Vector3, radius: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 32
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.85, 0.65, 0.8)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(ring)
	ring.global_position = at + Vector3.DOWN * 0.8
	ring.scale = Vector3(1.0, 0.4, 1.0)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(radius, 0.4, radius), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(ring.queue_free)


## Plane-like flight: steering slowly bends the flight path and banks the car
## into the turn; W/S push the nose down/up like a stick (bending the path and
## tilting the car); the nose follows the flight path (pitch limited).
func _glide(delta: float) -> void:
	var v := _car.linear_velocity
	var flat := Vector3(v.x, 0.0, v.z)
	var stick := Input.get_axis("accelerate", "decelerate")         # W = nose down, S = nose up
	_climb_time = _climb_time + delta if stick > 0.0 else 0.0
	if stick > 0.0 and (flat.length() < STALL_SPEED or _climb_time > STALL_TIME):
		stalled = true                                              # tilted back too long: stall -> slam
		return
	if flat.length() < 4.0:
		_do_auto_level(delta)
		return
	var steer := Input.get_axis("turn_right", "turn_left")
	flat = flat.rotated(Vector3.UP, steer * GLIDE_TURN_RATE * delta)
	v = Vector3(flat.x, v.y, flat.z)
	if stick != 0.0:   # swing the velocity in its vertical plane: speed is kept, height is traded for it
		var side := flat.normalized().cross(Vector3.UP)
		var bent := v.rotated(side, stick * GLIDE_PITCH_RATE * delta)   # +angle about right = nose up
		if absf(atan2(bent.y, Vector2(bent.x, bent.z).length())) < GLIDE_MAX_PITCH or absf(bent.y) < absf(v.y):
			v = bent
		flat = Vector3(v.x, 0.0, v.z)
	_car.linear_velocity = v
	var pitch := clampf(atan2(v.y, flat.length()) + stick * GLIDE_PITCH_TILT, -GLIDE_MAX_PITCH, GLIDE_MAX_PITCH)
	var heading := flat.normalized()
	var dir := (heading * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
	var up := Vector3.UP.rotated(dir, -steer * GLIDE_BANK)          # left wing down turning left
	var target := Basis.looking_at(dir, up).get_rotation_quaternion()
	var current := _car.global_basis.get_rotation_quaternion()
	var delta_q := (target * current.inverse()).normalized()
	if delta_q.w < 0.0:
		delta_q = -delta_q
	var angle := delta_q.get_angle()
	if angle > 0.001:
		_car.angular_velocity = delta_q.get_axis() * angle * GLIDE_STIFFNESS


## Air under the car for flight controls: the nearer of straight down (blob
## shadow's ray: catches falling / flipped near the ground) and out of the car's
## underside (belly ray: catches riding a wall or loop). INF when both are clear.
func _height_above_ground() -> float:
	var belly := INF
	if _belly and _belly.is_colliding():
		belly = _belly.global_position.distance_to(_belly.get_collision_point()) - RIDE_HEIGHT
	return minf(belly, _drop_clearance())


## What's out of the car's underside within the belly ray: {collider, normal
## (facing the car), gap (m below the wheels)}, or {} if nothing.
func belly_contact() -> Dictionary:
	if not _belly or not _belly.is_colliding():
		return {}
	var n := _belly.get_collision_normal()
	if n.dot(_car.global_basis.y) < 0.0:
		n = -n
	return {collider = _belly.get_collider(), normal = n,
		gap = _belly.global_position.distance_to(_belly.get_collision_point()) - RIDE_HEIGHT}


## World-down clearance (the blob shadow's ray): a fall is always straight down.
func _drop_clearance() -> float:
	return (_shadow.ground_clearance() if _shadow else INF) - RIDE_HEIGHT


## Fast falls (dive / stall plunge) cover over a metre per tick and can skip
## through thin road and park meshes. If the ground (per the shadow ray, a tick
## old, so allow for this tick's drop) is nearer than the next two ticks of
## travel, slow the fall to land on it. Forward speed is untouched, and
## _fall_speed keeps the real impact speed, so the ground pound is unchanged.
func _guard_tunnel(delta: float) -> void:
	var v := _car.linear_velocity
	if v.y > -15.0:
		return
	var gap := _drop_clearance() + v.y * delta          # this tick's drop is already under way
	if gap == INF or gap > -v.y * delta * 2.0:
		return
	var safe := maxf(maxf(gap, 0.0) / delta * 0.5, 4.0)
	if -v.y > safe:
		_cushioned_speed = maxf(_cushioned_speed, -v.y)
		_car.linear_velocity.y = -safe


## Stalled: the nose drops and the car plunges straight down; landing hard
## enough is a ground pound (see _enter_grounded).
func _plunge(delta: float) -> void:
	_car.apply_central_force(Vector3.DOWN * _car.mass * STALL_ACCEL)
	var v := _car.linear_velocity
	_car.linear_velocity = Vector3(v.x, 0.0, v.z).move_toward(Vector3.ZERO, 20.0 * delta) + Vector3.UP * v.y
	var heading := -_car.global_basis.z
	heading.y = 0.0
	heading = heading.normalized() if heading.length() > 0.01 else Vector3.FORWARD
	var dir := heading * cos(STALL_NOSE) + Vector3.DOWN * sin(STALL_NOSE)
	var target := Basis.looking_at(dir, Vector3.UP).get_rotation_quaternion()
	var delta_q := (target * _car.global_basis.get_rotation_quaternion().inverse()).normalized()
	if delta_q.w < 0.0:
		delta_q = -delta_q
	if delta_q.get_angle() > 0.001:
		_car.angular_velocity = delta_q.get_axis() * delta_q.get_angle() * GLIDE_STIFFNESS * 1.5


func _do_auto_level(delta: float) -> void:
	var current_up := _car.global_basis.y
	var correction := current_up.cross(Vector3.UP)
	_car.apply_torque(correction * level_torque)
	_car.angular_velocity = _car.angular_velocity.lerp(Vector3.ZERO, level_damping * delta)
