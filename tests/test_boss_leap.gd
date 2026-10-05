extends GutTest

## The leap charge: a landing circle is marked ahead of the car, the boss jumps
## onto it after the telegraph, and a car caught inside takes the hit.

const LEVEL := preload("res://scenes/levels/hadeda_park/hadeda_park.tscn")


func test_leap_marks_a_circle_lands_on_it_and_hits_a_car_inside() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	level.race_seconds = 0.5
	scene_root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_until(func() -> bool: return level.phase == level.Phase.FIGHT, 40.0, "boss arrives")
	var fight: BossFight = level.fight
	await wait_until(func() -> bool: return fight._state == &"fight", 10.0, "boss ready")
	fight._cooldown = INF                                # the boss's own brain stays out of it
	await wait_until(func() -> bool: return not fight._busy and not fight.boss.laser.is_active(), 15.0, "boss idle")
	await wait_seconds(1.0)                              # any melee clip already playing ends
	var car: RigidBody3D = level.car
	car.linear_velocity = Vector3.ZERO
	var health := GameManager.current_health
	fight._leap_combo(1)
	await wait_physics_frames(3)
	var markers := fight.find_children("*", "MeshInstance3D", false, false).filter(
		func(m: Node) -> bool: return (m as MeshInstance3D).mesh is PlaneMesh)
	assert_eq(markers.size(), 1, "a landing circle is marked")
	await wait_until(func() -> bool: return not fight._busy, 5.0, "leap finishes")
	var boss_to_car := Vector2(fight.boss.global_position.x - car.global_position.x,
		fight.boss.global_position.z - car.global_position.z).length()
	assert_lt(boss_to_car, BossFight.LEAP_RADIUS + 25.0, "the boss landed on the car's spot")
	assert_lt(GameManager.current_health, health, "a car inside the circle is hit")
	get_tree().paused = false
	scene_root.queue_free()


func test_lava_attack_burns_a_car_in_the_middle_while_the_boss_flies() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	GameManager.reset()
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	level.race_seconds = 0.5
	scene_root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_until(func() -> bool: return level.phase == level.Phase.FIGHT, 40.0, "boss arrives")
	var fight: BossFight = level.fight
	await wait_until(func() -> bool: return fight._state == &"fight", 10.0, "boss ready")
	fight._cooldown = INF                                # the boss's own brain stays out of it
	await wait_until(func() -> bool: return not fight._busy and not fight.boss.laser.is_active(), 15.0, "boss idle")
	await wait_seconds(1.0)                              # any melee clip already playing ends
	var car: RigidBody3D = level.car
	var spot := Transform3D(Basis(), fight.global_position + Vector3(30, 1.5, 0))   # well inside the lava radius
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, spot)   # a plain position set can be lost to the physics sync
	car.global_transform = spot
	car.linear_velocity = Vector3.ZERO
	await wait_physics_frames(2)
	assert_lt(car.global_position.distance_to(spot.origin), 2.0, "car placed in the lava zone: at %s want %s, fight %s, frozen %s, store %s" % [car.global_position.round(), spot.origin.round(), fight.global_position.round(), car.freeze, GameManager.invulnerable])
	fight.lava_duration = 3.0
	fight._lava_attack()
	await wait_physics_frames(3)
	var warnings := fight.find_children("*", "MeshInstance3D", false, false).filter(
		func(m: Node) -> bool: return (m as MeshInstance3D).mesh is CylinderMesh)
	assert_eq(warnings.size(), 1, "the lava zone blinks a warning before the stomps")
	await wait_until(func() -> bool: return fight._flying, 12.0, "lava up, boss flying")
	await wait_until(func() -> bool: return fight._lava and fight._lava.position.y >= 0.0, 5.0, "lava surface up")
	var health := GameManager.current_health
	await wait_seconds(1.0)
	assert_gt(fight.boss.position.y, 15.0, "the boss is flying over the lava")
	assert_lt(GameManager.current_health, health, "a car in the lava burns")
	await wait_until(func() -> bool: return not fight._busy, 10.0, "attack ends")
	assert_null(fight._lava, "the lava sank away")
	assert_almost_eq(fight.boss.position.y, 0.0, 0.01, "the boss landed")
	get_tree().paused = false
	scene_root.queue_free()


func test_after_three_attacks_the_boss_rests_and_the_camera_locks_on() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	level.race_seconds = 0.5
	scene_root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_until(func() -> bool: return level.phase == level.Phase.FIGHT, 40.0, "boss arrives")
	var fight: BossFight = level.fight
	var cam := get_viewport().get_camera_3d()
	assert_eq(cam.get("focus"), fight.boss, "the camera locks onto the boss")
	await wait_until(func() -> bool: return fight._state == &"fight", 10.0, "boss ready")
	fight._attacks_since_rest = BossFight.ATTACKS_BEFORE_REST
	fight._cooldown = 0.0
	await wait_until(func() -> bool: return fight.resting, 5.0, "the boss gets winded")
	await wait_seconds(BossFight.REST_TIME[fight.stage] * 0.8)
	assert_true(fight.resting, "it stays put for the whole rest")
	assert_eq(fight.boss.current_clip(), &"idle", "no attacks while winded")
	await wait_until(func() -> bool: return not fight.resting, 3.0, "and recovers")
	assert_eq(fight._attacks_since_rest, 0)
	get_tree().paused = false
	scene_root.queue_free()



