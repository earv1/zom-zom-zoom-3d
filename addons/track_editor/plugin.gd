@tool
extends EditorPlugin

const DOCK_SCENE = preload("res://addons/track_editor/editor_dock.tscn")
const TrackTheme = preload("res://addons/track_editor/track_theme.gd")

const CELL   := Vector3(8.0, 4.0, 8.0)
const NO_HIT := Vector3(INF, INF, INF)
const ANCHOR_SNAP_RADIUS := 12.0  # world units — max distance to snap to an anchor
const GRID_BIAS := 2.0  # anchors are favored by this multiplier over grid

# Surface orientations: which direction the track bottom faces
enum Surface { FLOOR, CEILING, NORTH, SOUTH, EAST, WEST }
const SURFACE_BASES := {
	Surface.FLOOR:   Basis.IDENTITY,
	Surface.CEILING: Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)),
	Surface.NORTH:   Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)),
	Surface.SOUTH:   Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)),
	Surface.EAST:    Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)),
	Surface.WEST:    Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)),
}
const SURFACE_NAMES := {
	Surface.FLOOR: "Floor", Surface.CEILING: "Ceiling",
	Surface.NORTH: "North", Surface.SOUTH: "South",
	Surface.EAST: "East", Surface.WEST: "West",
}

var dock: Control
var _selected_piece: String = "straight"
var _rotation_y: int = 0
var _track_root: Node3D = null
var _ghost: Node3D = null
var _erase_mode := false
var _last_grid_pos := Vector3.ZERO  # remembered so ghost snaps on piece-change
var _last_snap_pos := Vector3.ZERO  # actual position (grid or anchor)
var _snapped_to_anchor := false
var _edit_mode := false
var _selected_placed_piece: Node3D = null
var _piece_params: Dictionary = {}
var _scene_cache: Dictionary = {}
var _connect_mode := false
var _connect_first: Node3D = null
var _current_layer := 0
var _theme_mode := TrackTheme.MODE_LINES
var _side_color_name := "yellow"
var _surface: int = Surface.FLOOR

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
	dock.rotate_requested.connect(_on_rotate_requested)
	dock.selection_cleared.connect(_on_selection_cleared)
	dock.delete_selection_requested.connect(_on_delete_selection_requested)
	dock.test_requested.connect(_on_test_requested)
	dock.connect_from_selection_requested.connect(_on_connect_from_selection_requested)
	dock.cancel_requested.connect(_on_cancel_requested)
	dock.layer_changed.connect(_on_layer_changed)
	dock.theme_mode_changed.connect(_on_theme_mode_changed)
	dock.side_color_changed.connect(_on_side_color_changed)
	dock.surface_changed.connect(_on_surface_changed)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	dock.set_layer(_current_layer, _current_layer * CELL.y)
	dock.set_theme_mode(_theme_mode)
	dock.set_side_color(_side_color_name)
	dock.set_surface(_surface)
	_update_context_ui(NO_HIT)

func _exit_tree() -> void:
	_destroy_ghost()
	_deselect_placed_piece()
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
	_deselect_placed_piece()
	if not _edit_mode:
		_update_context_ui(NO_HIT)
		return
	_rebuild_ghost()
	if is_instance_valid(_ghost) and _ghost.has_method("get_param_defs"):
		dock.show_params(_ghost.get_param_defs(), _ghost.get_config())
	_update_context_ui(_last_grid_pos)

func _on_edit_mode_changed(active: bool) -> void:
	_edit_mode = active
	if active:
		_rebuild_ghost()
		if is_instance_valid(_ghost) and _ghost.has_method("get_param_defs"):
			dock.show_params(_ghost.get_param_defs(), _ghost.get_config())
		dock.set_rotation_turns(_rotation_y)
	else:
		_destroy_ghost()
		_deselect_placed_piece()
		dock.clear_params()
		_connect_mode = false
		_connect_first = null
		dock.set_connect_active(false)
		dock.set_selection_info("Nothing selected", false)
	_update_context_ui(_last_grid_pos if active else NO_HIT)

func _on_connect_mode_changed(active: bool) -> void:
	_connect_mode = active
	_connect_first = null
	if active:
		_destroy_ghost()
		_deselect_placed_piece()
		dock.clear_params()
	else:
		if not _erase_mode:
			_rebuild_ghost()
			if is_instance_valid(_ghost) and _ghost.has_method("get_param_defs"):
				dock.show_params(_ghost.get_param_defs(), _ghost.get_config())
	_update_context_ui(_last_grid_pos)

