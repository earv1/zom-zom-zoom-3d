extends GutTest

## Ctrl dives; landing hard enough is a ground pound that hits nearby enemies.

const LEVEL := preload("res://scenes/levels/hadeda_park/hadeda_park.tscn")


func after_each() -> void:
	Input.action_release("dive")


func test_diving_into_the_ground_pounds_nearby_enemies() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	GameManager.reset()
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	scene_root.add_child(level)
	level.spawner.set_process(false)                    # no new spawns; existing enemies stay live
	await wait_physics_frames(3)
	var car: RigidBody3D = level.car
	var air: CarAirControl = car.get_node("CarAirControl")
	watch_signals(air)
	var spot := Vector3(-150, 0, 120)                       # open sand inside the dome
	for i in 3:
		level.spawner._spawn()
	await wait_physics_frames(2)
	var enemies := get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return e is BaseEnemy and e.visible)
	for i in enemies.size():
		(enemies[i] as BaseEnemy).global_position = spot + Vector3(4 + i * 2, 0.6, 0)
		(enemies[i] as BaseEnemy).car = null              # hold still
	car.global_transform = Transform3D(Basis(), spot + Vector3.UP * 40.0)
	car.linear_velocity = Vector3.ZERO
	var scrap := GameManager.scrap
	Input.action_press("dive")
	await wait_until(func() -> bool: return air.state == CarAirControl.State.GROUNDED and car.global_position.y < 3.0, 6.0, "lands")
	Input.action_release("dive")
	await wait_physics_frames(2)
	assert_signal_emitted(air, "ground_pounded", "a dive from 40 m is a ground pound")
	assert_gt(get_signal_parameters(air, "ground_pounded")[1], 0, "enemies caught in the shockwave")
	assert_gt(GameManager.scrap, scrap, "the pound pays scrap")
	scene_root.queue_free()
