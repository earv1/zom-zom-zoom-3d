@tool
extends Node2D

@export var title: String
@export var update_time: float = 0.1
@export var tracked_node: Node
@export var tracked_var_name: String
@export var evaluate_instead: bool = false :
	set(v):
		evaluate_instead = v
		notify_property_list_changed()
@export var font: Font = ThemeDB.fallback_font
@export var value_limits : Vector2 = Vector2(0.0, 100.0)
@export var size: Vector2 = Vector2(200,150) :
	set(value):
		queue_redraw()
		size = value

var time_left := 0.0
var points: Array[float]
var start_index := 0
var recent_value : float = 0.0

func _ready() -> void:
	points.resize(int(size.x))
	for i in range(points.size()):
		points[i] = size.y
	#fill_random()

func evaluate() -> float:
	var expression = Expression.new()
	#var error = expression.parse("tracked_node.global_basis.y", [])
	var error = expression.parse("tracked_node."+tracked_var_name, [])
	if error != OK:
		push_error(expression.get_error_text())
		return 0.0
	var result = expression.execute([], self)
	#if not expression.has_execute_failed():
		#print(str(result))
	return result

func fill_random() -> void:
	var n = randf()
	for i in range(points.size()):
		add_point(n * size.y)
		n = clampf(n+n*randf_range(-0.1,0.1), 0.0, 1.0)

	for i in range(100):
		await get_tree().create_timer(0.2).timeout
		n = clampf(n+n*randf_range(-0.1,0.1), 0.0, 1.0)
		add_point(n * size.y)

func add_point(new_value: float) -> void:
	var id = (start_index) % points.size()
	points[id] = (size.y-new_value)
	start_index += 1
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	time_left -= delta
	if time_left <= 0:
		time_left += update_time
		if not tracked_node: return

		var value: float
		if evaluate_instead:
			value = evaluate()
		else:
			value = tracked_node.get(tracked_var_name)
		recent_value = value
		value = remap(value, value_limits.x, value_limits.y, 0.0, size.y)
		add_point(value)


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color(Color.BLACK, 0.5), true)

	draw_text(Vector2(0.0, -5.0), "%s" % [title])
	draw_text(Vector2(5.0, 16.0), "%.3f" % [recent_value], HORIZONTAL_ALIGNMENT_LEFT)

	if Engine.is_editor_hint(): return

	var psize := points.size()
	for offset in range(psize-1):
		var i = (start_index + offset) % psize
		var i2 = (i+1) % psize
		var start := Vector2(offset, points[i])
		var end := Vector2(offset+1, points[i2])
		draw_line(start, end, Color.RED, 1.0, true)

func draw_text(pos, text, alignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string_outline(font, pos, text,
		alignment, size.x, 16, 8, Color.BLACK)
	draw_string(font, pos, text,
		alignment, size.x)


func _validate_property(property: Dictionary) -> void:
	if property.name == "tracked_var_name":
		if evaluate_instead:
			property.hint = PROPERTY_HINT_MULTILINE_TEXT
		else:
			property.hint = PROPERTY_HINT_NONE
