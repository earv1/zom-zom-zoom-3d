extends GutTest

## A car that comes down on two wheels rolls back onto all four smoothly, at
## rest and at speed: no hopping side to side, no launch.

const LEVEL := preload("res://scenes/levels/hadeda_park/hadeda_park.tscn")


func _drop_tilted(level: Node3D, speed: float) -> Dictionary:
	var car: RigidBody3D = level.car
	var xf := Transform3D(Basis(Vector3.BACK, deg_to_rad(35.0)), Vector3(-150, 1.4, 120))
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	car.global_transform = xf
	car.linear_velocity = Vector3.FORWARD * speed
	car.angular_velocity = Vector3.ZERO
	var peak := 0.0
	for i in 90:
		await wait_physics_frames(1)
		peak = maxf(peak, car.linear_velocity.y)
	return {peak = peak, roll = rad_to_deg(car.global_basis.get_euler().z)}


func test_two_wheel_landing_settles_smoothly() -> void:
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
	for speed in [0.0, 25.0]:
		var r: Dictionary = await _drop_tilted(level, speed)
		assert_lt(r.peak, 1.5, "no launch at %d m/s (peak up %.2f m/s)" % [speed, r.peak])
		assert_almost_eq(r.roll, 0.0, 3.0, "back on four wheels at %d m/s" % speed)
	root.queue_free()
