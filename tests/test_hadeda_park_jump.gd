extends GutTest

## The Sky Workshop jump is reachable: a full-throttle launch down the dome's
## launch lane, out through the west exit, lands the real car on the sky
## pillar's deck, where the workshop bay catches it.

const LEVEL := preload("res://scenes/levels/hadeda_park/hadeda_park.tscn")


func test_controlled_launch_reaches_the_sky_workshop() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	var holder := Node3D.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	var level: Node3D = LEVEL.instantiate()
	level.race_seconds = 9999.0
	holder.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var car: RigidBody3D = level.car
	await wait_physics_frames(2)
	car.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-75, 1.2, 0))   # dome launch lane
	car.linear_velocity = Vector3.ZERO
	await wait_physics_frames(10)
	car.set("motor_input", 1)
	var parked := false
	var t := 0.0
	while t < 10.0 and not parked:
		await wait_physics_frames(1)
		t += 1.0 / 60.0
		if car.global_position.x < -108.0:
			car.set("motor_input", 0)          # off the lip: hands off
		for store in get_tree().get_nodes_in_group("pit_stores"):
			if store.kind == &"sky" and store.is_open():
				parked = true
	gut.p("car at %s after %.1fs" % [car.global_position.round(), t])
	assert_true(parked, "the launch landed in the Sky Workshop bay")
	for store in get_tree().get_nodes_in_group("pit_stores"):
		store.leave()
	holder.queue_free()
