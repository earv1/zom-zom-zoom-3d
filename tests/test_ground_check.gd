extends GutTest

## Ground check: run after editing the park (`just check-ground`). The desert
## and its decor regenerate around the track on every launch, so there is
## nothing to bake; this makes sure nothing you can't see blocks the car:
##   - no hidden collider sits above ground (e.g. pooled, hidden enemies)
##   - the sand inside the dome is perfectly flat (no bumps between pieces)

const LEVEL := preload("res://scenes/levels/hadeda_park/hadeda_park.tscn")
const STEP := 4.0

var _level: Node3D


func before_all() -> void:
	for c in GameManager.level_up_triggered.get_connections():
		GameManager.level_up_triggered.disconnect(c.callable)
	var scene_root := Node3D.new()
	get_tree().root.add_child(scene_root)
	get_tree().current_scene = scene_root
	_level = LEVEL.instantiate()
	_level.race_seconds = 9999.0
	scene_root.add_child(_level)


func after_all() -> void:
	_level.get_parent().queue_free()


func test_no_invisible_colliders_above_ground() -> void:
	# kill a few enemies so some sit in the spawner's pool
	for i in 6:
		_level.spawner._spawn()
	await wait_physics_frames(3)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is BaseEnemy and e.visible:
			e.die()
	await wait_physics_frames(3)
	var hidden: Array[String] = []
	for body in _level.find_children("*", "CollisionObject3D", true, false):
		var b := body as CollisionObject3D
		if b is Area3D or b.collision_layer == 0 or b.is_visible_in_tree():
			continue
		if b.global_position.y < -3.0:
			continue                                   # buried (sunk arena), can't be hit
		hidden.append("%s at %s" % [b.get_path(), b.global_position.round()])
	assert_eq(hidden, [] as Array[String], "hidden colliders the car can hit")


func test_sand_inside_the_dome_is_flat() -> void:
	await wait_physics_frames(2)
	var dome: Node3D = _level.dome
	assert_not_null(dome, "the park has a dome")
	var r: float = float(dome.get("radius")) - float(dome.get("transition"))
	var c := dome.global_position
	var space := _level.get_world_3d().direct_space_state
	var bumps: Array[String] = []
	var x := -r
	while x <= r:
		var z := -r
		while z <= r:
			if x * x + z * z < r * r:
				var p := c + Vector3(x, 0, z)
				var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 150.0, p + Vector3.DOWN * 20.0)
				q.exclude = [_level.car.get_rid()]
				var hit := space.intersect_ray(q)
				if hit and String((hit.collider as Node).name) == "NearTerrainBody" \
						and absf(hit.position.y - DesertLandscape.COLLISION_FLOOR_Y) > 0.02 and bumps.size() < 10:
					bumps.append("%s h=%.2f" % [Vector2(p.x, p.z).round(), hit.position.y])
			z += STEP
		x += STEP
	assert_eq(bumps, [] as Array[String], "sand bumps inside the dome")
