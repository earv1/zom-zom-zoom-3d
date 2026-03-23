class_name ObjectiveMarker
extends Control

## Draws screen-edge arrows pointing toward 3D objectives.

const EDGE_MARGIN := 60.0  # pixels from screen edge
const ARROW_SIZE := 20.0
const ICON_SIZE := 12.0
const DISTANCE_FONT_SIZE := 18

var _camera: Camera3D
var _objectives: Array = []
# Each dict: { "node": Node3D, "color": Color, "label": String }


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_3d()
	queue_redraw()


func add_objective(node: Node3D, color: Color = Color.WHITE, label: String = "") -> void:
	_objectives.append({"node": node, "color": color, "label": label})


func remove_objective(node: Node3D) -> void:
	for i in range(_objectives.size() - 1, -1, -1):
		if _objectives[i]["node"] == node:
			_objectives.remove_at(i)


func _draw() -> void:
	if not _camera or not _camera.is_inside_tree():
		return

	_objectives = _objectives.filter(func(o: Dictionary) -> bool: return is_instance_valid(o["node"]))

	var screen_size := get_viewport_rect().size
	var center := screen_size * 0.5

	for obj in _objectives:
		var node: Node3D = obj["node"]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue

		var world_pos: Vector3 = node.global_position
		var color: Color = obj["color"]
		var label: String = obj["label"]

		# Dynamic label for exit gate
		if node.has_method("is_active") and label == "EXIT":
			if not node.is_active():
				color = Color(0.5, 0.5, 0.5)
				label = "EXIT (Lv %d)" % node.REQUIRED_LEVEL
			else:
				color = obj["color"]

		# Distance for the label
		var dist := _camera.global_position.distance_to(world_pos)
		var dist_text: String
		if dist >= 1000.0:
			dist_text = "%.1fkm" % (dist / 1000.0)
		else:
			dist_text = "%dm" % int(dist)

		# Check if behind camera
		var cam_forward := -_camera.global_basis.z
		var to_target := (world_pos - _camera.global_position).normalized()
		var is_behind := cam_forward.dot(to_target) < 0.0

		var screen_pos := _camera.unproject_position(world_pos)

		if is_behind:
			# Flip to opposite side of screen
			screen_pos = center + (center - screen_pos).normalized() * max(screen_size.x, screen_size.y)

		# Check if on screen (with margin)
		var safe_rect := Rect2(
			Vector2(EDGE_MARGIN, EDGE_MARGIN),
			screen_size - Vector2(EDGE_MARGIN, EDGE_MARGIN) * 2.0
		)

		if not is_behind and safe_rect.has_point(screen_pos):
			# On-screen: draw a diamond marker
			_draw_diamond(screen_pos, ICON_SIZE, color)
			_draw_label(screen_pos + Vector2(0, -ICON_SIZE - 14), dist_text, color)
		else:
			# Off-screen: clamp to edge and draw arrow
			var clamped := _clamp_to_edge(screen_pos, center, screen_size)
			var direction := (screen_pos - center).normalized()
			_draw_arrow(clamped, direction, color)
			_draw_label(clamped - direction * (ARROW_SIZE + 16), dist_text, color)
			if label != "":
				_draw_label(clamped - direction * (ARROW_SIZE + 34), label, color)


func _clamp_to_edge(pos: Vector2, center: Vector2, screen_size: Vector2) -> Vector2:
	var dir := pos - center
	if dir.length_squared() < 0.001:
		dir = Vector2.UP

	var margin := EDGE_MARGIN
	var half := (screen_size * 0.5) - Vector2(margin, margin)

	# Scale to fit within margin box
	var scale_x := absf(half.x / dir.x) if absf(dir.x) > 0.001 else 1e10
	var scale_y := absf(half.y / dir.y) if absf(dir.y) > 0.001 else 1e10
	var s := minf(scale_x, scale_y)

	return center + dir * s


func _draw_arrow(pos: Vector2, direction: Vector2, color: Color) -> void:
	var perp := Vector2(-direction.y, direction.x)
	var tip := pos + direction * ARROW_SIZE
	var base_l := pos - direction * ARROW_SIZE * 0.3 + perp * ARROW_SIZE * 0.6
	var base_r := pos - direction * ARROW_SIZE * 0.3 - perp * ARROW_SIZE * 0.6
	var points := PackedVector2Array([tip, base_l, base_r])

	# Draw filled triangle
	draw_colored_polygon(points, color)
	# Outline
	draw_polyline(PackedVector2Array([tip, base_l, base_r, tip]), Color.BLACK, 2.0, true)


func _draw_diamond(pos: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size, 0),
		pos + Vector2(0, size),
		pos + Vector2(-size, 0),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size, 0),
		pos + Vector2(0, size),
		pos + Vector2(-size, 0),
		pos + Vector2(0, -size),
	]), Color.BLACK, 2.0, true)


func _draw_label(pos: Vector2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var fsize := DISTANCE_FONT_SIZE
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	var offset := -text_size * 0.5
	# Shadow
	draw_string(font, pos + offset + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, Color(0, 0, 0, 0.7))
	# Text
	draw_string(font, pos + offset, text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, color)
