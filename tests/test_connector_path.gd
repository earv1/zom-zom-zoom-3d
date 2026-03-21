extends GutTest

const CONNECTOR_SCENE := preload("res://addons/track_editor/pieces/connector.tscn")

var _connector: Node3D

func after_each() -> void:
	if is_instance_valid(_connector):
		_connector.queue_free()
		_connector = null

func _make_connector() -> Node3D:
	_connector = CONNECTOR_SCENE.instantiate()
	add_child(_connector)
	return _connector

func test_connector_straight_path_remains_monotonic() -> void:
	var connector := _make_connector()
	connector.start_pos = Vector3(0, 0, 4)
	connector.start_dir = Vector3(0, 0, 1)
	connector.end_pos = Vector3(0, 0, 12)
	connector.end_dir = Vector3(0, 0, 1)

	var points: Array = connector.sample_centerline(24)
	assert_eq(points.size(), 25)
	for i in range(points.size() - 1):
		assert_lte(points[i].z, points[i + 1].z + 0.001, "straight connector should keep moving forward")

func test_connector_same_yz_different_x_plots_a_straight_line() -> void:
	var connector := _make_connector()
	connector.start_pos = Vector3(-4, 2, 6)
	connector.start_dir = Vector3(-1, 0, 0)
	connector.end_pos = Vector3(12, 2, 6)
	connector.end_dir = Vector3(1, 0, 0)

	var points: Array = connector.sample_centerline(24)
	assert_eq(points.size(), 25)
	for i in range(points.size()):
		var expected_x := lerpf(-4.0, 12.0, float(i) / 24.0)
		assert_almost_eq(points[i].x, expected_x, 0.001, "x should interpolate linearly")
		assert_almost_eq(points[i].y, 2.0, 0.001, "y should stay constant")
		assert_almost_eq(points[i].z, 6.0, 0.001, "z should stay constant")

func test_connector_same_z_with_x_and_y_offset_stays_flush_with_road_edges() -> void:
	var connector := _make_connector()
	connector.start_pos = Vector3(-4, 0, 6)
	connector.start_dir = Vector3(-1, 0, 0)
	connector.end_pos = Vector3(4, 4, 6)
	connector.end_dir = Vector3(1, 0, 0)

	var points: Array = connector.sample_centerline(24)
	var width_dirs: Array = connector.sample_width_dirs(24)
	assert_eq(points.size(), 25)
	assert_eq(width_dirs.size(), 25)
	for i in range(points.size()):
		assert_almost_eq(points[i].z, 6.0, 0.001, "z should stay constant")
		assert_almost_eq(width_dirs[i].x, 0.0, 0.001, "road edge direction should stay parallel to z axis")
		assert_almost_eq(width_dirs[i].y, 0.0, 0.001, "road edge direction should stay horizontal")
		assert_almost_eq(absf(width_dirs[i].z), 1.0, 0.001, "road edge direction should stay aligned with z axis")
	if points.size() >= 3:
		assert_gt(points[1].x, points[0].x, "connector should move toward the raised road immediately")
		assert_almost_eq(points[1].y - points[0].y, 0.0, 0.001, "connector should leave the start road flat")
		assert_almost_eq(points[points.size() - 1].y - points[points.size() - 2].y, 0.0, 0.001, "connector should approach the end road flat")
	for i in range(points.size() - 1):
		assert_lte(points[i].x, points[i + 1].x + 0.001, "x should not loop backward")
		assert_lte(points[i].y, points[i + 1].y + 0.001, "y should keep climbing toward the raised road")