func _on_erase_toggled(active: bool) -> void:
	_erase_mode = active
	if active:
		_destroy_ghost()
		_deselect_placed_piece()
		dock.clear_params()
	else:
		_rebuild_ghost()
	_update_context_ui(_last_grid_pos)

func _on_piece_params_changed(params: Dictionary) -> void:
	_piece_params = params
	if is_instance_valid(_selected_placed_piece):
		_apply_params_to_selected_piece(params)
	if _edit_mode:
		_rebuild_ghost()

func _on_rotate_requested(step: int) -> void:
	_rotate_by(step)

func _on_selection_cleared() -> void:
	_deselect_placed_piece()

func _on_delete_selection_requested() -> void:
	if is_instance_valid(_selected_placed_piece):
		_erase_piece(_selected_placed_piece)

func _on_test_requested() -> void:
	var editor := get_editor_interface()
	if editor != null and editor.has_method("play_current_scene"):
		editor.play_current_scene()
		dock.set_status("Running current scene.")

func _on_connect_from_selection_requested() -> void:
	if not is_instance_valid(_selected_placed_piece):
		return
	_set_current_layer(roundi(_selected_placed_piece.position.y / CELL.y), false)
	_connect_mode = true
	_connect_first = _selected_placed_piece
	dock.set_connect_active(true)
	dock.set_connect_status("Now click second piece")
	_destroy_ghost()
	_update_context_ui(_last_grid_pos)

func _on_cancel_requested() -> void:
	_cancel_active_mode()

func _on_layer_changed(delta: int) -> void:
	_set_current_layer(_current_layer + delta)

func _on_theme_mode_changed(mode: int) -> void:
	_theme_mode = mode
	_apply_theme_to_all_pieces()

func _on_side_color_changed(color_name: String) -> void:
	_side_color_name = color_name
	_apply_theme_to_all_pieces()

func _on_surface_changed(surface_id: int) -> void:
	_surface = surface_id
	if _edit_mode and not _connect_mode and not _erase_mode:
		_rebuild_ghost()
	_update_context_ui(_last_grid_pos if _edit_mode else NO_HIT)

func _apply_theme_to_all_pieces() -> void:
	if is_instance_valid(_track_root):
		for child in _track_root.get_children():
			if child is Node3D and child.has_method("apply_theme"):
				child.apply_theme(_theme_mode, _side_color_name)
		_refresh_neighbors()
	if is_instance_valid(_ghost) and _ghost.has_method("apply_theme"):
		_ghost.apply_theme(_theme_mode, _side_color_name)
		_ghost.basis = _get_placement_basis()
		_ghost.position = _last_grid_pos
		_set_ghost_alpha(_ghost, 0.4)
	_update_context_ui(_last_grid_pos if _edit_mode else NO_HIT)

