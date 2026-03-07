@tool
extends Node2D

@export var curve_base: Curve
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
		_ready()
		queue_redraw()
		size = value
@export var render_background := true
@export var render_curve := true
@export var line_color : Color = Color.GREEN
@export var curve_color : Color = Color.RED

var time_left := 0.0
var points: Array[float]
var start_index := 0
var recent_value : float = 0.0

func _ready() -> void:
	points.clear()
	points.resize(int(size.x+1))
	for i in range(points.size()):
		points[i] = size.y
	#fill_random()
	fill_curve()

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

func fill_curve() -> void:
	var max_size = points.size()
	for i in range(points.size()):
		var bake_i:float = float(i)/max_size
		var p := curve_base.sample_baked(bake_i)
		add_point(p, true, false)
	queue_redraw()


func add_point(new_value: float, do_remap: bool = false, refresh: bool = true) -> void:
	if do_remap:
		new_value = remap(new_value, value_limits.x, value_limits.y, 0.0, size.y)
	var id = (start_index) % points.size()
	points[id] = (size.y-new_value)
	start_index += 1
	if refresh:
		queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not visible: return

	time_left -= delta
	if time_left <= 0:
		time_left += update_time
		if not tracked_node: return

		var value: float
		if evaluate_instead:
			value = evaluate()
		else:
			value = tracked_node.get(tracked_var_name)

		recent_value = remap(value, 0.0, 1.0, 0.0, size.x)
		queue_redraw()


func _draw() -> void:
	if render_background:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(Color.BLACK, 0.5), true)
		draw_text(Vector2(0.0, -5.0), "%s" % [title])
		draw_text(Vector2(5.0, 16.0), "%.3f" % [recent_value], HORIZONTAL_ALIGNMENT_LEFT)

	if render_curve:
		# Draw curve
		var psize := points.size()
		for offset in range(psize-1):
			var i = (start_index + offset) % psize
			var i2 = (i+1) % psize
			var istart := Vector2(offset, points[i])
			var iend := Vector2(offset+1, points[i2])
			draw_line(istart, iend, curve_color, 0.5, true)

	# Draw current line
	var start := Vector2(recent_value, size.y)
	var end := Vector2(recent_value, points[int(recent_value)])
	draw_line(start, end, line_color, 1.0, true)
	start = end
	end.y = 0.0
	draw_line(start, end, Color(line_color, 0.4), 0.4, true)
	draw_circle(start, 3.0, Color(curve_color, 1.0))
	if Engine.is_editor_hint(): return

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