func test_turn_connector_leaves_and_arrives_parallel_to_roads() -> void:
	var connector := _make_connector()
	connector.start_pos = Vector3(0, 0, 4)
	connector.start_dir = Vector3(0, 0, 1)
	connector.end_pos = Vector3(12, 0, 0)
	connector.end_dir = Vector3(1, 0, 0)

	var points: Array = connector.sample_centerline(24)
	assert_eq(points.size(), 25)
	if points.size() >= 3:
		var start_delta: Vector3 = points[1] - points[0]
		var end_delta: Vector3 = points[points.size() - 1] - points[points.size() - 2]
		assert_almost_eq(start_delta.x, 0.0, 0.2, "turn should leave start road parallel")
		assert_gt(start_delta.z, 0.0, "turn should move forward along start road first")
		assert_gt(end_delta.x, 0.0, "turn should approach end road along x")
		assert_almost_eq(end_delta.z, 0.0, 0.2, "turn should arrive parallel to end road")

func test_turn_connector_four_guides_bracket_endpoints_along_road_dirs() -> void:
	var connector := _make_connector()
	connector.start_pos = Vector3(0, 0, 4)
	connector.start_dir = Vector3(0, 0, 1)
	connector.end_pos = Vector3(12, 0, 0)
	connector.end_dir = Vector3(1, 0, 0)

	var controls: Array = connector.sample_debug_controls(24)
	assert_eq(controls.size(), 4)
	assert_eq(controls[0], Vector3(0, 0, 4))
	assert_eq(controls[3], Vector3(12, 0, 0))
	# p1 sits forward of start along start_dir (0,0,1) — no x drift
	assert_gt(controls[1].z, 4.0, "start guide must be ahead of start along start_dir")
	assert_almost_eq(controls[1].x, 0.0, 0.01, "start guide must stay on start_dir axis (no pull)")
	# p2 sits behind end along end_dir (1,0,0) — no z drift
	assert_lt(controls[2].x, 12.0, "end guide must be behind end along end_dir")
	assert_almost_eq(controls[2].z, 0.0, 0.01, "end guide must stay on end_dir axis (no pull)")

func test_width_dir_at_start_is_perpendicular_to_start_dir() -> void:
	var connector := _make_connector()
	connector.start_pos = Vector3(0, 0, 4)
	connector.start_dir = Vector3(0, 0, 1)
	connector.end_pos = Vector3(12, 0, 0)
	connector.end_dir = Vector3(1, 0, 0)

	var width_dirs: Array = connector.sample_width_dirs(24)
	assert_almost_eq(width_dirs[0].dot(Vector3(0, 0, 1)), 0.0, 0.01,
		"width dir at start must be perpendicular to start_dir so road is flush at junction")

func test_width_dir_at_end_is_perpendicular_to_end_dir() -> void:
	var connector := _make_connector()
	connector.start_pos = Vector3(0, 0, 4)
	connector.start_dir = Vector3(0, 0, 1)
	connector.end_pos = Vector3(12, 0, 0)
	connector.end_dir = Vector3(1, 0, 0)

	var width_dirs: Array = connector.sample_width_dirs(24)
	assert_almost_eq(width_dirs[width_dirs.size() - 1].dot(Vector3(1, 0, 0)), 0.0, 0.01,
		"width dir at end must be perpendicular to end_dir so road is flush at junction")

# ── flush / no-flip tests ────────────────────────────────────────────────────
# These guard against the "last slab juts out" bug: if width_dirs[-1] is
# flipped or mis-aligned relative to width_dirs[-2], the ribbon builder's
# dot-product sign check can rotate the final slab 180°.

func test_width_dir_does_not_flip_at_last_segment() -> void:
	# Any >90° jump between the last two width_dirs causes a visible kink
	var connector := _make_connector()
	connector.start_pos = Vector3(0, 0, 4)
	connector.start_dir = Vector3(0, 0, 1)
	connector.end_pos   = Vector3(12, 0, 0)
	connector.end_dir   = Vector3(1, 0, 0)

	var wd: Array = connector.sample_width_dirs(24)
	var second_last: Vector3 = wd[wd.size() - 2]
	var last: Vector3        = wd[wd.size() - 1]
	assert_gt(second_last.dot(last), 0.0,
		"last two width_dirs must agree in sign — a negative dot means the final slab is flipped")