# ── viewport input ────────────────────────────────────────────────────────────

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if not _edit_mode:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_rotate_by(1)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if is_instance_valid(_selected_placed_piece):
				_erase_piece(_selected_placed_piece)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if event.keycode == KEY_ESCAPE:
			if _connect_mode or _erase_mode or is_instance_valid(_selected_placed_piece):
				_cancel_active_mode()
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	if not _ensure_track_root():
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseMotion:
		var grid_pos := _raycast_to_grid(viewport_camera, event.position)
		if grid_pos != NO_HIT:
			_last_grid_pos = grid_pos
			var snap_result := _best_snap_position(viewport_camera, event.position, grid_pos)
			_last_snap_pos = snap_result.position
			_snapped_to_anchor = snap_result.is_anchor
			_move_ghost(_last_snap_pos)
			if _snapped_to_anchor and is_instance_valid(_ghost):
				_ghost.rotation_degrees.y = snap_result.rotation_y
			_update_context_ui(_last_snap_pos)
		else:
			_update_context_ui(NO_HIT)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton and event.pressed:
		var picked_piece := _pick_piece_from_cursor(viewport_camera, event.position)
		var pos := _raycast_to_grid(viewport_camera, event.position)
		if pos == NO_HIT and picked_piece == null:
			return EditorPlugin.AFTER_GUI_INPUT_PASS

		if event.button_index == MOUSE_BUTTON_LEFT:
			if _connect_mode:
				var hit := picked_piece
				if hit != null:
					if _connect_first == null:
						_connect_first = hit
						dock.set_connect_status("Now click second piece")
						dock.set_selection_info("Connecting from %s" % _describe_piece(hit), true)
					elif hit != _connect_first:
						_create_connector(_connect_first, hit)
						_connect_first = null
						_connect_mode = false
						dock.set_connect_active(false)
						dock.set_status("Connector created.")
						dock.set_selection_info("Nothing selected", false)
						_update_context_ui(pos if pos != NO_HIT else _last_grid_pos)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			elif _erase_mode:
				if picked_piece != null:
					_erase_piece(picked_piece)
				elif pos != NO_HIT:
					_erase_at(pos)
			else:
				var place_pos := _last_snap_pos if _last_snap_pos != NO_HIT else pos
				var occupied := picked_piece if picked_piece != null else _get_piece_at(place_pos)
				if occupied != null:
					_select_placed_piece(occupied)
				elif place_pos != NO_HIT:
					_deselect_placed_piece()
					_place_piece(place_pos)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

		if event.button_index == MOUSE_BUTTON_RIGHT:
			if picked_piece != null:
				_erase_piece(picked_piece)
			elif pos != NO_HIT:
				_erase_at(pos)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

# ── grid helpers ──────────────────────────────────────────────────────────────

func _raycast_to_grid(cam: Camera3D, screen_pos: Vector2) -> Vector3:
	var origin := cam.project_ray_origin(screen_pos)
	var dir    := cam.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001:
		return NO_HIT
	var plane_y := _current_layer * CELL.y
	var t := (plane_y - origin.y) / dir.y
	if t < 0.0:
		return NO_HIT
	return _snap(origin + dir * t)

func _snap(world_pos: Vector3) -> Vector3:
	return Vector3(
		floorf(world_pos.x / CELL.x) * CELL.x + CELL.x * 0.5,
		_current_layer * CELL.y,
		floorf(world_pos.z / CELL.z) * CELL.z + CELL.z * 0.5
	)


func _best_snap_position(cam: Camera3D, screen_pos: Vector2, grid_pos: Vector3) -> Dictionary:
	## Compare grid snap to all available anchors from placed pieces.
	## Anchors are biased 2× closer (their distance is halved for comparison).
	## Returns { position: Vector3, is_anchor: bool, rotation_y: float }
	if not is_instance_valid(_track_root):
		return {"position": grid_pos, "is_anchor": false, "rotation_y": _rotation_y * 90.0}

	var ray_origin := cam.project_ray_origin(screen_pos)
	var ray_dir := cam.project_ray_normal(screen_pos)

	var best_pos := grid_pos
	var best_rot := _rotation_y * 90.0
	var best_dist := grid_pos.distance_to(ray_origin + ray_dir * ray_origin.distance_to(grid_pos))
	var is_anchor := false

	for child in _track_root.get_children():
		if child == _ghost:
			continue
		var anchors := _connection_anchors_for_piece(child)
		for anchor in anchors:
			var apos: Vector3 = anchor.position
			# Project anchor onto the camera ray to get screen-space distance
			var to_anchor := apos - ray_origin
			var t := to_anchor.dot(ray_dir)
			if t < 0.0:
				continue
			var closest_on_ray := ray_origin + ray_dir * t
			var screen_dist := apos.distance_to(closest_on_ray)

			# Apply anchor bias (halve distance for comparison)
			var biased_dist := screen_dist / GRID_BIAS

			if biased_dist < best_dist and screen_dist < ANCHOR_SNAP_RADIUS:
				best_dist = biased_dist
				# Place at anchor pos, offset by one cell in the anchor's out direction
				var out_dir: Vector3 = anchor.out_dir
				best_pos = apos + out_dir * CELL.x * 0.5
				# Snap the position to grid Y
				best_pos.y = _current_layer * CELL.y
				# Derive rotation from out_dir (incoming piece should face opposite)
				var facing := -out_dir
				best_rot = rad_to_deg(atan2(-facing.x, -facing.z))
				is_anchor = true

	return {"position": best_pos, "is_anchor": is_anchor, "rotation_y": best_rot}

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
	_ghost.basis = _get_placement_basis()
	if _ghost.has_method("apply_theme"):
		_ghost.apply_theme(_theme_mode, _side_color_name)
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
	piece.basis = _get_placement_basis()
	piece.name = _selected_piece + "_" + str(snappedi(grid_pos.x, 1)) + "_" + str(snappedi(grid_pos.y, 1)) + "_" + str(snappedi(grid_pos.z, 1))
	if piece.has_method("apply_theme"):
		piece.apply_theme(_theme_mode, _side_color_name)
	# Pre-set vars before entering tree so _ready()→_build() uses them (no double-build)
	for key in _piece_params:
		piece.set(key, _piece_params[key])

	var undo := get_undo_redo()
	undo.create_action("Place Track Piece")
	undo.add_do_method(_track_root, "add_child", piece)
	undo.add_do_reference(piece)
	undo.add_do_method(piece, "set_owner", scene_root)
	undo.add_undo_method(_track_root, "remove_child", piece)
	undo.commit_action()

	_refresh_neighbors()
	dock.set_status("Placed %s at %s" % [_selected_piece.capitalize(), _grid_to_text(grid_pos)])
	_update_context_ui(grid_pos)

