class_name FlightIndicator
extends Control
## Debug readout, top-left: an aeroplane icon whenever the car's flight mode is
## in control (glide / pitch / bank / stall), plus the clearance it decided on.

var air: CarAirControl

var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(150, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.position = Vector2(60, 14)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)


func _process(_delta: float) -> void:
	visible = is_instance_valid(air) and air.flying
	if not visible:
		return
	var clear := air._height_above_ground()
	_label.text = ("STALL" if air.stalled else "FLIGHT") + "\n%s" % ("clear" if clear == INF else "%.1f m" % clear)
	_label.add_theme_color_override("font_color", _colour())
	queue_redraw()


func _colour() -> Color:
	return Color(1.0, 0.35, 0.25) if air.stalled else Color(0.55, 0.9, 1.0)


func _draw() -> void:
	if not visible:
		return
	var c := _colour()
	var o := Vector2(28, 32)                             # icon centre; nose points up
	var plane := PackedVector2Array([
		o + Vector2(0, -24), o + Vector2(3, -18), o + Vector2(3, -6),     # nose, right of fuselage
		o + Vector2(24, 4), o + Vector2(24, 8), o + Vector2(3, 2),        # right wing
		o + Vector2(3, 14), o + Vector2(10, 20), o + Vector2(10, 23),     # right tailplane
		o + Vector2(0, 20),
		o + Vector2(-10, 23), o + Vector2(-10, 20), o + Vector2(-3, 14),  # left tailplane
		o + Vector2(-3, 2), o + Vector2(-24, 8), o + Vector2(-24, 4),     # left wing
		o + Vector2(-3, -6), o + Vector2(-3, -18),
	])
	var outline := plane.duplicate()
	outline.append(plane[0])
	draw_polyline(outline, Color.BLACK, 4.0, true)
	draw_colored_polygon(plane, c)
