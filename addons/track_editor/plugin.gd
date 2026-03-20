@tool
extends EditorPlugin

const DOCK_SCENE = preload("res://addons/track_editor/editor_dock.tscn")

const CELL   := Vector3(8.0, 4.0, 8.0)
const NO_HIT := Vector3(INF, INF, INF)

var dock: Control
var _selected_piece: String = "straight"
var _rotation_y: int = 0
var _track_root: Node3D = null
var _ghost: Node3D = null
var _erase_mode := false
var _last_grid_pos := Vector3.ZERO  # remembered so ghost snaps on piece-change
var _edit_mode := false
var _selected_placed_piece: Node3D = null
var _piece_params: Dictionary = {}
var _scene_cache: Dictionary = {}
var _connect_mode := false
var _connect_first: Node3D = null

var PIECE_SCENES := {
	"straight": "res://addons/track_editor/pieces/straight.tscn",
	"curve":    "res://addons/track_editor/pieces/curve.tscn",
	"ramp_up":  "res://addons/track_editor/pieces/ramp_up.tscn",
	"loop":     "res://addons/track_editor/pieces/loop.tscn",
	"bank":     "res://addons/track_editor/pieces/bank.tscn",
	"jump":     "res://addons/track_editor/pieces/jump.tscn",
}

func _enter_tree() -> void:
	dock = DOCK_SCENE.instantiate()
	dock.piece_selected.connect(_on_piece_selected)
	dock.erase_mode_toggled.connect(_on_erase_toggled)
	dock.edit_mode_changed.connect(_on_edit_mode_changed)
	dock.piece_params_changed.connect(_on_piece_params_changed)
	dock.connect_mode_toggled.connect(_on_connect_mode_changed)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
	_destroy_ghost()
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null

func _handles(_object: Object) -> bool:
	return true

func _make_visible(_visible: bool) -> void:
	pass

# ── dock callbacks ────────────────────────────────────────────────────────────

func _on_piece_selected(piece_name: String) -> void:
	_selected_piece = piece_name
	_erase_mode = false
	_piece_params = {}
	_selected_placed_piece = null
	if not _edit_mode:
		return
	_rebuild_ghost()
	if is_instance_valid(_ghost) and _ghost.has_method("get_param_defs"):
		dock.show_params(_ghost.get_param_defs(), _ghost.get_config())

func _on_edit_mode_changed(active: bool) -> void:
	_edit_mode = active
	if active:
		_rebuild_ghost()
		if is_instance_valid(_ghost) and _ghost.has_method("get_param_defs"):
			dock.show_params(_ghost.get_param_defs(), _ghost.get_config())
	else:
		_destroy_ghost()
		_selected_placed_piece = null
		dock.clear_params()
		_connect_mode = false
		_connect_first = null
		dock.set_connect_active(false)

func _on_connect_mode_changed(active: bool) -> void:
	_connect_mode = active
	_connect_first = null
	if active:
		_destroy_ghost()
		dock.clear_params()
	else:
		if not _erase_mode:
			_rebuild_ghost()
			if is_instance_valid(_ghost) and _ghost.has_method("get_param_defs"):
				dock.show_params(_ghost.get_param_defs(), _ghost.get_config())

func _on_erase_toggled(active: bool) -> void:
	_erase_mode = active
	if active:
		_destroy_ghost()
	else:
		_rebuild_ghost()

func _on_piece_params_changed(params: Dictionary) -> void:
	_piece_params = params
	if is_instance_valid(_selected_placed_piece):
		_selected_placed_piece.configure(params)
		_refresh_neighbors()
	if _edit_mode:
		_rebuild_ghost()

# ── viewport input ────────────────────────────────────────────────────────────

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if not _edit_mode:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_rotation_y = (_rotation_y + 1) % 4
			_rebuild_ghost()
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	if not _ensure_track_root():
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseMotion:
		var pos := _raycast_to_grid(viewport_camera, event.position)
		if pos != NO_HIT:
			_last_grid_pos = pos
			_move_ghost(pos)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton and event.pressed:
		var pos := _raycast_to_grid(viewport_camera, event.position)
		if pos == NO_HIT:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		if event.button_index == MOUSE_BUTTON_LEFT:
			if _connect_mode:
				var hit := _get_piece_at(pos)
				if hit != null:
					if _connect_first == null:
						_connect_first = hit
						dock.set_connect_status("Now click second piece")
					elif hit != _connect_first:
						_create_connector(_connect_first, hit)
						_connect_first = null
						_connect_mode = false
						dock.set_connect_active(false)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif _erase_mode:
				_erase_at(pos)
			else:
				var occupied := _get_piece_at(pos)
				if occupied != null:
					_select_placed_piece(occupied)
				else:
					_deselect_placed_piece()
					_place_piece(pos)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

		if event.button_index == MOUSE_BUTTON_RIGHT:
			_erase_at(pos)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