func _erase_at(grid_pos: Vector3) -> void:
	if not _ensure_track_root():
		return
	for child in _track_root.get_children():
		if child.position.is_equal_approx(grid_pos):
			_erase_piece(child)
			return

func _erase_piece(piece: Node3D) -> void:
	if not is_instance_valid(piece) or not _ensure_track_root():
		return
	var scene_root := _get_scene_root()
	var piece_desc := _describe_piece(piece)
	var undo := get_undo_redo()
	undo.create_action("Erase Track Piece")
	undo.add_do_method(_track_root, "remove_child", piece)
	undo.add_undo_method(_track_root, "add_child", piece)
	undo.add_undo_reference(piece)
	if scene_root:
		undo.add_undo_method(piece, "set_owner", scene_root)
	undo.commit_action()
	if _selected_placed_piece == piece:
		_deselect_placed_piece()
	_refresh_neighbors()
	dock.set_status("Removed %s" % piece_desc)
	_update_context_ui(_last_grid_pos)

# ── piece selection ───────────────────────────────────────────────────────────

func _select_placed_piece(piece: Node3D) -> void:
	if _selected_placed_piece == piece:
		return
	_deselect_placed_piece()
	_selected_placed_piece = piece
	_piece_params = piece.get_config() if piece.has_method("get_config") else {}
	if piece.has_method("get_param_defs"):
		dock.show_params(piece.get_param_defs(), piece.get_config())
	dock.set_selection_info(_describe_piece(piece), true)
	dock.set_status("Selected %s" % _describe_piece(piece))
	_set_current_layer(roundi(piece.position.y / CELL.y), false)
	_update_context_ui(piece.position)

func _deselect_placed_piece() -> void:
	_selected_placed_piece = null
	if dock:
		dock.set_selection_info("Nothing selected", false)
		if not _connect_mode and not _erase_mode and _edit_mode and is_instance_valid(_ghost) and _ghost.has_method("get_param_defs"):
			dock.show_params(_ghost.get_param_defs(), _ghost.get_config())
		else:
			dock.clear_params()
	_update_context_ui(_last_grid_pos if _edit_mode else NO_HIT)

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

	var anchor_pair := _select_connection_anchor_pair(piece_a, piece_b)
	var start_anchor: Dictionary = anchor_pair.start
	var end_anchor: Dictionary = anchor_pair.end

	var face_a: Vector3 = start_anchor.position
	var face_b: Vector3 = end_anchor.position
	var start_dir: Vector3 = start_anchor.out_dir
	var end_dir: Vector3 = -end_anchor.out_dir

	var start_width := 6.0
	var end_width := 6.0
	var start_width_val = piece_a.get("road_width")
	var end_width_val = piece_b.get("road_width")
	if start_width_val != null:
		start_width = start_width_val
	if end_width_val != null:
		end_width = end_width_val

	var scene_path := "res://addons/track_editor/pieces/connector.tscn"
	var packed: PackedScene = _scene_cache.get(scene_path)
	if packed == null:
		packed = load(scene_path)
		if packed == null:
			return
		_scene_cache[scene_path] = packed

	var conn: Node3D = packed.instantiate()
	conn.position = face_a
	conn.name = "connector_" + str(snappedi(face_a.x, 1)) + "_" + str(snappedi(face_a.y, 1)) + "_" + str(snappedi(face_a.z, 1))
	if conn.has_method("apply_theme"):
		conn.apply_theme(_theme_mode, _side_color_name)
	conn.set("start_pos",  face_a)
	conn.set("start_dir",  start_dir)
	conn.set("end_pos",    face_b)
	conn.set("end_dir",    end_dir)
	conn.set("start_up",   piece_a.basis.y.normalized())
	conn.set("end_up",     piece_b.basis.y.normalized())
	conn.set("road_width", start_width)
	conn.set("start_width", start_width)
	conn.set("end_width", end_width)

	var undo := get_undo_redo()
	undo.create_action("Connect Track Pieces")
	undo.add_do_method(_track_root, "add_child", conn)
	undo.add_do_reference(conn)
	undo.add_do_method(conn, "set_owner", scene_root)
	undo.add_undo_method(_track_root, "remove_child", conn)
	undo.commit_action()
	dock.set_status("Connected %s to %s" % [_describe_piece(piece_a), _describe_piece(piece_b)])
	_update_context_ui(_last_grid_pos)

