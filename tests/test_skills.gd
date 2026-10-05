extends GutTest

## Skill tracks: each loads with a start, ordered gates and a finish; respawn
## and gate rules work; and the courses are physically doable with the real car.

const SCENE := preload("res://scenes/levels/skills/skill_level.tscn")

var _root: Node3D


func _load(id: String) -> SkillLevel:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	_root = Node3D.new()
	get_tree().root.add_child(_root)
	get_tree().current_scene = _root
	var level: SkillLevel = SCENE.instantiate()
	level.skill_id = id
	level.record_times = false
	_root.add_child(level)
	await wait_physics_frames(3)
	return level


func after_each() -> void:
	for a in ["dive", "accelerate", "jump", "handbreak", "turn_left", "turn_right", "decelerate"]:
		Input.action_release(a)
	if is_instance_valid(_root):
		_root.queue_free()
	await wait_physics_frames(2)


func test_every_skill_loads_with_gates_and_a_start() -> void:
	for id in SkillLevel.ORDER:
		var level := await _load(id)
		assert_gt(level.gates.size(), 1, "%s has checkpoints and a finish" % id)
		assert_eq(int(level.gates.back().get("kind")), 3, "%s ends at a finish" % id)
		var start: Node3D = level._start_gate
		assert_not_null(start, "%s has a start" % id)
		assert_lt(level.car.global_position.distance_to(start.global_position), 3.0, "%s: the car starts at the start" % id)
		gut.p("%s: %d gates" % [id, level.gates.size()])
		_root.queue_free()
		await wait_physics_frames(2)


## What's straight below the car within 60 m: "pad", "deck" or "".
func _below(car: RigidBody3D) -> String:
	var q := PhysicsRayQueryParameters3D.create(car.global_position, car.global_position + Vector3.DOWN * 60.0)
	q.exclude = [car.get_rid()]
	var hit := car.get_world_3d().direct_space_state.intersect_ray(q)
	var node := hit.get("collider") as Node
	for i in 3:
		if node == null:
			return ""
		if String(node.name).begins_with("pound_pad"):
			return "pad"
		if String(node.name).begins_with("deck"):
			return "deck"
		node = node.get_parent()
	return ""


## Plays the pad course like a player: throttle off each deck and dive straight
## away (as the hint says); between pads, dive once you're over the next one. Returns when done or
## after `seconds`.
func _hop_pads(level: SkillLevel, seconds: float, window := 8.0) -> void:
	var car := level.car
	var air: CarAirControl = car.get_node("CarAirControl")
	var off_deck := false
	for i in int(seconds * 60.0):
		if level.done:
			break
		var below := _below(car)
		var on_deck := air.state == CarAirControl.State.GROUNDED and below == "deck"   # sections start on decks
		car.set("motor_input", 1 if on_deck else 0)        # throttle comes from key events, so set it directly
		if air.state == CarAirControl.State.GROUNDED:
			off_deck = on_deck                             # as the hint says: dive straight away off a deck
		if car.linear_velocity.y < -1.0 and (off_deck or below != ""):   # dive once over the next pad / deck
			Input.action_press("dive")
		else:
			Input.action_release("dive")
		await wait_physics_frames(1)


func test_ground_pound_course_is_hoppable_to_the_finish() -> void:
	var level := await _load("ground_pound")
	var passed := []
	await _hop_pads(level, 70.0)
	gut.p("reached gate %d / %d in %.1fs, done=%s, car at %s" % [level._next, level.gates.size(), level.elapsed, level.done, level.car.global_position.round()])
	assert_true(level.done, "pound pads chain all the way to the finish")


func test_upside_down_course_three_ceilings_to_the_finish() -> void:
	var level := await _load("upside_down")
	var car := level.car
	var air: CarAirControl = car.get_node("CarAirControl")
	var pads := level.track.get_node("TrackRoot").get_children().filter(
		func(n: Node) -> bool: return String(n.name).begins_with("pound_pad"))
	var drops := 0
	var section := 0
	var dropped := false
	var since := 0
	var retries := 0
	for i in 60 * 90:
		if level.done:
			break
		if level._next != section or i - since > 60 * 25:   # landed a checkpoint (or stuck 25 s): back on the run-up, like R
			if level._next == section:
				retries += 1
			section = level._next
			since = i
			dropped = false
			level.respawn()
			await wait_physics_frames(3)
		var pad: Node3D = pads[section]
		var inverted := car.global_basis.y.y < -0.8 and air.state == CarAirControl.State.GROUNDED
		car.set("motor_input", 0 if dropped else 1)
		var lead := car.linear_velocity.z * 1.3                # roughly the diving fall time from the ceiling
		if inverted and not dropped and car.global_position.z > pad.global_position.z - lead:
			Input.action_press("jump")
			dropped = true
			drops += 1
			await wait_physics_frames(2)
			Input.action_release("jump")
		if dropped and car.linear_velocity.y < -1.0:
			Input.action_press("dive")
		else:
			Input.action_release("dive")
		await wait_physics_frames(1)
	gut.p("gate %d / %d in %.1fs after %d drops (%d retries), car at %s" % [level._next, level.gates.size(), level.elapsed, drops, retries, car.global_position.round()])
	assert_true(level.done, "three ceiling drops, three pounds, to the finish")