# ── grid helpers ──────────────────────────────────────────────────────────────

func _raycast_to_grid(cam: Camera3D, screen_pos: Vector2) -> Vector3:
	var origin := cam.project_ray_origin(screen_pos)
	var dir    := cam.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001:
		return NO_HIT
	var t := -origin.y / dir.y
	if t < 0.0:
		return NO_HIT
	return _snap(origin + dir * t)

func _snap(world_pos: Vector3) -> Vector3:
	return Vector3(
		floorf(world_pos.x / CELL.x) * CELL.x + CELL.x * 0.5,
		0.0,
		floorf(world_pos.z / CELL.z) * CELL.z + CELL.z * 0.5
	)

# ── ghost ─────────────────────────────────────────────────────────────────────

func _rebuild_ghost() -> void:
	_destroy_ghost()
	if _erase_mode:
		return
	var scene_root := _get_scene_root()
	if scene_root == null:
		return
	var scene_path: String = PIECE_SCENES.get(_selected_piece, "")
	var packed: PackedScene = _scene_cache.get(scene_path)
	if packed == null:
		packed = load(scene_path)
		if packed == null:
			return
		_scene_cache[scene_path] = packed
	_ghost = packed.instantiate()
	_ghost.position = _last_grid_pos   # snap to last known cursor position
	_ghost.rotation_degrees.y = _rotation_y * 90.0
	# Pre-set vars before entering tree so _ready()→_build() uses them (no double-build)
	for key in _piece_params:
		_ghost.set(key, _piece_params[key])
	scene_root.add_child(_ghost)
	_set_ghost_alpha(_ghost, 0.4)

func _move_ghost(pos: Vector3) -> void:
	if is_instance_valid(_ghost):
		_ghost.position = pos

func _destroy_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

