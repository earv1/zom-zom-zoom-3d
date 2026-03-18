## GUT tests for track editor plugin helper functions.
## Mirrors the pure logic from plugin.gd without needing the full EditorPlugin.
extends GutTest

const CELL := Vector3(8.0, 4.0, 8.0)

# ── _snap ─────────────────────────────────────────────────────────────────────

func test_snap_centres_positive_coords() -> void:
	var result := _snap(Vector3(1.0, 5.0, 1.0))
	assert_almost_eq(result.x, 4.0, 0.001)
	assert_almost_eq(result.y, 0.0, 0.001)
	assert_almost_eq(result.z, 4.0, 0.001)

func test_snap_y_is_always_zero() -> void:
	var result := _snap(Vector3(3.0, 99.0, 3.0))
	assert_almost_eq(result.y, 0.0, 0.001)

func test_snap_crosses_cell_boundary() -> void:
	var result := _snap(Vector3(9.0, 0.0, 9.0))
	assert_almost_eq(result.x, 12.0, 0.001)
	assert_almost_eq(result.z, 12.0, 0.001)

func test_snap_negative_coords() -> void:
	var result := _snap(Vector3(-1.0, 0.0, -1.0))
	assert_almost_eq(result.x, -4.0, 0.001)
	assert_almost_eq(result.z, -4.0, 0.001)

func test_snap_on_cell_boundary() -> void:
	# A point exactly on the boundary (x=8) belongs to the next cell → centre 12
	var result := _snap(Vector3(8.0, 0.0, 8.0))
	assert_almost_eq(result.x, 12.0, 0.001)
	assert_almost_eq(result.z, 12.0, 0.001)

# ── _side_offsets ─────────────────────────────────────────────────────────────

func test_side_offsets_0deg_is_x_axis() -> void:
	var s := _side_offsets(0.0)
	assert_eq(s[0], Vector3(-8, 0, 0))
	assert_eq(s[1], Vector3( 8, 0, 0))

func test_side_offsets_180deg_is_x_axis() -> void:
	var s := _side_offsets(180.0)
	assert_eq(s[0], Vector3(-8, 0, 0))
	assert_eq(s[1], Vector3( 8, 0, 0))

func test_side_offsets_90deg_is_z_axis() -> void:
	var s := _side_offsets(90.0)
	assert_eq(s[0], Vector3(0, 0, -8))
	assert_eq(s[1], Vector3(0, 0,  8))

func test_side_offsets_270deg_is_z_axis() -> void:
	var s := _side_offsets(270.0)
	assert_eq(s[0], Vector3(0, 0, -8))
	assert_eq(s[1], Vector3(0, 0,  8))

# ── helpers (mirrors plugin.gd logic) ────────────────────────────────────────

func _snap(world_pos: Vector3) -> Vector3:
	return Vector3(
		floorf(world_pos.x / CELL.x) * CELL.x + CELL.x * 0.5,
		0.0,
		floorf(world_pos.z / CELL.z) * CELL.z + CELL.z * 0.5
	)

func _side_offsets(rot_y_deg: float) -> Array:
	var r := fmod(rot_y_deg, 180.0)
	if abs(r) < 1.0 or abs(r - 180.0) < 1.0:
		return [Vector3(-CELL.x, 0, 0), Vector3(CELL.x, 0, 0)]
	else:
		return [Vector3(0, 0, -CELL.z), Vector3(0, 0, CELL.z)]
