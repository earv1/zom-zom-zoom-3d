extends GutTest

## The load-time shader warm-up builds one of everything without errors, holds
## the car still while it runs, and cleans up after itself.

const LEVEL := preload("res://scenes/levels/hadeda_park/hadeda_park.tscn")


func test_warmup_runs_and_cleans_up() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	scene_root.add_child(level)
	level.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_physics_frames(2)
	var warm := ShaderWarmup.new()
	warm.level = level
	warm.car = level.car
	warm.pool = level.spawner.pool
	warm.force = true
	var seen := {}
	warm.done.connect(func() -> void: seen.rack = warm.get_child_count())   # just before it frees
	level.add_child(warm)
	assert_true(level.car.freeze, "car held while warming")
	await wait_until(func() -> bool: return seen.has("rack"), 5.0, "warm-up finishes")
	assert_gt(seen.get("rack", 0), 20, "one of everything on the rack")
	await wait_physics_frames(2)
	assert_false(is_instance_valid(warm), "rack freed")
	assert_false(level.car.freeze, "car released")
	assert_gt(ShaderWarmup.keep.size(), 0, "mid-run loads stay cached")
	scene_root.queue_free()
