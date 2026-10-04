extends GutTest

## Driving off the sand onto a road at speed is smooth: the road's edge is a
## gentle bevel in the collision, not an 8 cm wall the wheels catch and hop on.

const LEVEL := preload("res://scenes/levels/hadeda_park/hadeda_park.tscn")


func _cross(level: Node3D, speed: float, throttle: bool) -> float:
	var car: RigidBody3D = level.car
	var track_root: Node3D = level.track.get_node("TrackRoot")
	var conn: Node3D = null
	for piece in track_root.get_children():
		if piece.has_method("_sample_path") and not String(piece.name).begins_with("loop"):
			conn = piece
			break
	var path: Array = conn.call("_sample_path", 24).get("points", [])
	var mid := conn.global_transform * (path[path.size() / 2] as Vector3)
	var ahead := conn.global_transform * (path[path.size() / 2 + 1] as Vector3)
	var along := Vector3(ahead.x - mid.x, 0.0, ahead.z - mid.z).normalized()
	var across := along.cross(Vector3.UP)
	var start := mid + across * 26.0                     # out on the sand beside the road
	start.y = DesertLandscape.COLLISION_FLOOR_Y + 0.7
	var heading := Basis.looking_at(-across, Vector3.UP)
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(heading, start))
	car.global_transform = Transform3D(heading, start)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	await wait_physics_frames(30)                        # settle on the sand
	car.linear_velocity = -across * speed
	car.set("motor_input", 1 if throttle else 0)
	var peak := 0.0
	var start_flat := Vector2(start.x, start.z)
	for i in 240:                                         # from the sand, over the edge, to the road's centre
		await wait_physics_frames(1)
		peak = maxf(peak, car.linear_velocity.y)
		if Vector2(car.global_position.x, car.global_position.z).distance_to(start_flat) > 26.0:
			break
	car.set("motor_input", 0)
	return peak


func test_driving_onto_a_road_does_not_hop() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	GameManager.reset()
	var root := Node3D.new()
	get_tree().root.add_child(root)
	get_tree().current_scene = root
	var level: Node3D = LEVEL.instantiate()
	level.race_seconds = 9999.0
	root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_physics_frames(3)
	for speed in [15.0, 35.0]:
		for throttle in [false, true]:
			var peak := await _cross(level, speed, throttle)
			gut.p("onto the road at %d m/s, throttle %s: peak upward speed %.2f m/s" % [speed, throttle, peak])
			assert_lt(peak, 0.4, "no hop driving onto the road at %d m/s (throttle %s)" % [speed, throttle])
	root.queue_free()
