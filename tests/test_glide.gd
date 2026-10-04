extends GutTest

## Flight controls: hops lower than GLIDE_MIN_HEIGHT stay physical; with more
## air under the car steering bends the flight path, W/S pitch the nose down/up, and holding the nose up stalls
## the car into a plunging ground pound.

const LEVEL := preload("res://scenes/levels/hadeda_park/hadeda_park.tscn")

var _car: RigidBody3D
var _air: CarAirControl


func before_each() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	GameManager.reset()
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	scene_root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_physics_frames(3)
	_car = level.car
	_air = _car.get_node("CarAirControl")


func after_each() -> void:
	for a in ["turn_left", "accelerate", "decelerate", "dive"]:
		Input.action_release(a)
	get_tree().current_scene.queue_free()
	await wait_physics_frames(2)


## Mid-air at cruising speed in top gear, as if just off a ramp (a fresh state
## each time, so the glide delay starts over).
func _launch(height := 120.0) -> void:
	var gears: CarGears = _car.get_node("CarGears")
	gears.current_gear = CarGears.GEARS.size() - 1
	_air.state = CarAirControl.State.GROUNDED
	_air.stalled = false
	_car.global_transform = Transform3D(Basis(), Vector3(-150, height, 120))
	_car.linear_velocity = Vector3(0, 0, -35)
	_car.angular_velocity = Vector3.ZERO
	await wait_physics_frames(2)


func test_a_low_hop_gets_no_flight_steering() -> void:
	await _launch(DesertLandscape.COLLISION_FLOOR_Y + 0.56 + 1.4)    # 1.4 m of air: under the glide height
	Input.action_press("turn_left")
	await wait_physics_frames(12)
	assert_almost_eq(_car.linear_velocity.x, 0.0, 0.5, "no flight steering just above the ground")


func test_high_up_steering_banks_the_path() -> void:
	await _launch()
	Input.action_press("turn_left")
	await wait_seconds(1.0)
	assert_lt(_car.linear_velocity.x, -2.0, "the flight path bends left")


func test_w_noses_down_and_s_noses_up() -> void:
	await _launch()
	await wait_seconds(1.2)
	var free_vy := _car.linear_velocity.y
	await _launch()
	Input.action_press("accelerate")
	await wait_seconds(1.2)
	var dive_vy := _car.linear_velocity.y
	Input.action_release("accelerate")
	await _launch()
	Input.action_press("decelerate")
	await wait_seconds(1.2)
	var climb_vy := _car.linear_velocity.y
	assert_false(_air.stalled, "a short pull-up doesn't stall")
	assert_lt(dive_vy, free_vy - 3.0, "W pitches the path down")
	assert_gt(climb_vy, free_vy + 3.0, "S pitches the path up")


func test_holding_nose_up_stalls_into_a_ground_pound() -> void:
	watch_signals(_air)
	await _launch(60.0)
	Input.action_press("decelerate")
	await wait_until(func() -> bool: return _air.stalled, 4.0, "stalls")
	Input.action_release("decelerate")
	await wait_until(func() -> bool: return _air.state == CarAirControl.State.GROUNDED, 8.0, "lands")
	assert_signal_emitted(_air, "ground_pounded", "the stall plunge lands as a ground pound")


func test_a_stall_plunge_onto_the_sand_does_not_fall_through() -> void:
	watch_signals(_air)
	var road := Vector3(-150, 0, 120)                     # open sand (the heightmap the boss arena stands on)
	_car.global_transform = Transform3D(Basis(), road + Vector3.UP * 150.0)
	_car.linear_velocity = Vector3.ZERO
	_air.state = CarAirControl.State.GROUNDED
	await wait_physics_frames(2)
	_air.stalled = true
	Input.action_press("dive")
	var lowest := INF
	for i in 400:
		await wait_physics_frames(1)
		lowest = minf(lowest, _car.global_position.y)
		if _air.state == CarAirControl.State.GROUNDED:
			break
	Input.action_release("dive")
	await wait_seconds(0.5)
	assert_eq(_air.state, CarAirControl.State.GROUNDED, "lands")
	assert_gt(lowest, road.y - 0.5, "never dips below the ground")
	assert_gt(_car.global_position.y, road.y, "and stays on top of it")
	assert_signal_emitted(_air, "ground_pounded", "still a full ground pound")


func test_clearance_is_the_nearer_of_straight_down_and_out_of_the_belly() -> void:
	var low := DesertLandscape.COLLISION_FLOOR_Y + 1.4
	# rolled onto its side just above the sand: the belly sees nothing, straight down does
	_car.global_transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-150, low, 120))
	_car.linear_velocity = Vector3(0, 0, -35)
	_car.angular_velocity = Vector3.ZERO
	_air.state = CarAirControl.State.GROUNDED
	await wait_physics_frames(3)
	assert_eq(_air._belly.is_colliding(), false, "nothing out of the belly")
	assert_lt(_air._height_above_ground(), CarAirControl.GLIDE_MIN_HEIGHT, "but the sand is straight below")
	# high up and clear both ways: flight allowed
	_car.global_transform = Transform3D(Basis(), Vector3(-150, 120, 120))
	await wait_physics_frames(3)
	assert_gt(_air._height_above_ground(), CarAirControl.GLIDE_MIN_HEIGHT, "clear air both ways")


func test_leaving_flight_mode_drops_the_stall_and_the_spin_and_the_icon_follows() -> void:
	var icon := FlightIndicator.new()
	icon.air = _air
	add_child_autofree(icon)
	await _launch()
	await wait_physics_frames(3)
	assert_true(_air.flying, "high up: flight mode")
	icon._process(0.0)
	assert_true(icon.visible, "the aeroplane shows")
	_air.stalled = true
	# drop it just above the sand: under the flight height, flight mode lets go of everything
	_car.global_transform = Transform3D(Basis(), Vector3(-150, DesertLandscape.COLLISION_FLOOR_Y + 0.56 + 1.0, 120))
	_car.linear_velocity = Vector3(0, -2, -20)
	await wait_physics_frames(3)
	assert_false(_air.flying, "near the ground: no flight mode")
	assert_false(_air.stalled, "the stall is dropped with it")
	icon._process(0.0)
	assert_false(icon.visible, "and the aeroplane goes")