func _select_connection_anchor_pair(piece_a: Node3D, piece_b: Node3D) -> Dictionary:
	var start_anchors := _connection_anchors_for_piece(piece_a)
	var end_anchors := _connection_anchors_for_piece(piece_b)
	if start_anchors.is_empty():
		start_anchors = [{"position": piece_a.position, "out_dir": Vector3.FORWARD}]
	if end_anchors.is_empty():
		end_anchors = [{"position": piece_b.position, "out_dir": Vector3.BACK}]

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
				best_start = {"position": start_pos, "out_dir": (start_anchor.out_dir as Vector3).normalized()}
				best_end = {"position": end_pos, "out_dir": (end_anchor.out_dir as Vector3).normalized()}

	return {"start": best_start, "end": best_end}

func _connection_anchors_for_piece(piece: Node3D) -> Array:
	var local_anchors: Array = []
	if piece.has_method("get_connection_anchors"):
		local_anchors = piece.get_connection_anchors()
	else:
		local_anchors = [
			{"position": Vector3(0, 0, 4), "out_dir": Vector3(0, 0, 1)},
			{"position": Vector3(0, 0, -4), "out_dir": Vector3(0, 0, -1)},
		]

	var anchors: Array = []
	for anchor in local_anchors:
		var local_pos: Vector3 = anchor.get("position", Vector3.ZERO)
		var local_dir: Vector3 = anchor.get("out_dir", Vector3.FORWARD)
		anchors.append({
			"position": piece.transform * local_pos,
			"out_dir": (piece.transform.basis * local_dir).normalized(),
		})
	return anchors

func _get_scene_root() -> Node:
	var ei := get_editor_interface()
	if ei == null:
		return null
	return ei.get_edited_scene_root()

func _get_placement_basis() -> Basis:
	var yaw := Basis(Vector3.UP, deg_to_rad(_rotation_y * 90.0))
	var surface_basis: Basis = SURFACE_BASES[_surface]
	return surface_basis * yaw


func _rotate_by(step: int) -> void:
	_rotation_y = posmod(_rotation_y + step, 4)
	if dock:
		dock.set_rotation_turns(_rotation_y)
	if _edit_mode and not _connect_mode and not _erase_mode:
		_rebuild_ghost()
	_update_context_ui(_last_grid_pos)

func _apply_params_to_selected_piece(params: Dictionary) -> void:
	if not is_instance_valid(_selected_placed_piece) or not _selected_placed_piece.has_method("get_config"):
		return
	var old_config: Dictionary = _selected_placed_piece.get_config()
	var new_config := old_config.duplicate()
	for key in params:
		new_config[key] = params[key]
	if old_config == new_config:
		return
	var piece := _selected_placed_piece
	var undo := get_undo_redo()
	undo.create_action("Edit Track Piece")
	undo.add_do_method(piece, "configure", new_config)
	undo.add_do_method(self, "_refresh_neighbors")
	undo.add_undo_method(piece, "configure", old_config)
	undo.add_undo_method(self, "_refresh_neighbors")
	undo.commit_action()
	dock.set_status("Updated %s" % _describe_piece(piece))
	_update_context_ui(piece.position)

