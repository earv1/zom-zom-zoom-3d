extends GutTest

const LOOP_SCENE := preload("res://addons/track_editor/pieces/loop.tscn")
const STRAIGHT_SCENE := preload("res://addons/track_editor/pieces/straight.tscn")

var _pieces: Array[Node3D] = []

func after_each() -> void:
	for piece in _pieces:
		if is_instance_valid(piece):
			piece.queue_free()
	_pieces.clear()

func _load_loop() -> Node3D:
	var piece: Node3D = LOOP_SCENE.instantiate()
	add_child(piece)
	_pieces.append(piece)
	return piece

func _load_straight() -> Node3D:
	var piece: Node3D = STRAIGHT_SCENE.instantiate()
	add_child(piece)
	_pieces.append(piece)
	return piece

func test_loop_exposes_distinct_entry_and_exit_anchors() -> void:
	var loop := _load_loop()
	var anchors: Array = loop.get_connection_anchors()
	assert_eq(anchors.size(), 2)
	assert_eq(anchors[0].position, Vector3(4, 0, 0))
	assert_eq(anchors[0].out_dir, Vector3(1, 0, 0))
	assert_eq(anchors[1].position, Vector3(-4, 0, 8))
	assert_eq(anchors[1].out_dir, Vector3(-1, 0, 0))

func test_loop_exit_anchor_is_selected_for_targets_beyond_exit_side() -> void:
	var loop := _load_loop()
	var anchors := _anchors_for_piece(loop)
	var pair := _select_connection_anchor_pair(anchors, [{"position": Vector3(-12, 0, 8), "out_dir": Vector3(-1, 0, 0)}])
	assert_eq(pair.start.position, Vector3(-4, 0, 8))
	assert_eq(pair.start.out_dir, Vector3(-1, 0, 0))

func test_closest_anchor_wins_even_if_far_anchor_faces_better() -> void:
	var pair := _select_connection_anchor_pair(
		[{"position": Vector3(4, 0, 0), "out_dir": Vector3(1, 0, 0)}],
		[
			{"position": Vector3(100, 0, 0), "out_dir": Vector3(-1, 0, 0)},
			{"position": Vector3(5, 0, 6), "out_dir": Vector3(-1, 0, 0)},
		]
	)
	assert_eq(pair.start.position, Vector3(4, 0, 0))
	assert_eq(pair.end.position, Vector3(5, 0, 6))

func test_loop_to_straight_pair_uses_nearest_exit_and_entry() -> void:
	var loop := _load_loop()
	var straight := _load_straight()
	straight.position = Vector3(-8, 0, 4)

	var pair := _select_connection_anchor_pair(_anchors_for_piece(loop), _anchors_for_piece(straight))
	assert_eq(pair.start.position, Vector3(-4, 0, 8))
	assert_eq(pair.end.position, Vector3(-8, 0, 8))

func test_loop_exit_anchor_does_not_move_with_road_width() -> void:
	var loop := _load_loop()
	loop.configure({"road_width": 12.0, "radius": loop.radius})
	var anchors: Array = loop.get_connection_anchors()
	assert_eq(anchors[1].position, Vector3(-4, 0, 8))

func _anchors_for_piece(piece: Node3D) -> Array:
	var anchors: Array = []
	for anchor in piece.get_connection_anchors():
		var local_pos: Vector3 = anchor.position
		var local_dir: Vector3 = anchor.out_dir
		anchors.append({
			"position": piece.transform * local_pos,
			"out_dir": (piece.transform.basis * local_dir).normalized(),
		})
	return anchors

func _select_connection_anchor_pair(start_anchors: Array, end_anchors: Array) -> Dictionary:
	var best_start: Dictionary = start_anchors[0]
	var best_end: Dictionary = end_anchors[0]
	var best_dist := INF
	var best_facing := -INF
	for start_anchor in start_anchors:
		for end_anchor in end_anchors:
			var start_pos: Vector3 = start_anchor.position
			var end_pos: Vector3 = end_anchor.position
			var span := end_pos - start_pos
			var dist := span.length()
			var facing := 0.0
			if dist > 0.001:
				var dir := span / dist
				facing = start_anchor.out_dir.dot(dir) + (-end_anchor.out_dir).dot(dir)
			if dist < best_dist - 0.001 or (is_equal_approx(dist, best_dist) and facing > best_facing):
				best_dist = dist
				best_facing = facing
				best_start = start_anchor
				best_end = end_anchor
	return {"start": best_start, "end": best_end}