func test_width_dir_does_not_flip_at_first_segment() -> void:
	var connector := _make_connector()
	connector.start_pos = Vector3(0, 0, 4)
	connector.start_dir = Vector3(0, 0, 1)
	connector.end_pos   = Vector3(12, 0, 0)
	connector.end_dir   = Vector3(1, 0, 0)

	var wd: Array = connector.sample_width_dirs(24)
	assert_gt((wd[0] as Vector3).dot(wd[1]), 0.0,
		"first two width_dirs must agree in sign — a negative dot means the first slab is flipped")

func test_width_dir_no_flip_for_s_curve_same_dir() -> void:
	# Mirrors a real editor case: straight at (0,0) → straight at (1,3) on an 8-unit grid,
	# both facing +z, so start_dir = end_dir = (0,0,1) but pieces are offset in x and z.
	var connector := _make_connector()
	connector.start_pos = Vector3(0, 0, 4)
	connector.start_dir = Vector3(0, 0, 1)
	connector.end_pos   = Vector3(8, 0, 20)
	connector.end_dir   = Vector3(0, 0, 1)

	var wd: Array = connector.sample_width_dirs(24)
	for i in range(wd.size() - 1):
		assert_gt((wd[i] as Vector3).dot(wd[i + 1]), 0.0,
			"width_dir must not flip between step %d and %d" % [i, i + 1])

func test_flush_approach_width_dir_matches_end_dir() -> void:
	# _sample_flush_approach_path uses a constant width_dir derived from the chord,
	# but the end piece may face a different direction — verify they agree.
	var connector := _make_connector()
	connector.start_pos = Vector3(0, 0, 0)
	connector.start_dir = Vector3(0, 0, 1)
	connector.end_pos   = Vector3(0, 4, 8)   # height ramp, chord is along z
	connector.end_dir   = Vector3(0, 0, 1)   # end piece also faces z — should be consistent

	var wd: Array = connector.sample_width_dirs(24)
	assert_almost_eq((wd[wd.size() - 1] as Vector3).dot(Vector3(0, 0, 1)), 0.0, 0.01,
		"flush approach width_dir at end must be perpendicular to end_dir")

func test_connector_exits_along_start_dir_when_end_is_mostly_behind() -> void:
	# End is diagonally behind start — previously caused the path to exit backward
	var connector := _make_connector()
	connector.start_pos = Vector3(0, 0, 0)
	connector.start_dir = Vector3(0, 0, 1)
	connector.end_pos = Vector3(2, 0, -8)
	connector.end_dir = Vector3(1, 0, 0)

	var points: Array = connector.sample_centerline(24)
	assert_eq(points.size(), 25)
	# First step must move forward in z (along start_dir), not backward
	assert_gt(points[1].z, points[0].z, "connector must exit forward along start_dir even when end is behind")


func test_connector_does_not_curl_away_from_target_at_the_start() -> void:
	var connector := _make_connector()
	connector.start_pos = Vector3(4, 0, 0)
	connector.start_dir = Vector3(1, 0, 0)
	connector.end_pos = Vector3(-4, 0, 8)
	connector.end_dir = Vector3(-1, 0, 0)

	var points: Array = connector.sample_centerline(24)
	assert_eq(points.size(), 25)
	# Path must exit along start_dir (+x), so initial steps increase x.
	# It should NOT shoot far past start_pos before looping back.
	var guide_limit := 4.0 + 6.0  # start_x + generous bound
	for point in points:
		assert_lte(point.x, guide_limit, "connector should not overshoot wildly in start_dir before turning")
	# And it must arrive near end_pos
	assert_almost_eq(points[points.size() - 1].x, -4.0, 0.5, "connector must reach end_pos x")
	assert_almost_eq(points[points.size() - 1].z, 8.0, 0.5, "connector must reach end_pos z")
