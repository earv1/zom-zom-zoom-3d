extends GutTest

## Integration test for the Hadeda Park: race -> earthquake -> arena + boss ->
## earthquake -> race, for all three stages, ending in a win. Time runs 4x with
## 4x the physics ticks (so each physics step stays 1/60 s and the car's
## suspension stays stable), and each boss is finished off once it has landed.

const LEVEL := preload("res://scenes/levels/hadeda_park/hadeda_park.tscn")

var _level: Node3D


func before_all() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 32


func after_all() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8
	GameManager.reset()


func _phase_is(phase: int) -> Callable:
	return func() -> bool: return _level.phase == phase


func test_park_has_pit_lanes_and_spurs() -> void:
	var track: Node3D = load("res://scenes/levels/hadeda_park/park.tscn").instantiate()
	var routes := {}
	for child in track.get_node("TrackRoot").get_children():
		if child.has_meta("route"):
			routes[child.get_meta("route")] = true
	assert_eq(routes.keys().size(), 3, "two pit lanes and the spur into the dome")
	track.free()


func test_full_boss_cycle_ends_in_a_win() -> void:
	_level = LEVEL.instantiate()
	_level.race_seconds = 2.0
	# the car and enemies add skid marks / fragments to current_scene, so it must
	# exist before the level enters the tree, like it does in the real game
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	scene_root.add_child(_level)
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)   # the level-up screen would pause the tree
	watch_signals(GameManager)
	# the win screen pauses the tree, which would also stall this test's polling
	GameManager.game_won.connect(func() -> void: get_tree().paused = false, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	var track_root: Node3D = _level.track.get_node("TrackRoot")

	for stage in 3:
		await wait_until(_phase_is(_level.Phase.FIGHT), 40.0, "stage %d boss arrives" % stage)
		assert_eq(_level.phase, _level.Phase.FIGHT)
		assert_false(track_root.visible, "track is gone during the fight")
		assert_true(_level.arena.visible, "arena is up during the fight")
		await wait_seconds(_level.DOME_FIT_TIME)
		assert_eq(_level.dome.get("exits"), 0, "the arena dome has no exits")
		assert_lt(_level.dome.scale.x, 0.5, "the dome shrank round the arena")
		var to_dome := Vector2(_level.car.global_position.x - _level.dome.global_position.x,
			_level.car.global_position.z - _level.dome.global_position.z).length()
		assert_lt(to_dome, float(_level.dome.get("radius")) * _level.dome.scale.x, "car is inside the arena dome")
		assert_eq(_level.fight.stage, _level.STAGES[stage])
		var dist_to_center := Vector2(_level.car.global_position.x - _level.arena.global_position.x,
			_level.car.global_position.z - _level.arena.global_position.z).length()
		assert_lt(dist_to_center, _level.arena.radius, "car is inside the arena")

		await wait_until(func() -> bool: return _level.fight._state != &"drop", 10.0, "boss lands")
		_level.fight._on_hit(9999)

		if stage < 2:
			await wait_until(_phase_is(_level.Phase.RACE), 40.0, "track returns after stage %d" % stage)
			assert_true(track_root.visible)
			assert_almost_eq(track_root.position.y, 0.0, 0.01, "track is back at ground level")
			assert_false(_level.arena.visible, "arena sank")
			assert_almost_eq(_level.dome.scale.x, 1.0, 0.001, "dome back to full size")
			assert_eq(_level.dome.get("exits"), 4, "dome exits reopened")
			assert_lt(_level.car.global_position.distance_to(_level.start_grid.global_position), 8.0,
				"car is back on the start grid")
			assert_eq(_level.stage_index, stage + 1)

	await wait_until(_phase_is(_level.Phase.WON), 20.0, "run is won")
	assert_signal_emitted(GameManager, "game_won")
	scene_root.queue_free()


func test_driving_through_the_summon_panel_summons_the_boss() -> void:
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	var level: Node3D = LEVEL.instantiate()
	scene_root.add_child(level)
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	await wait_physics_frames(5)
	assert_eq(level.phase, level.Phase.RACE)
	var panels := get_tree().get_nodes_in_group("summon_panels")
	assert_eq(panels.size(), 1, "the park has a summon panel")
	var car: RigidBody3D = level.car
	car.global_transform = Transform3D(Basis(), (panels[0] as Node3D).global_position + Vector3(0, 1.2, 12))
	car.linear_velocity = Vector3(0, 0, -20)                  # drive through it
	await wait_until(func() -> bool: return level.phase != level.Phase.RACE, 5.0, "boss summoned")
	assert_eq(level.phase, level.Phase.QUAKE_OUT)
	scene_root.queue_free()