func test_a_ground_pound_on_the_boss_takes_a_twentieth_and_springs_the_car_up() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	GameManager.reset()
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	level.race_seconds = 0.5
	scene_root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_until(func() -> bool: return level.phase == level.Phase.FIGHT, 40.0, "boss arrives")
	var fight: BossFight = level.fight
	await wait_until(func() -> bool: return fight._state == &"fight", 10.0, "boss ready")
	fight._cooldown = INF
	await wait_until(func() -> bool: return not fight._busy and not fight.boss.laser.is_active(), 15.0, "boss idle")
	var car: RigidBody3D = level.car
	var air: CarAirControl = car.get_node("CarAirControl")
	var health := fight.health
	var bounced := [0.0]
	air.ground_pounded.connect(func(_s: float, _h: int) -> void: bounced[0] = car.linear_velocity.y)
	var above := Transform3D(Basis(), fight.boss.global_position + Vector3(4, 45, 0))   # right over the bird
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, above)
	car.global_transform = above
	car.linear_velocity = Vector3.DOWN * 10.0
	Input.action_press("dive")
	await wait_until(func() -> bool: return bounced[0] != 0.0, 8.0, "pounds")
	Input.action_release("dive")
	assert_lte(fight.health, health - roundi(fight.max_health / 20.0), "at least a twentieth of its health")
	assert_gt(bounced[0], 20.0, "and the car springs back up toward the roof")
	get_tree().paused = false
	scene_root.queue_free()


func test_boss_landings_shake_only_the_screen_and_the_dome_hugs_the_wall() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	GameManager.reset()
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	level.race_seconds = 0.5
	scene_root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_until(func() -> bool: return level.phase == level.Phase.FIGHT, 40.0, "boss arrives")
	await wait_seconds(BossFight.LEAP_AIR_TIME + 2.5)       # the dome finishes fitting
	var dome: Node3D = level.dome
	var r: float = float(dome.get("radius")) * dome.scale.x
	var h: float = float(dome.get("height")) * dome.scale.y
	assert_almost_eq(r, level.arena.radius + BossArena.WALL_INNER, 0.5, "the glass meets the wall's inner face")
	assert_almost_eq(h / r, 0.55, 0.02, "and stands taller than the flat park dome")
	var car: RigidBody3D = level.car
	await wait_physics_frames(30)
	var v := car.linear_velocity
	level._burst(1.0)
	await wait_physics_frames(1)
	assert_lt((car.linear_velocity - v).length(), 0.5, "a boss landing never shoves the car")
	assert_gt(level._kick, 0.5, "it kicks the screen")
	GameManager.screen_shake = false
	await wait_physics_frames(2)
	var cam := get_viewport().get_camera_3d()
	assert_eq(cam.h_offset, 0.0, "screen shake off: the camera stays still")
	GameManager.screen_shake = true
	get_tree().paused = false
	scene_root.queue_free()


func test_ramming_the_boss_at_speed_takes_a_fiftieth() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	GameManager.reset()
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	level.race_seconds = 0.5
	scene_root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_until(func() -> bool: return level.phase == level.Phase.FIGHT, 40.0, "boss arrives")
	var fight: BossFight = level.fight
	await wait_until(func() -> bool: return fight._state == &"fight", 10.0, "boss ready")
	fight._cooldown = INF
	await wait_until(func() -> bool: return not fight._busy and not fight.boss.laser.is_active(), 15.0, "boss idle")
	var car: RigidBody3D = level.car
	var ram: Node = car.get_node("RamComponent")
	var top: float = car.get("top_speed")
	# the air ram (and its rings) switches on near top speed, not at an unreachable 200 km/h
	car.linear_velocity = Vector3.FORWARD * top * 0.7
	await wait_physics_frames(1)
	await get_tree().process_frame
	assert_false(ram.is_ramming, "cruising below 80% of top speed: no ram")
	# line up 30 m out, aimed at the boss, at top speed
	var at := fight.boss.global_position
	var from := at + Vector3(30, 0.6, 0)
	var xf := Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	car.global_transform = xf
	var health := fight.health
	for i in 60:
		car.linear_velocity = (at - from).normalized() * top
		await wait_physics_frames(1)
		if fight.health < health:
			break
	assert_true(ram.is_ramming, "at top speed the car rams")
	assert_almost_eq(float(health - fight.health), roundf(fight.max_health / 50.0), 1.0, "a ram takes a fiftieth of its health")
	get_tree().paused = false
	scene_root.queue_free()