func _tap(action: String) -> void:
	Input.action_press(action)
	await wait_physics_frames(2)
	Input.action_release(action)
	await wait_physics_frames(2)


func test_tricks_course_spin_off_every_kicker_to_the_finish() -> void:
	var level := await _load("tricks")
	var car := level.car
	var air: CarAirControl = car.get_node("CarAirControl")
	var spins := [0]                                    # (closures copy ints: count in an array)
	air.trick_landed.connect(func(_n: String, _c: int) -> void: spins[0] += 1)
	# a spinless run is stopped at the first trick gate
	car.set("motor_input", 1)
	await wait_until(func() -> bool: return car.global_position.z < -420.0, 25.0, "past the first trick gate")
	assert_eq(level._next, 0, "no spin landed: the trick gate doesn't count")
	level.restart()
	await wait_physics_frames(3)
	for i in 60 * 60:
		if level.done:
			break
		car.set("motor_input", 1)
		if air.state == CarAirControl.State.AIRBORNE and car.global_position.y > 2.0:
			Input.action_press("handbreak")
			for a in ["accelerate", "turn_left", "decelerate", "turn_right", "accelerate", "turn_left", "decelerate", "turn_right"]:
				await _tap(a)                             # the second round chains another spin
			await wait_until(func() -> bool: return air.state == CarAirControl.State.GROUNDED, 8.0)
			Input.action_release("handbreak")
		await wait_physics_frames(1)
	gut.p("gate %d / %d in %.1fs, %d spins landed" % [level._next, level.gates.size(), level.elapsed, spins[0]])
	assert_gt(spins[0], 2, "a spin off each kicker")
	assert_true(level.done, "every trick gate opens and the finish is reached")


## Inside a loop: hold the road's centre line as it drifts sideways (the loop
## piece's own helix). Returns false when the car isn't in a loop.
func _steer_in_loop(car: RigidBody3D) -> bool:
	for loop in get_tree().get_nodes_in_group("_test_loops"):
		var best := INF
		var centre := Vector3.ZERO
		var across := Vector3.ZERO
		for i in 37:
			var a := TAU * i / 36.0
			var p: Vector3 = loop.global_transform * (loop.call("_arc", a) as Vector3)
			var d := p.distance_to(car.global_position)
			if d < best:
				best = d
				centre = p
				across = (loop.global_basis * (loop.call("_helix_width", a) as Vector3)).normalized()
		if best > 16.0:
			continue
		# right of the centre line, or pointing right of it -> steer left
		var s := signf(across.dot(car.global_basis.x))
		var right_off := (car.global_position - centre).dot(across) * s
		var right_head := (-car.global_basis.z).dot(across) * s
		_hold_wheel(car, clampf(right_off * 0.06 + right_head * 1.5, -0.4, 0.4))
		return true
	return false


## Steers along the track's recorded driving line: pure pursuit on where the
## car is actually going (its velocity, not its nose), looking 40 m ahead, so
## it doesn't weave at speed. Returns the nearest route index (it only moves on).
func _steer_along(car: RigidBody3D, route: PackedVector3Array, from: int) -> int:
	var here := car.global_position
	var best := from
	for i in range(from, mini(from + 12, route.size())):
		if route[i].distance_to(here) < route[best].distance_to(here):
			best = i
	var target := best
	while target < route.size() - 1 and route[target].distance_to(here) < 40.0:
		target += 1
	var v := car.linear_velocity
	var going := Vector2(v.x, v.z) if Vector2(v.x, v.z).length() > 5.0 else Vector2(-car.global_basis.z.x, -car.global_basis.z.z)
	var to := route[target] - here
	var turn := going.angle_to(Vector2(to.x, to.z))
	Input.action_release("turn_left")
	Input.action_release("turn_right")
	if _steer_in_loop(car):
		return best
	if car.global_basis.y.y > 0.7:                        # not mid-loop or upside down
		# turn > 0: target to the right. Damp with the yaw rate (+y = turning left).
		_hold_wheel(car, clampf(-turn * 1.2 - car.angular_velocity.y * 0.15, -0.5, 0.5))
	return best


## The wheels turn at a fixed rate while a key is held and recentre when let
## go, so feather left/right to hold a wheel angle (radians, + = left).
func _hold_wheel(car: RigidBody3D, want_left: float) -> void:
	var now: float = (car.get("wheels")[0] as Node3D).rotation.y
	if want_left > now + 0.01:
		Input.action_press("turn_left")
	elif want_left < now - 0.01:
		Input.action_press("turn_right")