func _describe_piece(piece: Node3D) -> String:
	var script := piece.get_script()
	var type_name := "piece"
	if script is Script:
		var path := (script as Script).resource_path.get_file().get_basename()
		if path != "":
			type_name = path.capitalize()
	return "%s at %s" % [type_name, _grid_to_text(piece.position)]

func _grid_to_text(pos: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [pos.x, pos.y, pos.z]

func _set_current_layer(layer: int, refresh_ghost: bool = true) -> void:
	_current_layer = max(layer, 0)
	if dock:
		dock.set_layer(_current_layer, _current_layer * CELL.y)
	if refresh_ghost and _edit_mode and not _connect_mode and not _erase_mode:
		_last_grid_pos.y = _current_layer * CELL.y
		_rebuild_ghost()
	_update_context_ui(_last_grid_pos if _edit_mode else NO_HIT)

func _pick_piece_from_cursor(cam: Camera3D, screen_pos: Vector2) -> Node3D:
	if not is_instance_valid(_track_root):
		return null
	var origin := cam.project_ray_origin(screen_pos)
	var end := origin + cam.project_ray_normal(screen_pos) * 2048.0
	var excludes: Array[RID] = []
	_append_collision_rids(_ghost, excludes)

	for _attempt in range(12):
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = excludes
		var result := cam.get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			return null
		var collider = result.get("collider")
		if collider != null and collider is CollisionObject3D:
			excludes.append((collider as CollisionObject3D).get_rid())
		if collider == null or not (collider is Node):
			continue
		var node := collider as Node
		while node != null and node.get_parent() != _track_root:
			node = node.get_parent()
		if node != null and node is Node3D and node.get_parent() == _track_root:
			return node as Node3D
	return null

func _append_collision_rids(node: Node, excludes: Array[RID]) -> void:
	if node == null:
		return
	if node is CollisionObject3D:
		excludes.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_append_collision_rids(child, excludes)

func _cancel_active_mode() -> void:
	if _connect_mode:
		_connect_mode = false
		_connect_first = null
		dock.set_connect_active(false)
		dock.set_connect_status("")
	if _erase_mode:
		_erase_mode = false
		_on_erase_toggled(false)
		return
	if is_instance_valid(_selected_placed_piece):
		_on_selection_cleared()
	if not _erase_mode and not _connect_mode and _edit_mode:
		_rebuild_ghost()
	_update_context_ui(_last_grid_pos)

func _update_context_ui(hover_pos: Vector3) -> void:
	if dock == null:
		return
	var title := "Browse pieces or enable edit mode."
	var hover := "Cursor: waiting"
	var can_cancel := false
	var can_connect := is_instance_valid(_selected_placed_piece)
	var can_rotate := _edit_mode and not _erase_mode and not _connect_mode

	if not _edit_mode:
		title = "Enable edit mode, choose a piece, then place from the palette."
	elif hover_pos == NO_HIT:
		title = "Move over the active build layer to place pieces."
	else:
		var hovered_piece := _get_piece_at(hover_pos)
		if _connect_mode:
			can_cancel = true
			title = "Connect mode: choose the second piece."
			hover = "Target: %s" % (_describe_piece(hovered_piece) if hovered_piece != null else _grid_to_text(hover_pos))
		elif _erase_mode:
			can_cancel = true
			title = "Erase mode: click a placed piece to remove it."
			hover = "Erase target: %s" % (_describe_piece(hovered_piece) if hovered_piece != null else "empty cell")
		elif hovered_piece != null:
			title = "Occupied cell: select, delete, or connect from this piece."
			hover = "Hover: %s" % _describe_piece(hovered_piece)
		else:
			title = "Open cell: click to place %s." % _selected_piece.capitalize()
			hover = "Place at %s" % _grid_to_text(hover_pos)

	if is_instance_valid(_selected_placed_piece):
		title = "Selection active: tweak settings, connect, delete, or clear."
		can_cancel = true
	if _connect_mode:
		can_connect = false
	title += " Active layer %d." % _current_layer

	dock.set_context_state({
		"title": title,
		"hover": hover,
		"can_connect_from_selection": can_connect,
		"can_cancel": can_cancel,
		"can_rotate": can_rotate,
	})