func _set_ghost_alpha(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		var mat := (node as MeshInstance3D).get_active_material(0)
		if mat is BaseMaterial3D:
			var dup := mat.duplicate() as BaseMaterial3D
			dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dup.albedo_color.a = alpha
			(node as MeshInstance3D).material_override = dup
	for child in node.get_children():
		_set_ghost_alpha(child, alpha)

# ── place / erase ─────────────────────────────────────────────────────────────

func _place_piece(grid_pos: Vector3) -> void:
	if not _ensure_track_root():
		return
	if _get_piece_at(grid_pos) != null:
		return  # cell occupied

	var scene_path: String = PIECE_SCENES.get(_selected_piece, "")
	var packed: PackedScene = _scene_cache.get(scene_path)
	if packed == null:
		packed = load(scene_path)
		if packed == null:
			return
		_scene_cache[scene_path] = packed
	var scene_root := _get_scene_root()
	if scene_root == null:
		return

	var piece: Node3D = packed.instantiate()
	piece.position = grid_pos
	piece.rotation_degrees.y = _rotation_y * 90.0
	piece.name = _selected_piece + "_" + str(snappedi(grid_pos.x, 1)) + "_" + str(snappedi(grid_pos.z, 1))
	# Pre-set vars before entering tree so _ready()→_build() uses them (no double-build)
	for key in _piece_params:
		piece.set(key, _piece_params[key])

	var undo := get_undo_redo()
	undo.create_action("Place Track Piece")
	undo.add_do_method(_track_root, "add_child", piece)
	undo.add_do_method(piece, "set_owner", scene_root)
	undo.add_undo_method(_track_root, "remove_child", piece)
	undo.commit_action()

	_refresh_neighbors()

func _erase_at(grid_pos: Vector3) -> void:
	if not _ensure_track_root():
		return
	for child in _track_root.get_children():
		if child.position.is_equal_approx(grid_pos):
			var scene_root := _get_scene_root()
			var undo := get_undo_redo()
			undo.create_action("Erase Track Piece")
			undo.add_do_method(_track_root, "remove_child", child)
			undo.add_undo_method(_track_root, "add_child", child)
			if scene_root:
				undo.add_undo_method(child, "set_owner", scene_root)
			undo.commit_action()
			if _selected_placed_piece == child:
				_deselect_placed_piece()
			_refresh_neighbors()
			return

# ── piece selection ───────────────────────────────────────────────────────────

func _select_placed_piece(piece: Node3D) -> void:
	_selected_placed_piece = piece
	if piece.has_method("get_param_defs"):
		dock.show_params(piece.get_param_defs(), piece.get_config())

func _deselect_placed_piece() -> void:
	_selected_placed_piece = null
	dock.clear_params()

func _get_piece_at(grid_pos: Vector3) -> Node3D:
	if not is_instance_valid(_track_root):
		return null
	for child in _track_root.get_children():
		if child.position.is_equal_approx(grid_pos):
			return child as Node3D
	return null

# ── neighbor widening ─────────────────────────────────────────────────────────

# Offsets perpendicular to a straight's travel direction, per rotation step.
# rotation_y 0/180 → runs along Z, sides are ±X
# rotation_y 90/270 → runs along X, sides are ±Z
func _side_offsets(rot_y_deg: float) -> Array:
	var r := fmod(rot_y_deg, 180.0)
	if abs(r) < 1.0 or abs(r - 180.0) < 1.0:
		return [Vector3(-CELL.x, 0, 0), Vector3(CELL.x, 0, 0)]
	else:
		return [Vector3(0, 0, -CELL.z), Vector3(0, 0, CELL.z)]

func _refresh_neighbors() -> void:
	if not is_instance_valid(_track_root):
		return
	# Build a position lookup for fast neighbour queries
	var pos_map: Dictionary = {}
	for child in _track_root.get_children():
		pos_map[child.position] = child

	for child in _track_root.get_children():
		if not child.has_method("set_neighbors"):
			continue
		var rot: float = (child as Node3D).rotation_degrees.y
		var offsets := _side_offsets(rot)
		var has_left  := pos_map.has(child.position + offsets[0])
		var has_right := pos_map.has(child.position + offsets[1])
		child.set_neighbors(has_left, has_right)

# ── track root ────────────────────────────────────────────────────────────────

func _ensure_track_root() -> bool:
	var scene_root := _get_scene_root()
	if scene_root == null:
		return false
	if is_instance_valid(_track_root) and _track_root.get_parent() == scene_root:
		return true
	for child in scene_root.get_children():
		if child.name == "TrackRoot":
			_track_root = child
			return true
	_track_root = Node3D.new()
	_track_root.name = "TrackRoot"
	scene_root.add_child(_track_root)
	_track_root.set_owner(scene_root)
	return true

func _create_connector(piece_a: Node3D, piece_b: Node3D) -> void:
	if not _ensure_track_root():
		return
	var scene_root := _get_scene_root()
	if scene_root == null:
		return

	# Axis each piece runs along (Z-axis rotated by rotation_degrees.y)
	var rot_a  := deg_to_rad(piece_a.rotation_degrees.y)
	var rot_b  := deg_to_rad(piece_b.rotation_degrees.y)
	var axis_a := Vector3(sin(rot_a), 0.0, cos(rot_a))
	var axis_b := Vector3(sin(rot_b), 0.0, cos(rot_b))

	# Exit face of A: whichever face is closer to B
	var fa_p := piece_a.position + axis_a * 4.0
	var fa_n := piece_a.position - axis_a * 4.0
	var face_a := fa_p if fa_p.distance_to(piece_b.position) < fa_n.distance_to(piece_b.position) else fa_n

	# Entry face of B: whichever face is closer to face_a
	var fb_p := piece_b.position + axis_b * 4.0
	var fb_n := piece_b.position - axis_b * 4.0
	var face_b := fb_p if fb_p.distance_to(face_a) < fb_n.distance_to(face_a) else fb_n

	# Tangent directions: away from A through face_a, into B through face_b
	var start_dir := (face_a - piece_a.position).normalized()
	var end_dir   := (piece_b.position - face_b).normalized()

	# Inherit road_width from piece A if it has one
	var rw := 6.0
	var rw_val = piece_a.get("road_width")
	if rw_val != null:
		rw = rw_val

	var scene_path := "res://addons/track_editor/pieces/connector.tscn"
	var packed: PackedScene = _scene_cache.get(scene_path)
	if packed == null:
		packed = load(scene_path)
		if packed == null:
			return
		_scene_cache[scene_path] = packed

	var conn: Node3D = packed.instantiate()
	conn.position = face_a
	conn.name = "connector_" + str(snappedi(face_a.x, 1)) + "_" + str(snappedi(face_a.z, 1))
	conn.set("start_pos",  face_a)
	conn.set("start_dir",  start_dir)
	conn.set("end_pos",    face_b)
	conn.set("end_dir",    end_dir)
	conn.set("road_width", rw)

	var undo := get_undo_redo()
	undo.create_action("Connect Track Pieces")
	undo.add_do_method(_track_root, "add_child", conn)
	undo.add_do_method(conn, "set_owner", scene_root)
	undo.add_undo_method(_track_root, "remove_child", conn)
	undo.commit_action()

func _get_scene_root() -> Node:
	var ei := get_editor_interface()
	if ei == null:
		return null
	return ei.get_edited_scene_root()