func test_track_sense_final_uses_every_skill_to_the_finish() -> void:
	var level := await _load("track_sense")
	var car := level.car
	var air: CarAirControl = car.get_node("CarAirControl")
	var route: PackedVector3Array = level.track.get_meta("route")
	for piece in level.track.get_node("TrackRoot").get_children():
		if String(piece.name).begins_with("loop"):
			piece.add_to_group("_test_loops")
	var pad: Node3D = level.track.get_node("TrackRoot").get_children().filter(
		func(n: Node) -> bool: return String(n.name).begins_with("pound_pad"))[0]
	var at := 0
	var dropped := false
	var spun := false
	var retries := 0
	var progress_gate := 0
	var progress_at := 0
	for i in 60 * 180:
		if level.done:
			break
		var inverted := car.global_basis.y.y < -0.8 and air.state == CarAirControl.State.GROUNDED
		car.set("motor_input", 0 if dropped else 1)
		if not inverted and not dropped:
			at = _steer_along(car, route, at)
		var clear_of_loops := get_tree().get_nodes_in_group("_test_loops").all(
			func(l: Node3D) -> bool: return l.global_position.distance_to(car.global_position) > 70.0)
		spun = level._spins > 0                            # done once a spin has really landed
		if level._next == 1 and not spun and air.state == CarAirControl.State.AIRBORNE and car.global_position.y > 4.0 \
				and car.global_basis.y.y > 0.9 and clear_of_loops:   # real air off the kicker, not a hop or the loop
			Input.action_press("handbreak")
			for a in ["accelerate", "turn_left", "decelerate", "turn_right"]:
				await _tap(a)
			await wait_until(func() -> bool: return air.state == CarAirControl.State.GROUNDED, 8.0)
			Input.action_release("handbreak")
		var ahead := (pad.global_position - car.global_position)
		if inverted and not dropped and Vector2(ahead.x, ahead.z).length() < car.linear_velocity.length() * 1.3:
			Input.action_press("jump")
			dropped = true
			await wait_physics_frames(2)
			Input.action_release("jump")
		if dropped and car.linear_velocity.y < -1.0:
			Input.action_press("dive")
		else:
			Input.action_release("dive")
		if level._next != progress_gate:
			progress_gate = level._next
			progress_at = i
		elif i - progress_at > 60 * 25 and retries < 4:
			# no checkpoint for 25 s (missed the pad, flew past a gate): R, like a player, and redo the section
			retries += 1
			progress_at = i
			dropped = false
			spun = false
			level.respawn()
			await wait_physics_frames(2)
			var nearest := 0
			for k in route.size():
				if route[k].distance_to(car.global_position) < route[nearest].distance_to(car.global_position):
					nearest = k
			at = nearest
		await wait_physics_frames(1)
	gut.p("gate %d / %d in %.1fs (%d respawns), route point %d / %d, car at %s" % [level._next, level.gates.size(), level.elapsed, retries, at, route.size(), car.global_position.round()])
	assert_true(level.done, "race, jump, fly, loop, spin, ceiling drop and pound: the finish")


func test_falling_off_respawns_at_the_last_gate_and_soft_pad_landings_dont_launch() -> void:
	var level := await _load("ground_pound")
	var car := level.car
	# roll gently onto pad 1 from just above it: no pound, no launch
	var pad: Node3D = level.track.get_node("TrackRoot").get_children().filter(
		func(n: Node) -> bool: return String(n.name).begins_with("pound_pad"))[0]
	var xf := Transform3D(Basis(), pad.global_position + Vector3.UP * 1.5)
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	car.global_transform = xf
	car.linear_velocity = Vector3.ZERO
	await wait_physics_frames(40)
	assert_lt(car.linear_velocity.y, 2.0, "a soft landing on a pad doesn't throw you")
	assert_eq(level._next, 0, "a pad is mid-obstacle: no checkpoint on it")
	# falling to the sand puts you back at the last gate passed (the start)
	xf = Transform3D(Basis(), Vector3(60, 2.0, 60))
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	car.global_transform = xf
	await wait_physics_frames(4)
	var above := level._start_gate.global_position + Vector3.UP * 1.2
	assert_lt(car.global_position.distance_to(above), 4.0, "below the course: back on solid ground at the last checkpoint")
	for gate in level.gates:                                  # every checkpoint is on a deck at the reset height
		assert_almost_eq(gate.global_position.y, 30.0, 10.5, "%s on solid ground" % gate.name)


func test_skills_menu_lists_every_skill() -> void:
	var menu: Node = load("res://scenes/ui/level_select.tscn").instantiate()
	add_child_autofree(menu)
	await wait_physics_frames(2)
	menu.call("_show_skills")
	await wait_physics_frames(1)
	var buttons := menu.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.is_visible_in_tree() and b.text.contains("\n"))
	assert_eq(buttons.size(), SkillLevel.ORDER.size(), "one button per skill")
	assert_true((buttons.back() as Button).text.begins_with("TRACK SENSE"), "the final comes last")