func test_leap_aims_where_a_moving_car_will_be_on_landing() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	GameManager.reset()
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	level.race_seconds = 0.5
	scene_root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_until(func() -> bool: return level.phase == level.Phase.FIGHT, 40.0, "boss arrives")
	var fight: BossFight = level.fight
	await wait_until(func() -> bool: return fight._state == &"fight", 10.0, "boss ready")
	fight._cooldown = INF
	await wait_until(func() -> bool: return not fight._busy and not fight.boss.laser.is_active(), 15.0, "boss idle")
	var car: RigidBody3D = level.car
	var start := fight.global_position + Vector3(-40, 0.6, 20)
	var xf := Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), start)
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	car.global_transform = xf
	car.linear_velocity = Vector3.RIGHT * 20.0
	await wait_physics_frames(1)
	car.linear_velocity = Vector3.RIGHT * 20.0
	var expect := car.global_position + Vector3.RIGHT * 20.0 * (BossFight.LEAP_TELEGRAPH + BossFight.LEAP_AIR_TIME)
	fight._leap_combo(1)
	await wait_physics_frames(1)
	var markers := fight.find_children("*", "MeshInstance3D", false, false).filter(
		func(m: Node) -> bool: return (m as MeshInstance3D).mesh is PlaneMesh)
	assert_eq(markers.size(), 1)
	var mark := (markers[0] as Node3D).global_position
	assert_lt(Vector2(mark.x - expect.x, mark.z - expect.z).length(), 3.0, "the circle sits where the car will be when it lands")
	await wait_until(func() -> bool: return not fight._busy, 6.0, "leap finishes")
	get_tree().paused = false
	scene_root.queue_free()


func _fight_level(test_stage := -1) -> Node3D:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	GameManager.reset()
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	ParkLevel.test_stage = test_stage
	var level: Node3D = LEVEL.instantiate()
	if test_stage < 0:
		level.race_seconds = 0.5
	scene_root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_until(func() -> bool: return level.phase == level.Phase.FIGHT, 40.0, "boss arrives")
	await wait_until(func() -> bool: return level.fight._state == &"fight", 10.0, "boss ready")
	level.fight._cooldown = INF
	await wait_until(func() -> bool: return not level.fight._busy and not level.fight.boss.laser.is_active(), 15.0, "boss idle")
	return level


func _put_car(car: RigidBody3D, at: Vector3) -> void:
	var xf := Transform3D(Basis(), at)
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	car.global_transform = xf
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO


func test_boss_test_mode_goes_straight_to_the_chosen_boss() -> void:
	var level := await _fight_level(2)
	assert_eq(level.fight.stage, HadedaBoss.Stage.CYDEDA, "boss test: cydeda straight away")
	assert_eq(ParkLevel.test_stage, -1, "the test choice is used once")
	get_tree().paused = false
	level.get_parent().queue_free()


func test_shockwave_hits_a_car_on_the_ground_but_not_one_in_the_air() -> void:
	var level := await _fight_level()
	var fight: BossFight = level.fight
	var car: RigidBody3D = level.car
	var air: CarAirControl = car.get_node("CarAirControl")
	_put_car(car, fight.global_position + Vector3(40, 0.7, 0))
	await wait_physics_frames(20)
	var health := GameManager.current_health
	fight._shockwave()
	await wait_seconds(40.0 / BossFight.WAVE_SPEED + 0.3)
	assert_lt(GameManager.current_health, health, "the ring hits a grounded car")
	# now hover the car above the ring's path
	_put_car(car, fight.global_position + Vector3(0, 0.7, 40))
	await wait_physics_frames(20)
	health = GameManager.current_health
	fight._shockwave()
	await wait_seconds(40.0 / BossFight.WAVE_SPEED - 0.25)
	_put_car(car, fight.global_position + Vector3(0, 9.0, 40))   # jumped
	car.freeze = true
	await wait_seconds(0.6)
	car.freeze = false
	assert_eq(GameManager.current_health, health, "jumping it dodges the ring")
	get_tree().paused = false
	level.get_parent().queue_free()


func test_lava_wells_up_in_the_middle_and_spreads_out() -> void:
	var level := await _fight_level()
	var fight: BossFight = level.fight
	GameManager.invulnerable = true                       # the car sits in it: don't let game over pause the test
	fight.lava_duration = 4.0
	fight._lava_attack()
	await wait_until(func() -> bool: return fight._lava != null and fight._lava.position.y >= 0.0, 6.0, "lava up")
	var reach := (fight._lava.mesh as CylinderMesh).top_radius
	assert_lt(fight._lava.scale.x * reach, reach * 0.8, "it starts small, in the middle")
	await wait_seconds(BossFight.LAVA_SPREAD_TIME)
	assert_almost_eq(fight._lava.scale.x, 1.0, 0.02, "then floods out to the wall")
	await wait_until(func() -> bool: return not fight._busy, 15.0, "attack ends")
	GameManager.invulnerable = false
	get_tree().paused = false
	level.get_parent().queue_free()
