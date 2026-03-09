extends Node
class_name MobileControls

# Maps active touch finger indices to which side they're holding.
var _touches: Dictionary = {}  # int -> "left" | "right"
var _is_mobile := false


func _ready() -> void:
	_is_mobile = DisplayServer.is_touchscreen_available()
	if not _is_mobile:
		return

	# Auto-accelerate — fire the event so raycast_car's _unhandled_input picks it up.
	var ev := InputEventAction.new()
	ev.action = "accelerate"
	ev.pressed = true
	Input.parse_input_event(ev)


func _input(event: InputEvent) -> void:
	if not _is_mobile:
		return

	# Consume emulated mouse button events so touch doesn't trigger brake/reverse.
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var half := get_viewport().get_visible_rect().size.x * 0.5
		var side := "left" if event.position.x < half else "right"

		if event.pressed:
			_touches[event.index] = side
		else:
			_touches.erase(event.index)

		_sync_actions()
		get_viewport().set_input_as_handled()


func _sync_actions() -> void:
	var has_left := false
	var has_right := false
	for side: String in _touches.values():
		if side == "left":  has_left  = true
		if side == "right": has_right = true

	if has_left:  Input.action_press("turn_left")
	else:         Input.action_release("turn_left")

	if has_right: Input.action_press("turn_right")
	else:         Input.action_release("turn_right")
