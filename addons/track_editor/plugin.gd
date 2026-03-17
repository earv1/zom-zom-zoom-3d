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
	_rebuild_ghost()

func _on_edit_mode_changed(active: bool) -> void:
	_edit_mode = active
	if not active:
		_destroy_ghost()

func _on_erase_toggled(active: bool) -> void:
	_erase_mode = active
	if active:
		_destroy_ghost()
	else:
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
			if _erase_mode:
				_erase_at(pos)
			else:
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
	var packed: PackedScene = load(PIECE_SCENES.get(_selected_piece, ""))
	if packed == null:
		return
	_ghost = packed.instantiate()
	_ghost.position = _last_grid_pos   # snap to last known cursor position
	_ghost.rotation_degrees.y = _rotation_y * 90.0
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
	for child in _track_root.get_children():
		if child.position.is_equal_approx(grid_pos):
			return  # cell occupied

	var packed: PackedScene = load(PIECE_SCENES.get(_selected_piece, ""))
	if packed == null:
		return
	var scene_root := _get_scene_root()
	if scene_root == null:
		return

	var piece: Node3D = packed.instantiate()
	piece.position = grid_pos
	piece.rotation_degrees.y = _rotation_y * 90.0
	piece.name = _selected_piece + "_" + str(snappedi(grid_pos.x, 1)) + "_" + str(snappedi(grid_pos.z, 1))

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
			_refresh_neighbors()
			return

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

func _get_scene_root() -> Node:
	var ei := get_editor_interface()
	if ei == null:
		return null
	return ei.get_edited_scene_root()
